import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Read only a private Android SAF cache copy. Never delete the source document.
final class FnsExtractFileReader {
  FnsExtractFileReader({
    Future<PlatformFile?> Function()? pick,
    Future<Directory> Function()? cacheDirectory,
  }) : _pick = pick ?? _pickPdf,
       _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  static const maxBytes = 5 * 1024 * 1024;
  final Future<PlatformFile?> Function() _pick;
  final Future<Directory> Function() _cacheDirectory;

  Future<Uint8List?> pickBytes() async {
    final selected = await _pick();
    if (selected == null) return null;
    if (selected.path == null) {
      throw const FormatException('Не удалось открыть выбранную выписку.');
    }
    final root = path.join(
      await (await _cacheDirectory()).resolveSymbolicLinks(),
      'file_picker',
    );
    final canonical = await File(selected.path!).resolveSymbolicLinks();
    if (!path.isWithin(root, canonical)) {
      throw const FormatException('Выберите PDF через системное окно Android.');
    }
    final file = File(canonical);
    try {
      if ((selected.extension ?? '').toLowerCase() != 'pdf' ||
          await file.length() > maxBytes) {
        throw const FormatException('Нужна выписка в PDF размером до 5 МБ.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.openRead()) {
        if (builder.length + chunk.length > maxBytes) {
          throw const FormatException('Размер выписки превышает 5 МБ.');
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.length < 8 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
        throw const FormatException('Выбранный файл не является PDF.');
      }
      return bytes;
    } finally {
      // Complete before upload/preview; no full extract remains in our cache.
      if (await file.exists()) await file.delete();
    }
  }
}

Future<PlatformFile?> _pickPdf() => FilePicker.pickFile(
  dialogTitle: 'Выберите выписку ФНС (PDF)',
  type: FileType.custom,
  allowedExtensions: const ['pdf'],
);

/// The plugin's void cleanup ignores Android File.delete() false results.
/// Delete only its verified private cache and propagate any failure instead.
Future<void> clearPrivatePickerCache({
  Future<Directory> Function()? cacheDirectory,
}) async {
  final cache = await (cacheDirectory ?? getTemporaryDirectory)();
  final base = await cache.resolveSymbolicLinks();
  final root = path.join(base, 'file_picker');
  if (!path.isWithin(base, root) || path.basename(root) != 'file_picker') {
    throw StateError('Invalid private picker cache directory.');
  }
  final rootType = await FileSystemEntity.type(root, followLinks: false);
  if (rootType == FileSystemEntityType.notFound) return;
  if (rootType != FileSystemEntityType.directory) {
    throw StateError('Private picker cache is not a directory.');
  }

  Future<void> discard(FileSystemEntity entity, int depth) async {
    if (depth > 32 ||
        (entity.path != root && !path.isWithin(root, entity.path))) {
      throw StateError('Private picker cache path escaped its scope.');
    }
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await for (final child in Directory(
        entity.path,
      ).list(followLinks: false)) {
        await discard(child, depth + 1);
      }
      await Directory(entity.path).delete();
    } else if (type == FileSystemEntityType.link) {
      await Link(entity.path).delete();
    } else if (type == FileSystemEntityType.file) {
      await File(entity.path).delete();
    } else if (type != FileSystemEntityType.notFound) {
      throw StateError('Unsupported private picker cache entry.');
    }
  }

  await discard(Directory(root), 0);
}
