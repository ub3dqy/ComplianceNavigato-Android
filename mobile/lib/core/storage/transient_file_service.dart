import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../network/compliance_repository.dart';
import '../network/filename_policy.dart';

Future<Directory> _systemTemporaryDirectory() => getTemporaryDirectory();

const MethodChannel _transientFileChannel = MethodChannel(
  'ru.ms777.compliancenavigator/transient-file',
);

Future<void> _systemOpenTransientFile(String filePath) =>
    _transientFileChannel.invokeMethod<void>(
      'openTransientFile',
      <String, String>{'path': filePath},
    );

typedef TransientFileOpener = Future<void> Function(String filePath);

final class TransientFileService {
  TransientFileService({
    Future<Directory> Function()? temporaryDirectory,
    TransientFileOpener? openFile,
  }) : _temporaryDirectory = temporaryDirectory ?? _systemTemporaryDirectory,
       _openFile = openFile ?? _systemOpenTransientFile;

  static const String _directoryName = 'compliance-navigator-transient';
  final Future<Directory> Function() _temporaryDirectory;
  final TransientFileOpener _openFile;

  Future<File> save(
    DownloadPayload payload, {
    required String scope,
    required String fallbackName,
    Set<String> allowedExtensions = safeDownloadExtensions,
  }) async {
    final Directory root = await _directory(create: true);
    final String safeScope = _validatedScope(scope);
    final Directory directory = Directory(path.join(root.path, safeScope));
    if (!path.isWithin(root.path, directory.path)) {
      throw const FormatException('Invalid transient file scope.');
    }
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final String name = validatedFilename(
      contentDisposition: payload.contentDisposition,
      fallback: fallbackName,
      allowedExtensions: allowedExtensions,
    );
    final String targetPath = path.join(directory.path, name);
    if (!path.isWithin(directory.path, targetPath)) {
      throw const FormatException('Download path escaped the cache directory.');
    }
    final File target = File(targetPath);
    await target.writeAsBytes(payload.bytes, flush: true);
    return target;
  }

  Future<void> open(File file, {required bool Function() isAllowed}) async {
    final File validated = await _validatedTransientFile(file);
    if (!isAllowed()) {
      return;
    }
    await _openFile(validated.path);
  }

  Future<ShareResult?> share(
    File file, {
    required bool Function() isAllowed,
  }) async {
    final File validated = await _validatedTransientFile(file);
    if (!isAllowed()) {
      return null;
    }
    return SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(validated.path)]),
    );
  }

  Future<void> discard(File file) async {
    final File validated = await _validatedTransientFile(
      file,
      requireExisting: false,
      requireViewerMimeType: false,
    );
    if (await validated.exists()) {
      await validated.delete();
    }
  }

  Future<void> purge() async {
    final Directory directory = await _directory(create: false);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Directory> _directory({required bool create}) async {
    final Directory cache = await _temporaryDirectory();
    final Directory directory = Directory(
      path.join(cache.path, _directoryName),
    );
    if (!path.isWithin(cache.path, directory.path)) {
      throw StateError('Invalid transient directory.');
    }
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _validatedTransientFile(
    File file, {
    bool requireExisting = true,
    bool requireViewerMimeType = true,
  }) async {
    final Directory directory = await _directory(create: false);
    final String root = path.normalize(path.absolute(directory.path));
    final String target = path.normalize(path.absolute(file.path));
    final File validated = File(target);
    if (!path.isWithin(root, target) ||
        (requireExisting && !await validated.exists())) {
      throw const FileSystemException(
        'Разрешён только временный файл приложения.',
      );
    }
    if (requireViewerMimeType) {
      final String? mediaType = lookupMimeType(target);
      if (mediaType == null || !_allowedViewerMimeTypes.contains(mediaType)) {
        throw const FormatException('Формат файла нельзя открыть безопасно.');
      }
    }
    return validated;
  }

  String _validatedScope(String value) {
    final String normalized = value.trim();
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$').hasMatch(normalized)) {
      throw const FormatException('Invalid transient file scope.');
    }
    return normalized;
  }
}

const Set<String> _allowedViewerMimeTypes = <String>{
  'application/json',
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/jpeg',
  'image/png',
  'text/csv',
  'text/html',
  'text/plain',
};
