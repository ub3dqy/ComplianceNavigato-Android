import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_error.dart';

AppError mapDioError(DioException error) {
  if (error.type == DioExceptionType.cancel) {
    return const AppError(
      kind: AppErrorKind.cancelled,
      safeMessage: 'Операция отменена.',
      code: 'cancelled',
    );
  }
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return const AppError(
      kind: AppErrorKind.timeout,
      safeMessage: 'Сервер не ответил вовремя. Повторите безопасный запрос.',
      code: 'timeout',
    );
  }
  if (error.type == DioExceptionType.badCertificate ||
      error.error is HandshakeException) {
    return const AppError(
      kind: AppErrorKind.tls,
      safeMessage: 'Не удалось подтвердить защищённое соединение с сервером.',
      code: 'tls_error',
    );
  }
  if (error.type == DioExceptionType.connectionError ||
      error.error is SocketException) {
    return const AppError(
      kind: AppErrorKind.offline,
      safeMessage: 'Нет соединения. Действующая сессия сохранена.',
      code: 'offline',
    );
  }

  final int? statusCode = error.response?.statusCode;
  final Object? raw = error.response?.data;
  String? code;
  String? message;
  String? requestId;
  Map<String, Object?> fields = const <String, Object?>{};
  if (raw case <String, Object?>{
    'error': final Map<String, Object?> envelope,
  }) {
    code = envelope['code'] as String?;
    message = envelope['message'] as String?;
    requestId = envelope['request_id'] as String?;
    final Object? rawFields = envelope['fields'];
    if (rawFields is Map<String, Object?>) {
      fields = rawFields;
    }
  }
  code ??= _defaultCode(statusCode);
  message ??= _safeMessage(statusCode, code);

  Duration? retryAfter;
  final String? retryHeader = error.response?.headers.value('retry-after');
  final int? retrySeconds = int.tryParse(retryHeader ?? '');
  if (retrySeconds != null && retrySeconds >= 0 && retrySeconds <= 86400) {
    retryAfter = Duration(seconds: retrySeconds);
  }
  return AppError(
    kind: _kind(statusCode, code),
    safeMessage: message,
    code: code,
    requestId: requestId,
    retryAfter: retryAfter,
    fields: fields,
  );
}

String _defaultCode(int? statusCode) => switch (statusCode) {
  400 => 'validation_error',
  401 => 'authentication_required',
  403 => 'permission_denied',
  404 => 'not_found',
  409 => 'conflict',
  413 => 'payload_too_large',
  415 => 'unsupported_media_type',
  428 => 'precondition_required',
  429 => 'rate_limited',
  503 => 'server_unavailable',
  _ => 'request_failed',
};

AppErrorKind _kind(int? statusCode, String code) {
  if (code == 'mfa_required' || code == 'mfa_invalid') {
    return AppErrorKind.mfa;
  }
  if (code == 'ai_queue_full') {
    return AppErrorKind.aiQueueFull;
  }
  if (code == 'usage_limit_exceeded') {
    return AppErrorKind.aiUsageLimit;
  }
  if (code == 'ai_unavailable' || code == 'security_violation') {
    return AppErrorKind.aiUnavailable;
  }
  if (code == 'schema_mismatch') {
    return AppErrorKind.schemaMismatch;
  }
  if (code == 'file_rejected' || statusCode == 413 || statusCode == 415) {
    return AppErrorKind.fileRejected;
  }
  return switch (statusCode) {
    400 => AppErrorKind.validation,
    401 => AppErrorKind.authentication,
    403 || 404 => AppErrorKind.permission,
    409 || 428 => AppErrorKind.conflict,
    429 => AppErrorKind.rateLimit,
    503 => AppErrorKind.serverUnavailable,
    _ => AppErrorKind.unknown,
  };
}

String _safeMessage(int? statusCode, String code) {
  if (code == 'mfa_required') {
    return 'Введите код TOTP или recovery-код.';
  }
  return switch (statusCode) {
    400 => 'Запрос содержит ошибки.',
    401 => 'Сессия завершена. Войдите снова.',
    403 || 404 => 'Недостаточно прав для этого действия.',
    409 || 428 =>
      'Данные изменились на сервере. Обновите их и повторите действие вручную.',
    429 => 'Слишком много запросов. Повторите позже.',
    503 => 'Сервис временно недоступен.',
    _ => 'Не удалось выполнить запрос.',
  };
}
