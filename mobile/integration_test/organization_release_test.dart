import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/organization_flow_test.dart' as organizations;
import '../test/organization_persistence_test.dart' as persistence;
import '../test/registry_lookup_test.dart' as registry;
import 'app_updates_test.dart' as updates;
import 'mobile_navigation_test.dart' as navigation;
import 'organization_storage_test.dart' as storage;
import 'pilot_flow_test.dart' as api;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Run before the UI harness deliberately replaces preferences with a fake.
  group('Native organization storage', storage.main);
  group('Organization flows', organizations.registerOrganizationFlowTests);
  group(
    'Organization data persistence',
    persistence.registerOrganizationPersistenceTests,
  );
  group(
    'Obligation and task persistence',
    persistence.registerObligationPersistenceTests,
  );
  group(
    'Acknowledged record refresh',
    persistence.registerAcknowledgedRefreshTests,
  );
  group('Registry lookup', registry.registerRegistryLookupTests);
  group('Existing navigation', navigation.main);
  group('Existing API flow', api.main);
  group('Existing native updater', updates.main);
}
