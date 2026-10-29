import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/errors/app_error.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const String _schemaHash =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'; // pragma: allowlist secret

AppConfig _config() => AppConfig.validate(const <String, String>{
  'APP_ENV': 'staging',
  'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
  'OPENAI_API_ENABLED': 'false',
  'AI_PROVIDER_AUTO_SWITCH': 'false',
  'GIT_COMMIT_SHA': 'device-remediation-test',
  'API_SCHEMA_SHA256': _schemaHash,
});

ResponseBody _jsonBody(Object? value, int status) => ResponseBody.fromString(
  jsonEncode(value),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
);

final class _UploadSequenceAdapter implements HttpClientAdapter {
  _UploadSequenceAdapter(
    this.statuses, {
    this.release,
    Completer<void>? started,
  }) : started = started ?? Completer<void>();

  final List<int> statuses;
  final Completer<void>? release;
  final Completer<void> started;
  int calls = 0;
  int createdEvidenceObjects = 0;
  final List<Uint8List> bodies = <Uint8List>[];
  final List<RequestOptions> requests = <RequestOptions>[];

  ResponseBody _response(RequestOptions options) {
    final int status = statuses[min(calls - 1, statuses.length - 1)];
    if (status >= 200 && status < 300) {
      createdEvidenceObjects += 1;
      return _jsonBody(<String, Object?>{'ok': true}, status);
    }
    return _jsonBody(<String, Object?>{
      'error': <String, Object?>{
        'code': status == 401 ? 'authentication_required' : 'request_failed',
      },
    }, status);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    requests.add(options);
    final BytesBuilder body = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final Uint8List chunk in requestStream) {
        body.add(chunk);
      }
    }
    bodies.add(body.takeBytes());
    if (!started.isCompleted) {
      started.complete();
    }
    if (release == null) {
      return _response(options);
    }
    return Future.any<ResponseBody>(<Future<ResponseBody>>[
      release!.future.then((_) => _response(options)),
      if (cancelFuture != null)
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

final class _RefreshAdapter implements HttpClientAdapter {
  _RefreshAdapter({this.status = 200, this.release});

  final int status;
  final Completer<void>? release;
  final Completer<void> started = Completer<void>();
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls += 1;
    if (!started.isCompleted) {
      started.complete();
    }
    await release?.future;
    if (status >= 200 && status < 300) {
      return _jsonBody(<String, Object?>{
        'access': 'rotated-access',
        'refresh': 'rotated-refresh',
      }, status);
    }
    return _jsonBody(<String, Object?>{
      'error': <String, Object?>{'code': 'server_unavailable'},
    }, status);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(HttpClientAdapter adapter) {
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

ApiClient _client({
  required SessionStore store,
  required HttpClientAdapter uploadAdapter,
  required HttpClientAdapter refreshAdapter,
  SanitizedDiagnostics? diagnostics,
  SessionInvalidated? onSessionInvalidated,
}) => ApiClient(
  config: _config(),
  sessionStore: store,
  sessionRevocationMarker: MemorySessionRevocationMarker(),
  diagnostics: diagnostics ?? SanitizedDiagnostics(),
  dio: _dio(uploadAdapter),
  refreshDio: _dio(refreshAdapter),
  onSessionInvalidated: onSessionInvalidated,
);

Future<FormData> _form(File file, String fileName) async =>
    FormData.fromMap(<String, Object?>{
      'title': 'Синтетическое подтверждение',
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

Future<File> _fixture(Directory directory, String extension) async {
  final File file = File(
    '${directory.path}${Platform.pathSeparator}synthetic.$extension',
  );
  await file.writeAsString('synthetic $extension upload body');
  return file;
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cn-device-remediation-');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'multipart is recreated once with the same scope, ETag and idempotency key',
    () async {
      final File file = await _fixture(directory, 'txt');
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('valid-refresh');
      final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
        401,
        201,
      ]);
      final _RefreshAdapter refreshAdapter = _RefreshAdapter();
      final ApiClient client =
          _client(
            store: store,
            uploadAdapter: uploadAdapter,
            refreshAdapter: refreshAdapter,
          )..setAccessToken(
            'server-rejected-access',
            expiresIn: const Duration(minutes: 10),
          );

      final Response<Object?> response = await client.upload(
        'organizations/organization-1/evidence/',
        formData: await _form(file, 'synthetic.txt'),
        etag: '"synthetic-etag"',
        onSendProgress: (_, _) {},
      );

      expect(response.statusCode, 201);
      expect(uploadAdapter.calls, 2);
      expect(refreshAdapter.calls, 1);
      expect(uploadAdapter.createdEvidenceObjects, 1);
      expect(uploadAdapter.bodies, hasLength(2));
      expect(
        uploadAdapter.bodies.every((Uint8List body) => body.isNotEmpty),
        isTrue,
      );
      expect(uploadAdapter.bodies[1], uploadAdapter.bodies[0]);
      expect(
        uploadAdapter.requests.map((RequestOptions item) => item.path).toSet(),
        <String>{'organizations/organization-1/evidence/'},
      );
      expect(
        uploadAdapter.requests[1].headers['Idempotency-Key'],
        uploadAdapter.requests[0].headers['Idempotency-Key'],
      );
      expect(
        uploadAdapter.requests.map(
          (RequestOptions item) => item.headers['If-Match'],
        ),
        everyElement('"synthetic-etag"'),
      );
      expect(await store.readRefreshToken(), 'rotated-refresh');
    },
  );

  test('near-expiry access refreshes once before upload', () async {
    final File file = await _fixture(directory, 'pdf');
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('valid-refresh');
    final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
      201,
    ]);
    final _RefreshAdapter refreshAdapter = _RefreshAdapter();
    final ApiClient client =
        _client(
          store: store,
          uploadAdapter: uploadAdapter,
          refreshAdapter: refreshAdapter,
        )..setAccessToken(
          'near-expiry-access',
          expiresIn: const Duration(seconds: 10),
        );

    await client.upload(
      'organizations/organization-1/evidence/',
      formData: await _form(file, 'synthetic.pdf'),
      onSendProgress: (_, _) {},
    );

    expect(refreshAdapter.calls, 1);
    expect(uploadAdapter.calls, 1);
    expect(
      uploadAdapter.requests.single.headers['Authorization'],
      'Bearer rotated-access',
    );
    expect(await store.readRefreshToken(), 'rotated-refresh');
  });

  test('concurrent callers share one refresh mutex', () async {
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('valid-refresh');
    final Completer<void> release = Completer<void>();
    final _RefreshAdapter refreshAdapter = _RefreshAdapter(release: release);
    final ApiClient client = _client(
      store: store,
      uploadAdapter: _UploadSequenceAdapter(<int>[200]),
      refreshAdapter: refreshAdapter,
    );

    final List<Future<void>> refreshes = <Future<void>>[
      client.refreshSession(),
      client.refreshSession(),
      client.refreshSession(),
    ];
    await refreshAdapter.started.future;
    release.complete();
    await Future.wait(refreshes);

    expect(refreshAdapter.calls, 1);
    expect(await store.readRefreshToken(), 'rotated-refresh');
  });

  test('refresh failure fails closed before any upload', () async {
    final File file = await _fixture(directory, 'docx');
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('valid-refresh');
    final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
      201,
    ]);
    final _RefreshAdapter refreshAdapter = _RefreshAdapter(status: 503);
    int invalidated = 0;
    final ApiClient client =
        _client(
          store: store,
          uploadAdapter: uploadAdapter,
          refreshAdapter: refreshAdapter,
          onSessionInvalidated: () => invalidated += 1,
        )..setAccessToken(
          'near-expiry-access',
          expiresIn: const Duration(seconds: 10),
        );

    await expectLater(
      client.upload(
        'organizations/organization-1/evidence/',
        formData: await _form(file, 'synthetic.docx'),
        onSendProgress: (_, _) {},
      ),
      throwsA(
        isA<AppError>()
            .having(
              (AppError error) => error.code,
              'code',
              'upload_session_refresh_failed',
            )
            .having(
              (AppError error) => error.safeMessage,
              'safeMessage',
              'Сессия завершена. Войдите повторно.',
            ),
      ),
    );

    expect(uploadAdapter.calls, 0);
    expect(await store.readRefreshToken(), isNull);
    expect(client.hasAccessToken, isFalse);
    expect(invalidated, 1);
  });

  test('a second authentication 401 is not retried', () async {
    final File file = await _fixture(directory, 'txt');
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('valid-refresh');
    final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
      401,
      401,
    ]);
    final _RefreshAdapter refreshAdapter = _RefreshAdapter();
    final ApiClient client =
        _client(
          store: store,
          uploadAdapter: uploadAdapter,
          refreshAdapter: refreshAdapter,
        )..setAccessToken(
          'server-rejected-access',
          expiresIn: const Duration(minutes: 10),
        );

    await expectLater(
      client.upload(
        'organizations/organization-1/evidence/',
        formData: await _form(file, 'synthetic.txt'),
        onSendProgress: (_, _) {},
      ),
      throwsA(
        isA<AppError>().having(
          (AppError error) => error.code,
          'code',
          'upload_session_refresh_failed',
        ),
      ),
    );

    expect(uploadAdapter.calls, 2);
    expect(refreshAdapter.calls, 1);
    expect(uploadAdapter.createdEvidenceObjects, 0);
    expect(client.hasAccessToken, isFalse);
    expect(await store.readRefreshToken(), isNull);
  });

  test('cancellation before proactive refresh starts no upload', () async {
    final File file = await _fixture(directory, 'txt');
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('valid-refresh');
    final Completer<void> releaseRefresh = Completer<void>();
    final _RefreshAdapter refreshAdapter = _RefreshAdapter(
      release: releaseRefresh,
    );
    final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
      201,
    ]);
    final ApiClient client =
        _client(
          store: store,
          uploadAdapter: uploadAdapter,
          refreshAdapter: refreshAdapter,
        )..setAccessToken(
          'near-expiry-access',
          expiresIn: const Duration(seconds: 10),
        );
    final CancelToken cancelToken = CancelToken();

    final Future<Response<Object?>> upload = client.upload(
      'organizations/organization-1/evidence/',
      formData: await _form(file, 'synthetic.txt'),
      cancelToken: cancelToken,
      onSendProgress: (_, _) {},
    );
    await refreshAdapter.started.future;
    final Future<void> rejected = expectLater(
      upload,
      throwsA(
        isA<AppError>().having(
          (AppError error) => error.kind,
          'kind',
          AppErrorKind.cancelled,
        ),
      ),
    );
    cancelToken.cancel('user_cancelled');
    await rejected;

    expect(uploadAdapter.calls, 0);
    releaseRefresh.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('cancellation after refresh stops the active upload', () async {
    final File file = await _fixture(directory, 'pdf');
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('valid-refresh');
    final Completer<void> releaseUpload = Completer<void>();
    final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
      201,
    ], release: releaseUpload);
    final _RefreshAdapter refreshAdapter = _RefreshAdapter();
    final ApiClient client =
        _client(
          store: store,
          uploadAdapter: uploadAdapter,
          refreshAdapter: refreshAdapter,
        )..setAccessToken(
          'near-expiry-access',
          expiresIn: const Duration(seconds: 10),
        );
    final CancelToken cancelToken = CancelToken();

    final Future<Response<Object?>> upload = client.upload(
      'organizations/organization-1/evidence/',
      formData: await _form(file, 'synthetic.pdf'),
      cancelToken: cancelToken,
      onSendProgress: (_, _) {},
    );
    await uploadAdapter.started.future;
    final Future<void> rejected = expectLater(
      upload,
      throwsA(
        isA<AppError>().having(
          (AppError error) => error.kind,
          'kind',
          AppErrorKind.cancelled,
        ),
      ),
    );
    cancelToken.cancel('user_cancelled');
    await rejected;

    expect(refreshAdapter.calls, 1);
    expect(uploadAdapter.calls, 1);
    expect(uploadAdapter.createdEvidenceObjects, 0);
    if (!releaseUpload.isCompleted) {
      releaseUpload.complete();
    }
  });

  test('TXT PDF and DOCX all survive one authentication replay', () async {
    for (final String extension in <String>['txt', 'pdf', 'docx']) {
      final File file = await _fixture(directory, extension);
      final MemorySessionStore store = MemorySessionStore();
      await store.writeRefreshToken('valid-refresh');
      final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
        401,
        201,
      ]);
      final _RefreshAdapter refreshAdapter = _RefreshAdapter();
      final ApiClient client =
          _client(
            store: store,
            uploadAdapter: uploadAdapter,
            refreshAdapter: refreshAdapter,
          )..setAccessToken(
            'server-rejected-access',
            expiresIn: const Duration(minutes: 10),
          );

      await client.upload(
        'organizations/organization-1/evidence/',
        formData: await _form(file, 'synthetic.$extension'),
        onSendProgress: (_, _) {},
      );

      expect(uploadAdapter.calls, 2, reason: extension);
      expect(uploadAdapter.createdEvidenceObjects, 1, reason: extension);
      expect(
        uploadAdapter.bodies.every((Uint8List body) => body.isNotEmpty),
        isTrue,
        reason: extension,
      );
    }
  });

  test('diagnostics contain no token or multipart body values', () async {
    final File file = await _fixture(directory, 'txt');
    await file.writeAsString('private-synthetic-body-marker');
    final MemorySessionStore store = MemorySessionStore();
    await store.writeRefreshToken('private-synthetic-refresh-marker');
    final SanitizedDiagnostics diagnostics = SanitizedDiagnostics();
    final _UploadSequenceAdapter uploadAdapter = _UploadSequenceAdapter(<int>[
      201,
    ]);
    final ApiClient client =
        _client(
          store: store,
          uploadAdapter: uploadAdapter,
          refreshAdapter: _RefreshAdapter(),
          diagnostics: diagnostics,
        )..setAccessToken(
          'private-synthetic-access-marker',
          expiresIn: const Duration(minutes: 10),
        );

    await client.upload(
      'organizations/organization-1/evidence/',
      formData: await _form(file, 'synthetic.txt'),
      onSendProgress: (_, _) {},
    );

    final String rendered = jsonEncode(
      diagnostics.entries
          .map(
            (DiagnosticEntry entry) => <String, Object?>{
              'method': entry.method,
              'path': entry.path,
              'status': entry.statusCode,
              'error': entry.errorCode,
            },
          )
          .toList(growable: false),
    );
    expect(rendered, isNot(contains('private-synthetic-body-marker')));
    expect(rendered, isNot(contains('private-synthetic-refresh-marker')));
    expect(rendered, isNot(contains('private-synthetic-access-marker')));
    expect(rendered, isNot(contains('Authorization')));
  });
}
