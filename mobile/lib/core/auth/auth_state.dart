import '../network/api_models.dart';

enum AuthPhase {
  checking,
  signedOut,
  mfaRequired,
  authenticated,
  locked,
  offline,
  blocked,
}

final class AuthState {
  const AuthState({
    required this.phase,
    this.user,
    this.safeError,
    this.mfaMethods = const <String>[],
    this.busy = false,
  });

  const AuthState.checking() : this(phase: AuthPhase.checking, busy: true);
  const AuthState.signedOut({String? safeError})
    : this(phase: AuthPhase.signedOut, safeError: safeError);

  final AuthPhase phase;
  final CurrentUserDto? user;
  final String? safeError;
  final List<String> mfaMethods;
  final bool busy;

  bool get isAuthenticated => phase == AuthPhase.authenticated;

  AuthState copyWith({
    AuthPhase? phase,
    CurrentUserDto? user,
    String? safeError,
    List<String>? mfaMethods,
    bool? busy,
    bool clearError = false,
  }) => AuthState(
    phase: phase ?? this.phase,
    user: user ?? this.user,
    safeError: clearError ? null : safeError ?? this.safeError,
    mfaMethods: mfaMethods ?? this.mfaMethods,
    busy: busy ?? this.busy,
  );
}
