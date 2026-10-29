import '../../core/network/api_models.dart';
import '../../core/network/sse_parser.dart';

const String aiUsageLimitMessage = 'Достигнут лимит AI. Повторите позже.';

final class AiStreamPresentationState {
  const AiStreamPresentationState({
    this.terminalStatus,
    this.banner,
    this.rateLimitState = const <String, Object?>{},
  });

  final String? terminalStatus;
  final String? banner;
  final JsonMap rateLimitState;

  static const Map<String, int> _terminalPriority = <String, int>{
    'completed': 5,
    'cancelled': 4,
    'failed': 3,
    'rejected': 2,
    'expired': 1,
  };

  AiStreamPresentationState applyEvent(AiStreamEvent event) {
    if (event.type == 'rate_limit') {
      final JsonMap diagnostic = Map<String, Object?>.unmodifiable(
        event.payload,
      );
      return AiStreamPresentationState(
        terminalStatus: terminalStatus,
        banner: terminalStatus != null
            ? banner
            : aiRateLimitExceeded(diagnostic)
            ? aiUsageLimitMessage
            : null,
        rateLimitState: diagnostic,
      );
    }

    final String? terminal = switch (event.type) {
      'completed' => 'completed',
      'cancelled' => 'cancelled',
      'error' => 'failed',
      'rejected' => 'rejected',
      'expired' => 'expired',
      _ => null,
    };
    if (terminal == null) {
      return this;
    }
    final Object? rawCode =
        event.payload['code'] ??
        (event.payload['error'] is Map<String, Object?>
            ? (event.payload['error']! as Map<String, Object?>)['code']
            : null);
    return _applyTerminal(
      terminal,
      failureBanner: rawCode == 'usage_limit_exceeded'
          ? aiUsageLimitMessage
          : null,
    );
  }

  AiStreamPresentationState applyRequest(AiRequestDto request) {
    final JsonMap diagnostic = request.rateLimitState.isEmpty
        ? rateLimitState
        : Map<String, Object?>.unmodifiable(request.rateLimitState);
    final AiStreamPresentationState withDiagnostic = AiStreamPresentationState(
      terminalStatus: terminalStatus,
      banner: banner,
      rateLimitState: diagnostic,
    );
    if (!_terminalPriority.containsKey(request.status)) {
      return withDiagnostic;
    }
    final String? safeFailure = request.status == 'failed'
        ? request.safeError?.trim()
        : null;
    return withDiagnostic._applyTerminal(
      request.status,
      failureBanner: aiRateLimitExceeded(diagnostic)
          ? aiUsageLimitMessage
          : safeFailure?.isNotEmpty == true
          ? safeFailure
          : null,
    );
  }

  AiStreamPresentationState _applyTerminal(
    String incoming, {
    String? failureBanner,
  }) {
    final String? current = terminalStatus;
    if (current != null &&
        _terminalPriority[current]! >= _terminalPriority[incoming]!) {
      return this;
    }
    final String? nextBanner = switch (incoming) {
      'completed' || 'cancelled' => null,
      'failed' => failureBanner ?? 'AI-запрос завершился ошибкой.',
      'rejected' => 'AI-запрос отклонён.',
      'expired' => 'Время ожидания AI-ответа истекло.',
      _ => null,
    };
    return AiStreamPresentationState(
      terminalStatus: incoming,
      banner: nextBanner,
      rateLimitState: rateLimitState,
    );
  }
}

bool aiRateLimitExceeded(JsonMap state) =>
    (state['state'] as String?)?.toLowerCase() == 'exceeded';

String aiRateLimitLabel(JsonMap state) {
  final String? value = (state['state'] as String?)?.toLowerCase();
  return switch (value) {
    'available' => 'Лимит доступен',
    'limited' => 'Лимит временно ограничен',
    'exceeded' => 'Лимит исчерпан',
    _ when state['limited'] == true => 'Лимит временно ограничен',
    _ when state['limited'] == false => 'Лимит доступен',
    _ => 'Состояние лимита получено',
  };
}
