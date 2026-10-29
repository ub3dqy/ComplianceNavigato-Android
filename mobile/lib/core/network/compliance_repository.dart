import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import '../config/app_config.dart';
import '../errors/app_error.dart';
import '../storage/secure_session_store.dart';
import 'api_client.dart';
import 'api_models.dart';
import 'sse_parser.dart';

sealed class LoginOutcome {
  const LoginOutcome();
}

final class LoginSucceeded extends LoginOutcome {
  const LoginSucceeded();
}

final class MfaRequired extends LoginOutcome {
  const MfaRequired({required this.methods});

  final List<String> methods;
}

final class DownloadPayload {
  const DownloadPayload({
    required this.bytes,
    required this.contentDisposition,
    required this.contentType,
  });

  final Uint8List bytes;
  final String? contentDisposition;
  final String? contentType;
}

final class DashboardSnapshot {
  const DashboardSnapshot({
    required this.questionnaire,
    required this.obligations,
    required this.tasks,
    required this.assessments,
    required this.scans,
  });

  final CurrentQuestionnaireDto questionnaire;
  final List<ObligationDto> obligations;
  final List<ChecklistItemDto> tasks;
  final List<AssessmentDto> assessments;
  final List<SiteScanDto> scans;
}

final class ComplianceRepository {
  ComplianceRepository({
    required this._client,
    required this._sessionStore,
    required this._config,
  });

  final ApiClient _client;
  final SessionStore _sessionStore;
  final AppConfig _config;
  final SseParser _sseParser = SseParser();

  Future<ApiHealthDto> health() async {
    final Response<Object?> response = await _client.get('health/');
    final ApiHealthDto health = _parseOne(response.data, ApiHealthDto.fromJson);
    if (health.status != 'ok' ||
        health.schemaSha256 != _config.apiSchemaSha256) {
      throw const AppError(
        kind: AppErrorKind.schemaMismatch,
        safeMessage: 'Версия мобильного контракта не совпадает с сервером.',
        code: 'schema_mismatch',
      );
    }
    return health;
  }

  Future<LoginOutcome> login({
    required String email,
    required String password,
    String? mfaCode,
  }) async {
    final Response<Object?> response = await _client.publicPost(
      'auth/login/',
      <String, Object?>{
        'email': email.trim(),
        'password': password,
        if (mfaCode?.trim().isNotEmpty == true) 'mfa_code': mfaCode!.trim(),
      },
    );
    if (response.statusCode == 202) {
      final Map<String, dynamic> json = ApiClient.jsonObject(response.data);
      final Object? rawMethods = json['methods'];
      final List<String> methods = rawMethods is List<dynamic>
          ? rawMethods.whereType<String>().toList(growable: false)
          : const <String>['totp', 'recovery_code'];
      return MfaRequired(methods: methods);
    }
    final TokenPairDto pair = _parseOne(response.data, TokenPairDto.fromJson);
    if (pair.tokenType != 'Bearer') {
      throw const AppError(
        kind: AppErrorKind.malformedResponse,
        safeMessage: 'Сервер вернул неподдерживаемый тип сессии.',
        code: 'invalid_token_type',
      );
    }
    await _sessionStore.writeRefreshToken(pair.refresh);
    _client.setAccessToken(
      pair.access,
      expiresIn: Duration(seconds: pair.accessExpiresIn),
    );
    return const LoginSucceeded();
  }

  Future<void> restoreSession() => _client.refreshSession();

  Future<void> logout() async {
    final String? refresh = await _sessionStore.readRefreshToken();
    try {
      if (refresh != null && refresh.isNotEmpty && _client.hasAccessToken) {
        await _client.post('auth/logout/', <String, Object?>{
          'refresh': refresh,
        }, idempotent: false);
      }
    } on AppError {
      // Local wipe is mandatory even if the network or an already revoked token fails.
    } finally {
      await _client.invalidateLocalSession(notify: false);
    }
  }

  Future<CurrentUserDto> currentUser() async {
    final Response<Object?> response = await _client.get('auth/me/');
    return _parseOne(response.data, CurrentUserDto.fromJson);
  }

  Future<List<OrganizationSummaryDto>> organizations() async {
    final Response<Object?> response = await _client.get('auth/organizations/');
    return _parseList(response.data, OrganizationSummaryDto.fromJson);
  }

  Future<OrganizationDto> createOrganization(
    JsonMap data, {
    required String idempotencyKey,
  }) async {
    final Response<Object?> response = await _client.post(
      'organizations/',
      data,
      idempotencyKey: idempotencyKey,
    );
    return _parseOne(response.data, OrganizationDto.fromJson);
  }

  Future<FnsExtractPreviewDto> previewFnsExtract(
    Uint8List bytes, {
    required String expectedInn,
    required CancelToken cancelToken,
  }) async {
    final response = await _client.upload(
      'organizations/fns-extract/',
      formData: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: 'fns-extract.pdf',
          contentType: DioMediaType('application', 'pdf'),
        ),
        'expected_inn': expectedInn,
      }),
      onSendProgress: (_, _) {},
      cancelToken: cancelToken,
    );
    final result = _parseOne(response.data, FnsExtractPreviewDto.fromJson);
    if (!{'llc', 'ie'}.contains(result.kind) ||
        !RegExp(result.kind == 'ie' ? r'^[0-9]{12}$' : r'^[0-9]{10}$')
            .hasMatch(result.inn) ||
        !RegExp(result.kind == 'ie' ? r'^[0-9]{15}$' : r'^[0-9]{13}$')
            .hasMatch(result.ogrn) ||
        (expectedInn.isNotEmpty && expectedInn != result.inn) ||
        (result.kind == 'ie' &&
            [
              result.fullName,
              result.shortName,
              result.kpp,
              result.legalAddress,
            ].any((v) => v != null))) {
      throw const FormatException('Не удалось проверить реквизиты выписки.');
    }
    return result;
  }

  Future<RegistryPreviewDto> lookupOrganization(
    String inn,
    CancelToken cancelToken,
  ) async {
    final response = await _client.lookupOrganization(inn, cancelToken);
    final result = _parseOne(response.data, RegistryPreviewDto.fromJson);
    final ie = result.kind == 'ie';
    final fields = <(String, int)>[
      (result.fullName, 300),
      (result.shortName, 160),
      (result.legalAddress ?? '', 2000),
      (result.leaderName ?? '', 200),
      (result.okved ?? '', 300),
    ];
    if (!{'llc', 'ie'}.contains(result.kind) ||
        result.inn != inn ||
        !RegExp(ie ? r'^[0-9]{12}$' : r'^[0-9]{10}$').hasMatch(result.inn) ||
        !RegExp(ie ? r'^[0-9]{15}$' : r'^[0-9]{13}$').hasMatch(result.ogrn) ||
        (ie && result.kpp != null) ||
        (result.kpp != null && !RegExp(r'^[0-9]{9}$').hasMatch(result.kpp!)) ||
        result.fullName.trim().isEmpty ||
        result.shortName.trim().isEmpty ||
        fields.any(
          (entry) =>
              entry.$1.length > entry.$2 ||
              entry.$1.runes.any((rune) => rune < 32),
        )) {
      throw const FormatException('Не удалось проверить реквизиты.');
    }
    return result;
  }

  Future<OrganizationDto> organization(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/',
    );
    return _parseOne(response.data, OrganizationDto.fromJson);
  }

  Future<List<MembershipDto>> memberships(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/memberships/',
    );
    return _parseList(response.data, MembershipDto.fromJson);
  }

  Future<DashboardSnapshot> dashboard(String organizationId) async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      currentQuestionnaire(organizationId),
      obligations(organizationId),
      checklist(organizationId),
      assessments(organizationId),
      scans(organizationId),
    ]);
    return DashboardSnapshot(
      questionnaire: values[0] as CurrentQuestionnaireDto,
      obligations: values[1] as List<ObligationDto>,
      tasks: values[2] as List<ChecklistItemDto>,
      assessments: values[3] as List<AssessmentDto>,
      scans: values[4] as List<SiteScanDto>,
    );
  }

  Future<List<WebsiteDto>> websites(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/websites/',
    );
    return _parseList(response.data, WebsiteDto.fromJson);
  }

  Future<WebsiteDto> createWebsite(
    String organizationId,
    JsonMap data, {
    String? idempotencyKey,
  }) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/websites/',
      data,
      idempotencyKey: idempotencyKey,
    );
    return _parseOne(response.data, WebsiteDto.fromJson);
  }

  Future<WebsiteDto> updateWebsite(
    String organizationId,
    String id,
    JsonMap data,
    String etag, {
    String? idempotencyKey,
  }) async {
    final Response<Object?> response = await _client.patch(
      'organizations/$organizationId/websites/$id/',
      data,
      etag: etag,
      idempotencyKey: idempotencyKey,
    );
    return _parseOne(response.data, WebsiteDto.fromJson);
  }

  Future<void> deleteWebsite(String organizationId, WebsiteDto website) async {
    await _client.delete(
      'organizations/$organizationId/websites/${website.id}/',
      etag: website.etag,
    );
  }

  Future<List<ExternalServiceDto>> services(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/external-services/',
    );
    return _parseList(response.data, ExternalServiceDto.fromJson);
  }

  Future<ExternalServiceDto> createService(
    String organizationId,
    JsonMap data, {
    String? idempotencyKey,
  }) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/external-services/',
      data,
      idempotencyKey: idempotencyKey,
    );
    return _parseOne(response.data, ExternalServiceDto.fromJson);
  }

  Future<List<ProcessingCountryDto>> countries(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/countries/',
    );
    return _parseList(response.data, ProcessingCountryDto.fromJson);
  }

  Future<ProcessingCountryDto> createCountry(
    String organizationId,
    JsonMap data, {
    String? idempotencyKey,
  }) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/countries/',
      data,
      idempotencyKey: idempotencyKey,
    );
    return _parseOne(response.data, ProcessingCountryDto.fromJson);
  }

  Future<CurrentQuestionnaireDto> currentQuestionnaire(
    String organizationId,
  ) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/questionnaires/current/',
    );
    return _parseOne(response.data, CurrentQuestionnaireDto.fromJson);
  }

  Future<QuestionnaireResponseDto> startQuestionnaire(
    String organizationId,
  ) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/questionnaires/current/',
      const <String, Object?>{},
    );
    return _parseOne(response.data, QuestionnaireResponseDto.fromJson);
  }

  Future<QuestionnaireResponseDto> saveQuestionnaire({
    required String organizationId,
    required QuestionnaireResponseDto response,
    required JsonMap answers,
    required bool complete,
  }) async {
    final Response<Object?> result = await _client.patch(
      'organizations/$organizationId/questionnaires/${response.id}/',
      <String, Object?>{'answers': answers, 'complete': complete},
      etag: response.etag,
    );
    return _parseOne(result.data, QuestionnaireResponseDto.fromJson);
  }

  Future<List<AssessmentDto>> assessments(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/assessments/',
    );
    return _parseList(response.data, AssessmentDto.fromJson);
  }

  Future<AssessmentDto> runAssessment(
    String organizationId,
    String? responseId,
  ) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/assessments/',
      <String, Object?>{'questionnaire_response_id': ?responseId},
    );
    return _parseOne(response.data, AssessmentDto.fromJson);
  }

  Future<List<ObligationDto>> obligations(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/obligations/',
    );
    return _parseList(response.data, ObligationDto.fromJson);
  }

  Future<ObligationDto> updateObligation(
    String organizationId,
    ObligationDto obligation,
    JsonMap data, {
    String? idempotencyKey,
  }) async {
    final Response<Object?> response = await _client.patch(
      'organizations/$organizationId/obligations/${obligation.id}/',
      data,
      etag: obligation.etag,
      idempotencyKey: idempotencyKey,
    );
    return _parseOne(response.data, ObligationDto.fromJson);
  }

  Future<List<ChecklistItemDto>> checklist(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/checklist/',
    );
    return _parseList(response.data, ChecklistItemDto.fromJson);
  }

  Future<ChecklistItemDto> updateTask(
    String organizationId,
    ChecklistItemDto task,
    JsonMap data,
  ) async {
    final Response<Object?> response = await _client.patch(
      'organizations/$organizationId/checklist/${task.id}/',
      data,
      etag: task.etag,
    );
    return _parseOne(response.data, ChecklistItemDto.fromJson);
  }

  Future<List<SiteScanDto>> scans(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/scan-jobs/',
    );
    return _parseList(response.data, SiteScanDto.fromJson);
  }

  Future<SiteScanDto> createScan(
    String organizationId,
    String websiteId,
  ) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/scan-jobs/',
      <String, Object?>{'website_id': websiteId},
    );
    return _parseOne(response.data, SiteScanDto.fromJson);
  }

  Future<SiteScanDto> scan(String organizationId, String scanId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/scan-jobs/$scanId/',
    );
    return _parseOne(response.data, SiteScanDto.fromJson);
  }

  Future<SiteScanDto> cancelScan(
    String organizationId,
    SiteScanDto scan,
  ) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/scan-jobs/${scan.id}/cancel/',
      const <String, Object?>{},
      etag: scan.etag,
    );
    return _parseOne(response.data, SiteScanDto.fromJson);
  }

  Future<List<DocumentTemplateDto>> documentTemplates(
    String organizationId,
  ) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/document-templates/',
    );
    return _parseList(response.data, DocumentTemplateDto.fromJson);
  }

  Future<List<GeneratedDocumentDto>> documents(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/documents/',
    );
    return _parseList(response.data, GeneratedDocumentDto.fromJson);
  }

  Future<GeneratedDocumentDto> generateDocument(
    String organizationId,
    String templateVersionId,
  ) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/documents/',
      <String, Object?>{'template_version_id': templateVersionId},
    );
    return _parseOne(response.data, GeneratedDocumentDto.fromJson);
  }

  Future<List<EvidenceDto>> evidence(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/evidence/',
    );
    return _parseList(response.data, EvidenceDto.fromJson);
  }

  Future<EvidenceDto> uploadEvidence({
    required String organizationId,
    required String title,
    required String filePath,
    required String fileName,
    required bool processingAuthorizedConfirmed,
    String? obligationId,
    required ProgressCallback onProgress,
    CancelToken? cancelToken,
    void Function()? onAuthReplay,
  }) async {
    if (!processingAuthorizedConfirmed) {
      throw ArgumentError('Не подтверждено право использовать файл.');
    }
    final String? mimeType = lookupMimeType(fileName);
    final FormData form = FormData.fromMap(<String, Object?>{
      'title': title,
      'obligation': ?obligationId,
      'processing_authorized_confirmed': processingAuthorizedConfirmed,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
      ),
    });
    final Response<Object?> response = await _client.upload(
      'organizations/$organizationId/evidence/',
      formData: form,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
      onAuthReplay: onAuthReplay,
    );
    return _parseOne(response.data, EvidenceDto.fromJson);
  }

  Future<void> deleteEvidence(String organizationId, EvidenceDto item) async {
    await _client.delete(
      'organizations/$organizationId/evidence/${item.id}/',
      etag: item.etag,
    );
  }

  Future<DownloadPayload> download(String relativePath) async {
    final Response<Uint8List> response = await _client.download(
      _normalizeDownloadPath(relativePath),
    );
    return DownloadPayload(
      bytes: response.data ?? Uint8List(0),
      contentDisposition: response.headers.value('content-disposition'),
      contentType: response.headers.value('content-type'),
    );
  }

  String _normalizeDownloadPath(String value) {
    const String apiPrefix = '/api/v1/';
    final String trimmed = value.trim();
    final Uri? supplied = Uri.tryParse(trimmed);
    String candidate = trimmed;
    bool rejectedAbsolute = false;
    if (supplied == null) {
      rejectedAbsolute = true;
    } else if (supplied.isAbsolute) {
      rejectedAbsolute =
          !_config.allows(supplied) ||
          supplied.hasQuery ||
          supplied.hasFragment;
      candidate = supplied.path;
    } else if (supplied.hasAuthority) {
      rejectedAbsolute = true;
    }
    final String relative = candidate.startsWith(apiPrefix)
        ? candidate.substring(apiPrefix.length)
        : candidate;
    final Uri? parsed = Uri.tryParse(relative);
    bool encodedPath = false;
    try {
      encodedPath = Uri.decodeComponent(relative) != relative;
    } on FormatException {
      encodedPath = true;
    }
    final bool unsafe =
        rejectedAbsolute ||
        parsed == null ||
        parsed.isAbsolute ||
        parsed.hasAuthority ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        encodedPath ||
        relative.startsWith('/') ||
        relative.contains(r'\') ||
        relative.contains('//') ||
        !relative.startsWith('organizations/') ||
        parsed.pathSegments.any(
          (String segment) => segment == '.' || segment == '..',
        );
    if (unsafe) {
      throw const AppError(
        kind: AppErrorKind.schemaMismatch,
        safeMessage: 'Сервер вернул неподдерживаемый адрес файла.',
        code: 'invalid_download_path',
      );
    }
    return relative;
  }

  Future<JsonMap> currentReport(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/reports/current/',
    );
    return ApiClient.jsonObject(response.data).cast<String, Object?>();
  }

  Future<AuditPageDto> auditPage(
    String organizationId, {
    String? cursor,
  }) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/audit-events/page/',
      query: <String, Object?>{'limit': 50, 'cursor': ?cursor},
    );
    return _parseOne(response.data, AuditPageDto.fromJson);
  }

  Future<List<AiConversationDto>> conversations(String organizationId) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/ai/conversations/',
    );
    return _parseList(response.data, AiConversationDto.fromJson);
  }

  Future<AiConversationDto> createConversation(
    String organizationId,
    String title,
  ) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/ai/conversations/',
      <String, Object?>{'title': title},
    );
    return _parseOne(response.data, AiConversationDto.fromJson);
  }

  Future<AiConversationDto> conversation(
    String organizationId,
    String conversationId,
  ) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/ai/conversations/$conversationId/',
    );
    return _parseOne(response.data, AiConversationDto.fromJson);
  }

  Future<AiRequestDto> sendAiMessage({
    required String organizationId,
    required String conversationId,
    required String message,
    String? assessmentId,
  }) async {
    final Response<Object?> response = await _client.postAiRequest(
      'organizations/$organizationId/ai/conversations/$conversationId/messages/',
      <String, Object?>{
        'message': message,
        'task_type': 'assistant',
        'assessment_id': ?assessmentId,
      },
    );
    return _parseOne(response.data, AiRequestDto.fromJson);
  }

  Stream<AiStreamEvent> streamAiEvents({
    required String organizationId,
    required String conversationId,
    required String requestId,
    int? after,
  }) async* {
    int? cursor = after;
    int failures = 0;
    int renderedCharacters = 0;
    while (true) {
      try {
        final ResponseBody body = await _client.openEventStream(
          'organizations/$organizationId/ai/conversations/$conversationId/messages/'
          '$requestId/events/stream/',
          lastEventId: cursor,
        );
        await for (final AiStreamEvent event in _sseParser.parse(body.stream)) {
          failures = 0;
          if (event.type == 'delta') {
            final Object? rawText = event.payload['text'];
            if (rawText is! String) {
              throw const AppError(
                kind: AppErrorKind.malformedResponse,
                safeMessage: 'Событие AI имеет неверный формат.',
                code: 'invalid_delta_payload',
              );
            }
            renderedCharacters += rawText.runes.length;
            if (renderedCharacters > SseParser.maxRenderedTextCharacters) {
              throw const AppError(
                kind: AppErrorKind.malformedResponse,
                safeMessage: 'Ответ AI превысил безопасный размер.',
                code: 'ai_response_too_large',
              );
            }
          }
          if (event.id != null) {
            cursor = event.id;
          }
          yield event;
          if (event.type == 'close') {
            return;
          }
        }
      } on AppError catch (error) {
        if (!error.canRetrySafely || failures >= 3) {
          rethrow;
        }
        failures += 1;
        await Future<void>.delayed(Duration(seconds: 1 << (failures - 1)));
      }
    }
  }

  Future<AiRequestDto> aiRequest(
    String organizationId,
    String conversationId,
    String requestId,
  ) async {
    final Response<Object?> response = await _client.get(
      'organizations/$organizationId/ai/conversations/$conversationId/messages/$requestId/',
    );
    return _parseOne(response.data, AiRequestDto.fromJson);
  }

  Future<AiRequestDto> cancelAi(
    String organizationId,
    String conversationId,
    AiRequestDto request,
  ) async {
    AiRequestDto current = request;
    const Set<String> terminal = <String>{
      'completed',
      'failed',
      'rejected',
      'cancelled',
      'expired',
    };
    for (int attempt = 0; attempt < 4; attempt += 1) {
      final Response<Object?> response;
      try {
        response = await _client.post(
          'organizations/$organizationId/ai/conversations/$conversationId/messages/'
          '${current.id}/cancel/',
          const <String, Object?>{},
          etag: current.etag,
        );
      } on AppError catch (error) {
        if (error.kind != AppErrorKind.conflict || attempt == 3) {
          rethrow;
        }
        current = await aiRequest(organizationId, conversationId, current.id);
        if (terminal.contains(current.status)) {
          return current;
        }
        continue;
      }
      return _parseOne(response.data, AiRequestDto.fromJson);
    }
    throw StateError('unreachable AI cancellation state');
  }

  Future<AiRequestDto> retryAi(
    String organizationId,
    String conversationId,
    AiRequestDto request,
  ) async {
    final Response<Object?> response = await _client.post(
      'organizations/$organizationId/ai/conversations/$conversationId/messages/'
      '${request.id}/retry/',
      const <String, Object?>{},
      etag: request.etag,
    );
    return _parseOne(response.data, AiRequestDto.fromJson);
  }

  Future<void> decideProposal({
    required String organizationId,
    required String conversationId,
    required String requestId,
    required String proposalId,
    required bool apply,
    required String etag,
  }) async {
    await _client.post(
      'organizations/$organizationId/ai/conversations/$conversationId/messages/'
      '$requestId/proposals/$proposalId/',
      <String, Object?>{'decision': apply ? 'apply' : 'reject'},
      etag: etag,
    );
  }

  Future<void> submitFeedback({
    required String organizationId,
    required String conversationId,
    required String requestId,
    required String rating,
  }) async {
    await _client.post(
      'organizations/$organizationId/ai/conversations/$conversationId/messages/'
      '$requestId/feedback/',
      <String, Object?>{'rating': rating},
    );
  }

  T _parseOne<T>(Object? value, T Function(Map<String, dynamic>) parser) {
    try {
      return parser(ApiClient.jsonObject(value));
    } on AppError {
      rethrow;
    } on Object {
      throw const AppError(
        kind: AppErrorKind.schemaMismatch,
        safeMessage: 'Ответ сервера не соответствует мобильному контракту.',
        code: 'schema_mismatch',
      );
    }
  }

  List<T> _parseList<T>(
    Object? value,
    T Function(Map<String, dynamic>) parser,
  ) {
    try {
      return ApiClient.jsonList(value)
          .map((dynamic item) => parser(ApiClient.jsonObject(item)))
          .toList(growable: false);
    } on AppError {
      rethrow;
    } on Object {
      throw const AppError(
        kind: AppErrorKind.schemaMismatch,
        safeMessage: 'Ответ сервера не соответствует мобильному контракту.',
        code: 'schema_mismatch',
      );
    }
  }
}
