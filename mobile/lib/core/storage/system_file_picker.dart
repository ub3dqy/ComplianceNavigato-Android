import 'package:file_picker/file_picker.dart';

import 'fns_extract_file.dart';

typedef EvidencePickOperation = Future<PlatformFile?> Function();
typedef EvidenceCacheCleanupOperation = Future<void> Function();

final class SystemFilePicker {
  SystemFilePicker({
    EvidencePickOperation? pickEvidence,
    EvidenceCacheCleanupOperation? clearTemporaryFiles,
  }) : _pickEvidence = pickEvidence ?? _pickEvidenceWithSaf,
       _clearTemporaryFiles = clearTemporaryFiles ?? clearPrivatePickerCache;

  static const List<String> allowedEvidenceExtensions = <String>[
    'pdf',
    'docx',
    'xlsx',
    'png',
    'jpg',
    'jpeg',
    'txt',
    'csv',
  ];

  final EvidencePickOperation _pickEvidence;
  final EvidenceCacheCleanupOperation _clearTemporaryFiles;

  Future<PlatformFile?> pickEvidence() async {
    final PlatformFile? selected = await _pickEvidence();
    if (selected == null) {
      return null;
    }
    final String extension = (selected.extension ?? '').toLowerCase();
    if (!allowedEvidenceExtensions.contains(extension) ||
        selected.path == null) {
      throw const FormatException('Выбранный файл не разрешён для загрузки.');
    }
    return selected;
  }

  Future<void> clearTemporaryFiles() => _clearTemporaryFiles();
}

Future<PlatformFile?> _pickEvidenceWithSaf() => FilePicker.pickFile(
  dialogTitle: 'Выберите подтверждение',
  type: FileType.custom,
  allowedExtensions: SystemFilePicker.allowedEvidenceExtensions,
);
