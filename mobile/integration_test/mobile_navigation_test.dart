import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/routing/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/mobile_ux_test.dart' as regressions;
import '../test/support/ux_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    regressions.main();
    return;
  }

  testWidgets('native navigation animation measurements use synthetic data', (
    tester,
  ) async {
    const root = ValueKey<String>('native-motion');
    await tester.pumpWidget(
      await createUxApp(
        captureKey: root,
        phase: AuthPhase.authenticated,
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
      tester.element(find.byKey(root)),
      listen: false,
    );
    container.read(appRouterProvider).go('/dashboard');
    await tester.pumpAndSettle();
    await binding.watchPerformance(() async {
      for (var round = 0; round < 4; round++) {
        for (final index in <int>[1, 2, 3, 4, 0]) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    }, reportKey: 'navigation_profile');
  });
}
