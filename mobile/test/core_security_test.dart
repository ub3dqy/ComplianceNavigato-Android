import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/auth/session_signals.dart';
import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/errors/app_error.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/api_error_mapper.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/network/compliance_repository.dart';
import 'package:compliance_navigator/core/network/filename_policy.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/network/sse_parser.dart';
import 'package:compliance_navigator/core/storage/app_preferences.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _schemaHash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'; // pragma: allowlist secret

AppConfig _config() => AppConfig.validate(const <String, String>{
  'APP_ENV': 'staging',
  'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
  'OPENAI_API_ENABLED': 'false',
  'AI_PROVIDER_AUTO_SWITCH': 'false',
  'GIT_COMMIT_SHA': 'test-commit',
  'API_SCHEMA_SHA256': _schemaHash,
});

typedef AdapterHandler = FutureOr<ResponseBody> Function(
  RequestOptions options,
);

final class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.handler);

  final AdapterHandler handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (cancelFuture == null) {
      return handler(options);
    }
    return Future.any<ResponseBody>(<Future<ResponseBody>>[
      Future<ResponseBody>.sync(() => handler(options)),
      cancelFuture.then<ResponseBody>(
        (_) => throw DioException.requestCancelled(
          requestOptions: options,
          reason: 'cancelled',
        ),
      ),
    ]);
  }

  @override
  void close({bool force = false}) {}
}

final class FakeSecureStorage extends FlutterSecureStorage {
  FakeSecureStorage(this.values);

  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values.clear();
}

final class ThrowingClearSessionStore implements SessionStore {
  String? refreshToken = 'refresh';

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

final class DelayedWriteSessionStore implements SessionStore {
  String? refreshToken = 'old-refresh';
  bool delayWrites = false;
  final Completer<void> writeStarted = Completer<void>();
  final Completer<void> releaseWrite = Completer<void>();

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String value) async {
    if (delayWrites) {
      if (!writeStarted.isCompleted) {
        writeStarted.complete();
      }
      await releaseWrite.future;
    }
    refreshToken = value;
  }

  @override
  Future<void> clear() async => refreshToken = null;
}

ResponseBody _jsonBody(Object value, int status) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
  },
);

Dio _dio(RecordingAdapter adapter) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://compliance-pilot.ms777.ru/api/v1/',
      validateStatus: (int? status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

Future<Response<Object?>> _postAiRequest(ApiClient client) =>
    client.postAiRequest(
      'organizations/organization-1/ai/conversations/conversation-1/messages/',
      const <String, Object?>{
        'message': 'Синтетический обезличенный вопрос',
        'task_type': 'assistant',
      },
    );

void main() {
  for (final validRefresh in [true, false]) {
    test('registry refresh before lookup: $validRefresh', () async {
      final store = MemorySessionStore();
      await store.writeRefreshToken('synthetic-refresh');
      final marker = MemorySessionRevocationMarker();
      final order = <String>[];
      final adapter = RecordingAdapter((request) {
        order.add('lookup');
        expect(request.headers['Authorization'], 'Bearer renewed-access');
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        expect(request.data, {'inn': '1234567894'});
        return _jsonBody({'ok': true}, 200);
      });
      final refresh = RecordingAdapter((request) {
        order.add('refresh');
        return validRefresh
            ? _jsonBody({
                'access': 'renewed-access',
                'refresh': 'renewed-refresh',
              }, 200)
            : _jsonBody({
                'error': {'code': 'token_not_valid'},
              }, 401);
      });
      final client =
          ApiClient(
            config: _config(),
            sessionStore: store,
            sessionRevocationMarker: marker,
            diagnostics: SanitizedDiagnostics(),
            dio: _dio(adapter),
            refreshDio: _dio(refresh),
          )..setAccessToken(
            'expired-access',
            expiresIn: const Duration(seconds: -1),
          );
      if (validRefresh) {
        await client.lookupOrganization('1234567894', CancelToken());
        expect(order, ['refresh', 'lookup']);
      } else {
        await expectLater(
          client.lookupOrganization('1234567894', CancelToken()),
          throwsA(
            isA<AppError>().having(
              (error) => error.code,
              'code',
              'registry_session_refresh_failed',
            ),
          ),
        );
        expect(order, ['refresh']);
        expect(adapter.requests, isEmpty);
        expect(await store.readRefreshToken(), isNull);
        expect(await marker.isSet(), isTrue);
      }
    });
  }

  group('API configuration', () {
    test('accepts only the exact staging HTTPS origin', () {
      final AppConfig config = _config();
      expect(config.environment, 'staging');
      expect(config.serverHostname, 'compliance-pilot.ms777.ru');
      expect(config.apiBaseUri.path, '/api/v1/');
      expect(
        config.allows(
          Uri.parse('https://compliance-pilot.ms777.ru/api/v1/auth/me/'),
        ),
        isTrue,
      );
      expect(
        config.allows(Uri.parse('http://compliance-pilot.ms777.ru/api/v1/')),
        isFalse,
      );
      expect(
        config.allows(
          Uri.parse('https://compliance-pilot.ms777.ru:443/api/v1/'),
        ),
        isTrue,
      );
      expect(
        config.allows(Uri.parse('https://attacker.invalid/api/v1/')),
        isFalse,
      );
    });

    test('fails closed for production, AI flags and malformed metadata', () {
      final Map<String, String> base = <String, String>{
        'APP_ENV': 'staging',
        'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
        'OPENAI_API_ENABLED': 'false',
        'AI_PROVIDER_AUTO_SWITCH': 'false',
        'GIT_COMMIT_SHA': 'abc',
        'API_SCHEMA_SHA256': _schemaHash,
      };
      expect(
        () => AppConfig.validate(<String, String>{
          ...base,
          'APP_ENV': 'production',
        }),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(<String, String>{
          ...base,
          'OPENAI_API_ENABLED': 'true',
        }),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(<String, String>{
          ...base,
          'AI_PROVIDER_AUTO_SWITCH': 'true',
        }),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(<String, String>{
          ...base,
          'API_BASE_URL': 'https://attacker.invalid',
        }),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(<String, String>{
          ...base,
          'API_SCHEMA_SHA256': 'bad',
        }),
        throwsStateError,
      );
      expect(
        () => AppConfig.validate(<String, String>{
          ...base,
          'GIT_COMMIT_SHA': 'bad\nvalue',
        }),
        throwsStateError,
      );
    });
  });

  group('strict models and local storage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('critical DTO rejects unknown and missing fields', () {
      expect(
        () => ApiHealthDto.fromJson(<String, dynamic>{
          'status': 'ok',
          'api_version': '1.0.0',
          'schema_sha256': _schemaHash,
          'unexpected': true,
        }),
        throwsA(isA<CheckedFromJsonException>()),
      );
      expect(
        () => OrganizationSummaryDto.fromJson(<String, dynamic>{
          'id': 'id',
          'short_name': 'Тест',
          'kind': 'llc',
          'updated_at': '2026-08-27T00:00:00Z',
        }),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });

    test('authenticated state reports identity and preserves busy flag', () {
      const AuthState state = AuthState(
        phase: AuthPhase.authenticated,
        busy: true,
      );
      expect(state.isAuthenticated, isTrue);
      expect(state.copyWith().busy, isTrue);
    });

    test('memory session store rotates and wipes refresh token', () async {
      final MemorySessionStore store = MemorySessionStore();
      expect(await store.readRefreshToken(), isNull);
      await store.writeRefreshToken('refresh-1');
      expect(await store.readRefreshToken(), 'refresh-1');
      await store.writeRefreshToken('refresh-2');
      expect(await store.readRefreshToken(), 'refresh-2');
      await store.clear();
      expect(await store.readRefreshToken(), isNull);
    });

    test(
      'secure session wrapper rejects empty tokens and clears storage',
      () async {
        final Map<String, String> values = <String, String>{};
        final SecureSessionStore store = SecureSessionStore(
          storage: FakeSecureStorage(values),
        );
        await expectLater(store.writeRefreshToken(''), throwsArgumentError);
        await store.writeRefreshToken('refresh');
        expect(await store.readRefreshToken(), 'refresh');
        await store.clear();
        expect(values, isEmpty);
      },
    );

    test(
      'preferences persist only theme, biometric flag and organization',
      () async {
        final AppPreferences preferences = AppPreferences();
        expect(await preferences.readThemeMode(), ThemeMode.system);
        expect(await preferences.readBiometricEnabled(), isFalse);
        expect(await preferences.readLastOrganizationId(), isNull);

        await preferences.writeThemeMode(ThemeMode.dark);
        await preferences.writeBiometricEnabled(true);
        await preferences.writeLastOrganizationId('organization-1');
        expect(await preferences.readThemeMode(), ThemeMode.dark);
        expect(await preferences.readBiometricEnabled(), isTrue);
        expect(await preferences.readLastOrganizationId(), 'organization-1');

        await preferences.clearSessionSelection();
        expect(await preferences.readLastOrganizationId(), isNull);
        await preferences.writeLastOrganizationId(null);
      },
    );

    test(
      'session revocation marker is flushed and survives recreation',
      () async {
        final Directory directory = await Directory.systemTemp.createTemp(
          'compliance-navigator-session-marker-',
        );
        try {
          Future<Directory> stateDirectory() async => directory;
          final FileSessionRevocationMarker first = FileSessionRevocationMarker(
            stateDirectory: stateDirectory,
          );
          expect(await first.isSet(), isFalse);

          await first.set();
          final FileSessionRevocationMarker recreated =
              FileSessionRevocationMarker(stateDirectory: stateDirectory);
          expect(await recreated.isSet(), isTrue);

          await recreated.clear();
          expect(await first.isSet(), isFalse);
        } finally {
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        }
      },
    );

    test(
      'session invalidation signal is broadcast and closes safely',
      () async {
        final SessionSignals signals = SessionSignals();
        final Future<void> received = signals.invalidated.first;
        signals.notifyInvalidated();
        await received;
        await signals.dispose();
        signals.notifyInvalidated();
      },
    );
  });

  group('errors and diagnostics', () {
    test('safe error exposes only retry and login decisions', () {
      const AppError auth = AppError(
        kind: AppErrorKind.authentication,
        safeMessage: 'Войдите снова.',
      );
      const AppError offline = AppError(
        kind: AppErrorKind.offline,
        safeMessage: 'Нет соединения.',
      );
      const AppError validation = AppError(
        kind: AppErrorKind.validation,
        safeMessage: 'Проверьте поля.',
      );
      expect(auth.requiresLogin, isTrue);
      expect(auth.canRetrySafely, isFalse);
      expect(offline.canRetrySafely, isTrue);
      expect(validation.canRetrySafely, isFalse);
      expect(validation.toString(), 'Проверьте поля.');
    });

    test('maps network, auth, conflict, throttling and AI failures safely', () {
      final RequestOptions request = RequestOptions(path: '/api/v1/test');
      expect(
        mapDioError(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionTimeout,
          ),
        ).kind,
        AppErrorKind.timeout,
      );
      expect(
        mapDioError(
          DioException(
            requestOptions: request,
            type: DioExceptionType.connectionError,
          ),
        ).kind,
        AppErrorKind.offline,
      );
      expect(
        mapDioError(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badCertificate,
          ),
        ).kind,
        AppErrorKind.tls,
      );
      expect(
        mapDioError(
          DioException(requestOptions: request, type: DioExceptionType.cancel),
        ).kind,
        AppErrorKind.cancelled,
      );

      AppError responseError(int status, String code) => mapDioError(
        DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response<Object?>(
            requestOptions: request,
            statusCode: status,
            data: <String, Object?>{
              'error': <String, Object?>{
                'code': code,
                'message': 'Безопасное сообщение',
                'request_id': 'request-1',
                'fields': <String, Object?>{
                  'field': <String>['error'],
                },
              },
            },
            headers: Headers.fromMap(<String, List<String>>{
              'retry-after': <String>['60'],
            }),
          ),
        ),
      );

      expect(
        responseError(401, 'authentication_required').kind,
        AppErrorKind.authentication,
      );
      expect(
        responseError(403, 'permission_denied').kind,
        AppErrorKind.permission,
      );
      expect(responseError(409, 'conflict').kind, AppErrorKind.conflict);
      expect(
        responseError(429, 'rate_limited').retryAfter,
        const Duration(seconds: 60),
      );
      expect(
        responseError(503, 'ai_queue_full').kind,
        AppErrorKind.aiQueueFull,
      );
      expect(
        responseError(503, 'usage_limit_exceeded').kind,
        AppErrorKind.aiUsageLimit,
      );
      expect(
        responseError(503, 'security_violation').kind,
        AppErrorKind.aiUnavailable,
      );
      expect(
        responseError(413, 'file_rejected').kind,
        AppErrorKind.fileRejected,
      );
      expect(responseError(400, 'mfa_invalid').kind, AppErrorKind.mfa);
    });

    test('diagnostics retain only method, API path and safe codes', () {
      final SanitizedDiagnostics diagnostics = SanitizedDiagnostics(limit: 2);
      diagnostics.record(
        method: 'post',
        uri: Uri.parse(
          'https://compliance-pilot.ms777.ru/api/v1/auth/login/?token=secret',
        ),
        statusCode: 401,
        errorCode: 'authentication_required',
      );
      diagnostics.record(
        method: 'get',
        uri: Uri.parse('https://attacker.invalid/private?email=x'),
        errorCode: 'BAD CODE!',
      );
      diagnostics.record(
        method: 'get',
        uri: Uri.parse('https://compliance-pilot.ms777.ru/api/v1/health/'),
        statusCode: 200,
      );
      expect(diagnostics.entries, hasLength(2));
      expect(diagnostics.entries.first.path, '/api/v1/unknown');
      expect(diagnostics.entries.first.errorCode, 'request_failed');
      expect(diagnostics.entries.last.path, '/api/v1/health/');
      diagnostics.clear();
      expect(diagnostics.entries, isEmpty);
    });
  });

  group('filenames', () {
    test('accepts safe content disposition and UTF-8 names', () {
      expect(
        validatedFilename(
          contentDisposition: 'attachment; filename="report.docx"',
          fallback: 'fallback.docx',
        ),
        'report.docx',
      );
      expect(
        validatedFilename(
          contentDisposition:
              "attachment; filename*=UTF-8''%D0%BE%D1%82%D1%87%D1%91%D1%82.pdf",
          fallback: 'fallback.pdf',
        ),
        'отчёт.pdf',
      );
    });

    test(
      'rejects traversal, executable extensions, CRLF and unsafe fallback',
      () {
        expect(
          validatedFilename(
            contentDisposition: 'attachment; filename="../token.txt"',
            fallback: 'safe.txt',
          ),
          'safe.txt',
        );
        expect(
          validatedFilename(
            contentDisposition: 'attachment; filename="payload.exe"',
            fallback: 'safe.txt',
          ),
          'safe.txt',
        );
        expect(
          validatedFilename(
            contentDisposition:
                'attachment; filename="secret.txt"\r\nX-Test: value',
            fallback: 'safe.txt',
          ),
          'safe.txt',
        );
        expect(
          () => validatedFilename(
            contentDisposition: null,
            fallback: '../unsafe.txt',
          ),
          throwsFormatException,
        );
      },
    );
  });

  group('SSE protocol', () {
    test('parses event IDs, deltas, heartbeat and terminal close', () async {
      final SseParser parser = SseParser();
      final List<AiStreamEvent> events = await parser
          .parse(
            Stream<List<int>>.fromIterable(<List<int>>[
              utf8.encode(': heartbeat\n\n'),
              utf8.encode('id: 1\nevent: delta\ndata: {"text":"При"}\n\n'),
              utf8.encode('id: 2\nevent: completed\ndata: {"ok":true}\n\n'),
              utf8.encode('event: close\ndata: {"status":"completed"}\n\n'),
            ]),
          )
          .toList();
      expect(events.map((AiStreamEvent item) => item.type), <String>[
        'heartbeat',
        'delta',
        'completed',
        'close',
      ]);
      expect(events[1].id, 1);
      expect(events[1].payload['text'], 'При');
    });

    test(
      'rejects unknown, missing IDs, invalid JSON and partial frames',
      () async {
        Future<void> rejected(String input) async {
          await expectLater(
            SseParser()
                .parse(Stream<List<int>>.value(utf8.encode(input)))
                .toList(),
            throwsA(isA<AppError>()),
          );
        }

        await rejected('id: 1\nevent: unknown\ndata: {}\n\n');
        await rejected('event: delta\ndata: {}\n\n');
        await rejected('id: 1\nevent: delta\ndata: no-json\n\n');
        await rejected('id: 1\nevent: delta\ndata: {}');
      },
    );

    test('rejects oversized pending frames and event payloads', () async {
      final String oversizedPending = List<String>.filled(
        SseParser.maxPendingFrameBytes + 1,
        'x',
      ).join();
      await expectLater(
        SseParser()
            .parse(Stream<List<int>>.value(utf8.encode(oversizedPending)))
            .toList(),
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'sse_buffer_too_large',
          ),
        ),
      );

      final String oversizedData = List<String>.filled(
        SseParser.maxEventDataBytes + 1,
        'x',
      ).join();
      await expectLater(
        SseParser()
            .parse(
              Stream<List<int>>.value(
                utf8.encode(
                  'id: 1\nevent: delta\ndata: {"text":"$oversizedData"}\n\n',
                ),
              ),
            )
            .toList(),
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'sse_data_too_large',
          ),
        ),
      );
    });

    test('rejects cumulative AI text above the server schema limit', () async {
      final String first = List<String>.filled(5000, 'а').join();
      final String second = List<String>.filled(3001, 'б').join();
      final String events =
          'id: 1\nevent: delta\ndata: ${jsonEncode(<String, String>{'text': first})}\n\n'
          'id: 2\nevent: delta\ndata: ${jsonEncode(<String, String>{'text': second})}\n\n'
          'event: close\ndata: {"status":"completed"}\n\n';
      final RecordingAdapter adapter = RecordingAdapter(
        (_) => ResponseBody(
          Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(events))),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/event-stream'],
          },
        ),
      );
      final MemorySessionStore store = MemorySessionStore();
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: MemorySessionRevocationMarker(),
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(adapter),
        refreshDio: _dio(adapter),
      );
      final ComplianceRepository repository = ComplianceRepository(
        client: client,
        sessionStore: store,
        config: _config(),
      );

      await expectLater(
        repository
            .streamAiEvents(
              organizationId: 'organization-1',
              conversationId: 'conversation-1',
              requestId: 'request-1',
            )
            .toList(),
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'ai_response_too_large',
          ),
        ),
      );
    });
  });

  group('authenticated client', () {
    test('private downloads normalize only the current API path', () async {
      final MemorySessionStore store = MemorySessionStore();
      final RecordingAdapter adapter = RecordingAdapter(
        (_) => ResponseBody.fromBytes(<int>[1, 2, 3], 200),
      );
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: MemorySessionRevocationMarker(),
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(adapter),
        refreshDio: _dio(adapter),
      );
      final ComplianceRepository repository = ComplianceRepository(
        client: client,
        sessionStore: store,
        config: _config(),
      );

      final DownloadPayload payload = await repository.download(
        '/api/v1/organizations/organization-1/documents/document-1/download/html/',
      );

      expect(payload.bytes, <int>[1, 2, 3]);
      expect(
        adapter.requests.single.uri.path,
        '/api/v1/organizations/organization-1/documents/document-1/download/html/',
      );
      final DownloadPayload absolutePayload = await repository.download(
        'https://compliance-pilot.ms777.ru/api/v1/'
        'organizations/organization-1/evidence/evidence-1/download/',
      );
      expect(absolutePayload.bytes, <int>[1, 2, 3]);
      expect(
        adapter.requests[1].uri.path,
        '/api/v1/organizations/organization-1/evidence/evidence-1/download/',
      );
      await expectLater(
        repository.download('https://attacker.invalid/api/v1/file'),
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'invalid_download_path',
          ),
        ),
      );
      await expectLater(
        repository.download(
          '//compliance-pilot.ms777.ru/api/v1/'
          'organizations/organization-1/evidence/evidence-1/download/',
        ),
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'invalid_download_path',
          ),
        ),
      );
      await expectLater(
        repository.download(
          'https://compliance-pilot.ms777.ru/api/v1/'
          'organizations/organization-1/evidence/evidence-1/download/?x=1',
        ),
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'invalid_download_path',
          ),
        ),
      );
    });

    test('AI cancellation refreshes a raced ETag before retrying', () async {
      Map<String, Object?> aiRequest(
        String status,
        String etag,
      ) => <String, Object?>{
        'id': 'request-1',
        'conversation_id': 'conversation-1',
        'status': status,
        'provider': 'codex_subscription',
        'execution_mode': 'live',
        'requested_model': 'gpt-5.3-codex-spark',
        'selected_model': 'gpt-5.3-codex-spark',
        'actual_model': status == 'cancelled' ? 'gpt-5.3-codex-spark' : null,
        'fallback_used': false,
        'reroute': <String, Object?>{},
        'rate_limit_state': <String, Object?>{},
        'context': <String, Object?>{},
        'result': null,
        'safe_error': status == 'cancelled'
            ? 'AI-запрос отменён пользователем.'
            : null,
        'telemetry': <String, Object?>{},
        'sanitization': <String, Object?>{},
        'created_at': '2026-08-28T12:00:00Z',
        'updated_at': '2026-08-28T12:00:01Z',
        'etag': etag,
      };

      int cancelCalls = 0;
      final RecordingAdapter adapter = RecordingAdapter((
        RequestOptions options,
      ) {
        if (options.method == 'GET') {
          return _jsonBody(aiRequest('running', '"running-etag"'), 200);
        }
        cancelCalls += 1;
        if (cancelCalls == 1) {
          return _jsonBody(<String, Object?>{
            'error': <String, Object?>{
              'code': 'conflict',
              'message': 'Данные изменились.',
            },
          }, 409);
        }
        return _jsonBody(aiRequest('cancelled', '"cancelled-etag"'), 200);
      });
      final MemorySessionStore store = MemorySessionStore();
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: MemorySessionRevocationMarker(),
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(adapter),
        refreshDio: _dio(adapter),
      );
      final ComplianceRepository repository = ComplianceRepository(
        client: client,
        sessionStore: store,
        config: _config(),
      );

      final AiRequestDto cancelled = await repository.cancelAi(
        'organization-1',
        'conversation-1',
        AiRequestDto.fromJson(aiRequest('queued', '"queued-etag"')),
      );

      expect(cancelled.status, 'cancelled');
      expect(cancelCalls, 2);
      expect(
        adapter.requests.map((RequestOptions item) => item.method),
        <String>['POST', 'GET', 'POST'],
      );
      expect(adapter.requests.first.headers['If-Match'], '"queued-etag"');
      expect(adapter.requests.last.headers['If-Match'], '"running-etag"');
    });

    test('uses one refresh operation for concurrent callers', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('old-refresh');
      int refreshCalls = 0;
      final RecordingAdapter refreshAdapter = RecordingAdapter((
        RequestOptions options,
      ) async {
        refreshCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _jsonBody(<String, Object?>{
          'access': 'new-access',
          'refresh': 'new-refresh',
        }, 200);
      });
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: MemorySessionRevocationMarker(),
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 200))),
        refreshDio: _dio(refreshAdapter),
      );
      await Future.wait<void>(<Future<void>>[
        client.refreshSession(),
        client.refreshSession(),
        client.refreshSession(),
      ]);
      expect(refreshCalls, 1);
      expect(await store.readRefreshToken(), 'new-refresh');
      expect(client.hasAccessToken, isTrue);
    });

    test('replays safe GET after refresh and adds concurrency headers to mutations', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('refresh');
      int getCalls = 0;
      final RecordingAdapter mainAdapter = RecordingAdapter((
        RequestOptions options,
      ) {
        if (options.method == 'GET') {
          getCalls += 1;
          return getCalls == 1
              ? _jsonBody(<String, Object?>{
                  'error': <String, Object?>{'code': 'authentication_required'},
                }, 401)
              : _jsonBody(<String, Object?>{'ok': true}, 200);
        }
        return _jsonBody(<String, Object?>{'ok': true}, 200);
      });
      final RecordingAdapter refreshAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{
          'access': 'rotated-access',
          'refresh': 'rotated-refresh',
        }, 200),
      );
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: MemorySessionRevocationMarker(),
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(mainAdapter),
        refreshDio: _dio(refreshAdapter),
      )..setAccessToken('expired');
      final Response<Object?> response = await client.get('organizations/');
      expect(response.statusCode, 200);
      expect(getCalls, 2);
      expect(
        mainAdapter.requests.last.headers['Authorization'],
        'Bearer rotated-access',
      );

      await client.patch('organizations/id/', <String, Object?>{
        'notes': 'test',
      }, etag: '"etag"');
      final RequestOptions mutation = mainAdapter.requests.last;
      expect(mutation.headers['If-Match'], '"etag"');
      expect(mutation.headers['Idempotency-Key'], isA<String>());
    });

    test(
      'does not refresh or replay an ordinary keyed mutation after 401',
      () async {
        final MemorySessionStore store = MemorySessionStore();
        await store.writeRefreshToken('refresh');
        int mutationCalls = 0;
        int refreshCalls = 0;
        final RecordingAdapter mainAdapter = RecordingAdapter((
          RequestOptions options,
        ) {
          mutationCalls += 1;
          return _jsonBody(<String, Object?>{
            'error': <String, Object?>{'code': 'authentication_required'},
          }, 401);
        });
        final RecordingAdapter refreshAdapter = RecordingAdapter((_) {
          refreshCalls += 1;
          return _jsonBody(<String, Object?>{
            'access': 'rotated-access',
            'refresh': 'rotated-refresh',
          }, 200);
        });
        final ApiClient client = ApiClient(
          config: _config(),
          sessionStore: store,
          sessionRevocationMarker: MemorySessionRevocationMarker(),
          diagnostics: SanitizedDiagnostics(),
          dio: _dio(mainAdapter),
          refreshDio: _dio(refreshAdapter),
        )..setAccessToken('server-rejected-access');

        await expectLater(
          client.post('organizations/id/assessments/', <String, Object?>{
            'title': 'Синтетическая оценка',
          }),
          throwsA(
            isA<AppError>().having(
              (AppError error) => error.kind,
              'kind',
              AppErrorKind.authentication,
            ),
          ),
        );

        expect(mutationCalls, 1);
        expect(refreshCalls, 0);
        expect(await store.readRefreshToken(), 'refresh');
        expect(client.hasAccessToken, isTrue);
      },
    );

    test('valid access sends an AI request exactly once', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('unused-refresh');
      int refreshCalls = 0;
      final RecordingAdapter mainAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{'ok': true}, 202),
      );
      final ApiClient client =
          ApiClient(
            config: _config(),
            sessionStore: store,
            sessionRevocationMarker: MemorySessionRevocationMarker(),
            diagnostics: SanitizedDiagnostics(),
            dio: _dio(mainAdapter),
            refreshDio: _dio(
              RecordingAdapter((_) {
                refreshCalls += 1;
                return _jsonBody(<String, Object?>{}, 500);
              }),
            ),
          )..setAccessToken(
            'current-access',
            expiresIn: const Duration(minutes: 2),
          );

      final Response<Object?> response = await _postAiRequest(client);

      expect(response.statusCode, 202);
      expect(mainAdapter.requests, hasLength(1));
      expect(refreshCalls, 0);
      expect(
        mainAdapter.requests.single.headers['Authorization'],
        'Bearer current-access',
      );
      expect(
        mainAdapter.requests.single.headers['Idempotency-Key'],
        isA<String>().having(
          (String value) => value.length,
          'length',
          greaterThan(7),
        ),
      );
    });

    test('missing access refreshes before the AI request', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('current-refresh');
      int refreshCalls = 0;
      final RecordingAdapter mainAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{'ok': true}, 202),
      );
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: MemorySessionRevocationMarker(),
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(mainAdapter),
        refreshDio: _dio(
          RecordingAdapter((_) {
            refreshCalls += 1;
            return _jsonBody(<String, Object?>{
              'access': 'refreshed-access',
              'refresh': 'rotated-refresh',
            }, 200);
          }),
        ),
      );

      await _postAiRequest(client);

      expect(refreshCalls, 1);
      expect(mainAdapter.requests, hasLength(1));
      expect(
        mainAdapter.requests.single.headers['Authorization'],
        'Bearer refreshed-access',
      );
      expect(await store.readRefreshToken(), 'rotated-refresh');
    });

    for (final ({String name, Duration lifetime}) scenario
        in <({String name, Duration lifetime})>[
          (name: 'soon-expiring', lifetime: const Duration(seconds: 30)),
          (name: 'expired', lifetime: const Duration(seconds: -1)),
        ]) {
      test('${scenario.name} access refreshes before the AI request', () async {
        final MemorySessionStore store = MemorySessionStore();
        await store.writeRefreshToken('current-refresh');
        int refreshCalls = 0;
        final RecordingAdapter mainAdapter = RecordingAdapter(
          (_) => _jsonBody(<String, Object?>{'ok': true}, 202),
        );
        final ApiClient client = ApiClient(
          config: _config(),
          sessionStore: store,
          sessionRevocationMarker: MemorySessionRevocationMarker(),
          diagnostics: SanitizedDiagnostics(),
          dio: _dio(mainAdapter),
          refreshDio: _dio(
            RecordingAdapter((_) {
              refreshCalls += 1;
              return _jsonBody(<String, Object?>{
                'access': 'refreshed-access',
                'refresh': 'rotated-refresh',
              }, 200);
            }),
          ),
        )..setAccessToken('stale-access', expiresIn: scenario.lifetime);

        await _postAiRequest(client);

        expect(refreshCalls, 1);
        expect(mainAdapter.requests, hasLength(1));
        expect(
          mainAdapter.requests.single.headers['Authorization'],
          'Bearer refreshed-access',
        );
      });
    }

    test(
      'first token_not_valid refreshes and replays AI once with one key',
      () async {
        final MemorySessionStore store = MemorySessionStore();
        await store.writeRefreshToken('current-refresh');
        int refreshCalls = 0;
        final List<String> idempotencyKeys = <String>[];
        final List<Object?> authorizationHeaders = <Object?>[];
        final RecordingAdapter mainAdapter = RecordingAdapter((
          RequestOptions options,
        ) {
          idempotencyKeys.add(options.headers['Idempotency-Key']! as String);
          authorizationHeaders.add(options.headers['Authorization']);
          if (idempotencyKeys.length == 1) {
            return _jsonBody(<String, Object?>{
              'error': <String, Object?>{
                'code': 'token_not_valid',
                'message': 'Запрос содержит ошибки.',
              },
            }, 401);
          }
          return _jsonBody(<String, Object?>{'ok': true}, 202);
        });
        final ApiClient client =
            ApiClient(
              config: _config(),
              sessionStore: store,
              sessionRevocationMarker: MemorySessionRevocationMarker(),
              diagnostics: SanitizedDiagnostics(),
              dio: _dio(mainAdapter),
              refreshDio: _dio(
                RecordingAdapter((_) {
                  refreshCalls += 1;
                  return _jsonBody(<String, Object?>{
                    'access': 'refreshed-access',
                    'refresh': 'rotated-refresh',
                  }, 200);
                }),
              ),
            )..setAccessToken(
              'server-rejected-access',
              expiresIn: const Duration(minutes: 2),
            );

        final Response<Object?> response = await _postAiRequest(client);

        expect(response.statusCode, 202);
        expect(mainAdapter.requests, hasLength(2));
        expect(refreshCalls, 1);
        expect(idempotencyKeys.toSet(), hasLength(1));
        expect(authorizationHeaders, <Object?>[
          'Bearer server-rejected-access',
          'Bearer refreshed-access',
        ]);
        expect(await store.readRefreshToken(), 'rotated-refresh');
      },
    );

    test('second AI 401 stops replay and wipes the session', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('current-refresh');
      final MemorySessionRevocationMarker marker =
          MemorySessionRevocationMarker();
      int refreshCalls = 0;
      final RecordingAdapter mainAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{
          'error': <String, Object?>{
            'code': 'token_not_valid',
            'message': 'Запрос содержит ошибки.',
          },
        }, 401),
      );
      final ApiClient client =
          ApiClient(
            config: _config(),
            sessionStore: store,
            sessionRevocationMarker: marker,
            diagnostics: SanitizedDiagnostics(),
            dio: _dio(mainAdapter),
            refreshDio: _dio(
              RecordingAdapter((_) {
                refreshCalls += 1;
                return _jsonBody(<String, Object?>{
                  'access': 'refreshed-access',
                  'refresh': 'rotated-refresh',
                }, 200);
              }),
            ),
          )..setAccessToken(
            'server-rejected-access',
            expiresIn: const Duration(minutes: 2),
          );

      await expectLater(
        _postAiRequest(client),
        throwsA(
          isA<AppError>()
              .having(
                (AppError error) => error.code,
                'code',
                'ai_session_refresh_failed',
              )
              .having(
                (AppError error) => error.safeMessage,
                'safeMessage',
                'Сессия завершена. Войдите повторно.',
              ),
        ),
      );

      expect(mainAdapter.requests, hasLength(2));
      expect(refreshCalls, 1);
      expect(client.hasAccessToken, isFalse);
      expect(await store.readRefreshToken(), isNull);
      expect(await marker.isSet(), isTrue);
    });

    test('invalid refresh blocks AI and wipes tokens before POST', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('invalid-refresh');
      final MemorySessionRevocationMarker marker =
          MemorySessionRevocationMarker();
      final RecordingAdapter mainAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{'ok': true}, 202),
      );
      final ApiClient client =
          ApiClient(
            config: _config(),
            sessionStore: store,
            sessionRevocationMarker: marker,
            diagnostics: SanitizedDiagnostics(),
            dio: _dio(mainAdapter),
            refreshDio: _dio(
              RecordingAdapter(
                (_) => _jsonBody(<String, Object?>{
                  'error': <String, Object?>{'code': 'token_not_valid'},
                }, 401),
              ),
            ),
          )..setAccessToken(
            'expired-access',
            expiresIn: const Duration(seconds: -1),
          );

      await expectLater(
        _postAiRequest(client),
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'ai_session_refresh_failed',
          ),
        ),
      );

      expect(mainAdapter.requests, isEmpty);
      expect(client.hasAccessToken, isFalse);
      expect(await store.readRefreshToken(), isNull);
      expect(await marker.isSet(), isTrue);
    });

    test('concurrent AI requests share one proactive refresh', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('current-refresh');
      int refreshCalls = 0;
      final RecordingAdapter mainAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{'ok': true}, 202),
      );
      final ApiClient client =
          ApiClient(
            config: _config(),
            sessionStore: store,
            sessionRevocationMarker: MemorySessionRevocationMarker(),
            diagnostics: SanitizedDiagnostics(),
            dio: _dio(mainAdapter),
            refreshDio: _dio(
              RecordingAdapter((_) async {
                refreshCalls += 1;
                await Future<void>.delayed(const Duration(milliseconds: 20));
                return _jsonBody(<String, Object?>{
                  'access': 'refreshed-access',
                  'refresh': 'rotated-refresh',
                }, 200);
              }),
            ),
          )..setAccessToken(
            'soon-expiring-access',
            expiresIn: const Duration(seconds: 30),
          );

      await Future.wait<Response<Object?>>(<Future<Response<Object?>>>[
        _postAiRequest(client),
        _postAiRequest(client),
      ]);

      expect(refreshCalls, 1);
      expect(mainAdapter.requests, hasLength(2));
      expect(
        mainAdapter.requests
            .map((RequestOptions item) => item.headers['Idempotency-Key'])
            .toSet(),
        hasLength(2),
      );
    });

    test('AI refresh diagnostics never contain access or refresh tokens', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('sensitive-old-refresh');
      final SanitizedDiagnostics diagnostics = SanitizedDiagnostics();
      final RecordingAdapter mainAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{'ok': true}, 202),
      );
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: MemorySessionRevocationMarker(),
        diagnostics: diagnostics,
        dio: _dio(mainAdapter),
        refreshDio: _dio(
          RecordingAdapter(
            (_) => _jsonBody(<String, Object?>{
              'access': 'sensitive-new-access',
              'refresh': 'sensitive-new-refresh',
            }, 200),
          ),
        ),
      );

      await _postAiRequest(client);

      final String safeDiagnostics = diagnostics.entries
          .map(
            (DiagnosticEntry item) =>
                '${item.method} ${item.path} ${item.statusCode} ${item.errorCode}',
          )
          .join('\n');
      expect(safeDiagnostics, isNot(contains('sensitive-old-refresh')));
      expect(safeDiagnostics, isNot(contains('sensitive-new-refresh')));
      expect(safeDiagnostics, isNot(contains('sensitive-new-access')));
      expect(safeDiagnostics, isNot(contains('Синтетический')));
    });

    test(
      'invalid refresh wipes session and unknown host is rejected',
      () async {
        final MemorySessionStore store = MemorySessionStore();
        await store.writeRefreshToken('revoked');
        int invalidated = 0;
        final ApiClient client = ApiClient(
          config: _config(),
          sessionStore: store,
          sessionRevocationMarker: MemorySessionRevocationMarker(),
          diagnostics: SanitizedDiagnostics(),
          dio: _dio(
            RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 200)),
          ),
          refreshDio: _dio(
            RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 401)),
          ),
          onSessionInvalidated: () => invalidated += 1,
        );
        await expectLater(client.refreshSession(), throwsA(isA<AppError>()));
        expect(await store.readRefreshToken(), isNull);
        expect(invalidated, 1);
        await expectLater(
          client.get('https://attacker.invalid/api/v1/data/'),
          throwsA(
            isA<AppError>().having(
              (AppError error) => error.code,
              'code',
              'hostname_rejected',
            ),
          ),
        );
      },
    );

    test(
      'logout cancellation stops in-flight work and clears access state',
      () async {
        final MemorySessionStore store = MemorySessionStore();
        await store.writeRefreshToken('refresh');
        final Completer<ResponseBody> pending = Completer<ResponseBody>();
        final ApiClient client = ApiClient(
          config: _config(),
          sessionStore: store,
          sessionRevocationMarker: MemorySessionRevocationMarker(),
          diagnostics: SanitizedDiagnostics(),
          dio: _dio(RecordingAdapter((_) => pending.future)),
          refreshDio: _dio(
            RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 200)),
          ),
        )..setAccessToken('access');
        final Future<Response<Object?>> request = client.get('organizations/');
        final Future<void> cancelled = expectLater(
          request,
          throwsA(
            isA<AppError>().having(
              (AppError error) => error.kind,
              'kind',
              AppErrorKind.cancelled,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await client.invalidateLocalSession();
        await cancelled;
        expect(client.hasAccessToken, isFalse);
        expect(await store.readRefreshToken(), isNull);
      },
    );

    test(
      'storage clear failure still invalidates memory and notifies the UI',
      () async {
        final ThrowingClearSessionStore store = ThrowingClearSessionStore();
        int invalidated = 0;
        final MemorySessionRevocationMarker marker =
            MemorySessionRevocationMarker();
        final ApiClient client = ApiClient(
          config: _config(),
          sessionStore: store,
          sessionRevocationMarker: marker,
          diagnostics: SanitizedDiagnostics(),
          dio: _dio(
            RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 200)),
          ),
          refreshDio: _dio(
            RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 200)),
          ),
          onSessionInvalidated: () => invalidated += 1,
        )..setAccessToken('access');

        await expectLater(
          client.invalidateLocalSession(),
          throwsA(isA<StateError>()),
        );
        expect(client.hasAccessToken, isFalse);
        expect(invalidated, 1);
        expect(await store.readRefreshToken(), 'session-invalidated');
        expect(await marker.isSet(), isTrue);
      },
    );

    test('logout cancels a pending refresh request', () async {
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('old-refresh');
      final MemorySessionRevocationMarker marker =
          MemorySessionRevocationMarker();
      final Completer<ResponseBody> pending = Completer<ResponseBody>();
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: marker,
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 200))),
        refreshDio: _dio(RecordingAdapter((_) => pending.future)),
      )..setAccessToken('expired');

      final Future<void> refresh = client.refreshSession();
      final Future<void> rejected = expectLater(
        refresh,
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.kind,
            'kind',
            AppErrorKind.cancelled,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await client.invalidateLocalSession();
      await rejected;

      expect(client.hasAccessToken, isFalse);
      expect(await store.readRefreshToken(), isNull);
      expect(await marker.isSet(), isTrue);
    });

    test('late refresh write cannot resurrect a logged out session', () async {
      final DelayedWriteSessionStore store = DelayedWriteSessionStore()
        ..delayWrites = true;
      final MemorySessionRevocationMarker marker =
          MemorySessionRevocationMarker();
      final RecordingAdapter refreshAdapter = RecordingAdapter(
        (_) => _jsonBody(<String, Object?>{
          'access': 'late-access',
          'refresh': 'late-refresh',
        }, 200),
      );
      final ApiClient client = ApiClient(
        config: _config(),
        sessionStore: store,
        sessionRevocationMarker: marker,
        diagnostics: SanitizedDiagnostics(),
        dio: _dio(RecordingAdapter((_) => _jsonBody(<String, Object?>{}, 200))),
        refreshDio: _dio(refreshAdapter),
      )..setAccessToken('expired');

      final Future<void> refresh = client.refreshSession();
      final Future<void> rejected = expectLater(
        refresh,
        throwsA(
          isA<AppError>().having(
            (AppError error) => error.code,
            'code',
            'session_invalidated',
          ),
        ),
      );
      await store.writeStarted.future;
      await client.invalidateLocalSession();
      store.releaseWrite.complete();
      await rejected;

      expect(client.hasAccessToken, isFalse);
      expect(await store.readRefreshToken(), isNull);
      expect(await marker.isSet(), isTrue);
    });
  });
}
