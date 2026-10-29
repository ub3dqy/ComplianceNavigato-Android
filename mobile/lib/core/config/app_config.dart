const String _stagingHost = 'compliance-pilot.ms777.ru';

final class AppConfig {
  AppConfig._({
    required this.environment,
    required this.apiBaseUri,
    required this.gitCommitSha,
    required this.apiSchemaSha256,
  });

  static AppConfig fromEnvironment() => validate(<String, String>{
    'APP_ENV': const String.fromEnvironment('APP_ENV', defaultValue: 'staging'),
    'API_BASE_URL': const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://compliance-pilot.ms777.ru',
    ),
    'OPENAI_API_ENABLED': const String.fromEnvironment(
      'OPENAI_API_ENABLED',
      defaultValue: 'false',
    ),
    'AI_PROVIDER_AUTO_SWITCH': const String.fromEnvironment(
      'AI_PROVIDER_AUTO_SWITCH',
      defaultValue: 'false',
    ),
    'GIT_COMMIT_SHA': const String.fromEnvironment(
      'GIT_COMMIT_SHA',
      defaultValue: 'development',
    ),
    'API_SCHEMA_SHA256': const String.fromEnvironment(
      'API_SCHEMA_SHA256',
      defaultValue:
          '0000000000000000000000000000000000000000000000000000000000000000',
    ),
  });

  static AppConfig validate(Map<String, String> values) {
    final String environment = values['APP_ENV']?.trim() ?? '';
    if (environment != 'staging') {
      throw StateError(
        'Production Android configuration is not approved. APP_ENV must be staging.',
      );
    }
    if (values['OPENAI_API_ENABLED'] != 'false' ||
        values['AI_PROVIDER_AUTO_SWITCH'] != 'false') {
      throw StateError(
        'OpenAI API and AI provider auto-switch must remain disabled.',
      );
    }

    final Uri supplied = Uri.parse(values['API_BASE_URL']?.trim() ?? '');
    final bool validRoot =
        supplied.scheme == 'https' &&
        supplied.host == _stagingHost &&
        supplied.userInfo.isEmpty &&
        !supplied.hasPort &&
        (supplied.path.isEmpty || supplied.path == '/') &&
        supplied.query.isEmpty &&
        supplied.fragment.isEmpty;
    if (!validRoot) {
      throw StateError(
        'The staging build may connect only to $_stagingHost over HTTPS.',
      );
    }

    final String schemaHash =
        values['API_SCHEMA_SHA256']?.trim().toLowerCase() ?? '';
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(schemaHash)) {
      throw StateError('API_SCHEMA_SHA256 must be a SHA-256 digest.');
    }
    final String gitSha = values['GIT_COMMIT_SHA']?.trim() ?? '';
    if (gitSha.isEmpty || gitSha.contains(RegExp(r'[\r\n]'))) {
      throw StateError('GIT_COMMIT_SHA is invalid.');
    }

    return AppConfig._(
      environment: environment,
      apiBaseUri: supplied.replace(path: '/api/v1/'),
      gitCommitSha: gitSha,
      apiSchemaSha256: schemaHash,
    );
  }

  final String environment;
  final Uri apiBaseUri;
  final String gitCommitSha;
  final String apiSchemaSha256;

  String get serverHostname => apiBaseUri.host;

  bool allows(Uri target) =>
      target.scheme == 'https' &&
      target.host == _stagingHost &&
      !target.hasPort &&
      target.userInfo.isEmpty &&
      (target.path == '/api/v1' || target.path.startsWith('/api/v1/'));
}
