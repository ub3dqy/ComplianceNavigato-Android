import 'dart:async';

final class SessionSignals {
  final StreamController<void> _invalidated =
      StreamController<void>.broadcast();

  Stream<void> get invalidated => _invalidated.stream;

  void notifyInvalidated() {
    if (!_invalidated.isClosed) {
      _invalidated.add(null);
    }
  }

  Future<void> dispose() => _invalidated.close();
}
