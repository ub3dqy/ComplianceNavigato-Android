import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:compliance_navigator/core/config/app_config.dart';
import 'package:compliance_navigator/core/errors/app_error.dart';
import 'package:compliance_navigator/core/network/api_client.dart';
import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/network/compliance_repository.dart';
import 'package:compliance_navigator/core/network/sanitized_diagnostics.dart';
import 'package:compliance_navigator/core/storage/secure_session_store.dart';
import 'package:compliance_navigator/core/storage/session_revocation_marker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const String _now = '2026-08-27T12:00:00Z';
const String _hash =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

Map<String, Object?> _template() => <String, Object?>{
  'id': 'template-1',
  'code': 'privacy-policy',
  'title': 'Политика обработки',
  'version': '1',
  'baseline_version': 'PD-2026-08-25-r1',
  'reviewed_at': '2026-08-25',
};

Map<String, Object?> _version() => <String, Object?>{
  'id': 'version-1',
  'version': '1',
  'title': 'Анкета',
  'description': 'Синтетическая анкета',
  'published_at': _now,
  'questions': <Object?>[
    <String, Object?>{
      'id': 'question-1',
      'code': 'has_website',
      'section': 'Основное',
      'position': 1,
      'text': 'Есть сайт?',
      'help_text': '',
      'question_type': 'tri_state',
      'required': true,
      'critical': false,
      'options': <Object?>[],
      'condition': <String, Object?>{},
    },
  ],
};

Map<String, Object?> _questionnaire() => <String, Object?>{
  'id': 'response-1',
  'version': _version(),
  'status': 'in_progress',
  'progress_percent': 50,
  'completed_at': null,
  'answers': <Object?>[
    <String, Object?>{
      'id': 'answer-1',
      'question_code': 'has_website',
      'value': 'yes',
      'updated_at': _now,
    },
  ],
  'created_at': _now,
  'updated_at': _now,
  'etag': '"questionnaire-1"',
};

Map<String, Object?> _website() => <String, Object?>{
  'id': 'website-1',
  'url': 'https://example.invalid',
  'name': 'Тестовый сайт',
  'purpose': 'Синтетический тест',
  'is_active': true,
  'public_operator_name': 'Пилот ООО',
  'user_reports_forms': 'yes',
  'last_checked_at': _now,
  'scan_authority_confirmed': true,
  'created_at': _now,
  'updated_at': _now,
  'etag': '"website-1"',
};

Map<String, Object?> _service() => <String, Object?>{
  'id': 'service-1',
  'name': 'Тестовый сервис',
  'service_type': 'hosting',
  'purpose': 'Синтетический тест',
  'data_categories': 'Обезличенные данные',
  'recipient_entity': 'Test Entity',
  'primary_country': 'Россия',
  'additional_countries': '',
  'location_status': 'needs_review',
  'processing_agreement': 'draft',
  'terms_url': null,
  'last_checked_at': null,
  'notes': '',
  'created_at': _now,
  'updated_at': _now,
  'etag': '"service-1"',
};

Map<String, Object?> _country() => <String, Object?>{
  'id': 'country-1',
  'name': 'Россия',
  'status': 'domestic',
  'purpose': 'Синтетический тест',
  'transfer_basis': '',
  'needs_review': true,
  'created_at': _now,
  'updated_at': _now,
  'etag': '"country-1"',
};

Map<String, Object?> _assessment() => <String, Object?>{
  'id': 'assessment-1',
  'questionnaire_response_id': 'response-1',
  'assessment_as_of': _now,
  'baseline_version': 'PD-2026-08-25-r1',
  'baseline_status': 'needs_review',
  'facts_sha256': _hash,
  'snapshot_sha256': _hash,
  'applied_rules_snapshot': <Object?>[],
  'sources_snapshot': <Object?>[],
  'results': <Object?>[
    <String, Object?>{
      'id': 'result-1',
      'rule_code': 'PD-WEB-002',
      'rule_version': '1',
      'outcome': 'needs_review',
      'severity': 'medium',
      'title': 'Проверить сайт',
      'explanation': 'Нужна проверка человеком',
      'required_actions': <Object?>[],
      'used_facts': <String, Object?>{'has_website': true},
      'source_snapshot': <Object?>[
        <String, Object?>{'code': 'SRC-SYNTHETIC'},
      ],
    },
  ],
  'created_at': _now,
  'updated_at': _now,
  'etag': '"assessment-1"',
};

Map<String, Object?> _obligation() => <String, Object?>{
  'id': 'obligation-1',
  'source_assessment_id': 'assessment-1',
  'rule_code': 'PD-WEB-002',
  'title': 'Проверить политику',
  'description': 'Синтетическая обязанность',
  'status': 'needs_review',
  'severity': 'medium',
  'due_date': null,
  'due_basis': 'После проверки',
  'responsible_id': null,
  'completed_at': null,
  'completion_date': null,
  'completion_comment': '',
  'evidence_absent_confirmed': false,
  'created_at': _now,
  'updated_at': _now,
  'etag': '"obligation-1"',
};

Map<String, Object?> _task() => <String, Object?>{
  'id': 'task-1',
  'obligation_id': 'obligation-1',
  'title': 'Подготовить черновик',
  'status': 'pending',
  'due_date': null,
  'notes': '',
  'completed_at': null,
  'created_at': _now,
  'updated_at': _now,
  'etag': '"task-1"',
};

Map<String, Object?> _scan({String status = 'completed'}) => <String, Object?>{
  'id': 'scan-1',
  'website_id': 'website-1',
  'status': status,
  'requested_url': 'https://example.invalid',
  'final_url': 'https://example.invalid/',
  'pages_scanned': status == 'completed' ? 1 : 0,
  'progress_percent': status == 'completed' ? 100 : 10,
  'progress_message': status,
  'incomplete_reason': '',
  'error_summary': '',
  'queued_at': _now,
  'started_at': _now,
  'finished_at': status == 'completed' ? _now : null,
  'retry_count': 0,
  'findings': <Object?>[
    if (status == 'completed')
      <String, Object?>{
        'id': 'finding-1',
        'code': 'FORM-REVIEW',
        'title': 'Проверить форму',
        'description': 'Синтетическая находка требует проверки.',
        'page_url': 'https://example.invalid/',
        'dom_context': 'form',
        'evidence_snippet': '<form>',
        'confidence': 'high',
        'needs_review': true,
      },
  ],
  'pages': <Object?>[
    if (status == 'completed')
      <String, Object?>{
        'id': 'page-1',
        'url': 'https://example.invalid',
        'final_url': 'https://example.invalid/',
        'status_code': 200,
        'content_bytes': 100,
        'is_https': true,
        'forms_count': 1,
        'external_domains': <Object?>['assets.example.invalid'],
      },
  ],
  'updated_at': _now,
  'etag': '"scan-1"',
};

Map<String, Object?> _document() => <String, Object?>{
  'id': 'document-1',
  'template': _template(),
  'baseline_version': 'PD-2026-08-25-r1',
  'sha256': _hash,
  'status': 'completed',
  'download_urls': <String, String>{
    'html': '/api/v1/organizations/organization-1/documents/document-1/download/html/',
    'docx': '/api/v1/organizations/organization-1/documents/document-1/download/docx/',
  },
  'created_at': _now,
  'updated_at': _now,
  'etag': '"document-1"',
};

Map<String, Object?> _evidence() => <String, Object?>{
  'id': 'evidence-1',
  'obligation_id': 'obligation-1',
  'title': 'Синтетическое подтверждение',
  'original_name': 'pilot.txt',
  'extension': '.txt',
  'mime_type': 'text/plain',
  'size_bytes': 5,
  'sha256': _hash,
  'download_url':
      '/api/v1/organizations/organization-1/evidence/evidence-1/download/',
  'created_at': _now,
  'updated_at': _now,
  'etag': '"evidence-1"',
};

Map<String, Object?> _conversation() => <String, Object?>{
  'id': 'conversation-1',
  'organization_id': 'organization-1',
  'title': 'Синтетический разговор',
  'status': 'active',
  'created_at': _now,
  'updated_at': _now,
  'messages': <Object?>[],
};

Map<String, Object?> _aiRequest({
  String status = 'completed',
}) => <String, Object?>{
  'id': 'request-1',
  'conversation_id': 'conversation-1',
  'status': status,
  'provider': 'codex_subscription',
  'execution_mode': 'live_subscription',
  'requested_model': 'gpt-5.6-terra',
  'selected_model': 'gpt-5.6-terra',
  'actual_model': 'gpt-5.6-terra',
  'fallback_used': false,
  'reroute': <String, Object?>{},
  'rate_limit_state': <String, Object?>{'state': 'available', 'resetAt': null},
  'context': <String, Object?>{},
  'result': <String, Object?>{
    'answer': 'Синтетическое объяснение',
    'cited_source_codes': <String>['SRC-SYNTHETIC'],
    'used_rule_codes': <String>['PD-WEB-002'],
    'uncertainties': <String>['Требуется проверка'],
    'requires_human_review': true,
    'safety_flags': <String>['synthetic_only'],
    'proposals': <Object?>[
      <String, Object?>{
        'id': 'proposal-1',
        'field': 'draft_wording',
        'value': 'Новый текст',
        'previous_value': 'Старый текст',
        'reason': 'Синтетическое предложение',
        'status': 'pending',
      },
    ],
  },
  'safe_error': null,
  'telemetry': <String, Object?>{
    'input_tokens': 10,
    'output_tokens': 20,
    'total_tokens': 30,
  },
  'sanitization': <String, Object?>{},
  'created_at': _now,
  'updated_at': _now,
  'etag': '"request-1"',
};

final class LocalFakeApiAdapter implements HttpClientAdapter {
  LocalFakeApiAdapter({
    this.sseEvents,
    this.beforeResponse,
    this.evidenceUnauthorizedOnce = false,
    this.drainRequestBodies = true,
  });

  final String? sseEvents;
  final Future<void> Function(RequestOptions options)? beforeResponse;
  final bool evidenceUnauthorizedOnce;
  final bool drainRequestBodies;
  int loginCalls = 0;
  int refreshCalls = 0;
  int evidenceUploadCalls = 0;
  final List<RequestOptions> requests = <RequestOptions>[];

  ResponseBody _json(Object? value, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode(value),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
          'etag': <String>['"fake-etag"'],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // A real HTTP server consumes the complete request body before replying.
    // Draining it also exercises Dio upload progress and releases file handles.
    if (drainRequestBodies && requestStream != null) {
      await requestStream.drain<void>();
    }
    requests.add(options);
    await beforeResponse?.call(options);
    final String path = options.uri.path;
    if (path.contains('/organizations/organization-2/')) {
      return _json(<String, Object?>{'detail': 'Недоступно'}, status: 404);
    }
    if (path.endsWith('/events/stream/')) {
      const String defaultEvents =
          'id: 1\nevent: delta\ndata: {"text":"Синтетическое"}\n\n'
          ': heartbeat\n\n'
          'id: 2\nevent: completed\ndata: {"status":"completed"}\n\n'
          'event: close\ndata: {"status":"completed"}\n\n';
      final String events = sseEvents ?? defaultEvents;
      return ResponseBody(
        Stream<Uint8List>.value(Uint8List.fromList(utf8.encode(events))),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/event-stream'],
        },
      );
    }
    if (options.responseType == ResponseType.bytes) {
      return ResponseBody(
        Stream<Uint8List>.value(Uint8List.fromList(utf8.encode('pilot'))),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/plain'],
          'content-disposition': <String>['attachment; filename="pilot.txt"'],
        },
      );
    }
    if (path.endsWith('/health/')) {
      return _json(<String, Object?>{
        'status': 'ok',
        'api_version': '1.0.0',
        'schema_sha256': _hash,
      });
    }
    if (path.endsWith('/auth/login/')) {
      loginCalls += 1;
      if (loginCalls == 1) {
        return _json(<String, Object?>{
          'challenge': 'mfa_required',
          'methods': <String>['totp', 'recovery_code'],
        }, status: 202);
      }
      return _json(<String, Object?>{
        'access': 'integration-access',
        'refresh': 'integration-refresh',
        'access_expires_in': 300,
        'refresh_expires_in': 86400,
        'token_type': 'Bearer',
      });
    }
    if (path.endsWith('/auth/refresh/')) {
      refreshCalls += 1;
      return _json(<String, Object?>{
        'access': 'rotated-access',
        'refresh': 'rotated-refresh',
      });
    }
    if (path.endsWith('/auth/me/')) {
      return _json(<String, Object?>{
        'id': 'user-1',
        'email': 'pilot@example.invalid',
        'is_staff': false,
        'is_superuser': false,
        'mfa_enabled': true,
      });
    }
    if (path.endsWith('/auth/organizations/')) {
      return _json(<Object?>[
        <String, Object?>{
          'id': 'organization-1',
          'short_name': 'Пилот ООО',
          'kind': 'llc',
          'role': 'owner',
          'updated_at': _now,
        },
      ]);
    }
    if (path.endsWith('/organizations/organization-1/')) {
      return _json(<String, Object?>{
        'id': 'organization-1',
        'kind': 'llc',
        'full_name': 'Вымышленная организация',
        'short_name': 'Пилот ООО',
        'inn': '0000000000',
        'kpp': '000000000',
        'ogrn': '0000000000000',
        'legal_address': 'Вымышленный адрес',
        'actual_address': 'Вымышленный адрес',
        'leader_name': 'Тестовый руководитель',
        'contact_email': null,
        'contact_phone': '',
        'tax_regime': 'test',
        'okved': '00.00',
        'employee_count': 0,
        'has_applicants': false,
        'activity_start_date': null,
        'privacy_responsible': 'Тестовая роль',
        'notes': '',
        'created_at': _now,
        'updated_at': _now,
        'etag': '"organization-1"',
      });
    }
    if (path.endsWith('/memberships/')) {
      return _json(<Object?>[
        <String, Object?>{
          'id': 'membership-1',
          'user_id': 'user-1',
          'email': 'pilot@example.invalid',
          'role': 'owner',
          'created_at': _now,
          'updated_at': _now,
          'etag': '"membership-1"',
        },
      ]);
    }
    if (path.endsWith('/websites/website-1/') || path.endsWith('/websites/')) {
      return _json(
        options.method == 'GET' && path.endsWith('/websites/')
            ? <Object?>[_website()]
            : _website(),
      );
    }
    if (path.endsWith('/external-services/')) {
      return _json(
        options.method == 'GET' ? <Object?>[_service()] : _service(),
      );
    }
    if (path.endsWith('/countries/')) {
      return _json(
        options.method == 'GET' ? <Object?>[_country()] : _country(),
      );
    }
    if (path.endsWith('/questionnaires/current/')) {
      return _json(
        options.method == 'GET'
            ? <String, Object?>{
                'response': _questionnaire(),
                'version': _version(),
              }
            : _questionnaire(),
      );
    }
    if (path.contains('/questionnaires/response-1/')) {
      return _json(_questionnaire());
    }
    if (path.endsWith('/assessments/')) {
      return _json(
        options.method == 'GET' ? <Object?>[_assessment()] : _assessment(),
      );
    }
    if (path.endsWith('/obligations/')) return _json(<Object?>[_obligation()]);
    if (path.contains('/obligations/obligation-1/')) {
      return _json(_obligation());
    }
    if (path.endsWith('/checklist/')) return _json(<Object?>[_task()]);
    if (path.contains('/checklist/task-1/')) return _json(_task());
    if (path.endsWith('/scan-jobs/')) {
      return _json(
        options.method == 'GET' ? <Object?>[_scan()] : _scan(status: 'queued'),
      );
    }
    if (path.endsWith('/scan-jobs/scan-1/cancel/')) {
      return _json(_scan(status: 'cancelled'));
    }
    if (path.endsWith('/scan-jobs/scan-1/')) return _json(_scan());
    if (path.endsWith('/document-templates/')) {
      return _json(<Object?>[_template()]);
    }
    if (path.endsWith('/documents/')) {
      return _json(
        options.method == 'GET' ? <Object?>[_document()] : _document(),
      );
    }
    if (path.endsWith('/evidence/')) {
      if (options.method == 'POST') {
        evidenceUploadCalls += 1;
        if (evidenceUnauthorizedOnce && evidenceUploadCalls == 1) {
          return _json(<String, Object?>{
            'error': <String, Object?>{'code': 'authentication_required'},
          }, status: 401);
        }
      }
      return _json(
        options.method == 'GET' ? <Object?>[_evidence()] : _evidence(),
      );
    }
    if (path.endsWith('/reports/current/')) {
      return _json(<String, Object?>{
        'status': 'needs_review',
        'baseline_version': 'PD-2026-08-25-r1',
      });
    }
    if (path.endsWith('/audit-events/page/')) {
      return _json(<String, Object?>{
        'results': <Object?>[
          <String, Object?>{
            'id': 'audit-1',
            'actor_id': 'user-1',
            'event_type': 'pilot.test',
            'object_type': 'organization',
            'object_id': 'organization-1',
            'summary': 'Синтетическое событие',
            'metadata': <String, Object?>{
              'scope': 'synthetic',
              'token_hint': 'must-not-render',
            },
            'created_at': _now,
          },
        ],
        'next_cursor': null,
      });
    }
    if (path.endsWith('/ai/conversations/')) {
      return _json(
        options.method == 'GET' ? <Object?>[_conversation()] : _conversation(),
      );
    }
    if (path.endsWith('/ai/conversations/conversation-1/')) {
      return _json(_conversation());
    }
    if (path.endsWith('/messages/')) {
      return _json(_aiRequest(status: 'queued'), status: 202);
    }
    if (path.endsWith('/messages/request-1/')) return _json(_aiRequest());
    if (path.endsWith('/messages/request-1/cancel/')) {
      return _json(_aiRequest(status: 'cancelled'));
    }
    if (path.endsWith('/messages/request-1/retry/')) {
      return _json(_aiRequest(status: 'queued'), status: 202);
    }
    return _json(<String, Object?>{});
  }

  @override
  void close({bool force = false}) {}
}

Future<void> runPilotRepositoryFlow() async {
  final AppConfig config = AppConfig.validate(const <String, String>{
    'APP_ENV': 'staging',
    'API_BASE_URL': 'https://compliance-pilot.ms777.ru',
    'OPENAI_API_ENABLED': 'false',
    'AI_PROVIDER_AUTO_SWITCH': 'false',
    'GIT_COMMIT_SHA': 'integration-test',
    'API_SCHEMA_SHA256': _hash,
  });
  final MemorySessionStore store = MemorySessionStore();
  final LocalFakeApiAdapter adapter = LocalFakeApiAdapter();
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUri.toString(),
      validateStatus: (int? status) => status != null && status < 300,
    ),
  )..httpClientAdapter = adapter;
  final ApiClient client = ApiClient(
    config: config,
    sessionStore: store,
    sessionRevocationMarker: MemorySessionRevocationMarker(),
    diagnostics: SanitizedDiagnostics(),
    dio: dio,
    refreshDio: dio,
  );
  final ComplianceRepository repository = ComplianceRepository(
    client: client,
    sessionStore: store,
    config: config,
  );

  expect((await repository.health()).status, 'ok');
  expect(
    await repository.login(
      email: ' pilot@example.invalid ',
      password: 'test', // pragma: allowlist secret
    ),
    isA<MfaRequired>(),
  );
  expect(
    await repository.login(
      email: 'pilot@example.invalid',
      password: 'test', // pragma: allowlist secret
      mfaCode: 'recovery-code',
    ),
    isA<LoginSucceeded>(),
  );
  await repository.restoreSession();
  expect(adapter.refreshCalls, 1);
  expect(await store.readRefreshToken(), 'rotated-refresh');
  expect((await repository.currentUser()).mfaEnabled, isTrue);
  expect((await repository.organizations()).single.role, 'owner');
  expect(
    (await repository.organization('organization-1')).shortName,
    'Пилот ООО',
  );
  expect((await repository.memberships('organization-1')).single.role, 'owner');
  await expectLater(
    repository.organization('organization-2'),
    throwsA(isA<AppError>()),
  );

  expect((await repository.dashboard('organization-1')).tasks, hasLength(1));
  final WebsiteDto website = (await repository.websites('organization-1'))
      .single;
  await repository.createWebsite('organization-1', <String, Object?>{
    'url': website.url,
  });
  await repository.updateWebsite(
    'organization-1',
    website.id,
    <String, Object?>{'name': 'Новое'},
    website.etag,
  );
  await repository.deleteWebsite('organization-1', website);
  expect(
    (await repository.services('organization-1')).single.locationStatus,
    'needs_review',
  );
  await repository.createService('organization-1', <String, Object?>{
    'name': 'Тест',
  });
  expect(
    (await repository.countries('organization-1')).single.needsReview,
    isTrue,
  );
  await repository.createCountry('organization-1', <String, Object?>{
    'name': 'Россия',
  });

  final CurrentQuestionnaireDto current = await repository.currentQuestionnaire(
    'organization-1',
  );
  await repository.startQuestionnaire('organization-1');
  await repository.saveQuestionnaire(
    organizationId: 'organization-1',
    response: current.response!,
    answers: <String, Object?>{'has_website': 'yes'},
    complete: false,
  );
  expect(
    (await repository.runAssessment(
      'organization-1',
      current.response!.id,
    )).results,
    isNotEmpty,
  );
  final ObligationDto obligation = (await repository.obligations(
    'organization-1',
  )).single;
  await repository.updateObligation(
    'organization-1',
    obligation,
    <String, Object?>{'status': 'done'},
  );
  final ChecklistItemDto task = (await repository.checklist('organization-1'))
      .single;
  await repository.updateTask('organization-1', task, <String, Object?>{
    'status': 'done',
  });

  final SiteScanDto queued = await repository.createScan(
    'organization-1',
    website.id,
  );
  expect(queued.status, 'queued');
  expect(
    (await repository.scan('organization-1', queued.id)).status,
    'completed',
  );
  expect(
    (await repository.cancelScan('organization-1', queued)).status,
    'cancelled',
  );
  expect(await repository.documentTemplates('organization-1'), isNotEmpty);
  expect(await repository.documents('organization-1'), isNotEmpty);
  expect(
    (await repository.generateDocument('organization-1', 'template-1')).status,
    'completed',
  );

  final Directory uploadDirectory = await Directory.systemTemp.createTemp(
    'compliance-pilot-test-',
  );
  final File file = File(
    '${uploadDirectory.path}${Platform.pathSeparator}pilot.txt',
  );
  await file.writeAsString('pilot');
  addTearDown(() async {
    if (await uploadDirectory.exists()) {
      await uploadDirectory.delete(recursive: true);
    }
  });
  final List<(int, int)> uploadProgress = <(int, int)>[];
  final int requestsBeforeDeniedUpload = adapter.requests.length;
  await expectLater(
    repository.uploadEvidence(
      organizationId: 'organization-1',
      title: 'Без подтверждения',
      filePath: file.path,
      fileName: 'pilot.txt',
      processingAuthorizedConfirmed: false,
      onProgress: (_, _) {},
    ),
    throwsArgumentError,
  );
  expect(adapter.requests.length, requestsBeforeDeniedUpload);
  final EvidenceDto evidence = await repository.uploadEvidence(
    organizationId: 'organization-1',
    title: 'Синтетическое подтверждение',
    filePath: file.path,
    fileName: 'pilot.txt',
    processingAuthorizedConfirmed: true,
    obligationId: obligation.id,
    onProgress: (int sent, int total) => uploadProgress.add((sent, total)),
  );
  expect(uploadProgress, isNotEmpty);
  expect(uploadProgress.last.$1, uploadProgress.last.$2);
  final FormData uploadData = adapter.requests.last.data as FormData;
  expect(
    Map.fromEntries(uploadData.fields),
    containsPair('processing_authorized_confirmed', 'true'),
  );
  expect(
    uploadData.fields.any(
      (entry) => entry.key == 'personal_data_removed_confirmed',
    ),
    isFalse,
  );
  expect(await repository.evidence('organization-1'), isNotEmpty);
  expect((await repository.download(evidence.downloadUrl)).bytes, isNotEmpty);
  await repository.deleteEvidence('organization-1', evidence);
  expect(
    await repository.currentReport('organization-1'),
    contains('baseline_version'),
  );
  expect((await repository.auditPage('organization-1')).results, hasLength(1));

  final AiConversationDto conversation = await repository.createConversation(
    'organization-1',
    'Синтетический разговор',
  );
  expect(await repository.conversations('organization-1'), isNotEmpty);
  await repository.conversation('organization-1', conversation.id);
  final AiRequestDto request = await repository.sendAiMessage(
    organizationId: 'organization-1',
    conversationId: conversation.id,
    message: 'Объясни результат без изменения данных',
  );
  final events = await repository
      .streamAiEvents(
        organizationId: 'organization-1',
        conversationId: conversation.id,
        requestId: request.id,
      )
      .toList();
  expect(
    events.map((event) => event.type),
    containsAll(<String>['delta', 'completed', 'close']),
  );
  final AiRequestDto completed = await repository.aiRequest(
    'organization-1',
    conversation.id,
    request.id,
  );
  expect(completed.actualModel, 'gpt-5.6-terra');
  await repository.cancelAi('organization-1', conversation.id, completed);
  await repository.retryAi('organization-1', conversation.id, completed);
  await repository.decideProposal(
    organizationId: 'organization-1',
    conversationId: conversation.id,
    requestId: completed.id,
    proposalId: 'proposal-1',
    apply: false,
    etag: completed.etag,
  );
  await repository.submitFeedback(
    organizationId: 'organization-1',
    conversationId: conversation.id,
    requestId: completed.id,
    rating: 'needs_review',
  );

  await repository.logout();
  expect(await store.readRefreshToken(), isNull);
}
