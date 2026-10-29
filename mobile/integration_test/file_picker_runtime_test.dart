import 'dart:io';

import 'package:compliance_navigator/core/storage/fns_extract_file.dart';
import 'package:compliance_navigator/core/storage/system_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android SAF selects TXT, PDF and DOCX and cancels safely', (
    WidgetTester tester,
  ) async {
    for (final String extension in <String>['txt', 'pdf', 'docx']) {
      debugPrint('CN_PICKER_READY:$extension');
      final PlatformFile? selected = await FilePicker.pickFile(
        dialogTitle: 'Выберите синтетический файл',
        type: FileType.custom,
        allowedExtensions: SystemFilePicker.allowedEvidenceExtensions,
      );
      expect(selected, isNotNull);
      expect(selected!.name, 'cn-picker-synthetic.$extension');
      expect(selected.extension, extension);
      expect(selected.path, isNotNull);
      expect(await selected.length(), greaterThan(0));
      if (extension == 'pdf') {
        final bytes = await FnsExtractFileReader(pick: () async => selected)
            .pickBytes();
        expect(bytes, isNotNull);
        expect(String.fromCharCodes(bytes!.take(5)), '%PDF-');
        expect(await File(selected.path!).exists(), isFalse);
        debugPrint('CN_FNS_PRIVATE_COPY_CLEANED');
      }
      debugPrint('CN_PICKER_DONE:$extension');
    }

    debugPrint('CN_PICKER_READY:cancel');
    final PlatformFile? cancelled = await FilePicker.pickFile(
      dialogTitle: 'Отмените выбор',
      type: FileType.custom,
      allowedExtensions: SystemFilePicker.allowedEvidenceExtensions,
    );
    expect(cancelled, isNull);
    debugPrint('CN_PICKER_DONE:cancel');
  });
}
