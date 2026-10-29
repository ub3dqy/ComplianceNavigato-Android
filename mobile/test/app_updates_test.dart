import 'dart:async';
import 'dart:convert';

import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/theme/app_theme.dart';
import 'package:compliance_navigator/features/authentication/login_screen.dart';
import 'package:compliance_navigator/features/authentication/session_gate_screen.dart';
import 'package:compliance_navigator/features/updates/app_updates.dart';
import 'package:compliance_navigator/features/updates/update_dialog.dart';
import 'package:compliance_navigator/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> installed() => <String, dynamic>{
  'package': updatePackage,
  'versionCode': 30500,
  'signerSha256': 'a' * 64,
};

Map<String, dynamic> manifest({int code = 30600}) {
  final name = 'compliance-navigator-$code-${'b' * 64}.apk';
  return <String, dynamic>{
    'schema': 1,
    'package': updatePackage,
    'version': '0.3.6',
    'version_code': code,
    'bytes': 100,
    'sha256': 'b' * 64,
    'certificate_sha256': 'a' * 64,
    'min_sdk': 26,
    'notes': 'Обновление с телефона.',
    'file': name,
    'source_commit': 'c' * 40,
    'url': '$updateOrigin/android/releases/$name',
  };
}

final class UpdateAdapter implements HttpClientAdapter {
  String body = jsonEncode(manifest());
  int status = 200;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: <String, List<String>>{
        'content-type': <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AppUpdates service;
  late UpdateAdapter adapter;
  late Map<String, dynamic> state;
  late Map<String, dynamic> startState;
  late String installResult;
  late bool corruptInstall;
  final calls = <MethodCall>[];

  Future<Object?> handleNative(MethodCall call) {
    calls.add(call);
    switch (call.method) {
      case 'appInfo':
        return SynchronousFuture<Object?>(installed());
      case 'downloadStatus':
        return SynchronousFuture<Object?>(state);
      case 'startDownload':
        state = Map<String, dynamic>.from(startState);
        return SynchronousFuture<Object?>(state);
      case 'cancelDownload':
        state = <String, dynamic>{'state': 'idle'};
        return SynchronousFuture<Object?>(state);
      case 'installUpdate':
        if (corruptInstall) {
          state = <String, dynamic>{'state': 'failed'};
          throw PlatformException(code: 'UPDATE_INVALID');
        }
        return SynchronousFuture<Object?>(installResult);
      case 'cancelUpdate':
        return SynchronousFuture<Object?>(null);
    }
    throw PlatformException(code: 'unexpected_method');
  }

  setUp(() {
    adapter = UpdateAdapter();
    service = AppUpdates(client: Dio()..httpClientAdapter = adapter);
    state = <String, dynamic>{'state': 'idle'};
    startState = <String, dynamic>{
      'state': 'ready',
      'received': 100,
      'bytes': 100,
    };
    installResult = 'installer_opened';
    corruptInstall = false;
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      nativeUpdates,
      handleNative,
    );
  });
  tearDown(() {
    service.dispose();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      nativeUpdates,
      null,
    );
  });

  test('parses a strictly newer matching signed APK', () {
    final offer = UpdateOffer.parse(manifest(), installed())!;
    expect(offer.versionCode, 30600);
    expect(offer.fileName, manifest()['file']);
    expect(offer.certificate, 'a' * 64);
    expect(UpdateOffer.parse(manifest(code: 30500), installed()), isNull);
    expect(UpdateOffer.parse(manifest(code: 30400), installed()), isNull);
  });

  for (final entry in <String, Object?>{
    'schema': 1.0,
    'package': 'another.package',
    'min_sdk': 26.0,
    'version': '../bad',
    'version_code': 1.5,
    'bytes': 536870913,
    'sha256': 'invalid',
    'certificate_sha256': 'd' * 64,
    'source_commit': 'invalid',
    'notes': 'x' * 1001,
    'url': 'https://example.invalid/update.apk',
    'file': '../private.apk',
    'unknown': true,
  }.entries) {
    test('rejects unsafe manifest field ${entry.key}', () {
      expect(
        () => UpdateOffer.parse(<String, dynamic>{
          ...manifest(),
          entry.key: entry.value,
        }, installed()),
        throwsA(isA<UpdateFailure>()),
      );
    });
  }

  test('checking never sends session headers or follows redirects', () async {
    final offer = await service.check();
    expect(offer?.versionCode, 30600);
    final request = adapter.requests.single;
    expect(request.uri.toString(), '$updateOrigin/android/latest.json');
    expect(request.followRedirects, isFalse);
    expect(
      request.headers.keys.map((key) => key.toLowerCase()),
      isNot(contains(anyOf('authorization', 'cookie'))),
    );
  });

  for (final status in <int>[301, 401, 404, 503]) {
    test('network response $status is a failure, not up-to-date', () async {
      adapter.status = status;
      await expectLater(service.check(), throwsA(isA<UpdateFailure>()));
    });
  }
  test('rejects oversized and invalid JSON', () async {
    adapter.body = 'x' * 16385;
    await expectLater(service.check(), throwsA(isA<UpdateFailure>()));
    adapter.body = '<html>unavailable</html>';
    await expectLater(service.check(), throwsA(isA<UpdateFailure>()));
  });
  test('disposal does not cancel a background Android download', () {
    service.dispose();
    expect(calls.where((call) => call.method == 'cancelDownload'), isEmpty);
  });
  test('unknown download and installer states fail closed', () async {
    final offer = UpdateOffer.parse(manifest(), installed())!;
    state = <String, dynamic>{'state': 'unexpected'};
    await expectLater(
      service.downloadState(offer),
      throwsA(isA<UpdateFailure>()),
    );
    installResult = 'unexpected';
    await expectLater(service.install(offer), throwsA(isA<UpdateFailure>()));
  });

  // Platform messages and Dio streaming also use the real event loop.
  // Advance frames while yielding that loop, and fail on an actual stalled UI.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      final elapsed = Stopwatch()..start();
      var frames = 0;
      do {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        if (elapsed.elapsed > const Duration(seconds: 30) || frames >= 1800) {
          throw TestFailure(
            'Update UI did not settle after platform work: '
            '$frames frames, ${adapter.requests.length} requests, '
            '${calls.map((call) => call.method).join(", ")}.',
          );
        }
      } while (tester.binding.hasScheduledFrame);
    });
  }

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    Future<bool> Function()? beforeInstall,
  }) async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      nativeUpdates,
      handleNative,
    );
    service.dispose();
    service = AppUpdates(client: Dio()..httpClientAdapter = adapter);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppUpdates(
                context,
                service,
                beforeInstall: beforeInstall,
              ),
              child: const Text('Проверить'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Проверить'));
    await settle(tester);
  }

  testWidgets('manual check, download and user-confirmed installation', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Доступно обновление'), findsOneWidget);
    await tester.tap(find.text('Скачать обновление'));
    await settle(tester);
    expect(find.text('Обновление готово'), findsOneWidget);
    expect(calls.where((call) => call.method == 'installUpdate'), isEmpty);
    await tester.tap(find.text('Установить'));
    await settle(tester);
    expect(find.textContaining('Подтвердите обновление'), findsOneWidget);
    expect(calls.where((call) => call.method == 'installUpdate').length, 1);
  });
  testWidgets('a current version shows no update without downloading', (
    tester,
  ) async {
    adapter.body = jsonEncode(manifest(code: 30500));
    await open(tester);
    expect(find.text('Обновлений нет'), findsOneWidget);
    expect(find.text('Скачать обновление'), findsNothing);
    expect(calls.where((call) => call.method == 'startDownload'), isEmpty);
  });
  testWidgets('unsaved form refusal postpones installation', (tester) async {
    state = <String, dynamic>{'state': 'ready', 'received': 100, 'bytes': 100};
    await open(tester, beforeInstall: () async => false);
    await tester.tap(find.text('Установить'));
    await settle(tester);
    expect(find.textContaining('Установка отложена'), findsOneWidget);
    expect(calls.where((call) => call.method == 'installUpdate'), isEmpty);
  });
  testWidgets('failed check displays retry instead of success', (tester) async {
    adapter.status = 503;
    await open(tester);
    expect(find.text('Не удалось проверить обновления'), findsOneWidget);
    expect(find.text('Обновлений нет'), findsNothing);
    adapter.status = 200;
    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(find.text('Доступно обновление'), findsOneWidget);
  });
  testWidgets('hide and reopen keeps an Android-managed download', (
    tester,
  ) async {
    startState = <String, dynamic>{
      'state': 'paused',
      'received': 50,
      'bytes': 100,
    };
    await open(tester);
    await tester.tap(find.text('Скачать обновление'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('50 %'), findsOneWidget);
    expect(find.textContaining('Android ожидает'), findsOneWidget);
    await tester.tap(find.text('Скрыть'));
    await settle(tester);
    expect(calls.where((call) => call.method == 'cancelDownload'), isEmpty);
    state = <String, dynamic>{'state': 'ready', 'received': 100, 'bytes': 100};
    await tester.tap(find.text('Проверить'));
    await settle(tester);
    expect(find.text('Обновление готово'), findsOneWidget);
    expect(calls.where((call) => call.method == 'startDownload').length, 1);
  });
  testWidgets('a previous failed transfer stays an error when reopened', (
    tester,
  ) async {
    state = <String, dynamic>{
      'state': 'failed',
      'message': 'Android не смог скачать обновление.',
    };
    await open(tester);
    expect(find.text('Android не смог скачать обновление.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Скачать обновление'), findsOneWidget);
    expect(find.text('Установить'), findsNothing);
  });
  testWidgets('explicit cancellation stops only the APK transfer', (
    tester,
  ) async {
    startState = <String, dynamic>{
      'state': 'running',
      'received': 10,
      'bytes': 100,
    };
    await open(tester);
    await tester.tap(find.text('Скачать обновление'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Отменить загрузку'));
    await settle(tester);
    expect(find.text('Загрузка отменена.'), findsOneWidget);
    expect(calls.where((call) => call.method == 'cancelDownload').length, 1);
    expect(find.text('Скачать обновление'), findsOneWidget);
  });
  testWidgets('unknown-source consent returns to a manual install button', (
    tester,
  ) async {
    installResult = 'permission_required';
    state = <String, dynamic>{'state': 'ready', 'received': 100, 'bytes': 100};
    await open(tester);
    await tester.tap(find.text('Установить'));
    await settle(tester);
    expect(find.textContaining('Разрешите установку из'), findsOneWidget);
    expect(find.text('Установить'), findsOneWidget);
  });
  testWidgets('a damaged download offers downloading again', (tester) async {
    state = <String, dynamic>{'state': 'ready', 'received': 100, 'bytes': 100};
    corruptInstall = true;
    await open(tester);
    await tester.tap(find.text('Установить'));
    await settle(tester);
    expect(find.text('Скачать обновление'), findsOneWidget);
    expect(find.textContaining('не прошёл проверку подписи'), findsOneWidget);
  });
  testWidgets('update dialog fits large text', (tester) async {
    await open(tester, scale: 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Позже'));
    await settle(tester);
    expect(service.presenting, isFalse);
  });

  for (final phase in <AuthPhase>[AuthPhase.signedOut, AuthPhase.offline]) {
    testWidgets('updates remain available before login in $phase', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appUpdatesProvider.overrideWithValue(service),
            authControllerProvider.overrideWithBuild(
              (ref, notifier) => AuthState(phase: phase),
            ),
            currentOrganizationProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: phase == AuthPhase.signedOut
                ? const LoginScreen()
                : const SessionGateScreen(),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Обновить приложение'));
      await tester.tap(find.text('Обновить приложение'));
      await settle(tester);
      expect(find.text('Доступно обновление'), findsOneWidget);
      expect(adapter.requests.single.uri.path, '/android/latest.json');
    });
  }
}
