import 'dart:io';

import 'package:compliance_navigator/app/app.dart';
import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/storage/app_preferences.dart';
import 'package:compliance_navigator/core/storage/fns_extract_file.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:compliance_navigator/core/storage/transient_file_service.dart';
import 'package:compliance_navigator/features/organizations/fns_extract_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pilot_repository_flow.dart';

const uxSchema =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Future<Widget> createUxApp({
  Key? captureKey,
  AuthPhase? phase,
  ThemeMode? themeMode,
  HttpClientAdapter? transport,
  OrganizationSummaryDto? currentOrganization,
  CurrentUserDto? user,
  PreferencesStore? preferences,
  FnsExtractFileReader? fnsFileReader,
  Future<bool> Function(String)? openFnsRegistry,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final config = AppConfig.validate(const <String, String>{
    'APP_ENV': 'staging',
    'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
    'OPENAI_API_ENABLED': 'false',
    'AI_PROVIDER_AUTO_SWITCH': 'false',
    'GIT_COMMIT_SHA': 'ux-audit-synthetic-only',
    'API_SCHEMA_SHA256': uxSchema,
  });
  final store = MemorySessionStore();
  final marker = MemorySessionRevocationMarker();
  final adapter = transport ?? LocalFakeApiAdapter();
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUri.toString(),
      validateStatus: (int? status) =>
          status != null && status >= 200 && status < 300,
    ),
  )..httpClientAdapter = adapter;
  final client = ApiClient(
    config: config,
    sessionStore: store,
    sessionRevocationMarker: marker,
    diagnostics: SanitizedDiagnostics(),
    dio: dio,
    refreshDio: dio,
  );
  if (phase == AuthPhase.authenticated) {
    client.setAccessToken(
      'synthetic-ux-access',
      expiresIn: const Duration(minutes: 5),
    );
  }
  final temporary = Directory.systemTemp.createTempSync('compliance-ux-audit-');
  addTearDown(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      if (themeMode != null)
        themeControllerProvider.overrideWithBuild((ref, notifier) => themeMode),
      sessionStoreProvider.overrideWithValue(store),
      sessionRevocationMarkerProvider.overrideWithValue(marker),
      apiClientProvider.overrideWithValue(client),
      if (preferences != null)
        preferencesProvider.overrideWithValue(preferences),
      if (fnsFileReader != null)
        fnsExtractFileReaderProvider.overrideWithValue(fnsFileReader),
      if (openFnsRegistry != null)
        fnsRegistryOpenerProvider.overrideWithValue(openFnsRegistry),
      if (phase != null)
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthState(phase: phase, user: user),
        ),
      if (currentOrganization != null)
        currentOrganizationProvider.overrideWithValue(currentOrganization),
      transientFileServiceProvider.overrideWithValue(
        TransientFileService(temporaryDirectory: () async => temporary),
      ),
    ],
    child: RepaintBoundary(
      key: captureKey,
      child: const ComplianceNavigatorApp(),
    ),
  );
}
