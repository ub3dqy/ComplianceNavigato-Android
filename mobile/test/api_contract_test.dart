import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readSchema(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Set<String> _strings(Object? value) =>
    (value as List<dynamic>).whereType<String>().toSet();

void main() {
  const String snapshotPath = 'contracts/openapi-v1.json';
  const String digestPath = 'contracts/openapi-v1.sha256';
  const String repositoryPath = '../docs/api/openapi-v1.json';

  test('the mobile snapshot exactly matches the repository API contract', () {
    final String expected = File(digestPath).readAsStringSync().trim();
    final List<int> snapshot = File(snapshotPath).readAsBytesSync();
    final List<int> repository = File(repositoryPath).readAsBytesSync();

    expect(sha256.convert(snapshot).toString(), expected);
    expect(sha256.convert(repository).toString(), expected);
    expect(repository, orderedEquals(snapshot));
  });

  test('all pilot-critical API paths remain explicit', () {
    final Map<String, dynamic> schema = _readSchema(snapshotPath);
    final Map<String, dynamic> paths = schema['paths'] as Map<String, dynamic>;
    const Set<String> requiredPaths = <String>{
      '/api/v1/health/',
      '/api/v1/auth/login/',
      '/api/v1/auth/refresh/',
      '/api/v1/auth/logout/',
      '/api/v1/auth/me/',
      '/api/v1/organizations/',
      '/api/v1/organizations/lookup-by-inn/',
      '/api/v1/organizations/{organization_id}/questionnaires/current/',
      '/api/v1/organizations/{organization_id}/assessments/',
      '/api/v1/organizations/{organization_id}/scan-jobs/',
      '/api/v1/organizations/{organization_id}/documents/',
      '/api/v1/organizations/{organization_id}/evidence/',
      '/api/v1/organizations/{organization_id}/reports/current/download/{report_format}/',
      '/api/v1/organizations/{organization_id}/audit-events/page/',
      '/api/v1/organizations/{organization_id}/ai/conversations/',
      '/api/v1/organizations/{organization_id}/ai/conversations/{conversation_id}/messages/{request_id}/events/stream/',
      '/api/v1/organizations/{organization_id}/ai/conversations/{conversation_id}/messages/{request_id}/retry/',
    };

    expect(paths.keys.toSet(), containsAll(requiredPaths));
  });

  test('critical request and response fields cannot disappear silently', () {
    final Map<String, dynamic> schema = _readSchema(snapshotPath);
    final Map<String, dynamic> components =
        schema['components'] as Map<String, dynamic>;
    final Map<String, dynamic> schemas =
        components['schemas'] as Map<String, dynamic>;
    final Map<String, Set<String>> required = <String, Set<String>>{
      'RegistryRequestRequest': <String>{'inn'},
      'RegistryPreview': <String>{
        'kind',
        'inn',
        'ogrn',
        'full_name',
        'short_name',
        'kpp',
        'legal_address',
        'leader_name',
        'okved',
      },
      'LoginRequest': <String>{'email', 'password'},
      'TokenPairResponse': <String>{
        'access',
        'refresh',
        'access_expires_in',
        'refresh_expires_in',
        'token_type',
      },
      'MFAChallengeResponse': <String>{'challenge', 'methods'},
      'CurrentOrganizationResponse': <String>{
        'id',
        'short_name',
        'kind',
        'role',
        'updated_at',
      },
      'CurrentQuestionnaireResponse': <String>{'response', 'version'},
      'AIRequestResponse': <String>{
        'id',
        'status',
        'requested_model',
        'selected_model',
        'actual_model',
        'fallback_used',
        'reroute',
        'result',
        'telemetry',
        'etag',
      },
      'Evidence': <String>{
        'id',
        'original_name',
        'mime_type',
        'size_bytes',
        'sha256',
        'download_url',
        'etag',
      },
    };

    for (final MapEntry<String, Set<String>> entry in required.entries) {
      final Map<String, dynamic> definition =
          schemas[entry.key] as Map<String, dynamic>;
      expect(
        _strings(definition['required']),
        containsAll(entry.value),
        reason: '${entry.key} lost a mobile-critical required field',
      );
    }

    final Map<String, dynamic> login =
        paths(schema)['/api/v1/auth/login/'] as Map<String, dynamic>;
    final Map<String, dynamic> responses =
        (login['post'] as Map<String, dynamic>)['responses']
            as Map<String, dynamic>;
    expect(responses.keys.toSet(), containsAll(<String>{'200', '202'}));
  });
}

Map<String, dynamic> paths(Map<String, dynamic> schema) =>
    schema['paths'] as Map<String, dynamic>;
