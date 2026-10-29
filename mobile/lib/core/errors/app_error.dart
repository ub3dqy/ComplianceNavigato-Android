enum AppErrorKind {
  offline,
  timeout,
  tls,
  authentication,
  mfa,
  permission,
  validation,
  conflict,
  rateLimit,
  serverUnavailable,
  maintenance,
  malformedResponse,
  schemaMismatch,
  fileRejected,
  aiUnavailable,
  aiQueueFull,
  aiUsageLimit,
  cancelled,
  unknown,
}

final class AppError implements Exception {
  const AppError({
    required this.kind,
    required this.safeMessage,
    this.code,
    this.requestId,
    this.retryAfter,
    this.fields = const <String, Object?>{},
  });

  final AppErrorKind kind;
  final String safeMessage;
  final String? code;
  final String? requestId;
  final Duration? retryAfter;
  final Map<String, Object?> fields;

  bool get requiresLogin => kind == AppErrorKind.authentication;
  bool get canRetrySafely => const <AppErrorKind>{
    AppErrorKind.offline,
    AppErrorKind.timeout,
    AppErrorKind.serverUnavailable,
    AppErrorKind.maintenance,
  }.contains(kind);

  @override
  String toString() => safeMessage;
}
