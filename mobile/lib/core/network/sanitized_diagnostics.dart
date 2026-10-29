import 'dart:collection';

final class DiagnosticEntry {
  const DiagnosticEntry({
    required this.timestamp,
    required this.method,
    required this.path,
    this.statusCode,
    this.errorCode,
  });

  final DateTime timestamp;
  final String method;
  final String path;
  final int? statusCode;
  final String? errorCode;
}

final class SanitizedDiagnostics {
  SanitizedDiagnostics({this.limit = 100});

  final int limit;
  final Queue<DiagnosticEntry> _entries = Queue<DiagnosticEntry>();

  List<DiagnosticEntry> get entries =>
      List<DiagnosticEntry>.unmodifiable(_entries);

  void record({
    required String method,
    required Uri uri,
    int? statusCode,
    String? errorCode,
  }) {
    final String path = uri.path.startsWith('/api/v1/')
        ? uri.path
        : '/api/v1/unknown';
    _entries.addLast(
      DiagnosticEntry(
        timestamp: DateTime.now().toUtc(),
        method: method.toUpperCase(),
        path: path,
        statusCode: statusCode,
        errorCode: _safeCode(errorCode),
      ),
    );
    while (_entries.length > limit) {
      _entries.removeFirst();
    }
  }

  void clear() => _entries.clear();

  static String? _safeCode(String? value) {
    if (value == null) {
      return null;
    }
    return RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(value)
        ? value
        : 'request_failed';
  }
}
