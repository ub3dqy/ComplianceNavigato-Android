import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../errors/app_error.dart';
import '../storage/secure_session_store.dart';
import '../storage/session_revocation_marker.dart';
import 'api_error_mapper.dart';
import 'api_models.dart';
import 'sanitized_diagnostics.dart';

typedef SessionInvalidated = FutureOr<void> Function();

final class ApiClient {
  ApiClient({
    required AppConfig config,
    required this._sessionStore,
    required this._sessionRevocationMarker,
    required this._diagnostics,
    Dio? dio,
    Dio? refreshDio,
    DateTime Function()? clock,
    this._onSessionInvalidated,
  }) : _config = config,
       _clock = clock ?? DateTime.now,
       _dio = dio ?? Dio(_baseOptions(config)),
       _refreshDio = refreshDio ?? Dio(_baseOptions(config)) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
        onResponse: _onResponse,
      ),
    );
  }

  static BaseOptions _baseOptions(AppConfig config) => BaseOptions(
    baseUrl: config.apiBaseUri.toString(),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 45),
    sendTimeout: const Duration(seconds: 60),
    responseType: ResponseType.json,
    followRedirects: false,
    headers: const <String, Object>{
      'Accept': 'application/json',
      'Cache-Control': 'no-store',
    },
    validateStatus: (int? status) =>
        status != null && status >= 200 && status < 300,
  );

  final AppConfig _config;
  final DateTime Function() _clock;
  final SessionStore _sessionStore;
  final SessionRevocationMarker _sessionRevocationMarker;
  final SanitizedDiagnostics _diagnostics;
  final Dio _dio;
  final Dio _refreshDio;
  final SessionInvalidated? _onSessionInvalidated;
  final Uuid _uuid = const Uuid();
  String? _accessToken;
  DateTime? _accessExpiresAt;
  Future<void>? _refreshInFlight;
  CancelToken _sessionCancelToken = CancelToken();
  CancelToken _refreshCancelToken = CancelToken();
  int _sessionGeneration = 0;

  bool get hasAccessToken => _accessToken != null;

  void setAccessToken(String? value, {Duration? expiresIn}) {
    _advanceSessionGeneration(reason: 'new_session');
    cancelInFlightRequests(reason: 'new_session');
    _accessToken = value?.isNotEmpty == true ? value : null;
    _accessExpiresAt = switch (_accessToken) {
      null => null,
      final String token =>
        expiresIn == null ? _jwtExpiry(token) : _clock().toUtc().add(expiresIn),
    };
  }

  static const Duration _sessionRefreshWindow = Duration(seconds: 45);
  static const Duration _fallbackAccessLifetime = Duration(minutes: 5);

  DateTime? _jwtExpiry(String token) {
    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Object? rawExpiry = decoded['exp'];
      if (rawExpiry is! num || rawExpiry <= 0) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(
        rawExpiry.toInt() * 1000,
        isUtc: true,
      );
    } on Object {
      // The expiry hint is advisory only; token trust stays server-side.
      return null;
    }
  }

  bool get _accessNeedsRefresh {
    final DateTime? expiry = _accessExpiresAt;
    return _accessToken == null ||
        expiry == null ||
        !expiry.isAfter(_clock().toUtc().add(_sessionRefreshWindow));
  }

  static const AppError _cancelledError = AppError(
    kind: AppErrorKind.cancelled,
    safeMessage: 'Операция отменена.',
    code: 'cancelled',
  );

  Future<void> _awaitWithCancellation(
    Future<void> operation,
    CancelToken? cancelToken,
  ) async {
    if (cancelToken == null) {
      await operation;
      return;
    }
    if (cancelToken.isCancelled) {
      throw _cancelledError;
    }
    await Future.any<void>(<Future<void>>[
      operation,
      cancelToken.whenCancel.then<void>((_) => throw _cancelledError),
    ]);
  }

  Future<AppError> _failClosedSession({
    required String errorCode,
    bool deferRequestCancellation = false,
  }) async {
    final CancelToken invalidatedSessionToken = _sessionCancelToken;
    bool alreadyInvalidated = false;
    try {
      alreadyInvalidated = await _sessionRevocationMarker.isSet();
    } on Object {
      // If the marker cannot be read, perform the full invalidation path.
    }
    if (!alreadyInvalidated) {
      try {
        await invalidateLocalSession(cancelRequests: !deferRequestCancellation);
      } on Object {
        // The in-memory token and durable marker are cleared on a best-effort basis.
      }
    } else {
      _accessToken = null;
      _accessExpiresAt = null;
      if (!deferRequestCancellation) {
        cancelInFlightRequests(reason: 'session_invalidated');
      }
    }
    if (deferRequestCancellation) {
      Timer.run(() {
        if (!invalidatedSessionToken.isCancelled) {
          invalidatedSessionToken.cancel('session_invalidated');
        }
      });
    }
    return AppError(
      kind: AppErrorKind.authentication,
      safeMessage: 'Сессия завершена. Войдите повторно.',
      code: errorCode,
    );
  }

  Future<void> _prepareProtectedRequest(
    CancelToken? cancelToken, {
    required String errorCode,
  }) async {
    if (!_accessNeedsRefresh) {
      return;
    }
    try {
      await _awaitWithCancellation(refreshSession(), cancelToken);
    } on AppError catch (error) {
      if (error.kind == AppErrorKind.cancelled) {
        rethrow;
      }
      throw await _failClosedSession(errorCode: errorCode);
    } on Object {
      throw await _failClosedSession(errorCode: errorCode);
    }
  }

  CancelToken _linkRequestCancellation(CancelToken requestCancelToken) {
    final CancelToken linked = CancelToken();
    void relay(DioException error) {
      if (!linked.isCancelled) {
        linked.cancel(error.error ?? error.message);
      }
    }

    for (final CancelToken source in <CancelToken>[
      _sessionCancelToken,
      requestCancelToken,
    ]) {
      if (source.isCancelled) {
        final DioException? error = source.cancelError;
        linked.cancel(error?.error ?? error?.message ?? 'cancelled');
      } else {
        unawaited(source.whenCancel.then<void>(relay));
      }
    }
    return linked;
  }

  void _advanceSessionGeneration({required String reason}) {
    _sessionGeneration += 1;
    if (!_refreshCancelToken.isCancelled) {
      _refreshCancelToken.cancel(reason);
    }
    _refreshCancelToken = CancelToken();
  }

  void _rejectChangedSession(int expectedGeneration) {
    if (expectedGeneration != _sessionGeneration) {
      throw const AppError(
        kind: AppErrorKind.authentication,
        safeMessage: 'Сессия завершена. Войдите снова.',
        code: 'session_invalidated',
      );
    }
  }

  Future<bool> _sessionWasRevoked(int expectedGeneration) async {
    _rejectChangedSession(expectedGeneration);
    final bool revoked = await _sessionRevocationMarker.isSet();
    _rejectChangedSession(expectedGeneration);
    return revoked;
  }

  void cancelInFlightRequests({String reason = 'context_changed'}) {
    if (!_sessionCancelToken.isCancelled) {
      _sessionCancelToken.cancel(reason);
    }
    _sessionCancelToken = CancelToken();
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_config.allows(options.uri)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const AppError(
            kind: AppErrorKind.schemaMismatch,
            safeMessage: 'Запрос к неподтверждённому серверу заблокирован.',
            code: 'hostname_rejected',
          ),
        ),
      );
      return;
    }
    if (options.extra['skipAuth'] != true && _accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  void _onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _diagnostics.record(
      method: response.requestOptions.method,
      uri: response.requestOptions.uri,
      statusCode: response.statusCode,
    );
    handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions request = error.requestOptions;
    final int? statusCode = error.response?.statusCode;
    final bool mayReplay = _mayReplay(request);
    if (statusCode == 401 &&
        request.extra['skipAuth'] != true &&
        request.extra['refreshed'] != true &&
        mayReplay) {
      try {
        await _awaitWithCancellation(refreshSession(), request.cancelToken);
        request.extra['refreshed'] = true;
        request.headers['Authorization'] = 'Bearer $_accessToken';
        if (request.data is FormData) {
          request.data = (request.data! as FormData).clone();
        }
        final Object? replayCallback = request.extra['onAuthReplay'];
        if (replayCallback is void Function()) {
          replayCallback();
        }
        final Response<Object?> retried = await _dio.fetch<Object?>(request);
        handler.resolve(retried);
        return;
      } on AppError catch (refreshError) {
        final AppError safeError;
        final DioExceptionType type;
        if (refreshError.kind == AppErrorKind.cancelled) {
          safeError = refreshError;
          type = DioExceptionType.cancel;
        } else if (request.extra['failClosedOnRefreshError'] == true) {
          safeError = await _failClosedSession(
            errorCode: _refreshFailureCode(request),
            deferRequestCancellation: true,
          );
          type = DioExceptionType.badResponse;
        } else {
          safeError = refreshError;
          type = DioExceptionType.badResponse;
        }
        handler.reject(
          DioException(
            requestOptions: request,
            response: error.response,
            type: type,
            error: safeError,
          ),
        );
        return;
      } on Object {
        final AppError safeError =
            request.extra['failClosedOnRefreshError'] == true
            ? await _failClosedSession(
                errorCode: _refreshFailureCode(request),
                deferRequestCancellation: true,
              )
            : const AppError(
                kind: AppErrorKind.unknown,
                safeMessage: 'Не удалось обновить сессию.',
                code: 'refresh_failed',
              );
        handler.reject(
          DioException(
            requestOptions: request,
            response: error.response,
            type: DioExceptionType.badResponse,
            error: safeError,
          ),
        );
        return;
      }
    }

    if (statusCode == 401 &&
        request.extra['failClosedOnRefreshError'] == true &&
        request.extra['refreshed'] == true) {
      final AppError safeError = await _failClosedSession(
        errorCode: _refreshFailureCode(request),
        deferRequestCancellation: true,
      );
      _diagnostics.record(
        method: request.method,
        uri: request.uri,
        statusCode: statusCode,
        errorCode: safeError.code,
      );
      handler.next(
        DioException(
          requestOptions: request,
          response: error.response,
          type: DioExceptionType.badResponse,
          error: safeError,
        ),
      );
      return;
    }

    final AppError mapped = error.error is AppError
        ? error.error! as AppError
        : mapDioError(error);
    _diagnostics.record(
      method: request.method,
      uri: request.uri,
      statusCode: statusCode,
      errorCode: mapped.code,
    );
    handler.next(
      DioException(
        requestOptions: request,
        response: error.response,
        type: error.type,
        error: mapped,
      ),
    );
  }

  bool _mayReplay(RequestOptions options) {
    final String method = options.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD') {
      return true;
    }
    final bool uploadReplay =
        options.extra['allowUploadAuthReplay'] == true &&
        options.extra['failClosedOnRefreshError'] == true &&
        options.data is FormData;
    final bool aiCreateReplay =
        method == 'POST' &&
        options.extra['allowAiCreateAuthReplay'] == true &&
        options.extra['failClosedOnRefreshError'] == true &&
        options.data is! FormData &&
        _isAiCreatePath(options.uri.path) &&
        _hasIdempotencyKey(options);
    return uploadReplay || aiCreateReplay;
  }

  static bool _hasIdempotencyKey(RequestOptions options) =>
      options.headers.entries.any(
        (MapEntry<String, dynamic> entry) =>
            entry.key.toLowerCase() == 'idempotency-key' &&
            entry.value is String &&
            (entry.value as String).isNotEmpty,
      );

  static bool _isAiCreatePath(String path) =>
      RegExp(r'^/api/v1/organizations/[^/]+/ai/conversations/[^/]+/messages/$')
          .hasMatch(path);

  static String _refreshFailureCode(RequestOptions request) =>
      request.extra['sessionRefreshFailureCode'] == 'ai_session_refresh_failed'
      ? 'ai_session_refresh_failed'
      : 'upload_session_refresh_failed';

  Future<void> refreshSession() {
    final Future<void>? active = _refreshInFlight;
    if (active != null) {
      return active;
    }
    final Future<void> created = _performRefresh();
    _refreshInFlight = created;
    return created.whenComplete(() {
      if (identical(_refreshInFlight, created)) {
        _refreshInFlight = null;
      }
    });
  }

  Future<void> _performRefresh() async {
    final int expectedGeneration = _sessionGeneration;
    final CancelToken refreshCancelToken = _refreshCancelToken;
    if (await _sessionWasRevoked(expectedGeneration)) {
      try {
        await invalidateLocalSession();
      } on Object {
        // The durable marker remains authoritative if another cleanup step fails.
      }
      throw const AppError(
        kind: AppErrorKind.authentication,
        safeMessage: 'Сессия завершена. Войдите снова.',
        code: 'session_invalidated',
      );
    }
    _rejectChangedSession(expectedGeneration);
    final String? refreshToken = await _sessionStore.readRefreshToken();
    if (await _sessionWasRevoked(expectedGeneration)) {
      throw const AppError(
        kind: AppErrorKind.authentication,
        safeMessage: 'Сессия завершена. Войдите снова.',
        code: 'session_invalidated',
      );
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      await invalidateLocalSession();
      throw const AppError(
        kind: AppErrorKind.authentication,
        safeMessage: 'Сессия завершена. Войдите снова.',
        code: 'missing_refresh_token',
      );
    }
    try {
      final Response<Object?> response = await _refreshDio.post<Object?>(
        'auth/refresh/',
        data: <String, Object?>{'refresh': refreshToken},
        cancelToken: refreshCancelToken,
      );
      if (await _sessionWasRevoked(expectedGeneration)) {
        throw const AppError(
          kind: AppErrorKind.authentication,
          safeMessage: 'Сессия завершена. Войдите снова.',
          code: 'session_invalidated',
        );
      }
      final Map<String, dynamic> data = _jsonObject(response.data);
      final String access = data['access'] as String? ?? '';
      final String rotated = data['refresh'] as String? ?? '';
      if (access.isEmpty || rotated.isEmpty) {
        throw const AppError(
          kind: AppErrorKind.malformedResponse,
          safeMessage: 'Сервер вернул неполные данные сессии.',
          code: 'malformed_refresh',
        );
      }
      try {
        await _sessionStore.writeRefreshToken(rotated);
      } on Object {
        try {
          await invalidateLocalSession();
        } on Object {
          // The invalidation signal is still delivered even if secure storage is unavailable.
        }
        throw const AppError(
          kind: AppErrorKind.authentication,
          safeMessage: 'Локальное хранилище сессии недоступно. Войдите снова.',
          code: 'session_storage_unavailable',
        );
      }
      bool revokedAfterWrite;
      try {
        revokedAfterWrite = await _sessionRevocationMarker.isSet();
      } on Object {
        revokedAfterWrite = true;
      }
      if (expectedGeneration != _sessionGeneration || revokedAfterWrite) {
        try {
          await invalidateLocalSession();
        } on Object {
          // The marker and overwrite fallback remain authoritative on cleanup failure.
        }
        throw const AppError(
          kind: AppErrorKind.authentication,
          safeMessage: 'Сессия завершена. Войдите снова.',
          code: 'session_invalidated',
        );
      }
      _accessToken = access;
      final Object? rawExpiresIn = data['access_expires_in'];
      _accessExpiresAt = rawExpiresIn is num && rawExpiresIn > 0
          ? _clock().toUtc().add(Duration(seconds: rawExpiresIn.toInt()))
          : _jwtExpiry(access) ?? _clock().toUtc().add(_fallbackAccessLifetime);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 400) {
        await invalidateLocalSession();
      }
      throw mapDioError(error);
    }
  }

  Future<void> invalidateLocalSession({
    bool notify = true,
    bool cancelRequests = true,
  }) async {
    _advanceSessionGeneration(reason: 'session_invalidated');
    _accessToken = null;
    _accessExpiresAt = null;
    if (cancelRequests) {
      cancelInFlightRequests(reason: 'session_invalidated');
    }
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await _sessionRevocationMarker.set();
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }
    if (notify) {
      try {
        await _onSessionInvalidated?.call();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    try {
      await _sessionStore.clear();
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
      try {
        await _sessionStore.writeRefreshToken('session-invalidated');
      } on Object {
        // The signed-out marker in regular app storage is the independent fallback.
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  Future<Response<Object?>> publicPost(String path, JsonMap data) => _request(
    path,
    method: 'POST',
    data: data,
    options: Options(extra: <String, Object?>{'skipAuth': true}),
    includeSessionCancellation: false,
  );

  Future<Response<Object?>> get(String path, {Map<String, Object?>? query}) =>
      _request(path, method: 'GET', query: query);

  Future<Response<Object?>> post(
    String path,
    JsonMap data, {
    bool idempotent = true,
    String? etag,
    String? idempotencyKey,
  }) => _mutation(
    path,
    'POST',
    data,
    idempotent: idempotent,
    etag: etag,
    idempotencyKey: idempotencyKey,
  );

  Future<Response<Object?>> postAiRequest(String path, JsonMap data) async {
    if (!_isAiCreatePath(_config.apiBaseUri.resolve(path).path)) {
      throw ArgumentError.value(
        path,
        'path',
        'Expected the AI request create path.',
      );
    }
    await _prepareProtectedRequest(
      null,
      errorCode: 'ai_session_refresh_failed',
    );
    return _mutation(
      path,
      'POST',
      data,
      idempotent: true,
      extra: const <String, Object?>{
        'allowAiCreateAuthReplay': true,
        'failClosedOnRefreshError': true,
        'sessionRefreshFailureCode': 'ai_session_refresh_failed',
      },
    );
  }

  // A transient lookup is not an organization mutation. Never store its
  // personal-data preview in an idempotency response or replay it automatically.
  Future<Response<Object?>> lookupOrganization(
    String inn,
    CancelToken cancelToken,
  ) async {
    await _prepareProtectedRequest(
      cancelToken,
      errorCode: 'registry_session_refresh_failed',
    );
    return _request(
      'organizations/lookup-by-inn/',
      method: 'POST',
      data: <String, Object?>{'inn': inn},
      cancelToken: cancelToken,
    );
  }

  Future<Response<Object?>> patch(
    String path,
    JsonMap data, {
    required String etag,
    String? idempotencyKey,
  }) => _mutation(
    path,
    'PATCH',
    data,
    idempotent: true,
    etag: etag,
    idempotencyKey: idempotencyKey,
  );

  Future<Response<Object?>> delete(String path, {required String etag}) =>
      _mutation(path, 'DELETE', null, idempotent: true, etag: etag);

  Future<Response<Object?>> _mutation(
    String path,
    String method,
    JsonMap? data, {
    required bool idempotent,
    String? etag,
    String? idempotencyKey,
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    final Map<String, Object> headers = <String, Object>{};
    if (idempotencyKey != null &&
        (!idempotent ||
            !RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(idempotencyKey))) {
      throw ArgumentError('An idempotent request requires a valid UUID.');
    }
    if (idempotent) {
      headers['Idempotency-Key'] = idempotencyKey ?? _uuid.v4();
    }
    if (etag != null) {
      headers['If-Match'] = etag;
    }
    return _request(
      path,
      method: method,
      data: data,
      options: Options(headers: headers, extra: extra),
    );
  }

  Future<Response<Object?>> upload(
    String path, {
    required FormData formData,
    required ProgressCallback onSendProgress,
    CancelToken? cancelToken,
    void Function()? onAuthReplay,
    String? etag,
  }) async {
    await _prepareProtectedRequest(
      cancelToken,
      errorCode: 'upload_session_refresh_failed',
    );
    return _request(
      path,
      method: 'POST',
      data: formData,
      options: Options(
        headers: <String, Object>{
          'Idempotency-Key': _uuid.v4(),
          'If-Match': ?etag,
        },
        extra: <String, Object?>{
          'allowUploadAuthReplay': true,
          'failClosedOnRefreshError': true,
          'onAuthReplay': ?onAuthReplay,
        },
      ),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
  }

  Future<Response<Uint8List>> download(String path) async {
    try {
      final Response<Uint8List> response = await _dio.get<Uint8List>(
        path,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: _sessionCancelToken,
      );
      return response;
    } on DioException catch (error) {
      throw error.error is AppError
          ? error.error! as AppError
          : mapDioError(error);
    }
  }

  Future<ResponseBody> openEventStream(String path, {int? lastEventId}) async {
    try {
      final Response<ResponseBody> response = await _dio.get<ResponseBody>(
        path,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 35),
          headers: <String, Object>{
            'Accept': 'text/event-stream',
            if (lastEventId != null) 'Last-Event-ID': lastEventId.toString(),
          },
        ),
        cancelToken: _sessionCancelToken,
      );
      final ResponseBody? body = response.data;
      if (body == null) {
        throw const AppError(
          kind: AppErrorKind.malformedResponse,
          safeMessage: 'Сервер не открыл поток AI.',
          code: 'empty_ai_stream',
        );
      }
      return body;
    } on DioException catch (error) {
      throw error.error is AppError
          ? error.error! as AppError
          : mapDioError(error);
    }
  }

  Future<Response<Object?>> _request(
    String path, {
    required String method,
    Object? data,
    Map<String, Object?>? query,
    Options? options,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
    bool includeSessionCancellation = true,
  }) async {
    final CancelToken? effectiveCancelToken = includeSessionCancellation
        ? cancelToken == null
              ? _sessionCancelToken
              : _linkRequestCancellation(cancelToken)
        : cancelToken;
    try {
      return await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: (options ?? Options()).copyWith(method: method),
        cancelToken: effectiveCancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (error) {
      throw error.error is AppError
          ? error.error! as AppError
          : mapDioError(error);
    }
  }

  static Map<String, dynamic> jsonObject(Object? value) => _jsonObject(value);

  static List<dynamic> jsonList(Object? value) {
    if (value is List<dynamic>) {
      return value;
    }
    throw const AppError(
      kind: AppErrorKind.malformedResponse,
      safeMessage: 'Сервер вернул данные в неожиданном формате.',
      code: 'malformed_response',
    );
  }

  static Map<String, dynamic> _jsonObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw const AppError(
      kind: AppErrorKind.malformedResponse,
      safeMessage: 'Сервер вернул данные в неожиданном формате.',
      code: 'malformed_response',
    );
  }
}
