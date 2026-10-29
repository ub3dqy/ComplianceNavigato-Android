import 'dart:io';

import 'package:compliance_navigator/core/storage/app_preferences.dart';
import 'package:compliance_navigator/core/storage/fns_extract_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native private-cache cleanup preserves the original behind a link',
    (tester) async {
      final cache = await getTemporaryDirectory();
      final originalDirectory = await cache.createTemp('cn-fns-native-');
      final original = File(
        path.join(originalDirectory.path, 'synthetic-original.pdf'),
      );
      final link = Link(
        path.join(cache.path, 'file_picker', 'synthetic-link.pdf'),
      );
      try {
        await original.writeAsString('synthetic original must remain');
        await Directory(path.dirname(link.path)).create(recursive: true);
        await link.create(original.path);
        await clearPrivatePickerCache();
        expect(await original.readAsString(), 'synthetic original must remain');
        expect(await link.exists(), isFalse);
      } finally {
        await clearPrivatePickerCache();
        if (!path.isWithin(cache.path, originalDirectory.path) ||
            !path
                .basename(originalDirectory.path)
                .startsWith('cn-fns-native-')) {
          throw StateError('Unexpected native fixture directory.');
        }
        if (await original.exists()) await original.delete();
        await originalDirectory.delete();
      }
    },
  );

  testWidgets(
    'Android stores, reloads and clears only the organization selection',
    (tester) async {
      await clearPrivatePickerCache();
      final preferences = AppPreferences();
      final previous = await preferences.readLastOrganizationId();
      final theme = await preferences.readThemeMode();
      final biometric = await preferences.readBiometricEnabled();
      try {
        await preferences.writeLastOrganizationId(
          'synthetic-native-organization',
        );
        expect(
          await AppPreferences().readLastOrganizationId(),
          'synthetic-native-organization',
        );
        await preferences.clearSessionSelection();
        expect(await AppPreferences().readLastOrganizationId(), isNull);
        expect(await preferences.readThemeMode(), theme);
        expect(await preferences.readBiometricEnabled(), biometric);
      } finally {
        await preferences.writeLastOrganizationId(previous);
      }
    },
  );
}
