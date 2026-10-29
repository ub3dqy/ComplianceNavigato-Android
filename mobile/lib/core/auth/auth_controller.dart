import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../app/providers.dart';
import '../errors/app_error.dart';
import '../network/api_models.dart';
import '../network/compliance_repository.dart';
import '../storage/app_preferences.dart';
import '../storage/secure_session_store.dart';
import '../storage/session_revocation_marker.dart';
import 'auth_state.dart';

final class AuthController extends Notifier<AuthState> {
  StreamSubscription<void>? _invalidatedSubscription;
  Future<bool>? _cleanupInFlight;
  String? _pendingEmail;
  String? _pendingPassword;

  ComplianceRepository get _repository => ref.read(repositoryProvider);
  SessionStore get _sessionStore => ref.read(sessionStoreProvider);
  SessionRevocationMarker get _sessionRevocationMarker =>
      ref.read(sessionRevocationMarkerProvider);
  PreferencesStore get _preferences => ref.read(preferencesProvider);

  @override
  AuthState build() {
    _invalidatedSubscription = ref
        .read(sessionSignalsProvider)
        .invalidated
        .listen((_) {
          unawaited(_handleSessionInvalidation());
        });
    ref.onDispose(() => unawaited(_invalidatedSubscription?.cancel()));
    unawaited(_initialize());
    return const AuthState.checking();
  }

  Future<void> _initialize() async {
    try {
      if (await _sessionRevocationMarker.isSet()) {
        final bool secureStorageCleared = await _attemptCleanup(
          _sessionStore.clear,
        );
        state = AuthState.signedOut(
          safeError: secureStorageCleared ? null : 'Сессия завершена. Защищённое хранилище требует повторной очистки.',
        );
        return;
      }
    } on Object {
      state = const AuthState.signedOut(
        safeError: 'Состояние сессии недоступно. Войдите снова.',
      );
      return;
    }
    final String? refresh = await _sessionStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      state = const AuthState.signedOut();
      return;
    }
    if (await _preferences.readBiometricEnabled()) {
      state = const AuthState(phase: AuthPhase.locked);
      return;
    }
    await _restore();
  }

  Future<void> retryRestore() => _restore();

  Future<void> _restore() async {
    state = const AuthState.checking();
    try {
      await _repository.health();
      await _repository.restoreSession();
      final CurrentUserDto user = await _repository.currentUser();
      state = AuthState(phase: AuthPhase.authenticated, user: user);
      await ref.read(organizationControllerProvider.notifier).load();
    } on AppError catch (error) {
      if (error.kind == AppErrorKind.offline ||
          error.kind == AppErrorKind.timeout) {
        state = AuthState(
          phase: AuthPhase.offline,
          safeError: error.safeMessage,
        );
      } else if (error.kind == AppErrorKind.schemaMismatch ||
          error.kind == AppErrorKind.tls) {
        state = AuthState(
          phase: AuthPhase.blocked,
          safeError: error.safeMessage,
        );
      } else {
        state = AuthState.signedOut(safeError: error.safeMessage);
      }
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState(phase: AuthPhase.signedOut, busy: true);
    try {
      await _repository.health();
      final LoginOutcome outcome = await _repository.login(
        email: email,
        password: password,
      );
      if (outcome is MfaRequired) {
        _pendingEmail = email;
        _pendingPassword = password;
        state = AuthState(
          phase: AuthPhase.mfaRequired,
          mfaMethods: outcome.methods,
        );
        return;
      }
      _clearPendingCredentials();
      if (!await _confirmNewSession()) {
        return;
      }
      await _completeLogin();
    } on AppError catch (error) {
      _clearPendingCredentials();
      state = AuthState.signedOut(safeError: error.safeMessage);
    }
  }

  Future<void> submitMfa(String code) async {
    final String? email = _pendingEmail;
    final String? password = _pendingPassword;
    if (email == null || password == null) {
      state = const AuthState.signedOut(safeError: 'Повторите вход.');
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final LoginOutcome outcome = await _repository.login(
        email: email,
        password: password,
        mfaCode: code,
      );
      if (outcome is MfaRequired) {
        state = state.copyWith(
          phase: AuthPhase.mfaRequired,
          busy: false,
          safeError: 'Код не принят. Проверьте TOTP или recovery-код.',
        );
        return;
      }
      _clearPendingCredentials();
      if (!await _confirmNewSession()) {
        return;
      }
      await _completeLogin();
    } on AppError catch (error) {
      state = state.copyWith(
        phase: AuthPhase.mfaRequired,
        busy: false,
        safeError: error.safeMessage,
      );
    }
  }

  Future<void> _completeLogin() async {
    final CurrentUserDto user = await _repository.currentUser();
    state = AuthState(phase: AuthPhase.authenticated, user: user);
    await ref.read(organizationControllerProvider.notifier).load();
  }

  void cancelMfa() {
    _clearPendingCredentials();
    state = const AuthState.signedOut();
  }

  Future<void> unlock() async {
    final LocalAuthentication localAuth = ref.read(localAuthenticationProvider);
    try {
      final bool available =
          await localAuth.isDeviceSupported() &&
          await localAuth.canCheckBiometrics;
      if (!available) {
        await _preferences.writeBiometricEnabled(false);
        await _restore();
        return;
      }
      final bool accepted = await localAuth.authenticate(
        localizedReason: 'Разблокируйте Комплаенс-Навигатор Pilot',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (accepted) {
        await _restore();
      }
    } on LocalAuthException {
      state = const AuthState(
        phase: AuthPhase.locked,
        safeError: 'Локальная проверка не выполнена.',
      );
    }
  }

  Future<void> logout() async {
    state = const AuthState(phase: AuthPhase.signedOut, busy: true);
    bool sessionCleanupComplete = await _attemptCleanup(
      _sessionRevocationMarker.set,
    );
    try {
      await _repository.logout();
    } on Object {
      sessionCleanupComplete = false;
    }
    final bool cleanupComplete = await _clearLocalSessionState();
    if (!sessionCleanupComplete || !cleanupComplete) {
      state = const AuthState.signedOut(
        safeError:
            'Сессия завершена, но локальные данные очищены не полностью.',
      );
    } else {
      state = const AuthState.signedOut();
    }
  }

  Future<void> _handleSessionInvalidation() async {
    state = const AuthState(phase: AuthPhase.signedOut, busy: true);
    final bool markerStored = await _attemptCleanup(
      _sessionRevocationMarker.set,
    );
    final bool cleanupComplete = await _clearLocalSessionState();
    if (!markerStored || !cleanupComplete) {
      state = const AuthState.signedOut(
        safeError: 'Сессия завершена. Проверьте очистку временных файлов и войдите снова.',
      );
    } else {
      state = const AuthState.signedOut(
        safeError: 'Сессия завершена. Войдите повторно.',
      );
    }
  }

  Future<bool> _clearLocalSessionState() async {
    final Future<bool>? inFlight = _cleanupInFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final Future<bool> cleanup = _performLocalCleanup();
    _cleanupInFlight = cleanup;
    try {
      return await cleanup;
    } finally {
      if (identical(_cleanupInFlight, cleanup)) {
        _cleanupInFlight = null;
      }
    }
  }

  Future<bool> _confirmNewSession() async {
    try {
      await _sessionRevocationMarker.clear();
      return true;
    } on Object {
      try {
        await _repository.logout();
      } on Object {
        // The signed-out marker remains authoritative even if token cleanup also fails.
      }
      state = const AuthState.signedOut(
        safeError:
            'Не удалось безопасно сохранить новую сессию. Повторите вход.',
      );
      return false;
    }
  }

  Future<bool> _performLocalCleanup() async {
    bool complete = true;
    _clearPendingCredentials();
    try {
      ref.read(diagnosticsProvider).clear();
      ref.read(organizationControllerProvider.notifier).clearInMemory();
    } on Object {
      complete = false;
    }
    for (final Future<void> Function() operation in <Future<void> Function()>[
      () => ref
          .read(organizationControllerProvider.notifier)
          .clearStoredSelection(),
      () => ref.read(transientFileServiceProvider).purge(),
    ]) {
      complete = await _attemptCleanup(operation) && complete;
    }
    return complete;
  }

  Future<bool> _attemptCleanup(Future<void> Function() operation) async {
    try {
      await operation().timeout(const Duration(seconds: 5));
      return true;
    } on Object {
      return false;
    }
  }

  void _clearPendingCredentials() {
    _pendingEmail = null;
    _pendingPassword = null;
  }
}
