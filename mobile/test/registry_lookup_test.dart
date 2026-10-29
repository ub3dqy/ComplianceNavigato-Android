import 'dart:async';

import 'package:compliance_navigator/features/organizations/registry_lookup_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'organization_flow_test.dart' as flow;
import 'support/organization_flow.dart';

Future<void> setField(WidgetTester tester, String name, String value) async {
  final field = find.byKey(ValueKey('organization-$name'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String name) => tester
    .widget<TextFormField>(find.byKey(ValueKey('organization-$name')))
    .controller!
    .text;

Future<void> pressLookup(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('organization-lookup-inn'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> cancelLookup(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('registry-cancel')));
  await tester.pumpAndSettle();
}

void registerRegistryLookupTests() {
  test('INN checksum uses ASCII digits and both subject types', () {
    expect(validRegistryInn('1234567894'), isTrue);
    expect(validRegistryInn('123456789047'), isTrue);
    for (final value in ['1234567890', '1111111111', '１２３４５６７８９４', '']) {
      expect(validRegistryInn(value), isFalse);
    }
  });

  for (final kind in ['llc', 'ie']) {
    testWidgets(
      '$kind lookup previews, fills and saves editable requisites separately',
      (tester) async {
        final adapter = OrganizationFlowAdapter();
        if (kind == 'ie') {
          adapter.registryPreview.addAll({
            'kind': 'ie',
            'inn': '123456789047',
            'ogrn': '123456789012343',
            'kpp': null,
          });
        }
        await flow.openOrganizationApp(tester, adapter);
        await flow.openOrganizationForm(tester);
        await setField(
          tester,
          'inn',
          adapter.registryPreview['inn']! as String,
        );
        await pressLookup(tester);
        await flow.waitForOrganizationUi(
          tester,
          find.text('Проверьте реквизиты'),
        );
        expect(adapter.creates, isEmpty);
        expect(adapter.registryReads, 1);
        final request = adapter.requests.singleWhere(
          (r) => r.path.endsWith('lookup-by-inn/'),
        );
        expect(request.data, {'inn': adapter.registryPreview['inn']});
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        await tester.tap(find.byKey(const ValueKey('registry-apply')));
        await tester.pumpAndSettle();
        expect(fieldText(tester, 'short_name'), 'Учебный справочник');
        await tester.ensureVisible(find.text('Реквизиты'));
        await tester.tap(find.text('Реквизиты'));
        await tester.pumpAndSettle();
        expect(fieldText(tester, 'leader_name'), 'Синтетиков Первый Учебный');
        await setField(tester, 'short_name', 'Уточнённое учебное имя');
        await flow.submitOrganization(tester);
        await flow.waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
        expect(adapter.creates, hasLength(1));
        final saved = adapter.savedByKey.values.single;
        expect(saved['kind'], kind);
        expect(saved['inn'], adapter.registryPreview['inn']);
        expect(saved['kpp'], kind == 'ie' ? '' : '123401001');
      },
    );
  }

  testWidgets('lookup keeps manual contacts, activity and notes', (
    tester,
  ) async {
    final adapter = OrganizationFlowAdapter();
    await flow.openOrganizationApp(tester, adapter);
    await flow.openOrganizationForm(tester);
    for (final section in ['Адреса и контакты', 'Деятельность', 'Заметки']) {
      await tester.ensureVisible(find.text(section));
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();
    }
    for (final entry in {
      'actual_address': 'Ручной учебный адрес',
      'contact_email': 'office@example.invalid',
      'employee_count': '7',
      'privacy_responsible': 'Синтетиков Второй Учебный',
      'notes': 'Учебная заметка',
    }.entries) {
      await setField(tester, entry.key, entry.value);
    }
    await setField(tester, 'inn', '1234567894');
    await pressLookup(tester);
    await flow.waitForOrganizationUi(tester, find.text('Проверьте реквизиты'));
    await tester.tap(find.byKey(const ValueKey('registry-apply')));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'employee_count'), '7');
    expect(fieldText(tester, 'actual_address'), 'Ручной учебный адрес');
    expect(
      fieldText(tester, 'privacy_responsible'),
      'Синтетиков Второй Учебный',
    );
    expect(fieldText(tester, 'notes'), 'Учебная заметка');
    await flow.submitOrganization(tester);
    await flow.waitForOrganizationUi(tester, find.text('СЛЕДУЮЩИЙ ШАГ'));
    expect(
      adapter.savedByKey.values.single['contact_email'],
      'office@example.invalid',
    );
  });

  for (final status in [200, 404, 409, 429, 503]) {
    testWidgets('cancel/error $status preserves draft and never creates', (
      tester,
    ) async {
      final adapter = OrganizationFlowAdapter()..registryStatus = status;
      await flow.openOrganizationApp(tester, adapter);
      await flow.openOrganizationForm(tester);
      await setField(tester, 'short_name', 'Ручной черновик');
      await setField(tester, 'inn', '1234567894');
      await pressLookup(tester);
      if (status == 200) {
        await flow.waitForOrganizationUi(
          tester,
          find.text('Проверьте реквизиты'),
        );
      } else {
        await tester.pumpAndSettle();
      }
      await cancelLookup(tester);
      expect(fieldText(tester, 'short_name'), 'Ручной черновик');
      expect(adapter.creates, isEmpty);
    });
  }

  testWidgets('cancel pending lookup ignores late response', (tester) async {
    final adapter = OrganizationFlowAdapter()..holdRegistry = Completer<void>();
    await flow.openOrganizationApp(tester, adapter);
    await flow.openOrganizationForm(tester);
    await setField(tester, 'inn', '1234567894');
    await pressLookup(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(adapter.registryReads, 1);
    await cancelLookup(tester);
    adapter.holdRegistry!.complete();
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'short_name'), isEmpty);
    expect(adapter.creates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid INN does not send a request', (tester) async {
    final adapter = OrganizationFlowAdapter();
    await flow.openOrganizationApp(tester, adapter);
    await flow.openOrganizationForm(tester);
    await setField(tester, 'inn', '1234567890');
    await pressLookup(tester);
    await tester.pumpAndSettle();
    expect(adapter.registryReads, 0);
    expect(find.byType(RegistryLookupDialog), findsNothing);
  });

  testWidgets('mismatched response is rejected without overwriting draft', (
    tester,
  ) async {
    final adapter = OrganizationFlowAdapter();
    adapter.registryPreview['inn'] = '1234567890';
    await flow.openOrganizationApp(tester, adapter);
    await flow.openOrganizationForm(tester);
    await setField(tester, 'inn', '1234567894');
    await pressLookup(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('registry-apply')), findsNothing);
    await cancelLookup(tester);
    expect(fieldText(tester, 'inn'), '1234567894');
  });

  testWidgets('preview remains usable with large text', (tester) async {
    final adapter = OrganizationFlowAdapter();
    await flow.openOrganizationApp(tester, adapter, textScale: 1.6);
    await flow.openOrganizationForm(tester);
    await setField(tester, 'inn', '1234567894');
    await pressLookup(tester);
    await flow.waitForOrganizationUi(tester, find.text('Проверьте реквизиты'));
    expect(tester.takeException(), isNull);
    await cancelLookup(tester);
  });
}

void main() => registerRegistryLookupTests();
