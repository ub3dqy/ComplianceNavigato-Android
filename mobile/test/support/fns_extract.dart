import 'dart:io';
import 'dart:typed_data';

import 'package:compliance_navigator/core/storage/fns_extract_file.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

final class SyntheticFnsFile extends PlatformFile {
  SyntheticFnsFile(this.file);
  final File file;
  @override
  String get name => path.basename(file.path);
  @override
  Uri get uri => file.uri;
  @override
  XFile get xFile => XFile(file.path);
  @override
  Future<int> length() => file.length();
  @override
  int lengthSync() => file.lengthSync();
  @override
  Future<Uint8List> readAsBytes() => file.readAsBytes();
  @override
  Stream<Uint8List> readAsByteStream() =>
      file.openRead().map(Uint8List.fromList);
}

final class SyntheticFnsSelection {
  SyntheticFnsSelection(this.directory);
  final Directory directory;
  bool cancel = false;
  List<int> bytes = '%PDF-synthetic-local-transport-only'.codeUnits;
  File get file => File(
    path.join(directory.path, 'file_picker', 'synthetic', 'extract.pdf'),
  );
  late final reader = FnsExtractFileReader(
    cacheDirectory: () async => directory,
    pick: () async {
      if (cancel) return null;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return SyntheticFnsFile(file);
    },
  );

  Future<void> dispose() async {
    final target = path.absolute(directory.path);
    if (!path.isWithin(path.absolute(Directory.systemTemp.path), target) ||
        !path.basename(target).startsWith('cn-fns-test-')) {
      throw StateError('Unexpected synthetic fixture cleanup directory.');
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

Future<SyntheticFnsSelection> createSyntheticFnsSelection() async =>
    SyntheticFnsSelection(Directory.systemTemp.createTempSync('cn-fns-test-'));
