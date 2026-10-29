import 'package:compliance_navigator/core/storage/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _PlatformPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a rejected platform write is reported instead of confirming selection',
    () async {
      final platform = _PlatformPreferences();
      when(() => platform.setString(any(), any()))
          .thenAnswer((_) async => false);
      final preferences = AppPreferences(loadPreferences: () async => platform);
      await expectLater(
        preferences.writeLastOrganizationId('synthetic-organization'),
        throwsStateError,
      );
    },
  );

  for (final clearSession in [false, true]) {
    test(
      'a rejected platform removal is reported, session cleanup=$clearSession',
      () async {
        final platform = _PlatformPreferences();
        when(() => platform.remove(any())).thenAnswer((_) async => false);
        final preferences = AppPreferences(
          loadPreferences: () async => platform,
        );
        await expectLater(
          clearSession
              ? preferences.clearSessionSelection()
              : preferences.writeLastOrganizationId(null),
          throwsStateError,
        );
      },
    );
  }

  test(
    'a rejected write cannot turn a speculative cache entry into a selection',
    () async {
      final platform = _PlatformPreferences();
      var cached = 'previous-organization';
      when(() => platform.setString(any(), any())).thenAnswer((
        invocation,
      ) async {
        // Match the SDK's cache-before-platform behavior on a rejected write.
        cached = invocation.positionalArguments[1] as String;
        return false;
      });
      when(() => platform.getString(any())).thenAnswer((_) => cached);
      when(() => platform.reload()).thenAnswer((_) async {
        cached = 'previous-organization';
      });
      final preferences = AppPreferences(loadPreferences: () async => platform);
      await expectLater(
        preferences.writeLastOrganizationId('unconfirmed-organization'),
        throwsStateError,
      );
      expect(
        await preferences.readLastOrganizationId(),
        'previous-organization',
      );
    },
  );

  test(
    'the selected organization can be reopened by a new preferences object',
    () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreferences().writeLastOrganizationId('synthetic-organization');
      expect(
        await AppPreferences().readLastOrganizationId(),
        'synthetic-organization',
      );
      await AppPreferences().clearSessionSelection();
      expect(await AppPreferences().readLastOrganizationId(), isNull);
    },
  );
}
