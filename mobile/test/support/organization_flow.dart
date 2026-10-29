import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/storage/app_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../widget_test.dart' as fixtures;

const organizationTestTime = '2026-10-27T06:00:00Z';
const organizationTestUser = CurrentUserDto(
  id: 'synthetic-admin',
  email: 'pilot@example.invalid',
  isStaff: true,
  isSuperuser: true,
  mfaEnabled: false,
);

Map<String, Object?> organizationSummary(
  String id,
  String name, {
  String kind = 'llc',
  String role = 'owner',
}) => {
  'id': id,
  'short_name': name,
  'kind': kind,
  'role': role,
  'updated_at': organizationTestTime,
};

Map<String, Object?> organizationCard(String id, Map<String, Object?> data) => {
  'id': id,
  'kind': 'llc',
  'full_name': 'Учебная организация',
  'short_name': 'Учебная организация',
  'inn': '',
  'kpp': '',
  'ogrn': '',
  'legal_address': '',
  'actual_address': '',
  'leader_name': '',
  'contact_email': '',
  'contact_phone': '',
  'tax_regime': '',
  'okved': '',
  'employee_count': 0,
  'has_applicants': false,
  'activity_start_date': null,
  'privacy_responsible': '',
  'notes': '',
  ...data,
  'created_at': organizationTestTime,
  'updated_at': organizationTestTime,
  'etag': '"synthetic-organization"',
};

/// Local transport only: it never opens a network connection or uses a real account.
final class OrganizationFlowAdapter implements HttpClientAdapter {
  OrganizationFlowAdapter({bool empty = false, String role = 'owner'}) {
    if (!empty) {
      organizations.addAll([
        organizationSummary('organization-1', 'Учебная Альфа', role: role),
        organizationSummary('organization-2', 'Учебная Бета', role: role),
      ]);
    }
  }

  final delegate = fixtures.WidgetAdapter(
    schemaHash:
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
  );
  final organizations = <Map<String, Object?>>[];
  final requests = <RequestOptions>[];
  final creates = <RequestOptions>[];
  final savedByKey = <String, Map<String, Object?>>{};
  final bodiesByKey = <String, String>{};
  int validationFailures = 0;
  bool loseFirstCreateReply = false;
  bool refuseCreation = false;
  Completer<void>? holdCreate;
  Completer<void>? holdList;
  bool failList = false;
  int fnsReads = 0;
  bool failFns = false;
  int registryReads = 0;
  int registryStatus = 200;
  Completer<void>? holdRegistry;
  final registryPreview = <String, Object?>{
    'kind': 'llc',
    'inn': '1234567894',
    'ogrn': '1234567890127',
    'full_name': 'Синтетическая организация из справочника',
    'short_name': 'Учебный справочник',
    'kpp': '123401001',
    'legal_address': 'Учебный адрес без реального местоположения',
    'leader_name': 'Синтетиков Первый Учебный',
    'okved': '00.00',
  };
  Completer<void>? holdFns;
  final fnsPreview = <String, Object?>{
    'kind': 'llc',
    'inn': '1234567894',
    'ogrn': '1234567890127',
    'full_name': 'Синтетическая организация из выписки',
    'short_name': 'Учебная выписка',
    'kpp': '123401001',
    'legal_address': 'Учебный адрес без реального местоположения',
    'okved': '00.00 Учебная деятельность',
  };

  ResponseBody json(Object? value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  ResponseBody error(
    int status,
    String code,
    String message, {
    JsonMap fields = const {},
  }) => json({
    'error': {
      'code': code,
      'message': message,
      'fields': fields,
      'request_id': 'synthetic-only',
    },
  }, status: status);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.uri.path;
    if (path.endsWith('/organizations/lookup-by-inn/')) {
      if (requestStream != null) await requestStream.drain<void>();
      registryReads++;
      await holdRegistry?.future;
      return registryStatus == 200
          ? json(registryPreview)
          : error(
              registryStatus,
              'registry_unavailable',
              'Учебный сбой справочника',
            );
    }
    if (path.endsWith('/organizations/fns-extract/')) {
      if (requestStream != null) await requestStream.drain<void>();
      fnsReads++;
      await holdFns?.future;
      return failFns
          ? error(
              400,
              'validation_error',
              'Проверьте выписку.',
              fields: {
                'file': ['ИНН выписки отличается от введённого.'],
              },
            )
          : json(fnsPreview);
    }
    if (path.endsWith('/auth/organizations/')) {
      final snapshot = [
        for (final item in organizations) Map<String, Object?>.from(item),
      ];
      await holdList?.future;
      return failList
          ? error(503, 'server_unavailable', 'Учебный сбой связи')
          : json(snapshot);
    }
    if (path.endsWith('/organizations/') && options.method == 'POST') {
      if (requestStream != null) await requestStream.drain<void>();
      creates.add(options);
      await holdCreate?.future;
      if (refuseCreation) {
        return error(
          403,
          'permission_denied',
          'Организации создаёт администратор пилота.',
        );
      }
      if (validationFailures > 0) {
        validationFailures--;
        return error(
          400,
          'validation_error',
          'Проверьте ИНН.',
          fields: {
            'inn': ['ИНН: учебная ошибка проверки.'],
          },
        );
      }
      final key = options.headers['Idempotency-Key']?.toString();
      if (key == null) {
        return error(400, 'validation_error', 'Нужен ключ запроса.');
      }
      final data = Map<String, Object?>.from(options.data as Map);
      if (bodiesByKey.containsKey(key) &&
          bodiesByKey[key] != jsonEncode(data)) {
        return error(409, 'idempotency_conflict', 'Данные запроса изменены.');
      }
      if (!savedByKey.containsKey(key)) {
        final id = 'organization-created-${savedByKey.length + 1}';
        savedByKey[key] = organizationCard(id, data);
        bodiesByKey[key] = jsonEncode(data);
        organizations.add(
          organizationSummary(
            id,
            data['short_name']! as String,
            kind: data['kind']! as String,
          ),
        );
        if (loseFirstCreateReply) {
          loseFirstCreateReply = false;
          return error(
            503,
            'server_unavailable',
            'Учебный обрыв после сохранения.',
          );
        }
      }
      return json(savedByKey[key], status: 201);
    }
    final detail = RegExp(r'/organizations/([^/]+)/$').firstMatch(path);
    if (detail != null) {
      final item = organizations.where((v) => v['id'] == detail[1]).firstOrNull;
      if (item == null) return error(404, 'not_found', 'Недоступно');
      final saved = savedByKey.values
          .where((v) => v['id'] == detail[1])
          .firstOrNull;
      // Summary-only role is not part of the strict full-card API response.
      final fields = Map<String, Object?>.from(item)..remove('role');
      return json(saved ?? organizationCard(detail[1]!, fields));
    }
    return delegate.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);
}

final class OrganizationPreferences implements PreferencesStore {
  String? selected;
  bool failNextWrite = false;
  Completer<void>? holdWrite;
  Completer<void>? writeStarted;
  @override
  Future<String?> readLastOrganizationId() async => selected;
  @override
  Future<void> writeLastOrganizationId(String? value) async {
    writeStarted?.complete();
    writeStarted = null;
    await holdWrite?.future;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('Synthetic storage failure');
    }
    selected = value;
  }

  @override
  Future<void> clearSessionSelection() async {
    selected = null;
  }

  @override
  Future<bool> readBiometricEnabled() async => false;
  @override
  Future<void> writeBiometricEnabled(bool value) async {}
  @override
  Future<ThemeMode> readThemeMode() async => ThemeMode.system;
  @override
  Future<void> writeThemeMode(ThemeMode value) async {}
}
