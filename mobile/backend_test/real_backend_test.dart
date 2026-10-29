// Explicit, disposable local-server acceptance. Never targets the working pilot.
import 'dart:io';
import 'dart:typed_data';

import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/errors/app_error.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/network/compliance_repository.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

final class _LoopbackFixtureAdapter implements HttpClientAdapter {
  _LoopbackFixtureAdapter(this.origin);

  final Uri origin;
  final IOHttpClientAdapter delegate = IOHttpClientAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final uri = options.uri;
    if (origin.scheme != 'http' ||
        origin.host != '127.0.0.1' ||
        !const <int>{18126, 18127}.contains(origin.port) ||
        uri.scheme != 'https' ||
        uri.host != 'compliance-pilot.ms777.ru' ||
        !uri.path.startsWith('/api/v1/')) {
      throw StateError('Only the disposable loopback fixture is permitted.');
    }
    return delegate.fetch(
      options.copyWith(baseUrl: origin.toString(), path: uri.path),
      requestStream,
      cancelFuture,
    );
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

({ComplianceRepository repository, Dio dio}) _repository() {
  final origin = Platform.environment['COMPLIANCE_QA_ORIGIN'];
  if (!const <String>{
        'http://127.0.0.1:18126',
        'http://127.0.0.1:18127',
      }.contains(origin) ||
      (Platform.environment['COMPLIANCE_QA_PASSWORD']?.length ?? 0) < 32) {
    throw StateError('Explicit synthetic fixture credentials are required.');
  }
  final config = AppConfig.validate(<String, String>{
    'APP_ENV': 'staging',
    'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
    'OPENAI_API_ENABLED': 'false',
    'AI_PROVIDER_AUTO_SWITCH': 'false',
    'GIT_COMMIT_SHA': 'local-backend-acceptance',
    'API_SCHEMA_SHA256': File('contracts/openapi-v1.sha256')
        .readAsStringSync()
        .trim()
        .split(' ')
        .first,
  });
  final store = MemorySessionStore();
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUri.toString(),
      followRedirects: false,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = _LoopbackFixtureAdapter(Uri.parse(origin!));
  final client = ApiClient(
    config: config,
    sessionStore: store,
    sessionRevocationMarker: MemorySessionRevocationMarker(),
    diagnostics: SanitizedDiagnostics(),
    dio: dio,
    refreshDio: dio,
  );
  return (
    repository: ComplianceRepository(
      client: client,
      sessionStore: store,
      config: config,
    ),
    dio: dio,
  );
}

Future<String> _login(ComplianceRepository repository, String role) async {
  expect((await repository.health()).status, 'ok');
  expect(
    await repository.login(
      email: 'ui-$role@example.invalid',
      password: Platform.environment['COMPLIANCE_QA_PASSWORD']!,
    ),
    isA<LoginSucceeded>(),
  );
  final organizations = await repository.organizations();
  final organization = organizations.singleWhere(
    (value) => value.shortName == 'Учебный контур',
  );
  expect(organization.role, role);
  expect(
    (await repository.organization(organization.id)).shortName,
    'Учебный контур',
  );
  return organization.id;
}

void main() {
  test(
    'real Django accepts the mobile client workflow and its strict DTOs',
    () async {
      final fixture = _repository();
      final repository = fixture.repository;
      addTearDown(() => fixture.dio.close(force: true));
      final org = await _login(repository, 'owner');
      final nonce = DateTime.now().microsecondsSinceEpoch.toString();
      expect(
        (await repository.currentUser()).email,
        'ui-owner@example.invalid',
      );
      expect(await repository.memberships(org), hasLength(3));
      await repository.restoreSession();
      final website = await repository.createWebsite(org, <String, Object?>{
        'url': 'https://mobile-qa-$nonce.example.invalid/',
        'name': 'Учебный сайт',
        'user_reports_forms': 'unknown',
        'scan_authority_confirmed': true,
      });
      expect(
        (await repository.websites(org)).map((value) => value.id),
        contains(website.id),
      );
      final changedWebsite = await repository.updateWebsite(
        org,
        website.id,
        <String, Object?>{'name': 'Учебный сайт после изменения'},
        website.etag,
      );
      expect(changedWebsite.name, 'Учебный сайт после изменения');
      await expectLater(
        repository.updateWebsite(org, website.id, <String, Object?>{
          'name': 'Устаревшая запись',
        }, website.etag),
        throwsA(
          isA<AppError>().having(
            (error) => error.kind,
            'kind',
            AppErrorKind.conflict,
          ),
        ),
      );
      final service = await repository.createService(org, <String, Object?>{
        'name': 'Учебный хостинг',
        'service_type': 'hosting',
        'primary_country': 'Россия',
        'location_status': 'russian',
        'processing_agreement': 'unknown',
      });
      expect(
        (await repository.services(org)).map((value) => value.id),
        contains(service.id),
      );
      final country = await repository.createCountry(org, <String, Object?>{
        'name': 'Учебная страна $nonce',
        'status': 'unknown',
        'needs_review': true,
      });
      expect(
        (await repository.countries(org)).map((value) => value.id),
        contains(country.id),
      );
      final current = await repository.currentQuestionnaire(org);
      final response =
          current.response ?? await repository.startQuestionnaire(org);
      final saved = await repository.saveQuestionnaire(
        organizationId: org,
        response: response,
        answers: <String, Object?>{'responsible_formalized': 'no'},
        complete: false,
      );
      expect(
        saved.answers.any(
          (answer) =>
              answer.questionCode == 'responsible_formalized' &&
              answer.value == 'no',
        ),
        isTrue,
      );
      final assessment = await repository.runAssessment(org, saved.id);
      expect(assessment.results, isNotEmpty);
      expect(
        (await repository.assessments(org)).map((value) => value.id),
        contains(assessment.id),
      );
      expect(await repository.obligations(org), isNotEmpty);
      final tasks = await repository.checklist(org);
      expect(tasks, isNotEmpty);
      final task = await repository.updateTask(
        org,
        tasks.first,
        <String, Object?>{'status': 'in_progress'},
      );
      expect(task.status, 'in_progress');
      final completedTask = await repository.updateTask(org, task, {
        'status': 'completed',
      });
      expect(completedTask.status, 'completed');
      expect(completedTask.completedAt, isNotNull);
      final reopenedTask = await repository.updateTask(org, completedTask, {
        'status': 'open',
      });
      expect(reopenedTask.status, 'open');
      expect(reopenedTask.completedAt, isNull);
      expect(
        (await repository.checklist(org))
            .singleWhere((item) => item.id == reopenedTask.id)
            .status,
        'open',
      );
      final obligation = (await repository.obligations(org)).first;
      final completionData = <String, Object?>{
        'status': 'completed',
        'completion_date': DateTime.now().toIso8601String().substring(0, 10),
        'completion_comment': 'Учебное подтверждение сохранено после проверки',
        'evidence_absent_confirmed': true,
      };
      const completionKey = '157f6e98-e70f-4449-94c2-33a4814f0851';
      final completedObligation = await repository.updateObligation(
        org,
        obligation,
        completionData,
        idempotencyKey: completionKey,
      );
      final replayedObligation = await repository.updateObligation(
        org,
        obligation,
        completionData,
        idempotencyKey: completionKey,
      );
      expect(replayedObligation.etag, completedObligation.etag);
      expect(
        completedObligation.completionComment,
        completionData['completion_comment'],
      );
      expect((await repository.dashboard(org)).assessments, isNotEmpty);
      expect(await repository.documentTemplates(org), isNotEmpty);
      expect(
        await repository.documents(org),
        isA<List<GeneratedDocumentDto>>(),
      );
      expect(await repository.currentReport(org), isNotEmpty);
      expect((await repository.auditPage(org)).results, isNotEmpty);
      final temporary = await Directory.systemTemp.createTemp(
        'compliance-real-backend-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final file = File('${temporary.path}/synthetic.txt');
      await file.writeAsString(
        'Synthetic UI acceptance only. No personal information.',
      );
      final evidence = await repository.uploadEvidence(
        organizationId: org,
        title: 'Учебное подтверждение',
        filePath: file.path,
        fileName: 'synthetic.txt',
        processingAuthorizedConfirmed: true,
        onProgress: (_, _) {},
      );
      expect(
        (await repository.evidence(org)).map((value) => value.id),
        contains(evidence.id),
      );
      final downloaded = await repository.download(
        'organizations/$org/evidence/${evidence.id}/download/',
      );
      expect(downloaded.bytes, await file.readAsBytes());
      await repository.deleteEvidence(org, evidence);
      expect(
        (await repository.evidence(org)).map((value) => value.id),
        isNot(contains(evidence.id)),
      );
      await repository.deleteWebsite(org, changedWebsite);
      expect(
        (await repository.websites(org)).map((value) => value.id),
        isNot(contains(website.id)),
      );
      await repository.logout();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'real viewer reads the shared saved questionnaire and results',
    () async {
      final fixture = _repository();
      final repository = fixture.repository;
      addTearDown(() => fixture.dio.close(force: true));
      final org = await _login(repository, 'viewer');
      final current = await repository.currentQuestionnaire(org);
      expect(current.response, isNotNull);
      expect(current.response!.answers, isNotEmpty);
      expect(await repository.assessments(org), isNotEmpty);
      expect(await repository.obligations(org), isNotEmpty);
      expect(await repository.currentReport(org), isNotEmpty);
      await repository.logout();
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );

  test(
    'real saved records survive a new login and remain in their organization',
    () async {
      final fixture = _repository();
      final repository = fixture.repository;
      addTearDown(() => fixture.dio.close(force: true));
      final first = await _login(repository, 'owner');
      expect(
        (await repository.obligations(first)).any(
          (item) =>
              item.completionComment ==
              'Учебное подтверждение сохранено после проверки',
        ),
        isTrue,
      );
      final other = await repository.createOrganization({
        'kind': 'llc',
        'short_name': 'Учебная вторая организация',
        'full_name': 'Синтетическая карточка проверки сохранения',
      }, idempotencyKey: '54b1d583-ec63-4248-b4d1-4d439ac1b51a');
      final response = await repository.startQuestionnaire(other.id);
      expect(
        (await repository.obligations(other.id)).any(
          (item) =>
              item.completionComment ==
              'Учебное подтверждение сохранено после проверки',
        ),
        isFalse,
      );
      await repository.saveQuestionnaire(
        organizationId: other.id,
        response: response,
        answers: {'responsible_formalized': 'yes'},
        complete: false,
      );
      final siteData = <String, Object?>{
        'url': 'https://saved-tenant.example.invalid/',
        'name': 'Сохранённый учебный сайт второй организации',
        'scan_authority_confirmed': true,
      };
      const siteKey = '1656455c-30db-4f8e-9b8f-59b64b8e765a';
      final site = await repository.createWebsite(
        other.id,
        siteData,
        idempotencyKey: siteKey,
      );
      final replay = await repository.createWebsite(
        other.id,
        siteData,
        idempotencyKey: siteKey,
      );
      expect(replay.id, site.id);
      const patchKey = '53025b65-9334-422d-beb7-d9686146b265';
      final changed = await repository.updateWebsite(
        other.id,
        site.id,
        {'purpose': 'Синтетическое изменение'},
        site.etag,
        idempotencyKey: patchKey,
      );
      final repeated = await repository.updateWebsite(
        other.id,
        site.id,
        {'purpose': 'Синтетическое изменение'},
        site.etag,
        idempotencyKey: patchKey,
      );
      expect(repeated.etag, changed.etag);
      final serviceData = <String, Object?>{
        'name': 'Учебный сервис второй организации',
        'service_type': 'other',
      };
      const serviceKey = '82bf8d2d-0430-47f5-93bb-d6ae04f763b7';
      final service = await repository.createService(
        other.id,
        serviceData,
        idempotencyKey: serviceKey,
      );
      expect(
        (await repository.createService(
          other.id,
          serviceData,
          idempotencyKey: serviceKey,
        )).id,
        service.id,
      );
      final countryData = <String, Object?>{
        'name': 'Учебная страна второй организации',
        'status': 'unknown',
      };
      const countryKey = 'a79c5fbc-ae0e-4d72-9b5e-51e84704bb20';
      final country = await repository.createCountry(
        other.id,
        countryData,
        idempotencyKey: countryKey,
      );
      expect(
        (await repository.createCountry(
          other.id,
          countryData,
          idempotencyKey: countryKey,
        )).id,
        country.id,
      );
      await repository.logout();
      await _login(repository, 'owner');
      final otherQuestionnaire = await repository.currentQuestionnaire(
        other.id,
      );
      expect(
        otherQuestionnaire.response!.answers
            .singleWhere((a) => a.questionCode == 'responsible_formalized')
            .value,
        'yes',
      );
      final firstQuestionnaire = await repository.currentQuestionnaire(first);
      expect(
        firstQuestionnaire.response!.answers
            .singleWhere((a) => a.questionCode == 'responsible_formalized')
            .value,
        'no',
      );
      expect(
        (await repository.websites(other.id))
            .where((value) => value.id == site.id),
        hasLength(1),
      );
      expect(
        (await repository.services(other.id))
            .where((value) => value.id == service.id),
        hasLength(1),
      );
      expect(
        (await repository.countries(other.id))
            .where((value) => value.id == country.id),
        hasLength(1),
      );
      expect(
        (await repository.websites(first)).any((value) => value.id == site.id),
        isFalse,
      );
      expect(
        (await repository.services(first))
            .any((value) => value.id == service.id),
        isFalse,
      );
      expect(
        (await repository.countries(first))
            .any((value) => value.id == country.id),
        isFalse,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
