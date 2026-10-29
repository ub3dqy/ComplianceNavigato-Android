import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef SessionStateDirectory = Future<Directory> Function();

abstract interface class SessionRevocationMarker {
  Future<bool> isSet();
  Future<void> set();
  Future<void> clear();
}

final class FileSessionRevocationMarker implements SessionRevocationMarker {
  FileSessionRevocationMarker({SessionStateDirectory? stateDirectory})
    : _stateDirectory = stateDirectory ?? getApplicationSupportDirectory;

  static const String _fileName = 'session-invalidated-v1';
  final SessionStateDirectory _stateDirectory;

  Future<File> _file() async {
    final Directory directory = await _stateDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<bool> isSet() async => (await _file()).exists();

  @override
  Future<void> set() async {
    final RandomAccessFile marker = await (await _file()).open(
      mode: FileMode.write,
    );
    try {
      await marker.writeByte(1);
      await marker.flush();
    } finally {
      await marker.close();
    }
  }

  @override
  Future<void> clear() async {
    final File marker = await _file();
    if (await marker.exists()) {
      await marker.delete();
    }
  }
}

final class MemorySessionRevocationMarker implements SessionRevocationMarker {
  bool _isSet = false;

  @override
  Future<bool> isSet() async => _isSet;

  @override
  Future<void> set() async => _isSet = true;

  @override
  Future<void> clear() async => _isSet = false;
}
