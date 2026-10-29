import 'package:json_annotation/json_annotation.dart';

part 'api_models.g.dart';

typedef JsonMap = Map<String, Object?>;

@JsonSerializable(createToJson: false)
final class ApiHealthDto {
  const ApiHealthDto({
    required this.status,
    required this.apiVersion,
    required this.schemaSha256,
  });

  factory ApiHealthDto.fromJson(Map<String, dynamic> json) =>
      _$ApiHealthDtoFromJson(json);

  final String status;
  final String apiVersion;
  final String schemaSha256;
}

@JsonSerializable(createToJson: false)
final class TokenPairDto {
  const TokenPairDto({
    required this.access,
    required this.refresh,
    required this.accessExpiresIn,
    required this.refreshExpiresIn,
    required this.tokenType,
  });

  factory TokenPairDto.fromJson(Map<String, dynamic> json) =>
      _$TokenPairDtoFromJson(json);

  final String access;
  final String refresh;
  final int accessExpiresIn;
  final int refreshExpiresIn;
  final String tokenType;
}

@JsonSerializable(createToJson: false)
final class RefreshDto {
  const RefreshDto({required this.access, required this.refresh});

  factory RefreshDto.fromJson(Map<String, dynamic> json) =>
      _$RefreshDtoFromJson(json);

  final String access;
  final String refresh;
}

@JsonSerializable(createToJson: false)
final class CurrentUserDto {
  const CurrentUserDto({
    required this.id,
    required this.email,
    required this.isStaff,
    required this.isSuperuser,
    required this.mfaEnabled,
  });

  factory CurrentUserDto.fromJson(Map<String, dynamic> json) =>
      _$CurrentUserDtoFromJson(json);

  final String id;
  final String email;
  final bool isStaff;
  final bool isSuperuser;
  final bool mfaEnabled;
}

@JsonSerializable(createToJson: false)
final class OrganizationSummaryDto {
  const OrganizationSummaryDto({
    required this.id,
    required this.shortName,
    required this.kind,
    required this.role,
    required this.updatedAt,
  });

  factory OrganizationSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$OrganizationSummaryDtoFromJson(json);

  final String id;
  final String shortName;
  final String kind;
  final String role;
  final DateTime updatedAt;
}

@JsonSerializable(createToJson: false)
final class RegistryPreviewDto {
  const RegistryPreviewDto({
    required this.kind,
    required this.inn,
    required this.ogrn,
    required this.fullName,
    required this.shortName,
    required this.kpp,
    required this.legalAddress,
    required this.leaderName,
    required this.okved,
  });

  factory RegistryPreviewDto.fromJson(Map<String, dynamic> json) =>
      _$RegistryPreviewDtoFromJson(json);

  final String kind;
  final String inn;
  final String ogrn;
  final String fullName;
  final String shortName;
  final String? kpp;
  final String? legalAddress;
  final String? leaderName;
  final String? okved;
}

@JsonSerializable(createToJson: false)
final class FnsExtractPreviewDto {
  const FnsExtractPreviewDto({
    required this.kind,
    required this.inn,
    required this.ogrn,
    required this.fullName,
    required this.shortName,
    required this.kpp,
    required this.legalAddress,
    required this.okved,
  });

  factory FnsExtractPreviewDto.fromJson(Map<String, dynamic> json) =>
      _$FnsExtractPreviewDtoFromJson(json);

  final String kind;
  final String inn;
  final String ogrn;
  final String? fullName;
  final String? shortName;
  final String? kpp;
  final String? legalAddress;
  final String? okved;
}

@JsonSerializable(createToJson: false)
final class OrganizationDto {
  const OrganizationDto({
    required this.id,
    required this.kind,
    required this.fullName,
    required this.shortName,
    required this.inn,
    required this.kpp,
    required this.ogrn,
    required this.legalAddress,
    required this.actualAddress,
    required this.leaderName,
    required this.contactEmail,
    required this.contactPhone,
    required this.taxRegime,
    required this.okved,
    required this.employeeCount,
    required this.hasApplicants,
    required this.activityStartDate,
    required this.privacyResponsible,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory OrganizationDto.fromJson(Map<String, dynamic> json) =>
      _$OrganizationDtoFromJson(json);

  final String id;
  final String kind;
  final String fullName;
  final String shortName;
  final String inn;
  final String kpp;
  final String ogrn;
  final String legalAddress;
  final String actualAddress;
  final String leaderName;
  final String? contactEmail;
  final String contactPhone;
  final String taxRegime;
  final String okved;
  final int employeeCount;
  final bool hasApplicants;
  final String? activityStartDate;
  final String privacyResponsible;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class MembershipDto {
  const MembershipDto({
    required this.id,
    required this.userId,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory MembershipDto.fromJson(Map<String, dynamic> json) =>
      _$MembershipDtoFromJson(json);

  final String id;
  final String userId;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class WebsiteDto {
  const WebsiteDto({
    required this.id,
    required this.url,
    required this.name,
    required this.purpose,
    required this.isActive,
    required this.publicOperatorName,
    required this.userReportsForms,
    required this.lastCheckedAt,
    required this.scanAuthorityConfirmed,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory WebsiteDto.fromJson(Map<String, dynamic> json) =>
      _$WebsiteDtoFromJson(json);

  final String id;
  final String url;
  final String name;
  final String purpose;
  final bool isActive;
  final String publicOperatorName;
  final String userReportsForms;
  final DateTime? lastCheckedAt;
  final bool scanAuthorityConfirmed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class ExternalServiceDto {
  const ExternalServiceDto({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.purpose,
    required this.dataCategories,
    required this.recipientEntity,
    required this.primaryCountry,
    required this.additionalCountries,
    required this.locationStatus,
    required this.processingAgreement,
    required this.termsUrl,
    required this.lastCheckedAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory ExternalServiceDto.fromJson(Map<String, dynamic> json) =>
      _$ExternalServiceDtoFromJson(json);

  final String id;
  final String name;
  final String serviceType;
  final String purpose;
  final String dataCategories;
  final String recipientEntity;
  final String primaryCountry;
  final String additionalCountries;
  final String locationStatus;
  final String processingAgreement;
  final String? termsUrl;
  final String? lastCheckedAt;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class ProcessingCountryDto {
  const ProcessingCountryDto({
    required this.id,
    required this.name,
    required this.status,
    required this.purpose,
    required this.transferBasis,
    required this.needsReview,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory ProcessingCountryDto.fromJson(Map<String, dynamic> json) =>
      _$ProcessingCountryDtoFromJson(json);

  final String id;
  final String name;
  final String status;
  final String purpose;
  final String transferBasis;
  final bool needsReview;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class QuestionOptionDto {
  const QuestionOptionDto({required this.value, required this.label});

  factory QuestionOptionDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionOptionDtoFromJson(json);

  final String value;
  final String label;
}

@JsonSerializable(createToJson: false)
final class QuestionDto {
  const QuestionDto({
    required this.id,
    required this.code,
    required this.section,
    required this.position,
    required this.text,
    required this.helpText,
    required this.questionType,
    required this.required,
    required this.critical,
    required this.options,
    required this.condition,
  });

  factory QuestionDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionDtoFromJson(json);

  final String id;
  final String code;
  final String section;
  final int position;
  final String text;
  final String helpText;
  final String questionType;
  final bool required;
  final bool critical;
  final List<QuestionOptionDto> options;
  final JsonMap condition;
}

@JsonSerializable(createToJson: false)
final class QuestionnaireVersionDto {
  const QuestionnaireVersionDto({
    required this.id,
    required this.version,
    required this.title,
    required this.description,
    required this.publishedAt,
    required this.questions,
  });

  factory QuestionnaireVersionDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionnaireVersionDtoFromJson(json);

  final String id;
  final String version;
  final String title;
  final String description;
  final DateTime? publishedAt;
  final List<QuestionDto> questions;
}

@JsonSerializable(createToJson: false)
final class AnswerDto {
  const AnswerDto({
    required this.id,
    required this.questionCode,
    required this.value,
    required this.updatedAt,
  });

  factory AnswerDto.fromJson(Map<String, dynamic> json) =>
      _$AnswerDtoFromJson(json);

  final String id;
  final String questionCode;
  final Object? value;
  final DateTime updatedAt;
}

@JsonSerializable(createToJson: false)
final class QuestionnaireResponseDto {
  const QuestionnaireResponseDto({
    required this.id,
    required this.version,
    required this.status,
    required this.progressPercent,
    required this.completedAt,
    required this.answers,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory QuestionnaireResponseDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionnaireResponseDtoFromJson(json);

  final String id;
  final QuestionnaireVersionDto version;
  final String status;
  final int progressPercent;
  final DateTime? completedAt;
  final List<AnswerDto> answers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class CurrentQuestionnaireDto {
  const CurrentQuestionnaireDto({
    required this.response,
    required this.version,
  });

  factory CurrentQuestionnaireDto.fromJson(Map<String, dynamic> json) =>
      _$CurrentQuestionnaireDtoFromJson(json);

  final QuestionnaireResponseDto? response;
  final QuestionnaireVersionDto? version;
}

@JsonSerializable(createToJson: false)
final class AssessmentResultDto {
  const AssessmentResultDto({
    required this.id,
    required this.ruleCode,
    required this.ruleVersion,
    required this.outcome,
    required this.severity,
    required this.title,
    required this.explanation,
    required this.requiredActions,
    required this.usedFacts,
    required this.sourceSnapshot,
  });

  factory AssessmentResultDto.fromJson(Map<String, dynamic> json) =>
      _$AssessmentResultDtoFromJson(json);

  final String id;
  final String ruleCode;
  final String ruleVersion;
  final String outcome;
  final String severity;
  final String title;
  final String explanation;
  final List<Object?> requiredActions;
  final JsonMap usedFacts;
  final List<Object?> sourceSnapshot;
}

@JsonSerializable(createToJson: false)
final class AssessmentDto {
  const AssessmentDto({
    required this.id,
    required this.questionnaireResponseId,
    required this.assessmentAsOf,
    required this.baselineVersion,
    required this.baselineStatus,
    required this.factsSha256,
    required this.snapshotSha256,
    required this.appliedRulesSnapshot,
    required this.sourcesSnapshot,
    required this.results,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory AssessmentDto.fromJson(Map<String, dynamic> json) =>
      _$AssessmentDtoFromJson(json);

  final String id;
  final String? questionnaireResponseId;
  final DateTime? assessmentAsOf;
  final String baselineVersion;
  final String baselineStatus;
  final String factsSha256;
  final String snapshotSha256;
  final List<Object?> appliedRulesSnapshot;
  final List<Object?> sourcesSnapshot;
  final List<AssessmentResultDto> results;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class ObligationDto {
  const ObligationDto({
    required this.id,
    required this.sourceAssessmentId,
    required this.ruleCode,
    required this.title,
    required this.description,
    required this.status,
    required this.severity,
    required this.dueDate,
    required this.dueBasis,
    required this.responsibleId,
    required this.completedAt,
    required this.completionDate,
    required this.completionComment,
    required this.evidenceAbsentConfirmed,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory ObligationDto.fromJson(Map<String, dynamic> json) =>
      _$ObligationDtoFromJson(json);

  final String id;
  final String sourceAssessmentId;
  final String ruleCode;
  final String title;
  final String description;
  final String status;
  final String severity;
  final String? dueDate;
  final String dueBasis;
  final int? responsibleId;
  final DateTime? completedAt;
  final String? completionDate;
  final String completionComment;
  final bool evidenceAbsentConfirmed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class ChecklistItemDto {
  const ChecklistItemDto({
    required this.id,
    required this.obligationId,
    required this.title,
    required this.status,
    required this.dueDate,
    required this.notes,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory ChecklistItemDto.fromJson(Map<String, dynamic> json) =>
      _$ChecklistItemDtoFromJson(json);

  final String id;
  final String? obligationId;
  final String title;
  final String status;
  final String? dueDate;
  final String notes;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class DocumentTemplateDto {
  const DocumentTemplateDto({
    required this.id,
    required this.code,
    required this.title,
    required this.version,
    required this.baselineVersion,
    required this.reviewedAt,
  });

  factory DocumentTemplateDto.fromJson(Map<String, dynamic> json) =>
      _$DocumentTemplateDtoFromJson(json);

  final String id;
  final String code;
  final String title;
  final String version;
  final String baselineVersion;
  final String reviewedAt;
}

@JsonSerializable(createToJson: false)
final class GeneratedDocumentDto {
  const GeneratedDocumentDto({
    required this.id,
    required this.template,
    required this.baselineVersion,
    required this.sha256,
    required this.status,
    required this.downloadUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory GeneratedDocumentDto.fromJson(Map<String, dynamic> json) =>
      _$GeneratedDocumentDtoFromJson(json);

  final String id;
  final DocumentTemplateDto template;
  final String baselineVersion;
  final String sha256;
  final String status;
  final Map<String, String> downloadUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class EvidenceDto {
  const EvidenceDto({
    required this.id,
    required this.obligationId,
    required this.title,
    required this.originalName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.downloadUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory EvidenceDto.fromJson(Map<String, dynamic> json) =>
      _$EvidenceDtoFromJson(json);

  final String id;
  final String? obligationId;
  final String title;
  final String originalName;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final String downloadUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class SiteScanFindingDto {
  const SiteScanFindingDto({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.pageUrl,
    required this.domContext,
    required this.evidenceSnippet,
    required this.confidence,
    required this.needsReview,
  });

  factory SiteScanFindingDto.fromJson(Map<String, dynamic> json) =>
      _$SiteScanFindingDtoFromJson(json);

  final String id;
  final String code;
  final String title;
  final String description;
  final String? pageUrl;
  final String domContext;
  final String evidenceSnippet;
  final String confidence;
  final bool needsReview;
}

@JsonSerializable(createToJson: false)
final class SiteScanPageDto {
  const SiteScanPageDto({
    required this.id,
    required this.url,
    required this.finalUrl,
    required this.statusCode,
    required this.contentBytes,
    required this.isHttps,
    required this.formsCount,
    required this.externalDomains,
  });

  factory SiteScanPageDto.fromJson(Map<String, dynamic> json) =>
      _$SiteScanPageDtoFromJson(json);

  final String id;
  final String url;
  final String finalUrl;
  final int statusCode;
  final int contentBytes;
  final bool isHttps;
  final int formsCount;
  final List<Object?> externalDomains;
}

@JsonSerializable(createToJson: false)
final class SiteScanDto {
  const SiteScanDto({
    required this.id,
    required this.websiteId,
    required this.status,
    required this.requestedUrl,
    required this.finalUrl,
    required this.pagesScanned,
    required this.progressPercent,
    required this.progressMessage,
    required this.incompleteReason,
    required this.errorSummary,
    required this.queuedAt,
    required this.startedAt,
    required this.finishedAt,
    required this.retryCount,
    required this.findings,
    required this.pages,
    required this.updatedAt,
    required this.etag,
  });

  factory SiteScanDto.fromJson(Map<String, dynamic> json) =>
      _$SiteScanDtoFromJson(json);

  final String id;
  final String websiteId;
  final String status;
  final String requestedUrl;
  final String? finalUrl;
  final int pagesScanned;
  final int progressPercent;
  final String progressMessage;
  final String incompleteReason;
  final String errorSummary;
  final DateTime? queuedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int retryCount;
  final List<SiteScanFindingDto> findings;
  final List<SiteScanPageDto> pages;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class AuditEventDto {
  const AuditEventDto({
    required this.id,
    required this.actorId,
    required this.eventType,
    required this.objectType,
    required this.objectId,
    required this.summary,
    required this.metadata,
    required this.createdAt,
  });

  factory AuditEventDto.fromJson(Map<String, dynamic> json) =>
      _$AuditEventDtoFromJson(json);

  final String id;
  final String? actorId;
  final String eventType;
  final String objectType;
  final String objectId;
  final String summary;
  final JsonMap metadata;
  final DateTime createdAt;
}

@JsonSerializable(createToJson: false)
final class AuditPageDto {
  const AuditPageDto({required this.results, required this.nextCursor});

  factory AuditPageDto.fromJson(Map<String, dynamic> json) =>
      _$AuditPageDtoFromJson(json);

  final List<AuditEventDto> results;
  final String? nextCursor;
}

@JsonSerializable(createToJson: false)
final class AiConversationDto {
  const AiConversationDto({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.messages,
  });

  factory AiConversationDto.fromJson(Map<String, dynamic> json) =>
      _$AiConversationDtoFromJson(json);

  final String id;
  final String organizationId;
  final String title;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<JsonMap>? messages;
}

@JsonSerializable(createToJson: false)
final class AiRequestDto {
  const AiRequestDto({
    required this.id,
    required this.conversationId,
    required this.status,
    required this.provider,
    required this.executionMode,
    required this.requestedModel,
    required this.selectedModel,
    required this.actualModel,
    required this.fallbackUsed,
    required this.reroute,
    required this.rateLimitState,
    required this.context,
    required this.result,
    required this.safeError,
    required this.telemetry,
    required this.sanitization,
    required this.createdAt,
    required this.updatedAt,
    required this.etag,
  });

  factory AiRequestDto.fromJson(Map<String, dynamic> json) =>
      _$AiRequestDtoFromJson(json);

  final String id;
  final String conversationId;
  final String status;
  final String provider;
  final String executionMode;
  final String requestedModel;
  final String? selectedModel;
  final String? actualModel;
  final bool fallbackUsed;
  final JsonMap reroute;
  final JsonMap rateLimitState;
  final JsonMap context;
  final JsonMap? result;
  final String? safeError;
  final JsonMap telemetry;
  final JsonMap sanitization;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String etag;
}

@JsonSerializable(createToJson: false)
final class AiEventsDto {
  const AiEventsDto({required this.events, required this.status});

  factory AiEventsDto.fromJson(Map<String, dynamic> json) =>
      _$AiEventsDtoFromJson(json);

  final List<JsonMap> events;
  final String status;
}
