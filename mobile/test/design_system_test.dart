import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:compliance_navigator/core/presentation/human_labels.dart';
import 'package:compliance_navigator/core/theme/app_theme.dart';
import 'package:compliance_navigator/core/theme/design_tokens.dart';
import 'package:compliance_navigator/core/widgets/compliance_components.dart';
import 'package:compliance_navigator/core/widgets/status_badge.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('technical transport values receive human Russian labels', () {
    expect(humanProgressMessage('completed'), 'Проверка завершена');
    expect(humanProgressMessage('{"status":"completed"}'), 'Статус обновлён');
    expect(humanProgressMessage('Завершено вручную'), 'Завершено вручную');
    expect(humanConfidence('high'), 'Высокая');
    expect(humanDateTime(DateTime(2026, 8, 28, 15, 4)), '28.08.2026, 15:04');
  });

  group('green-v1 immutable tokens', () {
    test('light tokens keep exact owner-approved ARGB values', () {
      expect(AppColorTokens.lightPrimary.toARGB32(), 0xFF078B4B);
      expect(AppColorTokens.lightPrimaryDark.toARGB32(), 0xFF056A39);
      expect(AppColorTokens.lightPrimaryAccent.toARGB32(), 0xFF38C978);
      expect(AppColorTokens.lightPrimaryContainer.toARGB32(), 0xFFEAF8F0);
      expect(AppColorTokens.lightBackground.toARGB32(), 0xFFF4F8F5);
      expect(AppColorTokens.lightSurface.toARGB32(), 0xFFFFFFFF);
      expect(AppColorTokens.lightSurfaceVariant.toARGB32(), 0xFFEEF5F0);
      expect(AppColorTokens.lightTextPrimary.toARGB32(), 0xFF15251B);
      expect(AppColorTokens.lightTextSecondary.toARGB32(), 0xFF607067);
      expect(AppColorTokens.lightOutline.toARGB32(), 0xFFDCE8E0);
      expect(AppColorTokens.lightDisabled.toARGB32(), 0xFF95A29A);
    });

    test('dark tokens keep exact owner-approved ARGB values', () {
      expect(AppColorTokens.darkBackground.toARGB32(), 0xFF09150F);
      expect(AppColorTokens.darkSurface.toARGB32(), 0xFF122219);
      expect(AppColorTokens.darkSurfaceVariant.toARGB32(), 0xFF182C21);
      expect(AppColorTokens.darkPrimary.toARGB32(), 0xFF35D07F);
      expect(AppColorTokens.darkPrimaryContainer.toARGB32(), 0xFF174D31);
      expect(AppColorTokens.darkTextPrimary.toARGB32(), 0xFFF1F8F4);
      expect(AppColorTokens.darkTextSecondary.toARGB32(), 0xFFA9B9AF);
      expect(AppColorTokens.darkOutline.toARGB32(), 0xFF294236);
    });

    test('checked-in token manifest matches the typed source', () {
      final Map<String, dynamic> manifest = jsonDecode(
        File('../docs/android-design-green-v1.tokens.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(manifest['designVariant'], 2);
      expect(manifest['designName'], 'Свежий зелёный');
      expect(manifest['designVersion'], 'green-v1');
      expect((manifest['light'] as Map<String, dynamic>)['primary'], '#078B4B');
      expect(
        (manifest['dark'] as Map<String, dynamic>)['background'],
        '#09150F',
      );
      expect(manifest['spacingDp'], <int>[4, 8, 12, 16, 24, 32]);
      expect(manifest['minimumTouchTargetDp'], 48);
    });

    test('legacy blue seed and generated ColorScheme cannot return', () {
      final Iterable<File> sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart'));
      for (final File source in sources) {
        final String content = source.readAsStringSync();
        expect(
          content.toUpperCase(),
          isNot(contains('245B78')),
          reason: 'Legacy blue returned in ${source.path}',
        );
      }
      final String themeSource = File('lib/core/theme/app_theme.dart')
          .readAsStringSync();
      expect(themeSource, isNot(contains('ColorScheme.fromSeed')));
    });
  });

  group('explicit themes and semantic colors', () {
    test('light and dark ColorSchemes use exact roles', () {
      final ThemeData light = AppTheme.light();
      final ThemeData dark = AppTheme.dark();
      expect(light.colorScheme.brightness, Brightness.light);
      expect(light.colorScheme.primary, AppColorTokens.lightPrimary);
      expect(
        light.colorScheme.primaryContainer,
        AppColorTokens.lightPrimaryContainer,
      );
      expect(light.scaffoldBackgroundColor, AppColorTokens.lightBackground);
      expect(light.colorScheme.surface, AppColorTokens.lightSurface);
      expect(light.colorScheme.onSurface, AppColorTokens.lightTextPrimary);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.colorScheme.primary, AppColorTokens.darkPrimary);
      expect(
        dark.colorScheme.primaryContainer,
        AppColorTokens.darkPrimaryContainer,
      );
      expect(dark.scaffoldBackgroundColor, AppColorTokens.darkBackground);
      expect(dark.colorScheme.surface, AppColorTokens.darkSurface);
      expect(dark.colorScheme.onSurface, AppColorTokens.darkTextPrimary);
    });

    test('error and human review are never the primary green', () {
      for (final AppSemanticColors colors in <AppSemanticColors>[
        AppSemanticColors.light,
        AppSemanticColors.dark,
      ]) {
        expect(colors.needsHumanReview, isNot(colors.success));
        expect(colors.needsHumanReview, isNot(AppColorTokens.lightPrimary));
        expect(colors.needsHumanReview, isNot(AppColorTokens.darkPrimary));
      }
      expect(AppColorTokens.lightError, isNot(AppColorTokens.lightPrimary));
      expect(AppColorTokens.darkError, isNot(AppColorTokens.darkPrimary));
    });

    test('important text pairs meet WCAG normal-text contrast', () {
      final ThemeData light = AppTheme.light();
      final ThemeData dark = AppTheme.dark();
      final AppSemanticColors lightSemantic = light.complianceColors;
      final AppSemanticColors darkSemantic = dark.complianceColors;
      final List<(Color, Color)> pairs = <(Color, Color)>[
        (AppColorTokens.lightTextPrimary, AppColorTokens.lightBackground),
        (AppColorTokens.lightTextSecondary, AppColorTokens.lightBackground),
        (AppColorTokens.lightPrimaryDark, Colors.white),
        (AppColorTokens.darkTextPrimary, AppColorTokens.darkBackground),
        (AppColorTokens.darkTextSecondary, AppColorTokens.darkSurface),
        (lightSemantic.onSuccessContainer, lightSemantic.successContainer),
        (lightSemantic.onWarningContainer, lightSemantic.warningContainer),
        (
          lightSemantic.onInformationContainer,
          lightSemantic.informationContainer,
        ),
        (
          lightSemantic.onNeedsHumanReviewContainer,
          lightSemantic.needsHumanReviewContainer,
        ),
        (darkSemantic.onSuccessContainer, darkSemantic.successContainer),
        (darkSemantic.onWarningContainer, darkSemantic.warningContainer),
        (
          darkSemantic.onInformationContainer,
          darkSemantic.informationContainer,
        ),
        (
          darkSemantic.onNeedsHumanReviewContainer,
          darkSemantic.needsHumanReviewContainer,
        ),
      ];
      for (final (Color foreground, Color background) in pairs) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason:
              '${foreground.toARGB32().toRadixString(16)} on ${background.toARGB32().toRadixString(16)}',
        );
      }
    });
  });

  group('components and accessibility', () {
    testWidgets('semantic badges include text and distinct icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Column(
              children: <Widget>[
                SemanticStatusBadge(
                  label: 'Выполнено',
                  status: SemanticStatus.success,
                ),
                SemanticStatusBadge(
                  label: 'Ошибка',
                  status: SemanticStatus.error,
                ),
                SemanticStatusBadge(
                  label: 'Требует проверки',
                  status: SemanticStatus.needsHumanReview,
                ),
                StatusBadge(label: 'Совместимый успех'),
                StatusBadge(label: 'Совместимая проверка', warning: true),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Выполнено'), findsOneWidget);
      expect(find.text('Ошибка'), findsOneWidget);
      expect(find.text('Требует проверки'), findsOneWidget);
      expect(find.text('Совместимый успех'), findsOneWidget);
      expect(find.text('Совместимая проверка'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsNWidgets(2));
    });

    testWidgets('buttons and icon actions keep a 48 dp touch target', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: <Widget>[
                FilledButton(onPressed: () {}, child: const Text('Действие')),
                IconButton(
                  onPressed: () {},
                  tooltip: 'Обновить',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
      );
      final Size button = tester.getSize(find.byType(FilledButton));
      final Size iconButton = tester.getSize(find.byType(IconButton));
      expect(button.height, greaterThanOrEqualTo(48));
      expect(iconButton.width, greaterThanOrEqualTo(48));
      expect(iconButton.height, greaterThanOrEqualTo(48));
    });

    testWidgets('hero has no overflow at 360x800 and text scale 2', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: GreenHeroHeader(
                organizationName: 'Учебная организация',
                progress: 64,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('64%'), findsOneWidget);
    });

    testWidgets('adaptive navigation selects green phone and tablet states', (
      WidgetTester tester,
    ) async {
      const List<ComplianceNavigationDestination> destinations =
          <ComplianceNavigationDestination>[
            ComplianceNavigationDestination(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Главная',
            ),
            ComplianceNavigationDestination(
              icon: Icons.fact_check_outlined,
              selectedIcon: Icons.fact_check,
              label: 'Анкета',
            ),
          ];
      Future<void> pump(Size size) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: AdaptiveNavigation(
              selectedIndex: 1,
              destinations: destinations,
              onDestinationSelected: (_) {},
              child: const SizedBox.expand(),
            ),
          ),
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(const Size(390, 844));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await pump(const Size(800, 1280));
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        1,
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('adaptive icon manifest, dimensions and hashes are exact', () {
    final Map<String, dynamic> manifest = jsonDecode(
      File('tool/icon-manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(manifest['designVersion'], 'green-v1');
    final String adaptive = File(manifest['adaptiveForeground'] as String)
        .readAsStringSync();
    final String monochrome = File(manifest['adaptiveMonochrome'] as String)
        .readAsStringSync();
    final String api33 = File(
      'android/app/src/main/res/mipmap-anydpi-v33/ic_launcher.xml',
    ).readAsStringSync();
    expect(adaptive, contains('#056A39'));
    expect(adaptive.toUpperCase(), isNot(contains('#163A4E')));
    expect(monochrome, contains('strokeColor'));
    expect(api33, contains('@drawable/ic_launcher_monochrome'));

    for (final Object? raw in manifest['legacy'] as List<dynamic>) {
      final Map<String, dynamic> item = raw! as Map<String, dynamic>;
      final File file = File(item['path'] as String);
      final Uint8List bytes = file.readAsBytesSync();
      expect(sha256.convert(bytes).toString(), item['sha256']);
      expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      final ByteData header = ByteData.sublistView(bytes);
      expect(header.getUint32(16), item['size']);
      expect(header.getUint32(20), item['size']);
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final double firstLuminance = first.computeLuminance();
  final double secondLuminance = second.computeLuminance();
  final double light = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final double dark = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (light + 0.05) / (dark + 0.05);
}
