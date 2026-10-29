import 'dart:io';

import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:compliance_navigator/core/theme/app_theme.dart';
import 'package:compliance_navigator/core/widgets/compliance_components.dart';
import 'package:compliance_navigator/features/ai_assistant/ai_assistant_screen.dart';
import 'package:compliance_navigator/features/authentication/login_screen.dart';
import 'package:compliance_navigator/features/dashboard/dashboard_screen.dart';
import 'package:compliance_navigator/features/obligations/obligations_screen.dart';
import 'package:compliance_navigator/features/questionnaires/questionnaire_screen.dart';
import 'package:compliance_navigator/features/settings/settings_screen.dart';
import 'package:compliance_navigator/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/pilot_repository_flow.dart';

const String _schema =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

AppConfig _config() => AppConfig.validate(const <String, String>{
  'APP_ENV': 'staging',
  'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
  'OPENAI_API_ENABLED': 'false',
  'AI_PROVIDER_AUTO_SWITCH': 'false',
  'GIT_COMMIT_SHA': 'golden-synthetic',
  'API_SCHEMA_SHA256': _schema,
});

ApiClient _client(
  LocalFakeApiAdapter adapter,
  MemorySessionStore store,
  SessionRevocationMarker sessionRevocationMarker,
) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: _config().apiBaseUri.toString(),
      validateStatus: (int? status) => status != null && status < 300,
    ),
  )..httpClientAdapter = adapter;
  return ApiClient(
    config: _config(),
    sessionStore: store,
    sessionRevocationMarker: sessionRevocationMarker,
    diagnostics: SanitizedDiagnostics(),
    dio: dio,
    refreshDio: dio,
  );
}

OrganizationSummaryDto _organization() =>
    OrganizationSummaryDto.fromJson(<String, dynamic>{
      'id': 'organization-1',
      'short_name': 'Пилот ООО',
      'kind': 'llc',
      'role': 'owner',
      'updated_at': '2026-08-27T12:00:00Z',
    });

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpFeature(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  required ThemeMode themeMode,
  double textScale = 1,
}) async {
  _setSize(tester, size);
  final MemorySessionStore store = MemorySessionStore();
  final MemorySessionRevocationMarker sessionRevocationMarker =
      MemorySessionRevocationMarker();
  final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
  final ApiClient client = _client(adapter, store, sessionRevocationMarker)
    ..setAccessToken(
      'golden-test-access',
      expiresIn: const Duration(minutes: 5),
    );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config()),
        sessionStoreProvider.overrideWithValue(store),
        sessionRevocationMarkerProvider.overrideWithValue(
          sessionRevocationMarker,
        ),
        apiClientProvider.overrideWithValue(client),
        currentOrganizationProvider.overrideWithValue(_organization()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        theme: AppTheme.light(fontFamily: 'Roboto'),
        darkTheme: AppTheme.dark(fontFamily: 'Roboto'),
        themeMode: themeMode,
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

void main() {
  setUpAll(() async {
    final Uint8List bytes = File('tool/assets/Roboto-Regular.ttf')
        .readAsBytesSync();
    final FontLoader loader = FontLoader('Roboto')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    await loader.load();
    final Uint8List iconBytes = File('tool/assets/MaterialIcons-Regular.otf')
        .readAsBytesSync();
    final FontLoader iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future<ByteData>.value(ByteData.sublistView(iconBytes)));
    await iconLoader.load();
  });

  testWidgets('login phone light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const LoginScreen(),
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/login-phone-light.png'),
    );
  });

  testWidgets('AI tablet dark', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const AiAssistantScreen(),
      size: const Size(800, 1280),
      themeMode: ThemeMode.dark,
      textScale: 1.3,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ai-tablet-dark.png'),
    );
  });

  testWidgets('dashboard hero light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const Scaffold(
        body: GreenHeroHeader(
          organizationName: 'Учебная организация',
          progress: 64,
        ),
      ),
      size: const Size(390, 360),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard-hero-light.png'),
    );
  });

  testWidgets('dashboard phone light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const DashboardScreen(),
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard-phone-light.png'),
    );
  });

  testWidgets('dashboard phone dark', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const DashboardScreen(),
      size: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard-phone-dark.png'),
    );
  });

  testWidgets('dashboard tablet light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const DashboardScreen(),
      size: const Size(800, 1280),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard-tablet-light.png'),
    );
  });

  testWidgets('questionnaire phone light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const QuestionnaireScreen(),
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/questionnaire-phone-light.png'),
    );
  });

  testWidgets('obligations phone light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const ObligationsScreen(),
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/obligations-phone-light.png'),
    );
  });

  testWidgets('AI chat phone light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const AiAssistantScreen(),
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
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
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ai-chat-phone-light.png'),
    );
  });

  testWidgets('error phone light', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      Scaffold(
        body: ErrorState(
          message: 'Сервис временно недоступен.',
          onRetry: () {},
        ),
      ),
      size: const Size(390, 844),
      themeMode: ThemeMode.light,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/error-phone-light.png'),
    );
  });

  testWidgets('offline phone dark', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      Scaffold(
        body: ErrorState(
          title: 'Нет соединения',
          message: 'Данные текущей сессии не удалены.',
          icon: Icons.cloud_off_outlined,
          onRetry: () {},
        ),
      ),
      size: const Size(390, 844),
      themeMode: ThemeMode.dark,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/offline-phone-dark.png'),
    );
  });

  testWidgets('settings phone large text', (WidgetTester tester) async {
    await _pumpFeature(
      tester,
      const SettingsScreen(),
      size: const Size(412, 915),
      themeMode: ThemeMode.light,
      textScale: 2,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/settings-phone-text-2.png'),
    );
  });

  testWidgets('dashboard viewport, orientation and text-scale matrix', (
    WidgetTester tester,
  ) async {
    for (final (Size size, double scale) in <(Size, double)>[
      (const Size(360, 800), 1),
      (const Size(390, 844), 1.3),
      (const Size(412, 915), 2),
      (const Size(800, 1280), 1.3),
      (const Size(844, 390), 1),
      (const Size(1280, 800), 2),
    ]) {
      await _pumpFeature(
        tester,
        const DashboardScreen(),
        size: size,
        themeMode: ThemeMode.system,
        textScale: scale,
      );
      expect(
        tester.takeException(),
        isNull,
        reason: '${size.width}x${size.height}, text scale $scale',
      );
    }
  });
}
