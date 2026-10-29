import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/compliance_repository.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/storage/app_preferences.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:compliance_navigator/core/storage/transient_file_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/organization_flow.dart';

Future<ProviderContainer> createOrganizationContainer(
  OrganizationFlowAdapter adapter,
  PreferencesStore preferences, {
  bool failTransientDirectory = false,
}) async {
  final temporary = await Directory.systemTemp.createTemp(
    'compliance-organization-state-',
  );
  final config = AppConfig.validate(const {
    'APP_ENV': 'staging',
    'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
    'OPENAI_API_ENABLED': 'false',
    'AI_PROVIDER_AUTO_SWITCH': 'false',
    'GIT_COMMIT_SHA': 'synthetic-organization-state',
    'API_SCHEMA_SHA256':
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
  });
  final store = MemorySessionStore();
  final marker = MemorySessionRevocationMarker();
  final dio = Dio(BaseOptions(baseUrl: config.apiBaseUri.toString()))
    ..httpClientAdapter = adapter;
  final client =
      ApiClient(
        config: config,
        sessionStore: store,
        sessionRevocationMarker: marker,
        diagnostics: SanitizedDiagnostics(),
        dio: dio,
        refreshDio: dio,
      )..setAccessToken(
        'synthetic-state-access',
        expiresIn: const Duration(minutes: 5),
      );
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      sessionStoreProvider.overrideWithValue(store),
      sessionRevocationMarkerProvider.overrideWithValue(marker),
      preferencesProvider.overrideWithValue(preferences),
      apiClientProvider.overrideWithValue(client),
      transientFileServiceProvider.overrideWithValue(
        TransientFileService(
          temporaryDirectory: () async {
            if (failTransientDirectory) {
              throw const FileSystemException('Synthetic cleanup failure');
            }
            return temporary;
          },
        ),
      ),
    ],
  );
  addTearDown(() async {
    container.dispose();
    dio.close(force: true);
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });
  await container.read(organizationControllerProvider.future);
  return container;
}

Future<void> waitForRecordedList(
  OrganizationFlowAdapter adapter,
  int count,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (adapter.requests
            .where((v) => v.uri.path.endsWith('/auth/organizations/'))
            .length >=
        count) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('The synthetic list request did not start.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'created fields and the last valid selection survive a new app container',
    () async {
      SharedPreferences.setMockInitialValues({});
      final adapter = OrganizationFlowAdapter();
      final container = await createOrganizationContainer(
        adapter,
        AppPreferences(),
      );
      final controller = container.read(
        organizationControllerProvider.notifier,
      );
      await controller.load();
      final repository = container.read(repositoryProvider);
      final created = await repository.createOrganization({
        'kind': 'llc',
        'full_name': 'Синтетическая карточка для проверки хранения',
        'short_name': 'Учебная сохранённая карточка',
        'legal_address': 'Учебный адрес без реального местоположения',
        'actual_address': 'Другой учебный адрес',
        'contact_email': 'office@example.invalid',
        'contact_phone': '+0 000 000-00-00',
        'tax_regime': 'Учебный режим',
        'okved': '00.00',
        'employee_count': 7,
        'has_applicants': true,
        'activity_start_date': '2026-01-15',
        'privacy_responsible': 'назначен',
        'notes': 'Только синтетические сведения. Сохранены отдельно от других карточек.',
      }, idempotencyKey: '61505131-a247-4759-bc7d-ed5b8f68c770');
      expect(await controller.acceptCreated(created), isTrue);
      expect(await controller.select('organization-2'), isTrue);
      final other = await repository.organization('organization-2');
      expect(other.notes, isEmpty);
      expect(await controller.select(created.id), isTrue);

      // A fresh provider tree and store object reload membership and persisted ID.
      final reopened = await createOrganizationContainer(
        adapter,
        AppPreferences(),
      );
      await reopened.read(organizationControllerProvider.notifier).load();
      expect(reopened.read(currentOrganizationProvider)?.id, created.id);
      final stored = await reopened
          .read(repositoryProvider)
          .organization(created.id);
      expect(stored.fullName, created.fullName);
      expect(stored.shortName, created.shortName);
      expect(stored.legalAddress, created.legalAddress);
      expect(stored.actualAddress, created.actualAddress);
      expect(stored.contactEmail, created.contactEmail);
      expect(stored.contactPhone, created.contactPhone);
      expect(stored.taxRegime, created.taxRegime);
      expect(stored.okved, created.okved);
      expect(stored.employeeCount, 7);
      expect(stored.hasApplicants, isTrue);
      expect(stored.activityStartDate, '2026-01-15');
      expect(stored.privacyResponsible, 'назначен');
      expect(stored.notes, created.notes);
      expect(adapter.creates, hasLength(1));
    },
  );

  test(
    'initial activation clears transient files left by the previous process',
    () async {
      final container = await createOrganizationContainer(
        OrganizationFlowAdapter(),
        OrganizationPreferences(),
      );
      final previousFile = await container
          .read(transientFileServiceProvider)
          .save(
            DownloadPayload(
              bytes: Uint8List.fromList([115, 121, 110]),
              contentDisposition: 'attachment; filename="synthetic.txt"',
              contentType: 'text/plain',
            ),
            scope: 'previous-organization',
            fallbackName: 'synthetic.txt',
          );
      expect(await previousFile.exists(), isTrue);
      await container.read(organizationControllerProvider.notifier).load();
      expect(await previousFile.exists(), isFalse);
      expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
    },
  );

  test('initial activation fails closed when previous transient files cannot be cleared', () async {
    final preferences = OrganizationPreferences();
    final container = await createOrganizationContainer(
      OrganizationFlowAdapter(),
      preferences,
      failTransientDirectory: true,
    );
    await container.read(organizationControllerProvider.notifier).load();
    expect(container.read(currentOrganizationProvider), isNull);
    expect(
      container.read(organizationControllerProvider).value!.refreshError,
      isA<FileSystemException>(),
    );
    expect(preferences.selected, isNull);
  });

  test('a delayed list cannot restore organization state after local sign-out cleanup', () async {
    final adapter = OrganizationFlowAdapter();
    final preferences = OrganizationPreferences();
    final container = await createOrganizationContainer(adapter, preferences);
    final controller = container.read(organizationControllerProvider.notifier);
    await controller.load();
    final hold = Completer<void>();
    adapter.holdList = hold;
    final pending = controller.load();
    await waitForRecordedList(adapter, 2);
    await controller.clear();
    hold.complete();
    await pending;
    expect(container.read(currentOrganizationProvider), isNull);
    expect(
      container.read(organizationControllerProvider).value!.items,
      isEmpty,
    );
    expect(preferences.selected, isNull);
  });

  test('a late preference write is cleared after sign-out and cannot reselect a tenant', () async {
    final adapter = OrganizationFlowAdapter();
    final preferences = OrganizationPreferences();
    final container = await createOrganizationContainer(adapter, preferences);
    final controller = container.read(organizationControllerProvider.notifier);
    await controller.load();
    final writeStarted = Completer<void>();
    final hold = Completer<void>();
    preferences.writeStarted = writeStarted;
    preferences.holdWrite = hold;
    final select = controller.select('organization-2');
    await writeStarted.future.timeout(const Duration(seconds: 3));
    final clear = controller.clear();
    expect(container.read(currentOrganizationProvider), isNull);
    hold.complete();
    expect(await select, isFalse);
    await clear;
    expect(preferences.selected, isNull);
    expect(
      container.read(organizationControllerProvider).value!.items,
      isEmpty,
    );
  });

  test(
    'the newest refresh wins over an older delayed membership snapshot',
    () async {
      final adapter = OrganizationFlowAdapter();
      final preferences = OrganizationPreferences();
      final container = await createOrganizationContainer(adapter, preferences);
      final controller = container.read(
        organizationControllerProvider.notifier,
      );
      await controller.load();
      final hold = Completer<void>();
      adapter.holdList = hold;
      final oldLoad = controller.load();
      await waitForRecordedList(adapter, 2);
      adapter.holdList = null;
      adapter.organizations.removeAt(0);
      await controller.load();
      hold.complete();
      await oldLoad;
      expect(container.read(currentOrganizationProvider)?.id, 'organization-2');
      expect(
        container.read(organizationControllerProvider).value!.items,
        hasLength(1),
      );
      expect(preferences.selected, 'organization-2');
    },
  );

  test('a failed refresh preserves selection and a successful retry clears the error', () async {
    final adapter = OrganizationFlowAdapter();
    final container = await createOrganizationContainer(
      adapter,
      OrganizationPreferences(),
    );
    final controller = container.read(organizationControllerProvider.notifier);
    await controller.load();
    adapter.failList = true;
    await controller.load();
    expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
    expect(
      container.read(organizationControllerProvider).value!.refreshError,
      isNotNull,
    );
    expect(
      container.read(organizationControllerProvider).value!.isRefreshing,
      isFalse,
    );
    adapter.failList = false;
    await controller.load();
    expect(
      container.read(organizationControllerProvider).value!.refreshError,
      isNull,
    );
  });

  test(
    'revoked membership is never restored when saving the next selection fails',
    () async {
      final adapter = OrganizationFlowAdapter();
      final preferences = OrganizationPreferences();
      final container = await createOrganizationContainer(adapter, preferences);
      final controller = container.read(
        organizationControllerProvider.notifier,
      );
      await controller.load();
      adapter.organizations.removeAt(0);
      preferences.failNextWrite = true;
      await controller.load();
      expect(container.read(currentOrganizationProvider), isNull);
      expect(
        container
            .read(organizationControllerProvider)
            .value!
            .items
            .map((v) => v.id),
        ['organization-2'],
      );
      expect(
        container.read(organizationControllerProvider).value!.refreshError,
        isNotNull,
      );
      expect(await controller.select('organization-1'), isFalse);
      expect(await controller.select('organization-2'), isTrue);
    },
  );

  test(
    'explicit create retry keys must be UUIDs and apply only to keyed requests',
    () async {
      final adapter = OrganizationFlowAdapter();
      final container = await createOrganizationContainer(
        adapter,
        OrganizationPreferences(),
      );
      final client = container.read(apiClientProvider);
      expect(
        () => client.post('organizations/', {}, idempotencyKey: 'bad\r\nvalue'),
        throwsArgumentError,
      );
      expect(
        () => client.post(
          'organizations/',
          {},
          idempotencyKey: 'f1a18884-e29a-430a-9a3e-9a090ba17a88',
          idempotent: false,
        ),
        throwsArgumentError,
      );
      expect(adapter.creates, isEmpty);
    },
  );
}
