import 'dart:async';

import 'package:compliance_navigator/app/app.dart';
import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/routing/app_router.dart';
import 'package:compliance_navigator/core/storage/fns_extract_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fns_extract.dart';
import 'support/organization_flow.dart';
import 'support/ux_harness.dart';

Future<void> waitForOrganizationUi(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  if (finder.evaluate().isEmpty) {
    for (final element in find.byType(TextFormField).evaluate()) {
      final field = element.widget as TextFormField;
      final state = tester.state<FormFieldState<String>>(find.byWidget(field));
      debugPrint(
        'ORGANIZATION_TEST_FIELD key=${field.key} length=${field.controller?.text.length} error=${state.errorText}',
      );
    }
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> openOrganizationApp(
  WidgetTester tester,
  OrganizationFlowAdapter adapter, {
  CurrentUserDto user = organizationTestUser,
  OrganizationPreferences? preferences,
  FnsExtractFileReader? fnsFileReader,
  Future<bool> Function(String)? openFnsRegistry,
  double textScale = 1,
}) async {
  if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    await createUxApp(
      phase: AuthPhase.authenticated,
      user: user,
      transport: adapter,
      preferences: preferences ?? OrganizationPreferences(),
      fnsFileReader: fnsFileReader,
      openFnsRegistry: openFnsRegistry,
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ComplianceNavigatorApp)),
  );
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
  await tester.pumpAndSettle();
  return container;
}

Future<void> openOrganizationForm(WidgetTester tester) async {
  await tester.tap(find.text('Добавить организацию'));
  await waitForOrganizationUi(tester, find.text('Новая организация'));
}

Future<void> fillOrganizationName(
  WidgetTester tester, {
  String name = 'Учебная новая организация',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('organization-short_name')),
    name,
  );
  await tester.enterText(
    find.byKey(const ValueKey('organization-full_name')),
    '$name — синтетическая карточка',
  );
}

Future<void> submitOrganization(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('organization-create-submit'));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

Future<void> pressFnsImport(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final button = find.byKey(const ValueKey('organization-fns-import'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

void registerOrganizationFlowTests() {
  for (final kind in ['llc', 'ie']) {
    testWidgets(
      '$kind retains manually entered director and responsible names',
      (tester) async {
        final adapter = OrganizationFlowAdapter();
        await openOrganizationApp(tester, adapter);
        await openOrganizationForm(tester);
        if (kind == 'ie') {
          await tester.tap(find.byKey(const ValueKey('organization-kind')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('ИП').last);
          await tester.pumpAndSettle();
        }
        await fillOrganizationName(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        for (final section in ['Реквизиты', 'Деятельность']) {
          await tester.ensureVisible(find.text(section));
          await tester.tap(find.text(section));
          await tester.pumpAndSettle();
          final field = find.byKey(
            ValueKey(
              section == 'Реквизиты'
                  ? 'organization-leader_name'
                  : 'organization-privacy_responsible',
            ),
          );
          await tester.ensureVisible(field);
          await tester.enterText(
            field,
            section == 'Реквизиты'
                ? 'Синтетиков Первый Учебный'
                : 'Синтетиков Второй Учебный',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
        await submitOrganization(tester);
        await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
        final posted = adapter.creates.single.data as Map;
        expect(posted['kind'], kind);
        expect(posted['leader_name'], 'Синтетиков Первый Учебный');
        expect(posted['privacy_responsible'], 'Синтетиков Второй Учебный');
      },
    );
  }

  testWidgets(
    'IE extract imports only registration numbers and requires manual names',
    (tester) async {
      final selection = await createSyntheticFnsSelection();
      addTearDown(selection.dispose);
      final adapter = OrganizationFlowAdapter();
      adapter.fnsPreview.addAll({
        'kind': 'ie',
        'inn': '123456789047',
        'ogrn': '123456789012343',
        'full_name': null,
        'short_name': null,
        'kpp': null,
        'legal_address': null,
      });
      await openOrganizationApp(
        tester,
        adapter,
        fnsFileReader: selection.reader,
      );
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      await pressFnsImport(tester);
      await waitForOrganizationUi(tester, find.byType(AlertDialog));
      await tester.tap(find.text('Выбрать PDF'));
      await waitForOrganizationUi(tester, find.text('Заполнить форму'));
      await tester.tap(find.text('Заполнить форму'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('organization-kind')),
            )
            .initialValue,
        'ie',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('organization-short_name')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await fillOrganizationName(
        tester,
        name: 'Учебный ИП без реальных сведений',
      );
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      final posted = adapter.creates.single.data as Map;
      expect(posted['kind'], 'ie');
      expect(posted['kpp'], isEmpty);
      expect(posted['leader_name'], isEmpty);
      expect(posted['inn'], '123456789047');
    },
  );

  testWidgets(
    'FNS preview needs confirmation and never creates a card by itself',
    (tester) async {
      final selection = await createSyntheticFnsSelection();
      addTearDown(selection.dispose);
      final adapter = OrganizationFlowAdapter();
      await openOrganizationApp(
        tester,
        adapter,
        fnsFileReader: selection.reader,
        textScale: 2,
      );
      await openOrganizationForm(tester);
      await fillOrganizationName(tester, name: 'Учебный черновик');
      await pressFnsImport(tester);
      await waitForOrganizationUi(tester, find.byType(AlertDialog));
      await tester.tap(find.text('Выбрать PDF'));
      await waitForOrganizationUi(tester, find.text('Проверьте реквизиты'));
      expect(adapter.creates, isEmpty);
      expect(selection.file.existsSync(), isFalse);
      await tester.tap(find.byKey(const ValueKey('fns-extract-cancel')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('organization-short_name')),
            )
            .controller!
            .text,
        'Учебный черновик',
      );
      await pressFnsImport(tester);
      await waitForOrganizationUi(tester, find.byType(AlertDialog));
      await tester.tap(find.text('Выбрать PDF'));
      await waitForOrganizationUi(tester, find.text('Заполнить форму'));
      await tester.tap(find.text('Заполнить форму'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('organization-short_name')),
            )
            .controller!
            .text,
        'Учебная выписка',
      );
      expect(adapter.creates, isEmpty);
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(adapter.creates, hasLength(1));
      expect((adapter.creates.single.data as Map)['inn'], '1234567894');
      expect((adapter.creates.single.data as Map)['ogrn'], '1234567890127');
    },
  );

  testWidgets(
    'FNS errors and a canceled late preview preserve the original draft',
    (tester) async {
      final selection = await createSyntheticFnsSelection();
      addTearDown(selection.dispose);
      final adapter = OrganizationFlowAdapter()..failFns = true;
      await openOrganizationApp(
        tester,
        adapter,
        fnsFileReader: selection.reader,
      );
      await openOrganizationForm(tester);
      await fillOrganizationName(tester, name: 'Учебный черновик');
      await pressFnsImport(tester);
      await waitForOrganizationUi(tester, find.byType(AlertDialog));
      await tester.tap(find.text('Выбрать PDF'));
      await waitForOrganizationUi(
        tester,
        find.text('ИНН выписки отличается от введённого.'),
      );
      adapter.failFns = false;
      final held = Completer<void>();
      adapter.holdFns = held;
      await tester.tap(find.text('Выбрать PDF'));
      for (var attempt = 0; attempt < 100 && adapter.fnsReads < 2; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(adapter.fnsReads, 2);
      await tester.tap(find.byKey(const ValueKey('fns-extract-cancel')));
      await tester.pumpAndSettle();
      held.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('organization-short_name')),
            )
            .controller!
            .text,
        'Учебный черновик',
      );
      expect(adapter.creates, isEmpty);
      expect(find.text('Проверьте реквизиты'), findsNothing);
    },
  );

  testWidgets(
    'FNS dialog fits large text and validates INN before opening the registry',
    (tester) async {
      var calls = 0;
      await openOrganizationApp(
        tester,
        OrganizationFlowAdapter(),
        textScale: 2,
        openFnsRegistry: (inn) async {
          calls++;
          return false;
        },
      );
      await openOrganizationForm(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('organization-fns-import')),
      );
      await pressFnsImport(tester);
      await waitForOrganizationUi(tester, find.byType(AlertDialog));
      await tester.enterText(
        find.byKey(const ValueKey('fns-expected-inn')),
        '123',
      );
      await tester.pumpAndSettle();
      final open = find.text('Скопировать ИНН и открыть ФНС');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('fns-expected-inn')),
        '1234567894',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('fns-extract-cancel')));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'administrator creates the first organization and switches to it',
    (tester) async {
      final adapter = OrganizationFlowAdapter(empty: true);
      final container = await openOrganizationApp(tester, adapter);
      expect(find.text('Пока нет организаций'), findsOneWidget);
      await openOrganizationForm(tester);
      await submitOrganization(tester);
      expect(adapter.creates, isEmpty);
      expect(find.text('Заполните это поле.'), findsWidgets);
      await tester.ensureVisible(
        find.byKey(const ValueKey('organization-short_name')),
      );
      await fillOrganizationName(tester);
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(adapter.savedByKey, hasLength(1));
      expect(
        container.read(currentOrganizationProvider)?.id,
        'organization-created-1',
      );
      expect(container.read(currentOrganizationProvider)?.role, 'owner');
      final posted = adapter.creates.single;
      expect(
        posted.headers['Idempotency-Key'],
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
      expect((posted.data as Map)['kind'], 'llc');
      expect((posted.data as Map).containsKey('role'), isFalse);
      expect((posted.data as Map).containsKey('user_id'), isFalse);
      expect(
        adapter.requests.where(
          (v) => v.uri.path.contains('/organizations/organization-created-1/'),
        ),
        isNotEmpty,
      );
    },
  );

  testWidgets(
    'organization owner can create another card without global administrator rights',
    (tester) async {
      final adapter = OrganizationFlowAdapter();
      const user = CurrentUserDto(
        id: 'synthetic-owner',
        email: 'owner@example.invalid',
        isStaff: false,
        isSuperuser: false,
        mfaEnabled: false,
      );
      final container = await openOrganizationApp(tester, adapter, user: user);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(adapter.savedByKey, hasLength(1));
      expect(
        container.read(currentOrganizationProvider)?.id,
        'organization-created-1',
      );
      expect(container.read(authControllerProvider).user?.isSuperuser, isFalse);
      expect(container.read(authControllerProvider).user?.isStaff, isFalse);
    },
  );

  for (final role in ['viewer', 'editor']) {
    testWidgets('$role cannot create organizations even with a staff flag', (
      tester,
    ) async {
      final adapter = OrganizationFlowAdapter(role: role);
      const user = CurrentUserDto(
        id: 'synthetic-restricted',
        email: 'restricted@example.invalid',
        isStaff: true,
        isSuperuser: false,
        mfaEnabled: false,
      );
      final container = await openOrganizationApp(tester, adapter, user: user);
      expect(find.text('Добавить организацию'), findsNothing);
      container.read(appRouterProvider).go('/organizations/new');
      await waitForOrganizationUi(tester, find.text('Создание недоступно'));
      expect(
        find.byKey(const ValueKey('organization-create-submit')),
        findsNothing,
      );
      expect(adapter.creates, isEmpty);
    });
  }

  testWidgets(
    'an owner finishing local selection never sees a false permission denial',
    (tester) async {
      final adapter = OrganizationFlowAdapter();
      final preferences = OrganizationPreferences();
      const user = CurrentUserDto(
        id: 'synthetic-owner',
        email: 'owner@example.invalid',
        isStaff: false,
        isSuperuser: false,
        mfaEnabled: false,
      );
      await openOrganizationApp(
        tester,
        adapter,
        user: user,
        preferences: preferences,
      );
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      final held = Completer<void>();
      final started = Completer<void>();
      preferences.holdWrite = held;
      preferences.writeStarted = started;
      addTearDown(() {
        if (!held.isCompleted) held.complete();
      });
      await submitOrganization(tester);
      for (var attempt = 0; attempt < 100 && !started.isCompleted; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(started.isCompleted, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(adapter.savedByKey, hasLength(1));
      expect(find.text('Создание недоступно'), findsNothing);
      expect(find.text('Создаём организацию…'), findsOneWidget);
      held.complete();
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
    },
  );

  testWidgets(
    'optional form data stays with its card after switching away and back',
    (tester) async {
      final adapter = OrganizationFlowAdapter();
      final container = await openOrganizationApp(tester, adapter);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      const sections = {
        'Реквизиты': {'tax_regime': 'Учебный режим', 'okved': '00.00'},
        'Адреса и контакты': {
          'legal_address': 'Учебный адрес без реального местоположения',
          'actual_address': 'Другой учебный адрес',
          'contact_email': 'office@example.invalid',
          'contact_phone': '+0 000 000-00-00',
        },
        'Деятельность': {'employee_count': '7'},
        'Заметки': {'notes': 'Синтетическая заметка только этой карточки.'},
      };
      for (final section in sections.entries) {
        final heading = find.text(section.key);
        await tester.ensureVisible(heading);
        await tester.pumpAndSettle();
        await tester.tap(heading);
        await tester.pumpAndSettle();
        for (final field in section.value.entries) {
          final input = find.byKey(ValueKey('organization-${field.key}'));
          await tester.ensureVisible(input);
          await tester.pumpAndSettle();
          await tester.enterText(input, field.value);
        }
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      final id = container.read(currentOrganizationProvider)!.id;
      // Use the visible selector in both directions, with a fresh server read.
      container.read(appRouterProvider).go('/organizations');
      await waitForOrganizationUi(tester, find.text('Учебная Альфа'));
      await tester.tap(find.text('Учебная Альфа'));
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
      container.read(appRouterProvider).go('/organizations');
      await waitForOrganizationUi(
        tester,
        find.text('Учебная новая организация'),
      );
      await tester.tap(find.text('Учебная новая организация'));
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(container.read(currentOrganizationProvider)?.id, id);
      final stored = await tester.runAsync(
        () => container.read(repositoryProvider).organization(id),
      );
      expect(
        stored!.legalAddress,
        sections['Адреса и контакты']!['legal_address'],
      );
      expect(
        stored.actualAddress,
        sections['Адреса и контакты']!['actual_address'],
      );
      expect(stored.contactEmail, 'office@example.invalid');
      expect(stored.contactPhone, '+0 000 000-00-00');
      expect(stored.taxRegime, 'Учебный режим');
      expect(stored.okved, '00.00');
      expect(stored.employeeCount, 7);
      expect(stored.notes, sections['Заметки']!['notes']);
      expect(adapter.creates, hasLength(1));
      expect(
        container.read(organizationControllerProvider).value!.items,
        hasLength(3),
      );
    },
  );

  testWidgets(
    'lost create reply reuses the same immutable request and creates one card',
    (tester) async {
      final adapter = OrganizationFlowAdapter()..loseFirstCreateReply = true;
      await openOrganizationApp(tester, adapter);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('Повторить отправку'));
      expect(adapter.savedByKey, hasLength(1));
      final nameField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('organization-short_name')),
      );
      expect(nameField.enabled, isFalse);
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(adapter.creates, hasLength(2));
      expect(adapter.savedByKey, hasLength(1));
      expect(
        adapter.creates.map((v) => v.headers['Idempotency-Key']).toSet(),
        hasLength(1),
      );
      expect(adapter.creates.first.data, adapter.creates.last.data);
    },
  );

  testWidgets(
    'server field error keeps the draft and correction receives a new request key',
    (tester) async {
      final adapter = OrganizationFlowAdapter()..validationFailures = 1;
      await openOrganizationApp(tester, adapter);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('organization-inn')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('organization-inn')),
        '0000000000',
      );
      await submitOrganization(tester);
      await waitForOrganizationUi(
        tester,
        find.text('ИНН: учебная ошибка проверки.'),
      );
      expect(adapter.savedByKey, isEmpty);
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('organization-full_name')),
            )
            .controller!
            .text,
        contains('синтетическая карточка'),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('organization-inn')),
      );
      final inn = find.byKey(const ValueKey('organization-inn'));
      await tester.tap(inn);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(inn).controller!.text, isEmpty);
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(adapter.savedByKey, hasLength(1));
      expect(
        adapter.creates.map((v) => v.headers['Idempotency-Key']).toSet(),
        hasLength(2),
      );
    },
  );

  testWidgets('IE form clears hidden LLC-only data before submission', (
    tester,
  ) async {
    final adapter = OrganizationFlowAdapter();
    await openOrganizationApp(tester, adapter);
    await openOrganizationForm(tester);
    await fillOrganizationName(tester, name: 'Учебный предприниматель');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Реквизиты'));
    await tester.tap(find.text('Реквизиты'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('organization-kpp')));
    await tester.enterText(
      find.byKey(const ValueKey('organization-kpp')),
      '111111111',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('organization-kind')));
    await tester.tap(find.byKey(const ValueKey('organization-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ИП').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('organization-kpp')), findsNothing);
    await submitOrganization(tester);
    await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
    expect((adapter.creates.single.data as Map)['kind'], 'ie');
    expect((adapter.creates.single.data as Map)['kpp'], '');
  });

  testWidgets(
    'leaving a draft asks for confirmation and Stay preserves all input',
    (tester) async {
      final adapter = OrganizationFlowAdapter();
      final container = await openOrganizationApp(tester, adapter);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      container.read(appRouterProvider).pop();
      await waitForOrganizationUi(
        tester,
        find.text('Закрыть новую организацию?'),
      );
      await tester.tap(find.text('Остаться'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('organization-short_name')),
            )
            .controller!
            .text,
        'Учебная новая организация',
      );
      container.read(appRouterProvider).pop();
      await waitForOrganizationUi(tester, find.text('Закрыть форму'));
      await tester.tap(find.text('Закрыть форму'));
      await waitForOrganizationUi(
        tester,
        find.text('Выберите организацию для работы'),
      );
      expect(adapter.creates, isEmpty);
    },
  );

  testWidgets(
    'busy create blocks duplicate taps and Android Back until the reply',
    (tester) async {
      final adapter = OrganizationFlowAdapter()..holdCreate = Completer<void>();
      final container = await openOrganizationApp(tester, adapter);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      await submitOrganization(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(adapter.creates, hasLength(1));
      await tester.tap(
        find.byKey(const ValueKey('organization-create-submit')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Новая организация'), findsOneWidget);
      expect(adapter.creates, hasLength(1));
      expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
      adapter.holdCreate!.complete();
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(adapter.savedByKey, hasLength(1));
    },
  );

  testWidgets(
    'saved card stays available when local selection fails and POST is not repeated',
    (tester) async {
      final adapter = OrganizationFlowAdapter();
      final preferences = OrganizationPreferences();
      final container = await openOrganizationApp(
        tester,
        adapter,
        preferences: preferences,
      );
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      preferences.failNextWrite = true;
      await submitOrganization(tester);
      await waitForOrganizationUi(
        tester,
        find.text('Выберите организацию для работы'),
      );
      expect(adapter.creates, hasLength(1));
      expect(find.text('Учебная новая организация'), findsOneWidget);
      expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
      await tester.tap(find.text('Учебная новая организация'));
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(
        container.read(currentOrganizationProvider)?.id,
        'organization-created-1',
      );
      expect(adapter.creates, hasLength(1));
    },
  );

  testWidgets(
    'refresh adds available cards and switching uses the selected tenant',
    (tester) async {
      final adapter = OrganizationFlowAdapter();
      final container = await openOrganizationApp(tester, adapter);
      expect(find.textContaining('Текущая организация'), findsOneWidget);
      adapter.organizations.add(
        organizationSummary('organization-3', 'Учебная Гамма'),
      );
      await tester.tap(find.byTooltip('Обновить'));
      await waitForOrganizationUi(tester, find.text('Учебная Гамма'));
      await tester.tap(find.text('Учебная Бета'));
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(container.read(currentOrganizationProvider)?.id, 'organization-2');
      expect(
        adapter.requests.where(
          (v) => v.uri.path.contains('/organizations/organization-2/'),
        ),
        isNotEmpty,
      );
      container.read(appRouterProvider).go('/organizations');
      await waitForOrganizationUi(
        tester,
        find.textContaining('Текущая организация'),
      );
      expect(find.textContaining('Текущая организация'), findsOneWidget);
      await tester.tap(find.text('Учебная Альфа'));
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
    },
  );

  testWidgets(
    'new organization form fits large text without losing save or return controls',
    (tester) async {
      final adapter = OrganizationFlowAdapter(empty: true);
      await openOrganizationApp(tester, adapter, textScale: 2);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      final submit = find.byKey(const ValueKey('organization-create-submit'));
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(submit, findsOneWidget);
      expect(tester.takeException(), isNull);
      await submitOrganization(tester);
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(adapter.savedByKey, hasLength(1));
    },
  );

  testWidgets(
    'organization settings opens the selector and selected card is marked',
    (tester) async {
      final container = await openOrganizationApp(
        tester,
        OrganizationFlowAdapter(),
      );
      container.read(appRouterProvider).go('/settings');
      await waitForOrganizationUi(
        tester,
        find.widgetWithText(ListTile, 'Учебная Альфа'),
      );
      await tester.tap(find.widgetWithText(ListTile, 'Учебная Альфа'));
      await waitForOrganizationUi(
        tester,
        find.textContaining('Текущая организация'),
      );
      expect(find.text('Добавить организацию'), findsOneWidget);
    },
  );

  testWidgets(
    'changing organization asks about an unsaved questionnaire before showing the selector',
    (tester) async {
      final container = await openOrganizationApp(
        tester,
        OrganizationFlowAdapter(),
      );
      container.read(appRouterProvider).go('/questionnaire');
      await waitForOrganizationUi(tester, find.text('Нет'));
      await tester.tap(find.text('Нет'));
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/organizations');
      await waitForOrganizationUi(tester, find.text('Несохранённые изменения'));
      await tester.tap(find.text('Остаться'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'no',
      );
      expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
      container.read(appRouterProvider).go('/organizations');
      await waitForOrganizationUi(tester, find.text('Уйти без сохранения'));
      await tester.tap(find.text('Уйти без сохранения'));
      await waitForOrganizationUi(tester, find.text('Учебная Бета'));
      await tester.tap(find.text('Учебная Бета'));
      await waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
      expect(container.read(currentOrganizationProvider)?.id, 'organization-2');
    },
  );

  testWidgets(
    'server permission rejection keeps the form and never selects a new organization',
    (tester) async {
      final adapter = OrganizationFlowAdapter()..refuseCreation = true;
      final container = await openOrganizationApp(tester, adapter);
      await openOrganizationForm(tester);
      await fillOrganizationName(tester);
      await submitOrganization(tester);
      await waitForOrganizationUi(
        tester,
        find.text('Организации создаёт администратор пилота.'),
      );
      expect(adapter.savedByKey, isEmpty);
      expect(container.read(currentOrganizationProvider)?.id, 'organization-1');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('organization-short_name')),
            )
            .enabled,
        isTrue,
      );
    },
  );
}

void main() => registerOrganizationFlowTests();
