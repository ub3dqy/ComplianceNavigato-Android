import 'package:compliance_navigator/features/updates/app_updates.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native updater exposes the installed package and signer', (
    tester,
  ) async {
    final info = await nativeUpdates.invokeMapMethod<String, dynamic>(
      'appInfo',
    );
    expect(info?['package'], updatePackage);
    expect(info?['versionCode'], isA<int>());
    expect(info?['signerSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  testWidgets('native download validates destination before networking', (
    tester,
  ) async {
    await expectLater(
      nativeUpdates.invokeMethod<Object?>('startDownload', <String, Object>{
        'fileName': 'unrelated.apk',
        'versionCode': 2100000000,
        'bytes': 100,
        'sha256': 'a' * 64,
        'url': 'https://example.invalid/unrelated.apk',
      }),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'UPDATE_DOWNLOAD',
        ),
      ),
    );
  });

  testWidgets('native installer rejects missing and mismatched APKs', (
    tester,
  ) async {
    await expectLater(
      nativeUpdates.invokeMethod<String>('verifyUpdate', <String, Object>{
        'fileName': 'compliance-navigator-2100000000-${'a' * 64}.apk',
        'versionCode': 2100000000,
        'bytes': 100,
        'sha256': 'a' * 64,
      }),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'UPDATE_INVALID',
        ),
      ),
    );
  });

  testWidgets('querying an absent update is read-only and idle', (
    tester,
  ) async {
    final name = 'compliance-navigator-2100000000-${'f' * 64}.apk';
    final state = await nativeUpdates.invokeMapMethod<String, dynamic>(
      'downloadStatus',
      <String, Object>{
        'fileName': name,
        'versionCode': 2100000000,
        'bytes': 100,
        'sha256': 'f' * 64,
        'url': '$updateOrigin/android/releases/$name',
      },
    );
    expect(state?['state'], 'idle');
  });
}
