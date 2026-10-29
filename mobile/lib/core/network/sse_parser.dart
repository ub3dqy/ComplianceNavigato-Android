import 'dart:async';
import 'dart:convert';

import '../errors/app_error.dart';
import 'api_models.dart';

final class AiStreamEvent {
  const AiStreamEvent({
    required this.id,
    required this.type,
    required this.payload,
  });

  final int? id;
  final String type;
  final JsonMap payload;
}

final class SseParser {
  static const int maxPendingFrameBytes = 64 * 1024;
  static const int maxEventDataBytes = 32 * 1024;
  static const int maxRenderedTextCharacters = 8000;

  static const Set<String> _eventTypes = <String>{
    'started',
    'delta',
    'usage',
    'rerouted',
    'rate_limit',
    'security_violation',
    'cancelled',
    'completed',
    'rejected',
    'error',
    'expired',
    'close',
  };

  Stream<AiStreamEvent> parse(Stream<List<int>> input) async* {
    String buffer = '';
    final Stream<List<int>> byteChunks = input.map<List<int>>(
      (List<int> value) => List<int>.of(value, growable: false),
    );
    await for (final String chunk in byteChunks.transform(utf8.decoder)) {
      buffer += chunk.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      int boundary;
      while ((boundary = buffer.indexOf('\n\n')) >= 0) {
        final String frame = buffer.substring(0, boundary);
        buffer = buffer.substring(boundary + 2);
        if (utf8.encode(frame).length > maxPendingFrameBytes) {
          throw const AppError(
            kind: AppErrorKind.malformedResponse,
            safeMessage: 'Событие AI превысило безопасный размер.',
            code: 'sse_frame_too_large',
          );
        }
        if (frame.startsWith(':')) {
          yield const AiStreamEvent(
            id: null,
            type: 'heartbeat',
            payload: <String, Object?>{},
          );
          continue;
        }
        if (frame.trim().isEmpty) {
          continue;
        }
        yield _parseFrame(frame);
      }
      if (utf8.encode(buffer).length > maxPendingFrameBytes) {
        throw const AppError(
          kind: AppErrorKind.malformedResponse,
          safeMessage: 'Поток AI превысил безопасный размер события.',
          code: 'sse_buffer_too_large',
        );
      }
    }
    if (buffer.trim().isNotEmpty) {
      throw const AppError(
        kind: AppErrorKind.malformedResponse,
        safeMessage: 'Поток AI завершился неполным событием.',
        code: 'malformed_sse',
      );
    }
  }

  AiStreamEvent _parseFrame(String frame) {
    int? id;
    String? type;
    final List<String> data = <String>[];
    for (final String line in frame.split('\n')) {
      final int separator = line.indexOf(':');
      final String field = separator < 0 ? line : line.substring(0, separator);
      final String value = separator < 0
          ? ''
          : line.substring(separator + 1).replaceFirst(RegExp(r'^ '), '');
      switch (field) {
        case 'id':
          id = int.tryParse(value);
        case 'event':
          type = value;
        case 'data':
          data.add(value);
      }
    }
    if (type == null || !_eventTypes.contains(type)) {
      throw const AppError(
        kind: AppErrorKind.schemaMismatch,
        safeMessage: 'Получен неизвестный тип события AI.',
        code: 'unknown_ai_event',
      );
    }
    if (type != 'close' && id == null) {
      throw const AppError(
        kind: AppErrorKind.malformedResponse,
        safeMessage: 'Событие AI не содержит номера.',
        code: 'missing_event_id',
      );
    }
    Object? decoded;
    final String encodedData = data.join('\n');
    if (utf8.encode(encodedData).length > maxEventDataBytes) {
      throw const AppError(
        kind: AppErrorKind.malformedResponse,
        safeMessage: 'Данные события AI превысили безопасный размер.',
        code: 'sse_data_too_large',
      );
    }
    try {
      decoded = jsonDecode(encodedData);
    } on FormatException {
      throw const AppError(
        kind: AppErrorKind.malformedResponse,
        safeMessage: 'Событие AI повреждено.',
        code: 'invalid_event_json',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AppError(
        kind: AppErrorKind.malformedResponse,
        safeMessage: 'Событие AI имеет неверный формат.',
        code: 'invalid_event_payload',
      );
    }
    return AiStreamEvent(
      id: id,
      type: type,
      payload: decoded.cast<String, Object?>(),
    );
  }
}
