import 'dart:io';

import 'package:compliance_navigator/core/storage/fns_extract_file.dart';
import 'package:compliance_navigator/core/storage/private_cache_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fns_extract.dart';

void main() {
  test('startup cleanup removes private orphan copies and preserves original documents', () async {
    final fixture = await createSyntheticFnsSelection();
    addTearDown(fixture.dispose);
    final original = await File('${fixture.directory.path}/original.pdf')
        .writeAsString('source must remain');
    await fixture.file.parent.create(recursive: true);
    await fixture.file.writeAsString('%PDF-interrupted-private-copy');
    await clearPrivatePickerCache(
      cacheDirectory: () async => fixture.directory,
    );
    expect(await fixture.file.parent.parent.exists(), isFalse);
    expect(await original.readAsString(), 'source must remain');
    await clearPrivatePickerCache(
      cacheDirectory: () async => fixture.directory,
    );
    final invalid = await File('${fixture.directory.path}/file_picker')
        .writeAsString('unexpected regular file');
    await expectLater(
      clearPrivatePickerCache(cacheDirectory: () async => fixture.directory),
      throwsStateError,
    );
    expect(await invalid.exists(), isTrue);
  });

  test(
    'only the private picker copy is removed before returning PDF bytes',
    () async {
      final fixture = await createSyntheticFnsSelection();
      addTearDown(fixture.dispose);
      final original = await File('${fixture.directory.path}/original.pdf')
          .writeAsString('source must remain');
      final bytes = await fixture.reader.pickBytes();
      expect(bytes, fixture.bytes);
      expect(await fixture.file.exists(), isFalse);
      expect(await original.readAsString(), 'source must remain');
    },
  );

  test(
    'cancel and rejection never delete a source outside picker cache',
    () async {
      final fixture = await createSyntheticFnsSelection();
      addTearDown(fixture.dispose);
      fixture.cancel = true;
      expect(await fixture.reader.pickBytes(), isNull);
      final original = await File('${fixture.directory.path}/original.pdf')
          .writeAsString('%PDF-original');
      final reader = FnsExtractFileReader(
        cacheDirectory: () async => fixture.directory,
        pick: () async => SyntheticFnsFile(original),
      );
      await expectLater(reader.pickBytes(), throwsFormatException);
      expect(await original.exists(), isTrue);
    },
  );

  for (final invalid in ['not-pdf', 'oversize']) {
    test('reject $invalid and remove only the private copy', () async {
      final fixture = await createSyntheticFnsSelection();
      addTearDown(fixture.dispose);
      fixture.bytes = invalid == 'oversize'
          ? List<int>.filled(FnsExtractFileReader.maxBytes + 1, 0)
          : 'not a PDF'.codeUnits;
      await expectLater(fixture.reader.pickBytes(), throwsFormatException);
      expect(await fixture.file.exists(), isFalse);
    });
  }

  testWidgets(
    'interrupted private cache is cleared before opening an account',
    (tester) async {
      var cleared = false;
      await tester.pumpWidget(
        PrivateCacheBootstrap(
          clearCache: () async {
            cleared = true;
          },
          child: const MaterialApp(home: Text('Ready synthetic account')),
        ),
      );
      await tester.pumpAndSettle();
      expect(cleared, isTrue);
      expect(find.text('Ready synthetic account'), findsOneWidget);
    },
  );

  testWidgets(
    'cache cleanup failure blocks account entry until a successful retry',
    (tester) async {
      var failures = 1;
      await tester.pumpWidget(
        PrivateCacheBootstrap(
          clearCache: () async {
            if (failures-- > 0) {
              throw const FileSystemException('Synthetic failure');
            }
          },
          child: const MaterialApp(home: Text('Ready synthetic account')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ready synthetic account'), findsNothing);
      await tester.tap(find.text('Повторить очистку'));
      await tester.pumpAndSettle();
      expect(find.text('Ready synthetic account'), findsOneWidget);
    },
  );
}
