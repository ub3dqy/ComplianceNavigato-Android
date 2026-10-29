import 'dart:typed_data';

import 'package:compliance_navigator/core/storage/system_file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

base class _SyntheticPlatformFile extends PlatformFile {
  _SyntheticPlatformFile({required this.name, required String path})
    : uri = Uri.file(path);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  XFile get xFile => XFile(path!);

  @override
  Future<int> length() async => 5;

  @override
  int lengthSync() => 5;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(<int>[1, 2, 3]);

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream<Uint8List>.value(Uint8List.fromList(<int>[1, 2, 3]));
}

void main() {
  test('system picker accepts TXT, PDF and DOCX selections', () async {
    for (final String extension in <String>['txt', 'pdf', 'docx']) {
      final selected = _SyntheticPlatformFile(
        name: 'synthetic.$extension',
        path: '/synthetic/synthetic.$extension',
      );
      final picker = SystemFilePicker(pickEvidence: () async => selected);

      expect(await picker.pickEvidence(), same(selected));
    }
  });

  test('system picker cancellation is a safe no-op', () async {
    final picker = SystemFilePicker(pickEvidence: () async => null);

    expect(await picker.pickEvidence(), isNull);
  });

  test(
    'system picker delegates temporary-cache cleanup exactly once',
    () async {
      int cleanupCalls = 0;
      final picker = SystemFilePicker(
        pickEvidence: () async => null,
        clearTemporaryFiles: () async => cleanupCalls += 1,
      );

      await picker.clearTemporaryFiles();

      expect(cleanupCalls, 1);
    },
  );

  test('system picker rejects unsupported or non-local selections', () async {
    final unsupported = SystemFilePicker(
      pickEvidence: () async => _SyntheticPlatformFile(
        name: 'synthetic.exe',
        path: '/synthetic/synthetic.exe',
      ),
    );
    final missingPath = SystemFilePicker(
      pickEvidence: () async => _RemotePlatformFile(),
    );

    await expectLater(unsupported.pickEvidence(), throwsFormatException);
    await expectLater(missingPath.pickEvidence(), throwsFormatException);
  });
}

base class _RemotePlatformFile extends PlatformFile {
  @override
  String get name => 'synthetic.txt';

  @override
  Uri get uri => Uri.parse('content://synthetic/document/1');

  @override
  XFile get xFile => XFile.fromData(Uint8List(0), name: name);

  @override
  Future<int> length() async => 0;

  @override
  int lengthSync() => 0;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream<Uint8List>.empty();
}
