import 'dart:typed_data';

import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/routing/app_router.dart';
import 'package:compliance_navigator/core/widgets/compliance_scaffold.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/pilot_repository_flow.dart';
import 'support/ux_harness.dart';
import 'widget_test.dart' as fixtures;

const _root = ValueKey<String>('ux-regression-root');

final class _DraftAdapter implements HttpClientAdapter {
  _DraftAdapter({this.status = 200});
  final int status;
  final delegate = fixtures.WidgetAdapter(mfa: true, schemaHash: uxSchema);
  final writes = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.method == 'PATCH' &&
        options.path.endsWith('/questionnaires/response-1/')) {
      writes.add(options);
      if (status != 200) {
        return Future.value(
          ResponseBody.fromString(
            '{"detail":"synthetic failure"}',
            status,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ),
        );
      }
    }
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

Future<void> _enter(
  WidgetTester tester, {
  bool viewer = false,
  bool fullFixture = false,
  Size size = const Size(390, 844),
  double textScale = 1,
  HttpClientAdapter? transport,
}) async {
  if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    await createUxApp(
      captureKey: _root,
      transport:
          transport ??
          (fullFixture
              ? LocalFakeApiAdapter()
              : fixtures.WidgetAdapter(mfa: true, schemaHash: uxSchema)),
      currentOrganization: viewer
          ? OrganizationSummaryDto.fromJson(<String, dynamic>{
              'id': 'organization-1',
              'short_name': 'Учебная организация',
              'kind': 'llc',
              'role': 'viewer',
              'updated_at': '2026-08-27T12:00:00Z',
            })
          : null,
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'pilot@example.invalid',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'synthetic-only');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Войти'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Войти'));
  await _waitFor(tester, find.text('Продолжить'));
  await tester.enterText(find.byType(TextField).last, '000000');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Продолжить'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Продолжить'));
  await _waitFor(tester, find.text('Выберите организацию для работы'));
  await tester.scrollUntilVisible(
    find.text('Пилот ООО'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _waitFor(tester, find.text('Пилот ООО'));
  await tester.ensureVisible(find.text('Пилот ООО'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Пилот ООО'));
  String location() =>
      _container(tester)
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri
          .path;
  for (
    var attempt = 0;
    attempt < 100 && location() != '/dashboard';
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(location(), '/dashboard');
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byKey(_root)), listen: false);

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.byType(NavigationDestination).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Нет'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('short document lists still refresh with a pull gesture', (
    tester,
  ) async {
    final adapter = LocalFakeApiAdapter();
    await _enter(tester, transport: adapter);
    _container(tester).read(appRouterProvider).go('/documents');
    await tester.pumpAndSettle();
    int loads() => adapter.requests
        .where(
          (request) =>
              request.method == 'GET' && request.path.endsWith('/documents/'),
        )
        .length;
    final before = loads();
    expect(before, 1);
    await tester.drag(find.byType(ListView).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(loads(), before + 1);
  });

  testWidgets('saving before leaving sends the selected answer once', (
    tester,
  ) async {
    final adapter = _DraftAdapter();
    await _enter(tester, transport: adapter);
    await _edit(tester);
    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить и перейти'));
    await _waitFor(tester, find.text('Работа по шагам'));
    expect(adapter.writes, hasLength(1));
    expect((adapter.writes.single.data as Map)['answers'], {
      'has_website': 'no',
    });
    expect(find.text('Работа по шагам'), findsOneWidget);
  });

  testWidgets('failed save cannot discard the edited answer on navigation', (
    tester,
  ) async {
    final adapter = _DraftAdapter(status: 503);
    await _enter(tester, transport: adapter);
    await _edit(tester);
    await tester.tap(find.byType(NavigationDestination).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить и перейти'));
    await tester.pumpAndSettle();
    expect(adapter.writes, hasLength(1));
    expect(find.widgetWithText(OutlinedButton, 'Сохранить'), findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'no',
    );
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(find.text('Несохранённые изменения'), findsOneWidget);
    await tester.tap(find.text('Уйти без сохранения'));
    await _waitFor(tester, find.text('Работа по шагам'));
    expect(find.text('Работа по шагам'), findsOneWidget);
    expect(adapter.writes, hasLength(1));
  });

  testWidgets('all nine additional menu pages return to the menu', (
    tester,
  ) async {
    await _enter(tester);
    _container(tester).read(appRouterProvider).go('/more');
    await tester.pumpAndSettle();
    for (final entry in const [
      ('Сайты', '/websites'),
      ('Сервисы и страны', '/services'),
      ('Оценки', '/assessments'),
      ('Проверка сайтов', '/scanner'),
      ('Документы', '/documents'),
      ('Подтверждения', '/evidence'),
      ('Отчёты', '/reports'),
      ('Журнал действий', '/audit'),
      ('Настройки', '/settings'),
    ]) {
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, entry.$1),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ListTile, entry.$1));
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(tester.element(find.byType(ComplianceScaffold).last))
            .uri
            .path,
        entry.$2,
      );
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(
        _container(tester)
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/more',
      );
    }
  });

  testWidgets('Android Back asks before leaving an edited questionnaire', (
    tester,
  ) async {
    await _enter(tester);
    await _edit(tester);
    final back = tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Несохранённые изменения'), findsOneWidget);
    await tester.tap(find.text('Остаться'));
    await tester.pumpAndSettle();
    await back;
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'no',
    );
  });
  testWidgets(
    'bottom tabs ask about draft; Stay preserves the selected answer',
    (tester) async {
      await _enter(tester);
      await _edit(tester);
      await tester.tap(find.byTooltip('Назад'));
      await tester.pumpAndSettle();
      expect(find.text('Несохранённые изменения'), findsOneWidget);
      await tester.tap(find.text('Остаться'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(0));
      await tester.pumpAndSettle();
      expect(find.text('Несохранённые изменения'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Сохранить'), findsOneWidget);
      await tester.tap(find.text('Остаться'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'no',
      );
    },
  );

  testWidgets(
    'refresh asks about draft; cancelling preserves the entered answer',
    (tester) async {
      await _enter(tester);
      await _edit(tester);
      await tester.tap(find.byTooltip('Обновить'));
      await tester.pumpAndSettle();
      expect(find.text('Несохранённые изменения'), findsOneWidget);
      await tester.tap(find.text('Остаться'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'no',
      );
    },
  );

  testWidgets('More settings has a real return path', (tester) async {
    await _enter(tester);
    _container(tester).read(appRouterProvider).go('/more');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Настройки'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    expect(_container(tester).read(appRouterProvider).canPop(), isTrue);
    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();
    expect(
      _container(tester)
          .read(appRouterProvider)
          .routeInformationProvider
          .value
          .uri
          .path,
      '/more',
    );
  });

  testWidgets(
    'viewer can read the second question and cannot save or change answers',
    (tester) async {
      await _enter(tester, viewer: true);
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byType(RadioListTile<String>).first,
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Далее'));
      await tester.pumpAndSettle();
      expect(find.text('Вопрос 2 из 2'), findsOneWidget);
      expect(find.text('Завершить'), findsNothing);
    },
  );

  testWidgets(
    'services and country tabs fit large text without raw wire statuses',
    (tester) async {
      await _enter(
        tester,
        fullFixture: true,
        size: const Size(360, 800),
        textScale: 2,
      );
      _container(tester).read(appRouterProvider).go('/services');
      await _waitFor(tester, find.text('Тестовый сервис'));
      expect(tester.takeException(), isNull);
      expect(find.text('Тестовый сервис'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Сведения о сервисе'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сведения о сервисе'));
      await tester.pumpAndSettle();
      expect(find.text('Черновик'), findsOneWidget);
      expect(find.textContaining('needs_review'), findsNothing);
      expect(find.textContaining('draft'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Страны'),
        -300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Страны'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('needs_review'), findsNothing);
      expect(find.textContaining('draft'), findsNothing);
    },
  );
}
