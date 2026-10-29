import 'package:compliance_navigator/core/network/api_models.dart';
import 'package:compliance_navigator/core/network/sse_parser.dart';
import 'package:compliance_navigator/features/ai_assistant/ai_stream_state.dart';
import 'package:flutter_test/flutter_test.dart';

AiStreamEvent _event(
  String type, [
  JsonMap payload = const <String, Object?>{},
]) => AiStreamEvent(id: 1, type: type, payload: payload);

AiRequestDto _request({
  required String status,
  JsonMap rateLimitState = const <String, Object?>{},
  String? safeError,
  JsonMap? result,
}) {
  final DateTime timestamp = DateTime.utc(2026, 8, 30);
  return AiRequestDto(
    id: 'request-1',
    conversationId: 'conversation-1',
    status: status,
    provider: 'codex_subscription',
    executionMode: 'subscription',
    requestedModel: 'model',
    selectedModel: 'model',
    actualModel: 'model',
    fallbackUsed: false,
    reroute: const <String, Object?>{},
    rateLimitState: rateLimitState,
    context: const <String, Object?>{},
    result: result,
    safeError: safeError,
    telemetry: const <String, Object?>{},
    sanitization: const <String, Object?>{},
    createdAt: timestamp,
    updatedAt: timestamp,
    etag: '"request-1"',
  );
}

void main() {
  group('AI stream terminal state', () {
    test('available then completed remains successful', () {
      final AiStreamPresentationState state = const AiStreamPresentationState()
          .applyEvent(
            _event('rate_limit', <String, Object?>{'state': 'available'}),
          )
          .applyEvent(_event('completed'));

      expect(state.terminalStatus, 'completed');
      expect(state.banner, isNull);
      expect(aiRateLimitLabel(state.rateLimitState), 'Лимит доступен');
    });

    test('limited then completed clears a stale warning', () {
      final AiStreamPresentationState state = const AiStreamPresentationState()
          .applyEvent(
            _event('rate_limit', <String, Object?>{'state': 'limited'}),
          )
          .applyEvent(_event('completed'));

      expect(state.terminalStatus, 'completed');
      expect(state.banner, isNull);
      expect(
        aiRateLimitLabel(state.rateLimitState),
        'Лимит временно ограничен',
      );
    });

    test('late available after completed is diagnostic only', () {
      final AiStreamPresentationState state = const AiStreamPresentationState()
          .applyEvent(_event('completed'))
          .applyEvent(
            _event('rate_limit', <String, Object?>{'state': 'available'}),
          );

      expect(state.terminalStatus, 'completed');
      expect(state.banner, isNull);
    });

    test('late exceeded after completed cannot replace success', () {
      final AiStreamPresentationState state = const AiStreamPresentationState()
          .applyEvent(_event('completed'))
          .applyEvent(
            _event('rate_limit', <String, Object?>{'state': 'exceeded'}),
          );

      expect(state.terminalStatus, 'completed');
      expect(state.banner, isNull);
      expect(aiRateLimitLabel(state.rateLimitState), 'Лимит исчерпан');
    });

    test('usage_limit_exceeded failure shows the limit banner', () {
      final AiStreamPresentationState state = const AiStreamPresentationState()
          .applyEvent(
            _event('error', <String, Object?>{'code': 'usage_limit_exceeded'}),
          );

      expect(state.terminalStatus, 'failed');
      expect(state.banner, aiUsageLimitMessage);
    });

    test('completed wins both sides of a cancel-complete race', () {
      final AiStreamPresentationState cancelledFirst =
          const AiStreamPresentationState()
              .applyEvent(_event('cancelled'))
              .applyEvent(_event('completed'));
      final AiStreamPresentationState completedFirst =
          const AiStreamPresentationState()
              .applyEvent(_event('completed'))
              .applyEvent(_event('cancelled'));

      expect(cancelledFirst.terminalStatus, 'completed');
      expect(completedFirst.terminalStatus, 'completed');
      expect(cancelledFirst.banner, isNull);
      expect(completedFirst.banner, isNull);
    });

    test('completed request restores the terminal state after reconnect', () {
      final AiStreamPresentationState state = const AiStreamPresentationState()
          .applyRequest(
            _request(
              status: 'completed',
              rateLimitState: const <String, Object?>{'state': 'available'},
              result: const <String, Object?>{'answer': 'Синтетический ответ'},
            ),
          );

      expect(state.terminalStatus, 'completed');
      expect(state.banner, isNull);
    });

    test('completed clears an earlier confirmed exceeded banner', () {
      final AiStreamPresentationState state = const AiStreamPresentationState()
          .applyEvent(
            _event('rate_limit', <String, Object?>{'state': 'exceeded'}),
          )
          .applyEvent(_event('completed'));

      expect(state.banner, isNull);
      expect(state.terminalStatus, 'completed');
    });

    test('unknown raw provider state is never rendered verbatim', () {
      const JsonMap raw = <String, Object?>{
        'state': 'provider_internal_red_zone',
      };

      expect(aiRateLimitLabel(raw), 'Состояние лимита получено');
      expect(aiRateLimitLabel(raw), isNot(contains('provider_internal')));
    });
  });
}
