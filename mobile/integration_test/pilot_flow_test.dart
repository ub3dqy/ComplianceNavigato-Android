import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/pilot_repository_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android runtime completes the local fake API pilot flow', (
    WidgetTester tester,
  ) async {
    await runPilotRepositoryFlow();
  });
}
