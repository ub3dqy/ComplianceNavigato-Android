import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:compliance_navigator/app/app.dart';
import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/errors/app_error.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/network/compliance_repository.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:compliance_navigator/core/storage/system_file_picker.dart';
import 'package:compliance_navigator/core/storage/transient_file_service.dart';
import 'package:compliance_navigator/core/theme/app_theme.dart';
import 'package:compliance_navigator/core/widgets/async_panel.dart';
import 'package:compliance_navigator/features/ai_assistant/ai_assistant_screen.dart';
import 'package:compliance_navigator/features/assessments/assessments_screen.dart';
import 'package:compliance_navigator/features/audit/audit_screen.dart';
import 'package:compliance_navigator/features/documents/documents_screen.dart';
import 'package:compliance_navigator/features/evidence/evidence_screen.dart';
import 'package:compliance_navigator/features/external_services/external_services_screen.dart';
import 'package:compliance_navigator/features/obligations/obligations_screen.dart';
import 'package:compliance_navigator/features/questionnaires/questionnaire_screen.dart';
import 'package:compliance_navigator/features/reports/reports_screen.dart';
import 'package:compliance_navigator/features/scanner/scanner_screen.dart';
import 'package:compliance_navigator/features/settings/more_screen.dart';
import 'package:compliance_navigator/features/settings/settings_screen.dart';
import 'package:compliance_navigator/features/websites/websites_screen.dart';
import 'package:compliance_navigator/l10n/app_localizations.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/pilot_repository_flow.dart';

const String _schema =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _mismatchSchema =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _now = '2026-08-27T12:00:00Z';
final MemorySessionRevocationMarker _sessionMarker =
    MemorySessionRevocationMarker();

AppConfig _config() => AppConfig.validate(const <String, String>{
  'APP_ENV': 'staging',
  'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
  'OPENAI_API_ENABLED': 'false',
  'AI_PROVIDER_AUTO_SWITCH': 'false',
  'GIT_COMMIT_SHA': 'widget-test',
  'API_SCHEMA_SHA256': _schema,
});

final Map<String, Object?> _version = <String, Object?>{
  'id': 'version-1',
  'version': 'v1',
  'title': 'Анкета пилота',
  'description': 'Только синтетические данные',
  'published_at': _now,
  'questions': <Object?>[
    <String, Object?>{
      'id': 'question-1',
      'code': 'has_website',
      'section': 'Общие сведения',
      'position': 1,
      'text': 'Есть ли у организации сайт?',
      'help_text': 'Выберите один вариант.',
      'question_type': 'tri_state',
      'required': true,
      'critical': false,
      'options': <Object?>[],
      'condition': <String, Object?>{},
    },
    <String, Object?>{
      'id': 'question-2',
      'code': 'contact_channel',
      'section': 'Общие сведения',
      'position': 2,
      'text': 'Какой канал связи используется?',
      'help_text': 'Укажите только синтетические сведения.',
      'question_type': 'short_text',
      'required': false,
      'critical': false,
      'options': <Object?>[],
      'condition': <String, Object?>{},
    },
  ],
};

Map<String, Object?> _response() => <String, Object?>{
  'id': 'response-1',
  'version': _version,
  'status': 'in_progress',
  'progress_percent': 50,
  'completed_at': null,
  'answers': <Object?>[],
  'created_at': _now,
  'updated_at': _now,
  'etag': '"response-etag"',
};

Map<String, Object?> _assessment() => <String, Object?>{
  'id': 'assessment-1',
  'questionnaire_response_id': 'response-1',
  'assessment_as_of': _now,
  'baseline_version': 'PD-2026-08-25-r1',
  'baseline_status': 'needs_review',
  'facts_sha256': _schema.replaceAll('a', 'b'),
  'snapshot_sha256': _schema.replaceAll('a', 'c'),
  'applied_rules_snapshot': <Object?>[],
  'sources_snapshot': <Object?>[],
  'results': <Object?>[
    <String, Object?>{
      'id': 'result-1',
      'rule_code': 'PD-WEB-002',
      'rule_version': '1',
      'outcome': 'needs_review',
      'severity': 'medium',
      'title': 'Проверить сайт',
      'explanation': 'Требуется проверка человеком.',
      'required_actions': <Object?>[],
      'used_facts': <String, Object?>{},
      'source_snapshot': <Object?>[],
    },
  ],
  'created_at': _now,
  'updated_at': _now,
  'etag': '"assessment-etag"',
};

Map<String, Object?> _obligation() => <String, Object?>{
  'id': 'obligation-1',
  'source_assessment_id': 'assessment-1',
  'rule_code': 'PD-WEB-002',
  'title': 'Проверить политику',
  'description': 'Тестовая обязанность',
  'status': 'needs_review',
  'severity': 'medium',
  'due_date': null,
  'due_basis': 'После проверки',
  'responsible_id': null,
  'completed_at': null,
  'completion_date': null,
  'completion_comment': '',
  'evidence_absent_confirmed': false,
  'created_at': _now,
  'updated_at': _now,
  'etag': '"obligation-etag"',
};

final class WidgetAdapter implements HttpClientAdapter {
  WidgetAdapter({
    this.mfa = false,
    this.offline = false,
    this.schemaHash = _schema,
  });

  final bool mfa;
  final bool offline;
  final String schemaHash;
  int loginCalls = 0;

  ResponseBody _body(Object data, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final String path = options.uri.path;
    if (path.endsWith('/health/')) {
      return _body(<String, Object?>{
        'status': 'ok',
        'api_version': '1.0.0',
        'schema_sha256': schemaHash,
      });
    }
    if (path.endsWith('/auth/login/')) {
      loginCalls += 1;
      if (mfa && loginCalls == 1) {
        return _body(<String, Object?>{
          'challenge': 'mfa_required',
          'methods': <String>['totp', 'recovery_code'],
        }, status: 202);
      }
      return _body(<String, Object?>{
        'access': 'access-token',
        'refresh': 'refresh-token',
        'access_expires_in': 300,
        'refresh_expires_in': 86400,
        'token_type': 'Bearer',
      });
    }
    if (path.endsWith('/auth/me/')) {
      return _body(<String, Object?>{
        'id': 'user-1',
        'email': 'pilot@example.invalid',
        'is_staff': false,
        'is_superuser': false,
        'mfa_enabled': mfa,
      });
    }
    if (path.endsWith('/auth/organizations/')) {
      return _body(<Object?>[
        <String, Object?>{
          'id': 'organization-1',
          'short_name': 'Пилот ООО',
          'kind': 'llc',
          'role': 'owner',
          'updated_at': _now,
        },
        <String, Object?>{
          'id': 'organization-2',
          'short_name': 'Другая организация',
          'kind': 'llc',
          'role': 'editor',
          'updated_at': _now,
        },
      ]);
    }
    if (path.endsWith('/questionnaires/current/')) {
      return _body(<String, Object?>{
        'response': _response(),
        'version': _version,
      });
    }
    if (path.endsWith('/questionnaires/response-1/') &&
        options.method == 'PATCH') {
      return _body(_response());
    }
    if (path.endsWith('/obligations/')) {
      return _body(<Object?>[_obligation()]);
    }
    if (path.endsWith('/checklist/')) {
      return _body(<Object?>[]);
    }
    if (path.endsWith('/assessments/')) {
      return _body(<Object?>[_assessment()]);
    }
    if (path.endsWith('/scan-jobs/')) {
      return _body(<Object?>[]);
    }
    if (path.endsWith('/websites/')) {
      return _body(<Object?>[]);
    }
    if (path.endsWith('/document-templates/')) {
      return _body(<Object?>[
        <String, Object?>{
          'id': 'template-1',
          'code': 'privacy-policy',
          'title': 'Политика обработки',
          'version': '1',
          'baseline_version': 'PD-2026-08-25-r1',
          'reviewed_at': '2026-08-25',
        },
      ]);
    }
    if (path.endsWith('/documents/') ||
        path.endsWith('/evidence/') ||
        path.endsWith('/ai/conversations/')) {
      return _body(<Object?>[]);
    }
    if (path.endsWith('/audit-events/page/')) {
      return _body(<String, Object?>{
        'results': <Object?>[],
        'next_cursor': null,
      });
    }
    if (path.endsWith('/reports/current/')) {
      return _body(<String, Object?>{
        'status': 'needs_review',
        'baseline_version': 'PD-2026-08-25-r1',
      });
    }
    return _body(<String, Object?>{});
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(HttpClientAdapter adapter, SessionStore store) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: _config().apiBaseUri.toString(),
      validateStatus: (int? status) =>
          status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = adapter;
  return ApiClient(
    config: _config(),
    sessionStore: store,
    sessionRevocationMarker: _sessionMarker,
    diagnostics: SanitizedDiagnostics(),
    dio: dio,
    refreshDio: dio,
  );
}

final class _ThrowingClearSessionStore implements SessionStore {
  String? refreshToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String value) async {
    refreshToken = value;
  }

  @override
  Future<void> clear() async {
    throw StateError('synthetic secure storage failure');
  }
}

OrganizationSummaryDto _organization() =>
    OrganizationSummaryDto.fromJson(<String, dynamic>{
      'id': 'organization-1',
      'short_name': 'Пилот ООО',
      'kind': 'llc',
      'role': 'owner',
      'updated_at': _now,
    });

OrganizationSummaryDto _otherOrganization() =>
    OrganizationSummaryDto.fromJson(<String, dynamic>{
      'id': 'organization-2',
      'short_name': 'Другая организация',
      'kind': 'llc',
      'role': 'owner',
      'updated_at': _now,
    });

final NotifierProvider<_TestOrganizationController, OrganizationSummaryDto?>
_testOrganizationProvider =
    NotifierProvider<_TestOrganizationController, OrganizationSummaryDto?>(
      _TestOrganizationController.new,
    );

final class _TestOrganizationController
    extends Notifier<OrganizationSummaryDto?> {
  @override
  OrganizationSummaryDto? build() => _organization();

  void select(OrganizationSummaryDto? organization) {
    ref.read(organizationGenerationProvider.notifier).advance();
    state = organization;
  }
}

Future<void> _pumpMutableOrganizationScreen(
  WidgetTester tester,
  Widget screen, {
  required HttpClientAdapter adapter,
  Size size = const Size(390, 844),
  TransientFileService? transientFiles,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final MemorySessionStore store = MemorySessionStore();
  final ApiClient client = _client(adapter, store)
    ..setAccessToken(
      'widget-test-access',
      expiresIn: const Duration(minutes: 5),
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config()),
        sessionStoreProvider.overrideWithValue(store),
        sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
        apiClientProvider.overrideWithValue(client),
        if (transientFiles != null)
          transientFileServiceProvider.overrideWithValue(transientFiles),
        currentOrganizationProvider.overrideWith(
          (Ref ref) => ref.watch(_testOrganizationProvider),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: screen,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  double textScale = 1,
  HttpClientAdapter? adapter,
  SystemFilePicker? filePicker,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final MemorySessionStore store = MemorySessionStore();
  final HttpClientAdapter actualAdapter = adapter ?? WidgetAdapter();
  final ApiClient client = _client(actualAdapter, store)
    ..setAccessToken(
      'widget-test-access',
      expiresIn: const Duration(minutes: 5),
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config()),
        sessionStoreProvider.overrideWithValue(store),
        sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
        apiClientProvider.overrideWithValue(client),
        currentOrganizationProvider.overrideWithValue(_organization()),
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => const AuthState(
            phase: AuthPhase.authenticated,
            user: CurrentUserDto(
              id: 'widget-test-user',
              email: 'pilot@example.invalid',
              isStaff: false,
              isSuperuser: false,
              mfaEnabled: false,
            ),
          ),
        ),
        if (filePicker != null)
          systemFilePickerProvider.overrideWithValue(filePicker),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

base class _WidgetPlatformFile extends PlatformFile {
  _WidgetPlatformFile({
    required this.name,
    required String path,
    this.reportedLength = 23,
  }) : uri = Uri.file(path);

  final int? reportedLength;

  @override
  final String name;

  @override
  final Uri uri;

  @override
  XFile get xFile => XFile(path!);

  @override
  Future<int?> length() async => reportedLength;

  @override
  int? lengthSync() => reportedLength;

  @override
  Future<Uint8List> readAsBytes() => File(path!).readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      File(path!)
          .openRead()
          .map((List<int> chunk) => Uint8List.fromList(chunk));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _sessionMarker.clear();
  });

  test(
    'organization controller switches context and clears selection',
    () async {
      final Directory temporaryRoot = await Directory.systemTemp.createTemp(
        'compliance-navigator-organization-controller-',
      );
      final MemorySessionStore store = MemorySessionStore();
      final WidgetAdapter adapter = WidgetAdapter();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(store),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(adapter, store)),
          transientFileServiceProvider.overrideWithValue(
            TransientFileService(temporaryDirectory: () async => temporaryRoot),
          ),
        ],
      );
      try {
        await container.read(organizationControllerProvider.future);
        final controller = container.read(
          organizationControllerProvider.notifier,
        );
        await controller.load();
        expect(
          container.read(organizationControllerProvider).value?.current?.id,
          'organization-1',
        );
        expect(await controller.select('missing-organization'), isFalse);
        expect(await controller.select('organization-1'), isTrue);

        final int generationBefore = container.read(
          organizationGenerationProvider,
        );
        expect(await controller.select('organization-2'), isTrue);
        expect(
          container.read(organizationControllerProvider).value?.current?.id,
          'organization-2',
        );
        expect(
          container.read(organizationGenerationProvider),
          generationBefore + 1,
        );

        await controller.clear();
        expect(
          container.read(organizationControllerProvider).value?.items,
          isEmpty,
        );
      } finally {
        container.dispose();
        if (await temporaryRoot.exists()) {
          await temporaryRoot.delete(recursive: true);
        }
      }
    },
  );

  testWidgets(
    'login, MFA, organization selection and dashboard work end to end',
    (WidgetTester tester) async {
      final temporaryRoot = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('compliance-login-files-'),
      ))!;
      addTearDown(() async {
        if (await temporaryRoot.exists()) {
          await temporaryRoot.delete(recursive: true);
        }
      });
      final MemorySessionStore store = MemorySessionStore();
      final WidgetAdapter adapter = WidgetAdapter(mfa: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transientFileServiceProvider.overrideWithValue(
              TransientFileService(
                temporaryDirectory: () async => temporaryRoot,
              ),
            ),
            appConfigProvider.overrideWithValue(_config()),
            sessionStoreProvider.overrideWithValue(store),
            sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
            apiClientProvider.overrideWithValue(_client(adapter, store)),
          ],
          child: const ComplianceNavigatorApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Вход в закрытый пилот'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'pilot@example.invalid',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Проверка входа'), findsOneWidget);
      await tester.tap(find.text('Использовать резервный код'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'recovery-code');
      await tester.tap(find.text('Продолжить'));
      for (
        var attempt = 0;
        attempt < 100 && find.text('Пилот ООО').evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Пилот ООО'), findsOneWidget);
      await tester.tap(find.text('Пилот ООО'));
      await tester.pumpAndSettle();
      expect(find.text('Работа по шагам'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(await store.readRefreshToken(), 'refresh-token');
    },
  );

  testWidgets('offline restore keeps the session and offers retry', (
    WidgetTester tester,
  ) async {
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('existing-refresh');
    final WidgetAdapter adapter = WidgetAdapter(offline: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(store),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(adapter, store)),
        ],
        child: const ComplianceNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Нет соединения'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
    expect(await store.readRefreshToken(), 'existing-refresh');
  });

  testWidgets('auth controller clears MFA secrets, invalidates and logs out', (
    WidgetTester tester,
  ) async {
    final MemorySessionStore store = MemorySessionStore();
    final WidgetAdapter adapter = WidgetAdapter(mfa: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(store),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(adapter, store)),
        ],
        child: const ComplianceNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('Вход в закрытый пилот')),
    );
    final controller = container.read(authControllerProvider.notifier);

    await controller.submitMfa('missing-context');
    expect(container.read(authControllerProvider).safeError, 'Повторите вход.');

    final Future<void> mfaLogin = controller.login(
      email: 'pilot@example.invalid',
      password: 'synthetic-password', // pragma: allowlist secret
    );
    await tester.pumpAndSettle();
    await mfaLogin;
    expect(container.read(authControllerProvider).phase, AuthPhase.mfaRequired);
    controller.cancelMfa();
    expect(container.read(authControllerProvider).phase, AuthPhase.signedOut);

    await tester.runAsync(
      () => controller.login(
        email: 'pilot@example.invalid',
        password: 'synthetic-password', // pragma: allowlist secret
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    container.read(sessionSignalsProvider).notifyInvalidated();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(container.read(authControllerProvider).phase, AuthPhase.signedOut);
    expect(
      container.read(authControllerProvider).safeError,
      'Сессия завершена. Проверьте очистку временных файлов и войдите снова.',
    );
  });

  testWidgets('authenticated logout wipes server and local session state', (
    WidgetTester tester,
  ) async {
    final Directory temporaryRoot = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('compliance-navigator-logout-'),
    ))!;
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final MemorySessionStore store = MemorySessionStore();
    final WidgetAdapter adapter = WidgetAdapter();
    final SanitizedDiagnostics diagnostics = SanitizedDiagnostics()
      ..record(
        method: 'GET',
        uri: Uri.parse('https://example.invalid/api/v1/audit/'),
      );
    final TransientFileService transientFiles = TransientFileService(
      temporaryDirectory: () async => temporaryRoot,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(store),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(adapter, store)),
          diagnosticsProvider.overrideWithValue(diagnostics),
          transientFileServiceProvider.overrideWithValue(transientFiles),
        ],
        child: const ComplianceNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('Вход в закрытый пилот')),
    );
    final controller = container.read(authControllerProvider.notifier);
    await tester.runAsync(
      () => controller.login(
        email: 'pilot@example.invalid',
        password: 'synthetic-password', // pragma: allowlist secret
      ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    final File transient = (await tester.runAsync(
      () => container
          .read(transientFileServiceProvider)
          .save(
            DownloadPayload(
              bytes: Uint8List.fromList(<int>[1, 2, 3]),
              contentDisposition: 'attachment; filename="logout.json"',
              contentType: 'application/json',
            ),
            scope: 'organization-1',
            fallbackName: 'logout.json',
            allowedExtensions: const <String>{'.json'},
          ),
    ))!;
    expect(await tester.runAsync(transient.exists), isTrue);
    expect(diagnostics.entries, isNotEmpty);
    await tester.runAsync(controller.logout);
    await tester.pumpAndSettle();
    expect(container.read(authControllerProvider).phase, AuthPhase.signedOut);
    expect(await store.readRefreshToken(), isNull);
    expect(adapter.loginCalls, 1);
    expect(diagnostics.entries, isEmpty);
    expect(await tester.runAsync(transient.parent.exists), isFalse);
  });

  testWidgets('logout still signs out when secure storage clear fails', (
    WidgetTester tester,
  ) async {
    final Directory temporaryRoot = (await tester.runAsync(
      () => Directory.systemTemp.createTemp(
        'compliance-navigator-storage-failure-',
      ),
    ))!;
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final _ThrowingClearSessionStore store = _ThrowingClearSessionStore();
    final WidgetAdapter adapter = WidgetAdapter();
    final TransientFileService transientFiles = TransientFileService(
      temporaryDirectory: () async => temporaryRoot,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(store),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(adapter, store)),
          transientFileServiceProvider.overrideWithValue(transientFiles),
        ],
        child: const ComplianceNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('Вход в закрытый пилот')),
    );
    await tester.runAsync(
      () => container
          .read(authControllerProvider.notifier)
          .login(
            email: 'pilot@example.invalid',
            password: 'synthetic-password', // pragma: allowlist secret
          ),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(authControllerProvider).phase,
      AuthPhase.authenticated,
    );
    final File transient = (await tester.runAsync(
      () => transientFiles.save(
        DownloadPayload(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          contentDisposition: 'attachment; filename="logout.json"',
          contentType: 'application/json',
        ),
        scope: 'organization-1',
        fallbackName: 'logout.json',
        allowedExtensions: const <String>{'.json'},
      ),
    ))!;

    await tester.runAsync(
      () => container
          .read(authControllerProvider.notifier)
          .logout()
          .timeout(const Duration(seconds: 10)),
    );
    await tester.pumpAndSettle();

    final AuthState auth = container.read(authControllerProvider);
    expect(auth.phase, AuthPhase.signedOut);
    expect(auth.busy, isFalse);
    expect(auth.safeError, contains('очищены не полностью'));
    expect(await tester.runAsync(transient.exists), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(store),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(adapter, store)),
          transientFileServiceProvider.overrideWithValue(transientFiles),
        ],
        child: const ComplianceNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Вход в закрытый пилот'), findsOneWidget);
    expect(find.text('Обзор'), findsNothing);
    expect(adapter.loginCalls, 1);
  });

  testWidgets('schema mismatch blocks restore and offline login stays safe', (
    WidgetTester tester,
  ) async {
    final MemorySessionStore blockedStore = MemorySessionStore();
    await blockedStore.writeRefreshToken('existing-refresh');
    final WidgetAdapter mismatch = WidgetAdapter(schemaHash: _mismatchSchema);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(blockedStore),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(mismatch, blockedStore)),
        ],
        child: const ComplianceNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('контракта не совпадает'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final MemorySessionStore offlineStore = MemorySessionStore();
    final WidgetAdapter offline = WidgetAdapter(offline: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(offlineStore),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(_client(offline, offlineStore)),
        ],
        child: const ComplianceNavigatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.text('Вход в закрытый пилот')),
    );
    final Future<void> login = container
        .read(authControllerProvider.notifier)
        .login(
          email: 'pilot@example.invalid',
          password: 'synthetic-password', // pragma: allowlist secret
        );
    await tester.pumpAndSettle();
    await login;
    expect(container.read(authControllerProvider).phase, AuthPhase.signedOut);
    expect(container.read(authControllerProvider).safeError, isNotEmpty);
  });

  testWidgets('questionnaire and obligations render protected pilot data', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const QuestionnaireScreen());
    expect(find.text('Есть ли у организации сайт?'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .semanticsValue,
      '50%',
    );

    await _pumpScreen(tester, const ObligationsScreen());
    expect(find.text('Проверить политику'), findsOneWidget);
  });

  testWidgets('assessment, scanner, documents and evidence have real states', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, const AssessmentsScreen());
    expect(find.textContaining('PD-2026-08-25-r1'), findsOneWidget);
    await tester.tap(find.textContaining('Оценка от'));
    await tester.pumpAndSettle();
    expect(find.text('Проверить сайт'), findsOneWidget);

    await _pumpScreen(tester, const ScannerScreen());
    expect(find.text('Проверок пока нет.'), findsOneWidget);
    await _pumpScreen(tester, const DocumentsScreen());
    await tester.tap(find.text('Доступные шаблоны'));
    await tester.pumpAndSettle();
    expect(find.text('Политика обработки'), findsOneWidget);
    await _pumpScreen(tester, const EvidenceScreen());
    expect(find.text('Подтверждений пока нет.'), findsOneWidget);
  });

  testWidgets('shared async panel renders safe success and retry states', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      AsyncPanel<String>(
        future: Future<String>.value('Готово'),
        builder: (BuildContext context, String value) => Text(value),
        onRetry: () {},
      ),
    );
    expect(find.text('Готово'), findsOneWidget);

    int retries = 0;
    await _pumpScreen(
      tester,
      AsyncPanel<String>(
        future: Future<String>.delayed(
          Duration.zero,
          () => throw const AppError(
            kind: AppErrorKind.offline,
            safeMessage: 'Нет безопасного соединения.',
          ),
        ),
        builder: (BuildContext context, String value) => Text(value),
        onRetry: () => retries += 1,
      ),
    );
    expect(find.text('Нет безопасного соединения.'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    expect(retries, 1);
  });

  testWidgets('AI assistant and settings fit dark tablet and large text', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      const AiAssistantScreen(),
      size: const Size(800, 1280),
      brightness: Brightness.dark,
      textScale: 1.3,
    );
    expect(find.text('Помощник'), findsOneWidget);
    expect(find.textContaining('Вопрос AI'), findsOneWidget);

    await _pumpScreen(tester, const SettingsScreen(), textScale: 2);
    await tester.scrollUntilVisible(
      find.text('О приложении'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('О приложении'), findsOneWidget);
    expect(
      find.textContaining('Можно использовать реальные сведения'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('website management requires authority and confirms deletion', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(tester, const WebsitesScreen(), adapter: adapter);
    expect(find.text('Тестовый сайт'), findsOneWidget);
    expect(find.textContaining('https://example.invalid'), findsOneWidget);

    await tester.tap(find.byTooltip('Изменить сайт'));
    await tester.pumpAndSettle();
    expect(find.text('Изменить сайт'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Назначение'),
      'Обновлённый синтетический тест',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'PATCH' &&
            request.path.endsWith('/websites/website-1/'),
      ),
      isTrue,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить сайт?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'DELETE' &&
            request.path.endsWith('/websites/website-1/'),
      ),
      isTrue,
    );
  });

  testWidgets('external service and country forms submit synthetic records', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const ExternalServicesScreen(),
      size: const Size(800, 1280),
      adapter: adapter,
    );
    expect(find.text('Тестовый сервис'), findsOneWidget);
    expect(find.text('Страна: Россия'), findsOneWidget);

    await tester.tap(find.byTooltip('Добавить сервис'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Название'),
      'Новый синтетический сервис',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Назначение'),
      'Проверка',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'POST' &&
            request.path.endsWith('/external-services/'),
      ),
      isTrue,
    );

    await tester.tap(find.text('Страны'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Добавить страну'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Страна'),
      'Вымышленная страна',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Цель обработки'),
      'Синтетическая проверка',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'POST' && request.path.endsWith('/countries/'),
      ),
      isTrue,
    );
  });

  testWidgets('audit, reports and complete more menu render pilot content', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(tester, const AuditScreen(), adapter: adapter);
    expect(find.text('Синтетическое событие'), findsOneWidget);
    await tester.tap(find.text('Сведения о событии'));
    await tester.pumpAndSettle();
    expect(find.textContaining('scope: synthetic'), findsOneWidget);
    expect(find.textContaining('must-not-render'), findsNothing);
    expect(find.text('Больше событий нет.'), findsOneWidget);
    await tester.tap(find.byTooltip('Обновить'));
    await tester.pumpAndSettle();

    await _pumpScreen(tester, const ReportsScreen(), adapter: adapter);
    expect(find.text('Сводка по организации'), findsOneWidget);
    expect(find.textContaining('PD-2026-08-25-r1'), findsOneWidget);
    await tester.tap(find.text('Выбрать формат'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Открыть HTML'), findsOneWidget);

    await _pumpScreen(tester, const MoreScreen(), adapter: adapter);
    expect(find.text('Пилот ООО'), findsOneWidget);
    expect(find.text('Сайты'), findsOneWidget);
    expect(find.text('Журнал действий'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Настройки'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('AI stream shows evidence, proposals and feedback controls', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const AiAssistantScreen(),
      size: const Size(700, 3000),
      adapter: adapter,
    );
    await tester.tap(find.byTooltip('Разговоры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Синтетический разговор'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Вопрос AI-помощнику'),
      'Объясни синтетический результат',
    );
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();

    expect(find.text('Синтетическое объяснение'), findsOneWidget);
    expect(find.textContaining('draft_wording'), findsNothing);
    expect(find.textContaining('Формулировка черновика'), findsOneWidget);
    await tester.tap(find.text('Источники и основания'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SRC-SYNTHETIC'), findsOneWidget);
    expect(find.textContaining('PD-WEB-002'), findsOneWidget);
    expect(find.textContaining('Требуется проверка'), findsWidgets);
    expect(find.textContaining('synthetic_only'), findsOneWidget);
    expect(find.textContaining('До: Старый текст'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Отклонить'));
    await tester.pumpAndSettle();
    expect(find.text('Отклонить предложение?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Отклонить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.path.endsWith('/proposals/proposal-1/'),
      ),
      isTrue,
    );

    await tester.tap(find.text('Полезно'));
    await tester.pumpAndSettle();
    expect(find.text('Отзыв сохранён.'), findsOneWidget);
  });

  testWidgets(
    'completed AI answer is not replaced by an available rate-limit warning',
    (WidgetTester tester) async {
      final LocalFakeApiAdapter adapter = LocalFakeApiAdapter(
        sseEvents:
            'id: 1\nevent: rate_limit\ndata: {"state":"available","resetAt":null}\n\n'
            'id: 2\nevent: delta\ndata: {"text":"Синтетическое объяснение"}\n\n'
            'id: 3\nevent: completed\ndata: {"status":"completed"}\n\n'
            'event: close\ndata: {"status":"completed"}\n\n',
      );
      await _pumpScreen(
        tester,
        const AiAssistantScreen(),
        size: const Size(700, 3000),
        adapter: adapter,
      );
      await tester.tap(find.byTooltip('Разговоры'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Синтетический разговор'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Вопрос AI-помощнику'),
        'Проверь порядок событий',
      );
      await tester.tap(find.byTooltip('Отправить'));
      await tester.pumpAndSettle();

      expect(find.text('Синтетическое объяснение'), findsOneWidget);
      expect(find.text('Ответ готов'), findsOneWidget);
      await tester.tap(find.text('Сведения об ответе'));
      await tester.pumpAndSettle();
      expect(find.text('Лимит доступен'), findsOneWidget);
      expect(find.textContaining('Достигнут лимит AI'), findsNothing);
    },
  );

  testWidgets('AI queued request can be cancelled and retried', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter(
      sseEvents: 'event: close\ndata: {"status":"queued"}\n\n',
    );
    await _pumpScreen(tester, const AiAssistantScreen(), adapter: adapter);
    await tester.tap(find.byTooltip('Разговоры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Синтетический разговор'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Вопрос AI-помощнику'),
      'Тест отмены',
    );
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) => request.path.endsWith('/retry/'),
      ),
      isTrue,
    );
  });

  testWidgets('new AI conversation shows the personal-data notice', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      const AiAssistantScreen(),
      adapter: LocalFakeApiAdapter(),
    );
    await tester.tap(find.byTooltip('Разговоры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Новый разговор'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Название организации, реквизиты ИП'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Отправить'), findsOneWidget);
  });

  testWidgets('first AI message cannot bypass the personal-data notice', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const AiAssistantScreen(),
      size: const Size(900, 1000),
      adapter: adapter,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Вопрос AI-помощнику'),
      'Первый синтетический вопрос',
    );
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Название организации, реквизиты ИП'),
      findsOneWidget,
    );
    expect(
      adapter.requests.where(
        (RequestOptions request) => request.method == 'POST',
      ),
      isEmpty,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextField, 'Вопрос AI-помощнику'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Отправить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'POST' &&
            request.path.endsWith('/ai/conversations/'),
      ),
      isTrue,
    );
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'POST' && request.path.endsWith('/messages/'),
      ),
      isTrue,
    );
  });

  testWidgets('AI content clears before another organization is loaded', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpMutableOrganizationScreen(
      tester,
      const AiAssistantScreen(),
      adapter: adapter,
      size: const Size(900, 1000),
    );
    await tester.tap(find.byTooltip('Разговоры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Синтетический разговор'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (request) => request.path.endsWith('/ai/conversations/conversation-1/'),
      ),
      isTrue,
    );
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    container
        .read(_testOrganizationProvider.notifier)
        .select(
          OrganizationSummaryDto.fromJson(<String, dynamic>{
            'id': 'organization-2',
            'short_name': 'Другая организация',
            'kind': 'llc',
            'role': 'owner',
            'updated_at': _now,
          }),
        );
    await tester.pump();
    expect(find.text('Синтетический разговор'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('late AI response cannot restore the previous organization', (
    WidgetTester tester,
  ) async {
    final Completer<void> releaseMessage = Completer<void>();
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter(
      beforeResponse: (RequestOptions request) async {
        if (request.method == 'POST' && request.path.endsWith('/messages/')) {
          await releaseMessage.future;
        }
      },
    );
    await _pumpMutableOrganizationScreen(
      tester,
      const AiAssistantScreen(),
      adapter: adapter,
      size: const Size(900, 1000),
    );
    await tester.tap(find.byTooltip('Разговоры'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Синтетический разговор'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Вопрос AI-помощнику'),
      'Запоздалый синтетический ответ',
    );
    await tester.tap(find.byTooltip('Отправить'));
    await tester.pump();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(AiAssistantScreen)),
    );
    container
        .read(_testOrganizationProvider.notifier)
        .select(_otherOrganization());
    await tester.pump();
    releaseMessage.complete();
    await tester.pumpAndSettle();

    expect(find.text('Синтетическое объяснение'), findsNothing);
    expect(find.text('Синтетическое'), findsNothing);
    expect(find.text('Синтетический разговор'), findsNothing);
  });

  testWidgets('late audit page is discarded after organization switch', (
    WidgetTester tester,
  ) async {
    final Completer<void> releaseAudit = Completer<void>();
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter(
      beforeResponse: (RequestOptions request) async {
        if (request.path.contains('/organizations/organization-1/') &&
            request.path.endsWith('/audit-events/page/')) {
          await releaseAudit.future;
        }
      },
    );
    await _pumpMutableOrganizationScreen(
      tester,
      const AuditScreen(),
      adapter: adapter,
      settle: false,
    );
    await tester.pump();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(AuditScreen)),
    );
    container
        .read(_testOrganizationProvider.notifier)
        .select(_otherOrganization());
    await tester.pump();
    releaseAudit.complete();
    await tester.pumpAndSettle();

    expect(find.text('Синтетическое событие'), findsNothing);
  });

  testWidgets(
    'late download is not saved or opened after organization switch',
    (WidgetTester tester) async {
      final Completer<void> releaseDownload = Completer<void>();
      final LocalFakeApiAdapter adapter = LocalFakeApiAdapter(
        beforeResponse: (RequestOptions request) async {
          if (request.responseType == ResponseType.bytes) {
            await releaseDownload.future;
          }
        },
      );
      final Directory temporaryRoot = (await tester.runAsync(
        () => Directory.systemTemp.createTemp(
          'compliance-navigator-tenant-download-',
        ),
      ))!;
      addTearDown(() async {
        if (await temporaryRoot.exists()) {
          await temporaryRoot.delete(recursive: true);
        }
      });
      var opened = false;
      final TransientFileService transientFiles = TransientFileService(
        temporaryDirectory: () async => temporaryRoot,
        openFile: (_) async => opened = true,
      );
      await _pumpMutableOrganizationScreen(
        tester,
        const EvidenceScreen(),
        adapter: adapter,
        transientFiles: transientFiles,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Открыть'));
      await tester.pump();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(EvidenceScreen)),
      );
      container
          .read(_testOrganizationProvider.notifier)
          .select(_otherOrganization());
      await tester.pump();
      container
          .read(_testOrganizationProvider.notifier)
          .select(_organization());
      await tester.pump();
      releaseDownload.complete();
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      final bool hasNoFiles = (await tester.runAsync(
        () =>
            Directory(temporaryRoot.path)
                .list(recursive: true)
                .where((FileSystemEntity item) => item is File)
                .isEmpty,
      ))!;
      expect(hasNoFiles, isTrue);
    },
  );

  testWidgets('questionnaire answer is edited and completed explicitly', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(tester, const QuestionnaireScreen(), adapter: adapter);
    await tester.tap(find.text('Да'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нет').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Завершить'));
    await tester.pumpAndSettle();
    expect(find.text('Анкета завершена.'), findsOneWidget);
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'PATCH' &&
            request.path.endsWith('/questionnaires/response-1/'),
      ),
      isTrue,
    );
  });

  testWidgets('questionnaire clears tenant state and keeps leave warning', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpMutableOrganizationScreen(
      tester,
      const QuestionnaireScreen(),
      adapter: adapter,
    );
    expect(find.text('Есть сайт?'), findsOneWidget);
    await tester.tap(find.text('Да'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Нет').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Обновить'));
    await tester.pumpAndSettle();
    expect(find.text('Несохранённые изменения'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Остаться'));
    await tester.pumpAndSettle();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(QuestionnaireScreen)),
    );
    container
        .read(_testOrganizationProvider.notifier)
        .select(
          OrganizationSummaryDto.fromJson(<String, dynamic>{
            'id': 'organization-2',
            'short_name': 'Другая организация',
            'kind': 'llc',
            'role': 'owner',
            'updated_at': _now,
          }),
        );
    await tester.pump();
    expect(find.text('Есть сайт?'), findsNothing);
    expect(find.text('Да'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('obligations and checklist require explicit user actions', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const ObligationsScreen(),
      size: const Size(700, 1200),
      adapter: adapter,
    );
    await tester.tap(find.text('Проверить политику'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Подтвердить выполнение'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Комментарий'),
      'Синтетическая проверка завершена',
    );
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'PATCH' &&
            request.path.endsWith('/obligations/obligation-1/'),
      ),
      isTrue,
    );

    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Подготовить черновик'),
    );
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'PATCH' &&
            request.path.endsWith('/checklist/task-1/'),
      ),
      isTrue,
    );
  });

  testWidgets('scanner starts and repeats an authorized synthetic scan', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const ScannerScreen(),
      size: const Size(700, 1200),
      adapter: adapter,
    );
    expect(find.textContaining('https://example.invalid'), findsWidgets);
    expect(find.textContaining('Проверка завершена'), findsOneWidget);
    expect(find.textContaining('completed'), findsNothing);
    await tester.tap(find.textContaining('https://example.invalid').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('форм: 1'), findsOneWidget);
    expect(find.textContaining('assets.example.invalid'), findsOneWidget);
    expect(find.text('Проверить форму'), findsOneWidget);
    expect(find.textContaining('Уверенность: Высокая'), findsOneWidget);
    await tester.tap(find.byTooltip('Повторить').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Новая проверка'));
    await tester.pumpAndSettle();
    expect(find.text('Новая проверка сайта'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Запустить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests
          .where(
            (RequestOptions request) =>
                request.method == 'POST' &&
                request.path.endsWith('/scan-jobs/'),
          )
          .length,
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('documents are generated and evidence can be deleted', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const DocumentsScreen(),
      size: const Size(700, 1200),
      adapter: adapter,
    );
    expect(find.text('Политика обработки'), findsOneWidget);
    await tester.tap(find.text('Сведения о документе'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Контрольная сумма сохранена'), findsOneWidget);
    expect(find.textContaining('SHA-256:'), findsNothing);
    await tester.tap(find.byTooltip('Создать документ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Создать'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'POST' && request.path.endsWith('/documents/'),
      ),
      isTrue,
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Открыть HTML'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.path.endsWith('/documents/document-1/download/html/'),
      ),
      isTrue,
    );

    await _pumpScreen(
      tester,
      const EvidenceScreen(),
      size: const Size(700, 1200),
      adapter: adapter,
    );
    expect(find.text('Синтетическое подтверждение'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Открыть'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.path.endsWith('/evidence/evidence-1/download/'),
      ),
      isTrue,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить подтверждение?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'DELETE' &&
            request.path.endsWith('/evidence/evidence-1/'),
      ),
      isTrue,
    );
  });

  testWidgets('evidence upload refreshes in place without a second picker', (
    WidgetTester tester,
  ) async {
    final File file = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'test${Platform.pathSeparator}fixtures${Platform.pathSeparator}'
      'device-remediation-synthetic.txt',
    );
    expect(await tester.runAsync(file.exists), isTrue);
    int pickerCalls = 0;
    int cleanupCalls = 0;
    final SystemFilePicker picker = SystemFilePicker(
      pickEvidence: () async {
        pickerCalls += 1;
        return _WidgetPlatformFile(name: 'synthetic.txt', path: file.path);
      },
      clearTemporaryFiles: () async => cleanupCalls += 1,
    );
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter(
      evidenceUnauthorizedOnce: true,
      drainRequestBodies: false,
    );
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('valid-refresh');
    final ApiClient client = _client(adapter, store)
      ..setAccessToken(
        'server-rejected-access',
        expiresIn: const Duration(minutes: 10),
      );

    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config()),
          sessionStoreProvider.overrideWithValue(store),
          sessionRevocationMarkerProvider.overrideWithValue(_sessionMarker),
          apiClientProvider.overrideWithValue(client),
          currentOrganizationProvider.overrideWithValue(_organization()),
          systemFilePickerProvider.overrideWithValue(picker),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const EvidenceScreen(),
        ),
      ),
    );
    for (int attempt = 0; attempt < 100; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byTooltip('Добавить подтверждение').evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.tap(find.byTooltip('Добавить подтверждение'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Загрузить'))
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.textContaining(
        'Подтверждаю право использовать файл в этой организации',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Загрузить'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Загрузить'));
    await tester.pump();
    await tester.runAsync(() async {
      for (int attempt = 0; attempt < 100; attempt += 1) {
        if (adapter.evidenceUploadCalls == 2) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    for (int attempt = 0; attempt < 100; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (adapter.evidenceUploadCalls == 2 &&
          find.byTooltip('Отменить загрузку').evaluate().isEmpty) {
        break;
      }
    }

    expect(pickerCalls, 1);
    expect(cleanupCalls, 1);
    expect(adapter.evidenceUploadCalls, 2);
    expect(adapter.refreshCalls, 1);
    expect(find.text('Подтверждения'), findsOneWidget);
    expect(find.text('Синтетическое подтверждение'), findsOneWidget);
    expect(find.textContaining('Сессия завершена'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('unknown file size blocks upload and clears picker cache', (
    WidgetTester tester,
  ) async {
    int cleanupCalls = 0;
    final SystemFilePicker picker = SystemFilePicker(
      pickEvidence: () async => _WidgetPlatformFile(
        name: 'synthetic.txt',
        path: '/synthetic/proof.txt',
        reportedLength: null,
      ),
      clearTemporaryFiles: () async => cleanupCalls += 1,
    );
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const EvidenceScreen(),
      size: const Size(700, 1200),
      adapter: adapter,
      filePicker: picker,
    );
    await tester.tap(find.byTooltip('Добавить подтверждение'));
    await tester.pumpAndSettle();
    expect(adapter.evidenceUploadCalls, 0);
    expect(cleanupCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Не удалось определить размер файла. Выберите другой файл.'),
      findsOneWidget,
    );
  });

  testWidgets('evidence picker cache is cleared after dialog cancellation', (
    WidgetTester tester,
  ) async {
    final File file = File(
      '${Directory.current.path}${Platform.pathSeparator}'
      'test${Platform.pathSeparator}fixtures${Platform.pathSeparator}'
      'device-remediation-synthetic.txt',
    );
    expect(await tester.runAsync(file.exists), isTrue);
    int pickerCalls = 0;
    int cleanupCalls = 0;
    final SystemFilePicker picker = SystemFilePicker(
      pickEvidence: () async {
        pickerCalls += 1;
        return _WidgetPlatformFile(name: 'synthetic.txt', path: file.path);
      },
      clearTemporaryFiles: () async => cleanupCalls += 1,
    );
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const EvidenceScreen(),
      size: const Size(700, 1200),
      adapter: adapter,
      filePicker: picker,
    );

    await tester.tap(find.byTooltip('Добавить подтверждение'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(cleanupCalls, 1);
    expect(adapter.evidenceUploadCalls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('assessment run stays deterministic and settings are explicit', (
    WidgetTester tester,
  ) async {
    final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
    await _pumpScreen(
      tester,
      const AssessmentsScreen(),
      size: const Size(700, 1200),
      adapter: adapter,
    );
    await tester.tap(find.textContaining('Оценка от'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Движок правил проверил фактов: 1'),
      findsOneWidget,
    );
    expect(find.textContaining('has_website: true'), findsNothing);
    expect(find.textContaining('SRC-SYNTHETIC'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Закрыть'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Новая оценка'));
    await tester.pumpAndSettle();
    expect(find.textContaining('детерминированный движок'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Выполнить'));
    await tester.pumpAndSettle();
    expect(
      adapter.requests.any(
        (RequestOptions request) =>
            request.method == 'POST' && request.path.endsWith('/assessments/'),
      ),
      isTrue,
    );

    await _pumpScreen(
      tester,
      const SettingsScreen(),
      size: const Size(700, 1500),
      adapter: adapter,
    );
    await tester.tap(find.text('Как в системе'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Тёмная').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Выйти'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('Выйти из приложения?'), findsNothing);
  });
}
