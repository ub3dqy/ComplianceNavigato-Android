import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../core/auth/session_signals.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_models.dart';
import '../core/network/compliance_repository.dart';
import '../core/network/sanitized_diagnostics.dart';
import '../core/storage/app_preferences.dart';
import '../core/storage/fns_extract_file.dart';
import '../core/storage/secure_session_store.dart';
import '../core/storage/session_revocation_marker.dart';
import '../core/storage/system_file_picker.dart';
import '../core/storage/transient_file_service.dart';
import '../core/theme/theme_controller.dart';
import '../features/organizations/organization_controller.dart';

final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (Ref ref) => AppConfig.fromEnvironment(),
);

final Provider<SessionStore> sessionStoreProvider = Provider<SessionStore>(
  (Ref ref) => SecureSessionStore(),
);

final Provider<SessionRevocationMarker> sessionRevocationMarkerProvider =
    Provider<SessionRevocationMarker>(
      (Ref ref) => FileSessionRevocationMarker(),
    );

final Provider<PreferencesStore> preferencesProvider =
    Provider<PreferencesStore>((Ref ref) => AppPreferences());

final Provider<SanitizedDiagnostics> diagnosticsProvider =
    Provider<SanitizedDiagnostics>((Ref ref) => SanitizedDiagnostics());

final Provider<SessionSignals> sessionSignalsProvider =
    Provider<SessionSignals>((Ref ref) {
      final SessionSignals signals = SessionSignals();
      ref.onDispose(() => unawaited(signals.dispose()));
      return signals;
    });

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final SessionSignals signals = ref.watch(sessionSignalsProvider);
  return ApiClient(
    config: ref.watch(appConfigProvider),
    sessionStore: ref.watch(sessionStoreProvider),
    sessionRevocationMarker: ref.watch(sessionRevocationMarkerProvider),
    diagnostics: ref.watch(diagnosticsProvider),
    onSessionInvalidated: signals.notifyInvalidated,
  );
});

final Provider<ComplianceRepository> repositoryProvider =
    Provider<ComplianceRepository>(
      (Ref ref) => ComplianceRepository(
        client: ref.watch(apiClientProvider),
        sessionStore: ref.watch(sessionStoreProvider),
        config: ref.watch(appConfigProvider),
      ),
    );

final Provider<LocalAuthentication> localAuthenticationProvider =
    Provider<LocalAuthentication>((Ref ref) => LocalAuthentication());

final Provider<TransientFileService> transientFileServiceProvider =
    Provider<TransientFileService>((Ref ref) => TransientFileService());

final Provider<SystemFilePicker> systemFilePickerProvider =
    Provider<SystemFilePicker>((Ref ref) => SystemFilePicker());

final fnsExtractFileReaderProvider = Provider<FnsExtractFileReader>(
  (ref) => FnsExtractFileReader(),
);

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final AsyncNotifierProvider<OrganizationController, OrganizationSelection>
organizationControllerProvider =
    AsyncNotifierProvider<OrganizationController, OrganizationSelection>(
      OrganizationController.new,
    );

final Provider<OrganizationSummaryDto?> currentOrganizationProvider =
    Provider<OrganizationSummaryDto?>((Ref ref) {
      return ref.watch(organizationControllerProvider).value?.current;
    });

int currentOrganizationGeneration(WidgetRef ref) =>
    ref.read(organizationGenerationProvider);

bool isCurrentOrganization(
  WidgetRef ref,
  String organizationId, {
  int? generation,
}) =>
    ref.read(currentOrganizationProvider)?.id == organizationId &&
    (generation == null ||
        ref.read(organizationGenerationProvider) == generation);

final NotifierProvider<OrganizationGenerationController, int>
organizationGenerationProvider =
    NotifierProvider<OrganizationGenerationController, int>(
      OrganizationGenerationController.new,
    );

final AsyncNotifierProvider<ThemeController, ThemeMode>
themeControllerProvider = AsyncNotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

final StreamProvider<List<ConnectivityResult>> connectivityProvider =
    StreamProvider<List<ConnectivityResult>>(
      (Ref ref) => Connectivity().onConnectivityChanged,
    );
