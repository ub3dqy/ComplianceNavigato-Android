import 'dart:async';
import 'dart:io';

import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/organization_flow.dart';
import '../test/support/ux_harness.dart';

const _root = ValueKey<String>('all-mobile-pages');
const _pages = <(String, String, AuthPhase)>[
  ('01-loading', '/splash', AuthPhase.checking),
  ('02-login', '/login', AuthPhase.signedOut),
  ('03-mfa', '/mfa', AuthPhase.mfaRequired),
  ('04-session', '/session', AuthPhase.offline),
  ('05-organizations', '/organizations', AuthPhase.authenticated),
  ('06-dashboard', '/dashboard', AuthPhase.authenticated),
  ('07-questionnaire', '/questionnaire', AuthPhase.authenticated),
  ('08-obligations', '/obligations', AuthPhase.authenticated),
  ('09-assistant', '/ai', AuthPhase.authenticated),
  ('10-more', '/more', AuthPhase.authenticated),
  ('11-websites', '/websites', AuthPhase.authenticated),
  ('12-services', '/services', AuthPhase.authenticated),
  ('13-assessments', '/assessments', AuthPhase.authenticated),
  ('14-scanner', '/scanner', AuthPhase.authenticated),
  ('15-documents', '/documents', AuthPhase.authenticated),
  ('16-evidence', '/evidence', AuthPhase.authenticated),
  ('17-reports', '/reports', AuthPhase.authenticated),
  ('18-audit', '/audit', AuthPhase.authenticated),
  ('19-settings', '/settings', AuthPhase.authenticated),
  ('20-organization-create', '/organizations/new', AuthPhase.authenticated),
];

Future<void> _mount(
  WidgetTester tester,
  String path,
  AuthPhase phase,
  ThemeMode theme,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    await createUxApp(
      captureKey: _root,
      phase: phase,
      themeMode: theme,
      user: path.startsWith('/organizations') ? organizationTestUser : null,
      currentOrganization: OrganizationSummaryDto.fromJson(<String, dynamic>{
        'id': 'organization-1',
        'short_name': 'Учебная организация',
        'kind': 'llc',
        'role': 'owner',
        'updated_at': '2026-08-27T12:00:00Z',
      }),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byKey(_root)),
    listen: false,
  );
  if (phase == AuthPhase.authenticated) {
    if (path == '/organizations') {
      var loaded = false;
      unawaited(
        container
            .read(organizationControllerProvider.notifier)
            .load()
            .then((_) => loaded = true),
      );
      for (var attempt = 0; attempt < 100 && !loaded; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(loaded, isTrue);
    }
    container.read(appRouterProvider).go(path);
  }
  if (phase == AuthPhase.checking) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    for (final font in <(String, String)>[
      ('Roboto', 'tool/assets/Roboto-Regular.ttf'),
      ('MaterialIcons', 'tool/assets/MaterialIcons-Regular.otf'),
    ]) {
      final bytes = File(font.$2).readAsBytesSync();
      await (FontLoader(
        font.$1,
      )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
    }
  });

  for (final theme in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('all 20 ${theme.name} pages match reviewed native snapshots', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final (name, path, phase) in _pages) {
        await _mount(tester, path, phase, theme);
        expect(tester.takeException(), isNull, reason: '$name ${theme.name}');
        await expectLater(
          find.byKey(_root),
          matchesGoldenFile('goldens/all-pages/$name-${theme.name}.png'),
        );
      }
    });
  }

  testWidgets('20 pages expose labelled Android-sized touch targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      for (final (name, path, phase) in _pages) {
        await _mount(tester, path, phase, ThemeMode.light);
        await expectLater(
          tester,
          meetsGuideline(androidTapTargetGuideline),
          reason: name,
        );
        await expectLater(
          tester,
          meetsGuideline(labeledTapTargetGuideline),
          reason: name,
        );
      }
    } finally {
      semantics.dispose();
    }
  });

  for (final (size, scale, theme) in <(Size, double, ThemeMode)>[
    (const Size(360, 800), 2, ThemeMode.light),
    (const Size(412, 915), 2, ThemeMode.dark),
    (const Size(800, 1280), 1.3, ThemeMode.dark),
    (const Size(844, 390), 1, ThemeMode.system),
  ]) {
    testWidgets('20 pages fit $size at text $scale, ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final (name, path, phase) in _pages) {
        await _mount(tester, path, phase, theme);
        expect(
          tester.takeException(),
          isNull,
          reason: '$name $size text=$scale',
        );
      }
    });
  }
}
