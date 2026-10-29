import 'dart:io';

import 'package:compliance_navigator/core/network/compliance_repository.dart';
import 'package:compliance_navigator/core/storage/transient_file_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  late Directory temporaryRoot;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp(
      'compliance-navigator-test-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'getTemporaryDirectory');
          return temporaryRoot.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test('download stays in transient cache and purge removes it', () async {
    final TransientFileService service = TransientFileService();
    final File saved = await service.save(
      DownloadPayload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentDisposition: 'attachment; filename="pilot-report.json"',
        contentType: 'application/json',
      ),
      scope: 'organization-1',
      fallbackName: 'fallback.json',
      allowedExtensions: const <String>{'.json'},
    );

    expect(await saved.readAsBytes(), <int>[1, 2, 3]);
    expect(saved.path, startsWith(temporaryRoot.path));
    expect(saved.path, endsWith('pilot-report.json'));

    await service.purge();
    expect(await saved.parent.exists(), isFalse);
    await service.purge();
  });

  test('system viewer receives only a validated transient file', () async {
    String? openedPath;
    final TransientFileService service = TransientFileService(
      openFile: (String filePath) async => openedPath = filePath,
    );
    final File saved = await service.save(
      DownloadPayload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentDisposition: 'attachment; filename="pilot-report.pdf"',
        contentType: 'application/pdf',
      ),
      scope: 'organization-1',
      fallbackName: 'fallback.pdf',
      allowedExtensions: const <String>{'.pdf'},
    );

    await service.open(saved, isAllowed: () => true);

    expect(openedPath, saved.path);
  });

  test('system viewer rejects a file outside transient cache', () async {
    var opened = false;
    final TransientFileService service = TransientFileService(
      openFile: (String _) async => opened = true,
    );
    final File outside = File(
      '${temporaryRoot.parent.path}/compliance-navigator-outside.txt',
    );
    await outside.writeAsString('synthetic');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });

    await expectLater(
      service.open(outside, isAllowed: () => true),
      throwsA(isA<FileSystemException>()),
    );
    expect(opened, isFalse);
  });

  test('organization scopes do not overwrite or discard each other', () async {
    final TransientFileService service = TransientFileService();
    final DownloadPayload payload = DownloadPayload(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      contentDisposition: 'attachment; filename="report.json"',
      contentType: 'application/json',
    );
    final File first = await service.save(
      payload,
      scope: 'organization-1',
      fallbackName: 'report.json',
      allowedExtensions: const <String>{'.json'},
    );
    final File second = await service.save(
      payload,
      scope: 'organization-2',
      fallbackName: 'report.json',
      allowedExtensions: const <String>{'.json'},
    );

    expect(first.path, isNot(second.path));
    await service.discard(first);
    expect(await first.exists(), isFalse);
    expect(await second.exists(), isTrue);
  });

  test('share rejects files outside the transient cache', () async {
    final TransientFileService service = TransientFileService();
    final File outside = File(
      '${temporaryRoot.parent.path}/compliance-navigator-share-outside.txt',
    );
    await outside.writeAsString('synthetic');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });

    await expectLater(
      service.share(outside, isAllowed: () => true),
      throwsA(isA<FileSystemException>()),
    );
  });
}
