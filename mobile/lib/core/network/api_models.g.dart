// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ApiHealthDto _$ApiHealthDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ApiHealthDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const ['status', 'api_version', 'schema_sha256'],
        );
        final val = ApiHealthDto(
          status: $checkedConvert('status', (v) => v as String),
          apiVersion: $checkedConvert('api_version', (v) => v as String),
          schemaSha256: $checkedConvert('schema_sha256', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'apiVersion': 'api_version',
        'schemaSha256': 'schema_sha256',
      },
    );

TokenPairDto _$TokenPairDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TokenPairDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'access',
            'refresh',
            'access_expires_in',
            'refresh_expires_in',
            'token_type',
          ],
        );
        final val = TokenPairDto(
          access: $checkedConvert('access', (v) => v as String),
          refresh: $checkedConvert('refresh', (v) => v as String),
          accessExpiresIn: $checkedConvert(
            'access_expires_in',
            (v) => (v as num).toInt(),
          ),
          refreshExpiresIn: $checkedConvert(
            'refresh_expires_in',
            (v) => (v as num).toInt(),
          ),
          tokenType: $checkedConvert('token_type', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'accessExpiresIn': 'access_expires_in',
        'refreshExpiresIn': 'refresh_expires_in',
        'tokenType': 'token_type',
      },
    );

RefreshDto _$RefreshDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RefreshDto', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['access', 'refresh']);
      final val = RefreshDto(
        access: $checkedConvert('access', (v) => v as String),
        refresh: $checkedConvert('refresh', (v) => v as String),
      );
      return val;
    });

CurrentUserDto _$CurrentUserDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CurrentUserDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'email',
            'is_staff',
            'is_superuser',
            'mfa_enabled',
          ],
        );
        final val = CurrentUserDto(
          id: $checkedConvert('id', (v) => v as String),
          email: $checkedConvert('email', (v) => v as String),
          isStaff: $checkedConvert('is_staff', (v) => v as bool),
          isSuperuser: $checkedConvert('is_superuser', (v) => v as bool),
          mfaEnabled: $checkedConvert('mfa_enabled', (v) => v as bool),
        );
        return val;
      },
      fieldKeyMap: const {
        'isStaff': 'is_staff',
        'isSuperuser': 'is_superuser',
        'mfaEnabled': 'mfa_enabled',
      },
    );

OrganizationSummaryDto _$OrganizationSummaryDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('OrganizationSummaryDto', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const ['id', 'short_name', 'kind', 'role', 'updated_at'],
  );
  final val = OrganizationSummaryDto(
    id: $checkedConvert('id', (v) => v as String),
    shortName: $checkedConvert('short_name', (v) => v as String),
    kind: $checkedConvert('kind', (v) => v as String),
    role: $checkedConvert('role', (v) => v as String),
    updatedAt: $checkedConvert(
      'updated_at',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
}, fieldKeyMap: const {'shortName': 'short_name', 'updatedAt': 'updated_at'});

RegistryPreviewDto _$RegistryPreviewDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RegistryPreviewDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'kind',
            'inn',
            'ogrn',
            'full_name',
            'short_name',
            'kpp',
            'legal_address',
            'leader_name',
            'okved',
          ],
        );
        final val = RegistryPreviewDto(
          kind: $checkedConvert('kind', (v) => v as String),
          inn: $checkedConvert('inn', (v) => v as String),
          ogrn: $checkedConvert('ogrn', (v) => v as String),
          fullName: $checkedConvert('full_name', (v) => v as String),
          shortName: $checkedConvert('short_name', (v) => v as String),
          kpp: $checkedConvert('kpp', (v) => v as String?),
          legalAddress: $checkedConvert('legal_address', (v) => v as String?),
          leaderName: $checkedConvert('leader_name', (v) => v as String?),
          okved: $checkedConvert('okved', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'fullName': 'full_name',
        'shortName': 'short_name',
        'legalAddress': 'legal_address',
        'leaderName': 'leader_name',
      },
    );

FnsExtractPreviewDto _$FnsExtractPreviewDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'FnsExtractPreviewDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'kind',
        'inn',
        'ogrn',
        'full_name',
        'short_name',
        'kpp',
        'legal_address',
        'okved',
      ],
    );
    final val = FnsExtractPreviewDto(
      kind: $checkedConvert('kind', (v) => v as String),
      inn: $checkedConvert('inn', (v) => v as String),
      ogrn: $checkedConvert('ogrn', (v) => v as String),
      fullName: $checkedConvert('full_name', (v) => v as String?),
      shortName: $checkedConvert('short_name', (v) => v as String?),
      kpp: $checkedConvert('kpp', (v) => v as String?),
      legalAddress: $checkedConvert('legal_address', (v) => v as String?),
      okved: $checkedConvert('okved', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'fullName': 'full_name',
    'shortName': 'short_name',
    'legalAddress': 'legal_address',
  },
);

OrganizationDto _$OrganizationDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OrganizationDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'kind',
            'full_name',
            'short_name',
            'inn',
            'kpp',
            'ogrn',
            'legal_address',
            'actual_address',
            'leader_name',
            'contact_email',
            'contact_phone',
            'tax_regime',
            'okved',
            'employee_count',
            'has_applicants',
            'activity_start_date',
            'privacy_responsible',
            'notes',
            'created_at',
            'updated_at',
            'etag',
          ],
        );
        final val = OrganizationDto(
          id: $checkedConvert('id', (v) => v as String),
          kind: $checkedConvert('kind', (v) => v as String),
          fullName: $checkedConvert('full_name', (v) => v as String),
          shortName: $checkedConvert('short_name', (v) => v as String),
          inn: $checkedConvert('inn', (v) => v as String),
          kpp: $checkedConvert('kpp', (v) => v as String),
          ogrn: $checkedConvert('ogrn', (v) => v as String),
          legalAddress: $checkedConvert('legal_address', (v) => v as String),
          actualAddress: $checkedConvert('actual_address', (v) => v as String),
          leaderName: $checkedConvert('leader_name', (v) => v as String),
          contactEmail: $checkedConvert('contact_email', (v) => v as String?),
          contactPhone: $checkedConvert('contact_phone', (v) => v as String),
          taxRegime: $checkedConvert('tax_regime', (v) => v as String),
          okved: $checkedConvert('okved', (v) => v as String),
          employeeCount: $checkedConvert(
            'employee_count',
            (v) => (v as num).toInt(),
          ),
          hasApplicants: $checkedConvert('has_applicants', (v) => v as bool),
          activityStartDate: $checkedConvert(
            'activity_start_date',
            (v) => v as String?,
          ),
          privacyResponsible: $checkedConvert(
            'privacy_responsible',
            (v) => v as String,
          ),
          notes: $checkedConvert('notes', (v) => v as String),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
          etag: $checkedConvert('etag', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'fullName': 'full_name',
        'shortName': 'short_name',
        'legalAddress': 'legal_address',
        'actualAddress': 'actual_address',
        'leaderName': 'leader_name',
        'contactEmail': 'contact_email',
        'contactPhone': 'contact_phone',
        'taxRegime': 'tax_regime',
        'employeeCount': 'employee_count',
        'hasApplicants': 'has_applicants',
        'activityStartDate': 'activity_start_date',
        'privacyResponsible': 'privacy_responsible',
        'createdAt': 'created_at',
        'updatedAt': 'updated_at',
      },
    );

MembershipDto _$MembershipDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MembershipDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'user_id',
            'email',
            'role',
            'created_at',
            'updated_at',
            'etag',
          ],
        );
        final val = MembershipDto(
          id: $checkedConvert('id', (v) => v as String),
          userId: $checkedConvert('user_id', (v) => v as String),
          email: $checkedConvert('email', (v) => v as String),
          role: $checkedConvert('role', (v) => v as String),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
          etag: $checkedConvert('etag', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'userId': 'user_id',
        'createdAt': 'created_at',
        'updatedAt': 'updated_at',
      },
    );

WebsiteDto _$WebsiteDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'WebsiteDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'url',
        'name',
        'purpose',
        'is_active',
        'public_operator_name',
        'user_reports_forms',
        'last_checked_at',
        'scan_authority_confirmed',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = WebsiteDto(
      id: $checkedConvert('id', (v) => v as String),
      url: $checkedConvert('url', (v) => v as String),
      name: $checkedConvert('name', (v) => v as String),
      purpose: $checkedConvert('purpose', (v) => v as String),
      isActive: $checkedConvert('is_active', (v) => v as bool),
      publicOperatorName: $checkedConvert(
        'public_operator_name',
        (v) => v as String,
      ),
      userReportsForms: $checkedConvert(
        'user_reports_forms',
        (v) => v as String,
      ),
      lastCheckedAt: $checkedConvert(
        'last_checked_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      scanAuthorityConfirmed: $checkedConvert(
        'scan_authority_confirmed',
        (v) => v as bool,
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'isActive': 'is_active',
    'publicOperatorName': 'public_operator_name',
    'userReportsForms': 'user_reports_forms',
    'lastCheckedAt': 'last_checked_at',
    'scanAuthorityConfirmed': 'scan_authority_confirmed',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

ExternalServiceDto _$ExternalServiceDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ExternalServiceDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'name',
        'service_type',
        'purpose',
        'data_categories',
        'recipient_entity',
        'primary_country',
        'additional_countries',
        'location_status',
        'processing_agreement',
        'terms_url',
        'last_checked_at',
        'notes',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = ExternalServiceDto(
      id: $checkedConvert('id', (v) => v as String),
      name: $checkedConvert('name', (v) => v as String),
      serviceType: $checkedConvert('service_type', (v) => v as String),
      purpose: $checkedConvert('purpose', (v) => v as String),
      dataCategories: $checkedConvert('data_categories', (v) => v as String),
      recipientEntity: $checkedConvert('recipient_entity', (v) => v as String),
      primaryCountry: $checkedConvert('primary_country', (v) => v as String),
      additionalCountries: $checkedConvert(
        'additional_countries',
        (v) => v as String,
      ),
      locationStatus: $checkedConvert('location_status', (v) => v as String),
      processingAgreement: $checkedConvert(
        'processing_agreement',
        (v) => v as String,
      ),
      termsUrl: $checkedConvert('terms_url', (v) => v as String?),
      lastCheckedAt: $checkedConvert('last_checked_at', (v) => v as String?),
      notes: $checkedConvert('notes', (v) => v as String),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'serviceType': 'service_type',
    'dataCategories': 'data_categories',
    'recipientEntity': 'recipient_entity',
    'primaryCountry': 'primary_country',
    'additionalCountries': 'additional_countries',
    'locationStatus': 'location_status',
    'processingAgreement': 'processing_agreement',
    'termsUrl': 'terms_url',
    'lastCheckedAt': 'last_checked_at',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

ProcessingCountryDto _$ProcessingCountryDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'ProcessingCountryDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'name',
        'status',
        'purpose',
        'transfer_basis',
        'needs_review',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = ProcessingCountryDto(
      id: $checkedConvert('id', (v) => v as String),
      name: $checkedConvert('name', (v) => v as String),
      status: $checkedConvert('status', (v) => v as String),
      purpose: $checkedConvert('purpose', (v) => v as String),
      transferBasis: $checkedConvert('transfer_basis', (v) => v as String),
      needsReview: $checkedConvert('needs_review', (v) => v as bool),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'transferBasis': 'transfer_basis',
    'needsReview': 'needs_review',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

QuestionOptionDto _$QuestionOptionDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('QuestionOptionDto', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['value', 'label']);
      final val = QuestionOptionDto(
        value: $checkedConvert('value', (v) => v as String),
        label: $checkedConvert('label', (v) => v as String),
      );
      return val;
    });

QuestionDto _$QuestionDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'QuestionDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'code',
        'section',
        'position',
        'text',
        'help_text',
        'question_type',
        'required',
        'critical',
        'options',
        'condition',
      ],
    );
    final val = QuestionDto(
      id: $checkedConvert('id', (v) => v as String),
      code: $checkedConvert('code', (v) => v as String),
      section: $checkedConvert('section', (v) => v as String),
      position: $checkedConvert('position', (v) => (v as num).toInt()),
      text: $checkedConvert('text', (v) => v as String),
      helpText: $checkedConvert('help_text', (v) => v as String),
      questionType: $checkedConvert('question_type', (v) => v as String),
      required: $checkedConvert('required', (v) => v as bool),
      critical: $checkedConvert('critical', (v) => v as bool),
      options: $checkedConvert(
        'options',
        (v) => (v as List<dynamic>)
            .map((e) => QuestionOptionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      condition: $checkedConvert('condition', (v) => v as Map<String, dynamic>),
    );
    return val;
  },
  fieldKeyMap: const {'helpText': 'help_text', 'questionType': 'question_type'},
);

QuestionnaireVersionDto _$QuestionnaireVersionDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('QuestionnaireVersionDto', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const [
      'id',
      'version',
      'title',
      'description',
      'published_at',
      'questions',
    ],
  );
  final val = QuestionnaireVersionDto(
    id: $checkedConvert('id', (v) => v as String),
    version: $checkedConvert('version', (v) => v as String),
    title: $checkedConvert('title', (v) => v as String),
    description: $checkedConvert('description', (v) => v as String),
    publishedAt: $checkedConvert(
      'published_at',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
    questions: $checkedConvert(
      'questions',
      (v) => (v as List<dynamic>)
          .map((e) => QuestionDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
}, fieldKeyMap: const {'publishedAt': 'published_at'});

AnswerDto _$AnswerDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AnswerDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const ['id', 'question_code', 'value', 'updated_at'],
    );
    final val = AnswerDto(
      id: $checkedConvert('id', (v) => v as String),
      questionCode: $checkedConvert('question_code', (v) => v as String),
      value: $checkedConvert('value', (v) => v),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'questionCode': 'question_code',
    'updatedAt': 'updated_at',
  },
);

QuestionnaireResponseDto _$QuestionnaireResponseDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'QuestionnaireResponseDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'version',
        'status',
        'progress_percent',
        'completed_at',
        'answers',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = QuestionnaireResponseDto(
      id: $checkedConvert('id', (v) => v as String),
      version: $checkedConvert(
        'version',
        (v) => QuestionnaireVersionDto.fromJson(v as Map<String, dynamic>),
      ),
      status: $checkedConvert('status', (v) => v as String),
      progressPercent: $checkedConvert(
        'progress_percent',
        (v) => (v as num).toInt(),
      ),
      completedAt: $checkedConvert(
        'completed_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      answers: $checkedConvert(
        'answers',
        (v) => (v as List<dynamic>)
            .map((e) => AnswerDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'progressPercent': 'progress_percent',
    'completedAt': 'completed_at',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

CurrentQuestionnaireDto _$CurrentQuestionnaireDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CurrentQuestionnaireDto', json, ($checkedConvert) {
  $checkKeys(json, allowedKeys: const ['response', 'version']);
  final val = CurrentQuestionnaireDto(
    response: $checkedConvert(
      'response',
      (v) => v == null
          ? null
          : QuestionnaireResponseDto.fromJson(v as Map<String, dynamic>),
    ),
    version: $checkedConvert(
      'version',
      (v) => v == null
          ? null
          : QuestionnaireVersionDto.fromJson(v as Map<String, dynamic>),
    ),
  );
  return val;
});

AssessmentResultDto _$AssessmentResultDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AssessmentResultDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'rule_code',
            'rule_version',
            'outcome',
            'severity',
            'title',
            'explanation',
            'required_actions',
            'used_facts',
            'source_snapshot',
          ],
        );
        final val = AssessmentResultDto(
          id: $checkedConvert('id', (v) => v as String),
          ruleCode: $checkedConvert('rule_code', (v) => v as String),
          ruleVersion: $checkedConvert('rule_version', (v) => v as String),
          outcome: $checkedConvert('outcome', (v) => v as String),
          severity: $checkedConvert('severity', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          explanation: $checkedConvert('explanation', (v) => v as String),
          requiredActions: $checkedConvert(
            'required_actions',
            (v) => v as List<dynamic>,
          ),
          usedFacts: $checkedConvert(
            'used_facts',
            (v) => v as Map<String, dynamic>,
          ),
          sourceSnapshot: $checkedConvert(
            'source_snapshot',
            (v) => v as List<dynamic>,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'ruleCode': 'rule_code',
        'ruleVersion': 'rule_version',
        'requiredActions': 'required_actions',
        'usedFacts': 'used_facts',
        'sourceSnapshot': 'source_snapshot',
      },
    );

AssessmentDto _$AssessmentDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AssessmentDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'questionnaire_response_id',
        'assessment_as_of',
        'baseline_version',
        'baseline_status',
        'facts_sha256',
        'snapshot_sha256',
        'applied_rules_snapshot',
        'sources_snapshot',
        'results',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = AssessmentDto(
      id: $checkedConvert('id', (v) => v as String),
      questionnaireResponseId: $checkedConvert(
        'questionnaire_response_id',
        (v) => v as String?,
      ),
      assessmentAsOf: $checkedConvert(
        'assessment_as_of',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      baselineVersion: $checkedConvert('baseline_version', (v) => v as String),
      baselineStatus: $checkedConvert('baseline_status', (v) => v as String),
      factsSha256: $checkedConvert('facts_sha256', (v) => v as String),
      snapshotSha256: $checkedConvert('snapshot_sha256', (v) => v as String),
      appliedRulesSnapshot: $checkedConvert(
        'applied_rules_snapshot',
        (v) => v as List<dynamic>,
      ),
      sourcesSnapshot: $checkedConvert(
        'sources_snapshot',
        (v) => v as List<dynamic>,
      ),
      results: $checkedConvert(
        'results',
        (v) => (v as List<dynamic>)
            .map((e) => AssessmentResultDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'questionnaireResponseId': 'questionnaire_response_id',
    'assessmentAsOf': 'assessment_as_of',
    'baselineVersion': 'baseline_version',
    'baselineStatus': 'baseline_status',
    'factsSha256': 'facts_sha256',
    'snapshotSha256': 'snapshot_sha256',
    'appliedRulesSnapshot': 'applied_rules_snapshot',
    'sourcesSnapshot': 'sources_snapshot',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

ObligationDto _$ObligationDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ObligationDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'source_assessment_id',
            'rule_code',
            'title',
            'description',
            'status',
            'severity',
            'due_date',
            'due_basis',
            'responsible_id',
            'completed_at',
            'completion_date',
            'completion_comment',
            'evidence_absent_confirmed',
            'created_at',
            'updated_at',
            'etag',
          ],
        );
        final val = ObligationDto(
          id: $checkedConvert('id', (v) => v as String),
          sourceAssessmentId: $checkedConvert(
            'source_assessment_id',
            (v) => v as String,
          ),
          ruleCode: $checkedConvert('rule_code', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          description: $checkedConvert('description', (v) => v as String),
          status: $checkedConvert('status', (v) => v as String),
          severity: $checkedConvert('severity', (v) => v as String),
          dueDate: $checkedConvert('due_date', (v) => v as String?),
          dueBasis: $checkedConvert('due_basis', (v) => v as String),
          responsibleId: $checkedConvert(
            'responsible_id',
            (v) => (v as num?)?.toInt(),
          ),
          completedAt: $checkedConvert(
            'completed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          completionDate: $checkedConvert(
            'completion_date',
            (v) => v as String?,
          ),
          completionComment: $checkedConvert(
            'completion_comment',
            (v) => v as String,
          ),
          evidenceAbsentConfirmed: $checkedConvert(
            'evidence_absent_confirmed',
            (v) => v as bool,
          ),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
          etag: $checkedConvert('etag', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'sourceAssessmentId': 'source_assessment_id',
        'ruleCode': 'rule_code',
        'dueDate': 'due_date',
        'dueBasis': 'due_basis',
        'responsibleId': 'responsible_id',
        'completedAt': 'completed_at',
        'completionDate': 'completion_date',
        'completionComment': 'completion_comment',
        'evidenceAbsentConfirmed': 'evidence_absent_confirmed',
        'createdAt': 'created_at',
        'updatedAt': 'updated_at',
      },
    );

ChecklistItemDto _$ChecklistItemDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ChecklistItemDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'obligation_id',
            'title',
            'status',
            'due_date',
            'notes',
            'completed_at',
            'created_at',
            'updated_at',
            'etag',
          ],
        );
        final val = ChecklistItemDto(
          id: $checkedConvert('id', (v) => v as String),
          obligationId: $checkedConvert('obligation_id', (v) => v as String?),
          title: $checkedConvert('title', (v) => v as String),
          status: $checkedConvert('status', (v) => v as String),
          dueDate: $checkedConvert('due_date', (v) => v as String?),
          notes: $checkedConvert('notes', (v) => v as String),
          completedAt: $checkedConvert(
            'completed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
          etag: $checkedConvert('etag', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'obligationId': 'obligation_id',
        'dueDate': 'due_date',
        'completedAt': 'completed_at',
        'createdAt': 'created_at',
        'updatedAt': 'updated_at',
      },
    );

DocumentTemplateDto _$DocumentTemplateDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DocumentTemplateDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'code',
            'title',
            'version',
            'baseline_version',
            'reviewed_at',
          ],
        );
        final val = DocumentTemplateDto(
          id: $checkedConvert('id', (v) => v as String),
          code: $checkedConvert('code', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          version: $checkedConvert('version', (v) => v as String),
          baselineVersion: $checkedConvert(
            'baseline_version',
            (v) => v as String,
          ),
          reviewedAt: $checkedConvert('reviewed_at', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {
        'baselineVersion': 'baseline_version',
        'reviewedAt': 'reviewed_at',
      },
    );

GeneratedDocumentDto _$GeneratedDocumentDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'GeneratedDocumentDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'template',
        'baseline_version',
        'sha256',
        'status',
        'download_urls',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = GeneratedDocumentDto(
      id: $checkedConvert('id', (v) => v as String),
      template: $checkedConvert(
        'template',
        (v) => DocumentTemplateDto.fromJson(v as Map<String, dynamic>),
      ),
      baselineVersion: $checkedConvert('baseline_version', (v) => v as String),
      sha256: $checkedConvert('sha256', (v) => v as String),
      status: $checkedConvert('status', (v) => v as String),
      downloadUrls: $checkedConvert(
        'download_urls',
        (v) => Map<String, String>.from(v as Map),
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'baselineVersion': 'baseline_version',
    'downloadUrls': 'download_urls',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

EvidenceDto _$EvidenceDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'EvidenceDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'obligation_id',
        'title',
        'original_name',
        'extension',
        'mime_type',
        'size_bytes',
        'sha256',
        'download_url',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = EvidenceDto(
      id: $checkedConvert('id', (v) => v as String),
      obligationId: $checkedConvert('obligation_id', (v) => v as String?),
      title: $checkedConvert('title', (v) => v as String),
      originalName: $checkedConvert('original_name', (v) => v as String),
      extension: $checkedConvert('extension', (v) => v as String),
      mimeType: $checkedConvert('mime_type', (v) => v as String),
      sizeBytes: $checkedConvert('size_bytes', (v) => (v as num).toInt()),
      sha256: $checkedConvert('sha256', (v) => v as String),
      downloadUrl: $checkedConvert('download_url', (v) => v as String),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'obligationId': 'obligation_id',
    'originalName': 'original_name',
    'mimeType': 'mime_type',
    'sizeBytes': 'size_bytes',
    'downloadUrl': 'download_url',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

SiteScanFindingDto _$SiteScanFindingDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SiteScanFindingDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'code',
            'title',
            'description',
            'page_url',
            'dom_context',
            'evidence_snippet',
            'confidence',
            'needs_review',
          ],
        );
        final val = SiteScanFindingDto(
          id: $checkedConvert('id', (v) => v as String),
          code: $checkedConvert('code', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          description: $checkedConvert('description', (v) => v as String),
          pageUrl: $checkedConvert('page_url', (v) => v as String?),
          domContext: $checkedConvert('dom_context', (v) => v as String),
          evidenceSnippet: $checkedConvert(
            'evidence_snippet',
            (v) => v as String,
          ),
          confidence: $checkedConvert('confidence', (v) => v as String),
          needsReview: $checkedConvert('needs_review', (v) => v as bool),
        );
        return val;
      },
      fieldKeyMap: const {
        'pageUrl': 'page_url',
        'domContext': 'dom_context',
        'evidenceSnippet': 'evidence_snippet',
        'needsReview': 'needs_review',
      },
    );

SiteScanPageDto _$SiteScanPageDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'SiteScanPageDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'url',
            'final_url',
            'status_code',
            'content_bytes',
            'is_https',
            'forms_count',
            'external_domains',
          ],
        );
        final val = SiteScanPageDto(
          id: $checkedConvert('id', (v) => v as String),
          url: $checkedConvert('url', (v) => v as String),
          finalUrl: $checkedConvert('final_url', (v) => v as String),
          statusCode: $checkedConvert('status_code', (v) => (v as num).toInt()),
          contentBytes: $checkedConvert(
            'content_bytes',
            (v) => (v as num).toInt(),
          ),
          isHttps: $checkedConvert('is_https', (v) => v as bool),
          formsCount: $checkedConvert('forms_count', (v) => (v as num).toInt()),
          externalDomains: $checkedConvert(
            'external_domains',
            (v) => v as List<dynamic>,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'finalUrl': 'final_url',
        'statusCode': 'status_code',
        'contentBytes': 'content_bytes',
        'isHttps': 'is_https',
        'formsCount': 'forms_count',
        'externalDomains': 'external_domains',
      },
    );

SiteScanDto _$SiteScanDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'SiteScanDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'website_id',
        'status',
        'requested_url',
        'final_url',
        'pages_scanned',
        'progress_percent',
        'progress_message',
        'incomplete_reason',
        'error_summary',
        'queued_at',
        'started_at',
        'finished_at',
        'retry_count',
        'findings',
        'pages',
        'updated_at',
        'etag',
      ],
    );
    final val = SiteScanDto(
      id: $checkedConvert('id', (v) => v as String),
      websiteId: $checkedConvert('website_id', (v) => v as String),
      status: $checkedConvert('status', (v) => v as String),
      requestedUrl: $checkedConvert('requested_url', (v) => v as String),
      finalUrl: $checkedConvert('final_url', (v) => v as String?),
      pagesScanned: $checkedConvert('pages_scanned', (v) => (v as num).toInt()),
      progressPercent: $checkedConvert(
        'progress_percent',
        (v) => (v as num).toInt(),
      ),
      progressMessage: $checkedConvert('progress_message', (v) => v as String),
      incompleteReason: $checkedConvert(
        'incomplete_reason',
        (v) => v as String,
      ),
      errorSummary: $checkedConvert('error_summary', (v) => v as String),
      queuedAt: $checkedConvert(
        'queued_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      startedAt: $checkedConvert(
        'started_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      finishedAt: $checkedConvert(
        'finished_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      retryCount: $checkedConvert('retry_count', (v) => (v as num).toInt()),
      findings: $checkedConvert(
        'findings',
        (v) => (v as List<dynamic>)
            .map((e) => SiteScanFindingDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      pages: $checkedConvert(
        'pages',
        (v) => (v as List<dynamic>)
            .map((e) => SiteScanPageDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'websiteId': 'website_id',
    'requestedUrl': 'requested_url',
    'finalUrl': 'final_url',
    'pagesScanned': 'pages_scanned',
    'progressPercent': 'progress_percent',
    'progressMessage': 'progress_message',
    'incompleteReason': 'incomplete_reason',
    'errorSummary': 'error_summary',
    'queuedAt': 'queued_at',
    'startedAt': 'started_at',
    'finishedAt': 'finished_at',
    'retryCount': 'retry_count',
    'updatedAt': 'updated_at',
  },
);

AuditEventDto _$AuditEventDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AuditEventDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'actor_id',
            'event_type',
            'object_type',
            'object_id',
            'summary',
            'metadata',
            'created_at',
          ],
        );
        final val = AuditEventDto(
          id: $checkedConvert('id', (v) => v as String),
          actorId: $checkedConvert('actor_id', (v) => v as String?),
          eventType: $checkedConvert('event_type', (v) => v as String),
          objectType: $checkedConvert('object_type', (v) => v as String),
          objectId: $checkedConvert('object_id', (v) => v as String),
          summary: $checkedConvert('summary', (v) => v as String),
          metadata: $checkedConvert(
            'metadata',
            (v) => v as Map<String, dynamic>,
          ),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'actorId': 'actor_id',
        'eventType': 'event_type',
        'objectType': 'object_type',
        'objectId': 'object_id',
        'createdAt': 'created_at',
      },
    );

AuditPageDto _$AuditPageDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AuditPageDto', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['results', 'next_cursor']);
      final val = AuditPageDto(
        results: $checkedConvert(
          'results',
          (v) => (v as List<dynamic>)
              .map((e) => AuditEventDto.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        nextCursor: $checkedConvert('next_cursor', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'nextCursor': 'next_cursor'});

AiConversationDto _$AiConversationDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AiConversationDto',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          allowedKeys: const [
            'id',
            'organization_id',
            'title',
            'status',
            'created_at',
            'updated_at',
            'messages',
          ],
        );
        final val = AiConversationDto(
          id: $checkedConvert('id', (v) => v as String),
          organizationId: $checkedConvert(
            'organization_id',
            (v) => v as String,
          ),
          title: $checkedConvert('title', (v) => v as String),
          status: $checkedConvert('status', (v) => v as String),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
          messages: $checkedConvert(
            'messages',
            (v) => (v as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'organizationId': 'organization_id',
        'createdAt': 'created_at',
        'updatedAt': 'updated_at',
      },
    );

AiRequestDto _$AiRequestDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'AiRequestDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'id',
        'conversation_id',
        'status',
        'provider',
        'execution_mode',
        'requested_model',
        'selected_model',
        'actual_model',
        'fallback_used',
        'reroute',
        'rate_limit_state',
        'context',
        'result',
        'safe_error',
        'telemetry',
        'sanitization',
        'created_at',
        'updated_at',
        'etag',
      ],
    );
    final val = AiRequestDto(
      id: $checkedConvert('id', (v) => v as String),
      conversationId: $checkedConvert('conversation_id', (v) => v as String),
      status: $checkedConvert('status', (v) => v as String),
      provider: $checkedConvert('provider', (v) => v as String),
      executionMode: $checkedConvert('execution_mode', (v) => v as String),
      requestedModel: $checkedConvert('requested_model', (v) => v as String),
      selectedModel: $checkedConvert('selected_model', (v) => v as String?),
      actualModel: $checkedConvert('actual_model', (v) => v as String?),
      fallbackUsed: $checkedConvert('fallback_used', (v) => v as bool),
      reroute: $checkedConvert('reroute', (v) => v as Map<String, dynamic>),
      rateLimitState: $checkedConvert(
        'rate_limit_state',
        (v) => v as Map<String, dynamic>,
      ),
      context: $checkedConvert('context', (v) => v as Map<String, dynamic>),
      result: $checkedConvert('result', (v) => v as Map<String, dynamic>?),
      safeError: $checkedConvert('safe_error', (v) => v as String?),
      telemetry: $checkedConvert('telemetry', (v) => v as Map<String, dynamic>),
      sanitization: $checkedConvert(
        'sanitization',
        (v) => v as Map<String, dynamic>,
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
      etag: $checkedConvert('etag', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'conversationId': 'conversation_id',
    'executionMode': 'execution_mode',
    'requestedModel': 'requested_model',
    'selectedModel': 'selected_model',
    'actualModel': 'actual_model',
    'fallbackUsed': 'fallback_used',
    'rateLimitState': 'rate_limit_state',
    'safeError': 'safe_error',
    'createdAt': 'created_at',
    'updatedAt': 'updated_at',
  },
);

AiEventsDto _$AiEventsDtoFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AiEventsDto',
  json,
  ($checkedConvert) {
    $checkKeys(json, allowedKeys: const ['events', 'status']);
    final val = AiEventsDto(
      events: $checkedConvert(
        'events',
        (v) =>
            (v as List<dynamic>).map((e) => e as Map<String, dynamic>).toList(),
      ),
      status: $checkedConvert('status', (v) => v as String),
    );
    return val;
  },
);
