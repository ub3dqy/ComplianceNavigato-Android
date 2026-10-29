import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:compliance_navigator/app/providers.dart';
import 'package:compliance_navigator/core/auth/auth_state.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/theme/app_theme.dart';
import 'package:compliance_navigator/features/external_services/external_services_screen.dart';
import 'package:compliance_navigator/features/obligations/obligations_screen.dart';
import 'package:compliance_navigator/features/questionnaires/questionnaire_screen.dart';
import 'package:compliance_navigator/features/websites/websites_screen.dart';
import 'package:compliance_navigator/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/organization_flow.dart';
import 'support/pilot_repository_flow.dart';
import 'support/ux_harness.dart';

final _selection = NotifierProvider<_Selection, OrganizationSummaryDto?>(
  _Selection.new,
);

final class _Selection extends Notifier<OrganizationSummaryDto?> {
  @override
  OrganizationSummaryDto build() => OrganizationSummaryDto.fromJson(
    organizationSummary('organization-1', 'Учебная Альфа'),
  );

  void select(String id) {
    ref.read(organizationGenerationProvider.notifier).advance();
    state = OrganizationSummaryDto.fromJson(
      organizationSummary(id, 'Учебная $id'),
    );
  }
}

final class _SaveAdapter implements HttpClientAdapter {
  final delegate = LocalFakeApiAdapter();
  final writes = <RequestOptions>[];
  final records = <String, List<JsonMap>>{};
  final replays = <String, JsonMap>{};
  final bodies = <String, String>{};
  int lostReplies = 0;
  int rejectedReplies = 0;
  int replayConflicts = 0;
  int stalePatches = 0;
  bool newerWebsite = false;
  Completer<void>? hold;

  ResponseBody json(Object? value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final match = RegExp(
      r'^(/api/v1/organizations/[^/]+/(?:websites|external-services|countries)/)',
    ).firstMatch(options.uri.path);
    if (match == null) return delegate.fetch(options, stream, cancel);
    final collection = match.group(1)!;
    if (options.method == 'GET' && records.containsKey(collection)) {
      return json(records[collection]);
    }
    if (options.method == 'GET' &&
        newerWebsite &&
        collection.endsWith('/websites/')) {
      final reply = await delegate.fetch(options, stream, cancel);
      final items =
          jsonDecode(await utf8.decoder.bind(reply.stream).join()) as List;
      (items.single as Map)['etag'] = '"website-2"';
      return json(items);
    }
    if (options.method == 'GET') return delegate.fetch(options, stream, cancel);
    writes.add(options);
    if (hold != null) await hold!.future;
    if (options.method == 'PATCH' && stalePatches > 0) {
      stalePatches--;
      newerWebsite = true;
      return json({'detail': 'Версия записи изменилась.'}, status: 409);
    }
    if (rejectedReplies > 0) {
      rejectedReplies--;
      return json({'detail': 'Проверьте введённые сведения.'}, status: 400);
    }
    final key =
        '${options.method}:${options.uri.path}:${options.headers['Idempotency-Key']}';
    final data = Map<String, Object?>.from(options.data as Map);
    if (replays.containsKey(key)) {
      expect(jsonEncode(data), bodies[key]);
      if (replayConflicts > 0) {
        replayConflicts--;
        return json({'detail': 'Такой запрос ещё выполняется.'}, status: 409);
      }
      return json(replays[key]);
    }
    final original = await delegate.fetch(options, stream, cancel);
    final record = Map<String, dynamic>.from(
      jsonDecode(await utf8.decoder.bind(original.stream).join()) as Map,
    );
    record.addAll(data);
    replays[key] = record;
    bodies[key] = jsonEncode(data);
    records[collection] = [record];
    if (lostReplies > 0) {
      lostReplies--;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'synthetic lost acknowledgement',
      );
    }
    return json(record);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

Future<void> _form(WidgetTester tester, String kind) async {
  if (kind == 'country') {
    await tester.tap(find.text('Страны'));
    await tester.pumpAndSettle();
  }
  await tester.tap(
    find.byTooltip(switch (kind) {
      'site' => 'Изменить сайт',
      'service' => 'Добавить сервис',
      _ => 'Добавить страну',
    }),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(
      TextFormField,
      kind == 'country' ? 'Страна' : 'Название',
    ),
    'Учебный черновик $kind',
  );
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 80 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue);
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  Widget screen,
  HttpClientAdapter adapter, {
  bool retryProviders = true,
}) async {
  if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final app = await createUxApp(
    phase: AuthPhase.authenticated,
    user: organizationTestUser,
    transport: adapter,
  ) as ProviderScope;
  await tester.pumpWidget(
    ProviderScope(
      retry: retryProviders ? null : (_, _) => null,
      overrides: [
        ...app.overrides,
        currentOrganizationProvider.overrideWith(
          (ref) => ref.watch(_selection),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byWidget(screen)));
}

void registerOrganizationPersistenceTests() {
  for (final kind in ['site', 'service', 'country']) {
    testWidgets('$kind retains entered data after rejected save', (
      tester,
    ) async {
      final suffix = switch (kind) {
        'site' => '/websites/website-1/',
        'service' => '/external-services/',
        _ => '/countries/',
      };
      var rejected = 0;
      final adapter = LocalFakeApiAdapter(
        beforeResponse: (options) async {
          if (options.method != 'GET' && options.path.endsWith(suffix)) {
            rejected++;
            throw DioException.badResponse(
              statusCode: 400,
              requestOptions: options,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 400,
                data: {
                  'error': {
                    'code': 'validation_error',
                    'message': 'Проверьте сведения.',
                  },
                },
              ),
            );
          }
        },
      );
      await _open(
        tester,
        kind == 'site'
            ? const WebsitesScreen()
            : const ExternalServicesScreen(),
        adapter,
      );
      if (kind == 'country') {
        await tester.tap(find.text('Страны'));
        await tester.pumpAndSettle();
      }
      await tester.tap(
        find.byTooltip(switch (kind) {
          'site' => 'Изменить сайт',
          'service' => 'Добавить сервис',
          _ => 'Добавить страну',
        }),
      );
      await tester.pumpAndSettle();
      final name = kind == 'country' ? 'Страна' : 'Название';
      await tester.enterText(
        find.widgetWithText(TextFormField, name),
        'Учебный черновик $kind',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(rejected, 1);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Учебный черновик $kind'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$kind retries a lost acknowledgement once without duplicate and stays in its organization',
      (tester) async {
        final adapter = _SaveAdapter()..lostReplies = 1;
        final container = await _open(
          tester,
          kind == 'site'
              ? const WebsitesScreen()
              : const ExternalServicesScreen(),
          adapter,
        );
        await _form(tester, kind);
        await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .every((field) => field.enabled == false),
          isTrue,
        );
        expect(adapter.replays, hasLength(1));
        await tester.tap(
          find.widgetWithText(FilledButton, 'Повторить сохранение'),
        );
        await tester.pumpAndSettle();
        expect(adapter.writes, hasLength(2));
        expect(
          adapter.writes[0].headers['Idempotency-Key'],
          adapter.writes[1].headers['Idempotency-Key'],
        );
        expect(
          adapter.writes[0].headers['If-Match'],
          adapter.writes[1].headers['If-Match'],
        );
        expect(adapter.replays, hasLength(1));
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Учебный черновик $kind'), findsOneWidget);
        container.read(_selection.notifier).select('organization-2');
        await tester.pumpAndSettle();
        expect(find.text('Учебный черновик $kind'), findsNothing);
        container.read(_selection.notifier).select('organization-1');
        await _until(
          tester,
          () => find.text('Учебный черновик $kind').evaluate().isNotEmpty,
        );
        expect(find.text('Учебный черновик $kind'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$kind keeps its draft and prevents duplicate presses while saving',
      (tester) async {
        final release = Completer<void>();
        final adapter = _SaveAdapter()..hold = release;
        await _open(
          tester,
          kind == 'site'
              ? const WebsitesScreen()
              : const ExternalServicesScreen(),
          adapter,
        );
        await _form(tester, kind);
        await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
        await _until(tester, () => adapter.writes.isNotEmpty);
        final fields = tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .toList();
        final cancel = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Отмена'),
        );
        final saving = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Сохранение…'),
        );
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(AlertDialog), findsOneWidget);
        release.complete();
        expect(fields.every((field) => field.enabled == false), isTrue);
        expect(cancel.onPressed, isNull);
        expect(saving.onPressed, isNull);
        expect(adapter.writes, hasLength(1));
        await tester.pumpAndSettle();
        expect(find.text('Учебный черновик $kind'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$kind draft expires on organization switch without sending it',
      (tester) async {
        final adapter = _SaveAdapter();
        final container = await _open(
          tester,
          kind == 'site'
              ? const WebsitesScreen()
              : const ExternalServicesScreen(),
          adapter,
        );
        await _form(tester, kind);
        container.read(_selection.notifier).select('organization-2');
        await tester.pumpAndSettle();
        expect(find.text('Учебный черновик $kind'), findsNothing);
        expect(find.text('Организация изменилась'), findsOneWidget);
        container.read(_selection.notifier).select('organization-1');
        await tester.pumpAndSettle();
        expect(find.text('Учебный черновик $kind'), findsNothing);
        expect(adapter.writes, isEmpty);
        await tester.tap(find.widgetWithText(TextButton, 'Закрыть'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a rejected country can be corrected without losing its other fields',
    (tester) async {
      final adapter = _SaveAdapter()..rejectedReplies = 1;
      await _open(tester, const ExternalServicesScreen(), adapter);
      await _form(tester, 'country');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Цель обработки'),
        'Учебная цель обработки',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(find.text('Учебная цель обработки'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Страна'),
        'Исправленная учебная страна',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(2));
      expect(
        adapter.writes[0].headers['Idempotency-Key'],
        isNot(adapter.writes[1].headers['Idempotency-Key']),
      );
      expect(
        (adapter.writes.last.data as Map)['purpose'],
        'Учебная цель обработки',
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Исправленная учебная страна'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'questionnaire cannot accept edits while refresh replaces answers',
    (tester) async {
      Completer<void>? release;
      var loads = 0;
      final adapter = LocalFakeApiAdapter(
        beforeResponse: (options) async {
          if (options.method == 'GET' &&
              options.path.endsWith('/questionnaires/current/')) {
            loads++;
            if (release != null) await release.future;
          }
        },
      );
      await _open(tester, const QuestionnaireScreen(), adapter);
      release = Completer<void>();
      await tester.tap(find.byTooltip('Обновить'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(loads, 2);
      final refresh = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('Обновить'),
          matching: find.byType(IconButton),
        ),
      );
      final save = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Сохранить'),
      );
      final answers = tester.widgetList<RadioListTile<String>>(
        find.byType(RadioListTile<String>),
      );
      // Always unblock the fixture, even when the regression assertion fails.
      release.complete();
      expect(refresh.onPressed, isNull);
      expect(save.onPressed, isNull);
      expect(answers, isNotEmpty);
      expect(answers.every((answer) => answer.enabled == false), isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late questionnaire refresh cannot erase a draft after A B A switch',
    (tester) async {
      final release = Completer<void>();
      var holdNext = false;
      final adapter = LocalFakeApiAdapter(
        beforeResponse: (options) async {
          if (holdNext &&
              options.method == 'GET' &&
              options.path.endsWith('/questionnaires/current/')) {
            holdNext = false;
            await release.future;
          }
        },
      );
      final container = await _open(
        tester,
        const QuestionnaireScreen(),
        adapter,
      );
      holdNext = true;
      await tester.tap(find.byTooltip('Обновить'));
      await tester.pump();
      container.read(_selection.notifier).select('organization-2');
      await tester.pumpAndSettle();
      container.read(_selection.notifier).select('organization-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Нет'));
      await tester.pumpAndSettle();
      expect(find.text('Есть изменения'), findsOneWidget);
      release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Есть изменения'), findsOneWidget);
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'no',
      );
    },
  );

  testWidgets(
    'late questionnaire save cannot clear a new draft after A B A switch',
    (tester) async {
      final release = Completer<void>();
      var writes = 0;
      final adapter = LocalFakeApiAdapter(
        beforeResponse: (options) async {
          if (options.method == 'PATCH' &&
              options.path.endsWith('/questionnaires/response-1/')) {
            writes++;
            await release.future;
          }
        },
      );
      final container = await _open(
        tester,
        const QuestionnaireScreen(),
        adapter,
      );
      await tester.tap(find.text('Нет'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Сохранить'));
      await _until(tester, () => writes == 1);
      container.read(_selection.notifier).select('organization-2');
      await tester.pumpAndSettle();
      container.read(_selection.notifier).select('organization-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Нет'));
      await tester.pumpAndSettle();
      release.complete();
      await tester.pumpAndSettle();
      expect(find.text('Есть изменения'), findsOneWidget);
      expect(find.text('Ответы сохранены.'), findsNothing);
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'no',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an uncertain create retains its request after a retry conflict',
    (tester) async {
      final adapter = _SaveAdapter()
        ..lostReplies = 1
        ..replayConflicts = 1;
      await _open(tester, const ExternalServicesScreen(), adapter);
      await _form(tester, 'service');
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Повторить сохранение'),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Повторить сохранение'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((field) => field.enabled == false),
        isTrue,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Повторить сохранение'),
      );
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(3));
      expect(
        adapter.writes.map((r) => r.headers['Idempotency-Key']).toSet(),
        hasLength(1),
      );
      expect(adapter.replays, hasLength(1));
      expect(find.text('Учебный черновик service'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'website conflict refresh preserves draft and saves only on a separate confirmation',
    (tester) async {
      final adapter = _SaveAdapter()..stalePatches = 1;
      await _open(tester, const WebsitesScreen(), adapter);
      await _form(tester, 'site');
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(find.text('Учебный черновик site'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Обновить версию'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(find.text('Учебный черновик site'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(2));
      expect(adapter.writes[0].headers['If-Match'], '"website-1"');
      expect(adapter.writes[1].headers['If-Match'], '"website-2"');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Учебный черновик site'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

final class _ObligationAdapter implements HttpClientAdapter {
  final delegate = LocalFakeApiAdapter();
  final writes = <RequestOptions>[];
  final records = <String, JsonMap>{};
  final replays = <String, JsonMap>{};
  final bodies = <String, String>{};
  final revisions = <String, int>{};
  Completer<void>? hold;
  Completer<void>? holdReload;
  int rejectedReplies = 0;
  int failureStatus = 400;
  int reloadFailures = 0;
  int lostReplies = 0;
  int stalePatches = 0;
  bool newerObligation = false;

  ResponseBody json(Object? value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    final path = options.uri.path;
    final match = RegExp(
      r'^(/api/v1/organizations/[^/]+/(?:obligations|checklist)/)',
    ).firstMatch(path);
    if (match == null) return delegate.fetch(options, stream, cancel);
    final collection = match.group(1)!;
    if (options.method == 'GET') {
      if (writes.isNotEmpty && holdReload != null) await holdReload!.future;
      if (writes.isNotEmpty && reloadFailures > 0) {
        reloadFailures--;
        return json({
          'detail': 'Синтетическая ошибка обновления.',
        }, status: 503);
      }
      if (records.containsKey(collection)) return json([records[collection]]);
      if (newerObligation && collection.endsWith('/obligations/')) {
        final reply = await delegate.fetch(options, stream, cancel);
        final items =
            jsonDecode(await utf8.decoder.bind(reply.stream).join()) as List;
        (items.single as Map)['etag'] = '"obligation-2"';
        return json(items);
      }
    }
    if (options.method != 'PATCH') {
      // This fixture grants access to both organizations. The general fixture
      // uses organization-2 for denial tests, so reuse its DTO shape for this
      // authorized read while retaining independent records by collection path.
      final fixture = options.copyWith(
        path: options.path.replaceFirst('organization-2/', 'organization-1/'),
      );
      return delegate.fetch(fixture, stream, cancel);
    }
    writes.add(options);
    if (hold != null) await hold!.future;
    if (rejectedReplies > 0) {
      rejectedReplies--;
      return json({
        'detail': 'Синтетическая ошибка сохранения.',
      }, status: failureStatus);
    }
    if (stalePatches > 0) {
      stalePatches--;
      newerObligation = true;
      return json({'detail': 'Синтетический конфликт версии.'}, status: 409);
    }
    final key = '${options.uri.path}:${options.headers['Idempotency-Key']}';
    final body = jsonEncode(options.data);
    if (replays.containsKey(key)) {
      expect(body, bodies[key]);
      return json(replays[key]);
    }
    final reply = await delegate.fetch(options, stream, cancel);
    final record = Map<String, dynamic>.from(
      jsonDecode(await utf8.decoder.bind(reply.stream).join()) as Map,
    );
    record.addAll(Map<String, Object?>.from(options.data as Map));
    final revision = (revisions[collection] ?? 1) + 1;
    revisions[collection] = revision;
    record['etag'] = '"${record['id'].toString().split('-').first}-$revision"';
    records[collection] = record;
    replays[key] = record;
    bodies[key] = body;
    if (lostReplies > 0) {
      lostReplies--;
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'synthetic lost acknowledgement',
      );
    }
    return json(record);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

Future<void> _completeForm(WidgetTester tester) async {
  await tester.tap(find.text('Проверить политику'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Подтвердить выполнение'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Комментарий'),
    'Учебное подтверждение выполнения',
  );
  await tester.tap(
    find.widgetWithText(
      CheckboxListTile,
      'Подтверждающий файл не требуется или отсутствует',
    ),
  );
  await tester.pumpAndSettle();
}

void registerObligationPersistenceTests() {
  testWidgets(
    'rejected obligation completion retains its comment and confirmation',
    (tester) async {
      final adapter = _ObligationAdapter()..rejectedReplies = 1;
      await _open(tester, const ObligationsScreen(), adapter);
      await _completeForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Учебное подтверждение выполнения'), findsOneWidget);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(
                CheckboxListTile,
                'Подтверждающий файл не требуется или отсутствует',
              ),
            )
            .value,
        isTrue,
      );
      final commentField = find.widgetWithText(TextFormField, 'Комментарий');
      expect(tester.widget<TextFormField>(commentField).enabled, isTrue);
      // Saving dismisses the native keyboard. Refocus as a user would before
      // injecting text; showKeyboard alone caches this same EditableText.
      await tester.tap(commentField);
      await tester.pumpAndSettle();
      await tester.enterText(commentField, 'Исправленный учебный комментарий');
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<String>>(
              find.widgetWithText(TextFormField, 'Комментарий'),
            )
            .value,
        'Исправленный учебный комментарий',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(2));
      expect(
        (adapter.writes.last.data as Map)['completion_comment'],
        'Исправленный учебный комментарий',
      );
      expect(
        adapter.writes.first.headers['Idempotency-Key'],
        isNot(adapter.writes.last.headers['Idempotency-Key']),
      );
      expect(
        (adapter.writes.last.data as Map)['evidence_absent_confirmed'],
        isTrue,
      );
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('Проверить политику'));
      await tester.pumpAndSettle();
      expect(
        find.text('Комментарий: Исправленный учебный комментарий'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'old obligation confirmation cannot write after switching organization',
    (tester) async {
      final adapter = _ObligationAdapter();
      final container = await _open(tester, const ObligationsScreen(), adapter);
      await _completeForm(tester);
      container.read(_selection.notifier).select('organization-2');
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Подтвердить');
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm);
        await tester.pumpAndSettle();
      }
      expect(adapter.writes, isEmpty);
      expect(find.text('Учебное подтверждение выполнения'), findsNothing);
    },
  );

  testWidgets('busy task accepts only one completion request', (tester) async {
    final release = Completer<void>();
    final adapter = _ObligationAdapter()..hold = release;
    await _open(tester, const ObligationsScreen(), adapter);
    final task = find.widgetWithText(CheckboxListTile, 'Подготовить черновик');
    await tester.tap(task);
    await _until(tester, () => adapter.writes.isNotEmpty);
    await tester.tap(task);
    await tester.pump();
    release.complete();
    await tester.pumpAndSettle();
    expect(adapter.writes, hasLength(1));
    expect(tester.widget<CheckboxListTile>(task).value, isTrue);
  });

  testWidgets('late task failure stays out of a different organization', (
    tester,
  ) async {
    final release = Completer<void>();
    final adapter = _ObligationAdapter()
      ..hold = release
      ..rejectedReplies = 1
      ..failureStatus = 503;
    final container = await _open(tester, const ObligationsScreen(), adapter);
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Подготовить черновик'),
    );
    await _until(tester, () => adapter.writes.isNotEmpty);
    container.read(_selection.notifier).select('organization-2');
    await tester.pumpAndSettle();
    release.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(adapter.writes, hasLength(1));
  });
  testWidgets(
    'lost obligation acknowledgement replays the same immutable completion',
    (tester) async {
      final adapter = _ObligationAdapter()..lostReplies = 1;
      await _open(tester, const ObligationsScreen(), adapter);
      await _completeForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await tester.pumpAndSettle();
      expect(find.text('Учебное подтверждение выполнения'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Комментарий'),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Повторить сохранение'),
      );
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(2));
      expect(adapter.replays, hasLength(1));
      expect(
        adapter.writes.first.headers['Idempotency-Key'],
        adapter.writes.last.headers['Idempotency-Key'],
      );
      expect(
        adapter.writes.first.headers['If-Match'],
        adapter.writes.last.headers['If-Match'],
      );
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('Проверить политику'));
      await tester.pumpAndSettle();
      expect(
        find.text('Комментарий: Учебное подтверждение выполнения'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'busy obligation completion blocks repeat presses and Android Back',
    (tester) async {
      final release = Completer<void>();
      final adapter = _ObligationAdapter()..hold = release;
      await _open(tester, const ObligationsScreen(), adapter);
      await _completeForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await _until(tester, () => adapter.writes.isNotEmpty);
      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Комментарий'),
      );
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Сохранение…'),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      release.complete();
      expect(field.enabled, isFalse);
      expect(save.onPressed, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'obligation conflict reload retains the comment and requires another confirmation',
    (tester) async {
      final adapter = _ObligationAdapter()..stalePatches = 1;
      await _open(tester, const ObligationsScreen(), adapter);
      await _completeForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      await tester.tap(find.widgetWithText(TextButton, 'Обновить версию'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(find.text('Учебное подтверждение выполнения'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(2));
      expect(adapter.writes.first.headers['If-Match'], '"obligation-1"');
      expect(adapter.writes.last.headers['If-Match'], '"obligation-2"');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets(
    'task completion and reopening persist only in their organization',
    (tester) async {
      final adapter = _ObligationAdapter();
      final container = await _open(tester, const ObligationsScreen(), adapter);
      final task = find.widgetWithText(
        CheckboxListTile,
        'Подготовить черновик',
      );
      for (final completed in [true, false, true]) {
        await tester.tap(task);
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(task).value, completed);
      }
      expect(adapter.writes, hasLength(3));
      expect((adapter.writes[1].data as Map)['status'], 'open');
      expect(adapter.writes[1].headers['If-Match'], '"task-2"');
      container.read(_selection.notifier).select('organization-2');
      await _until(
        tester,
        () =>
            task.evaluate().isNotEmpty &&
            tester.widget<CheckboxListTile>(task).value == false,
      );
      expect(tester.widget<CheckboxListTile>(task).value, isFalse);
      container.read(_selection.notifier).select('organization-1');
      await _until(
        tester,
        () =>
            task.evaluate().isNotEmpty &&
            tester.widget<CheckboxListTile>(task).value == true,
      );
      expect(
        adapter.writes.every(
          (request) => request.path.contains('organization-1/'),
        ),
        isTrue,
      );
    },
  );

  testWidgets('task remains disabled until its refreshed state arrives', (
    tester,
  ) async {
    final reload = Completer<void>();
    final adapter = _ObligationAdapter()..holdReload = reload;
    await _open(tester, const ObligationsScreen(), adapter);
    final task = find.widgetWithText(CheckboxListTile, 'Подготовить черновик');
    await tester.tap(task);
    await _until(tester, () => adapter.records.isNotEmpty);
    final control = tester.widget<CheckboxListTile>(task);
    reload.complete();
    expect(control.onChanged, isNull);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(task).value, isTrue);
    expect(adapter.writes, hasLength(1));
  });

  testWidgets(
    'failed list refresh reports the confirmed task save and retries only the read',
    (tester) async {
      final adapter = _ObligationAdapter()..reloadFailures = 1;
      await _open(
        tester,
        const ObligationsScreen(),
        adapter,
        retryProviders: false,
      );
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'Подготовить черновик'),
      );
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(
        find.text(
          'Задача сохранена. Не удалось обновить список. Обновите экран.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();
      final task = find.widgetWithText(
        CheckboxListTile,
        'Подготовить черновик',
      );
      expect(tester.widget<CheckboxListTile>(task).value, isTrue);
      expect(adapter.writes, hasLength(1));
    },
  );
}

void registerAcknowledgedRefreshTests() {
  testWidgets(
    'acknowledged obligation stays open until the fresh record arrives',
    (tester) async {
      final reload = Completer<void>();
      final adapter = _ObligationAdapter()..holdReload = reload;
      await _open(tester, const ObligationsScreen(), adapter);
      await _completeForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await _until(tester, () => adapter.records.isNotEmpty);
      final dialogStillOpen = find.byType(AlertDialog).evaluate().isNotEmpty;
      reload.complete();
      expect(dialogStillOpen, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('Проверить политику'));
      await tester.pumpAndSettle();
      expect(
        find.text('Комментарий: Учебное подтверждение выполнения'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'acknowledged obligation retries only list refresh after a read failure',
    (tester) async {
      final adapter = _ObligationAdapter()..reloadFailures = 1;
      await _open(
        tester,
        const ObligationsScreen(),
        adapter,
        retryProviders: false,
      );
      await _completeForm(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Подтвердить'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(
        find.text(
          'Сведения сохранены. Не удалось обновить список. Повторите обновление.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Обновить список'));
      await tester.pumpAndSettle();
      expect(adapter.writes, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}

void main() {
  registerOrganizationPersistenceTests();
  registerObligationPersistenceTests();
  registerAcknowledgedRefreshTests();
}
