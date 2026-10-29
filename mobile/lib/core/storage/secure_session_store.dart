import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String value);
  Future<void> clear();
}

final class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _refreshKey = 'pilot_refresh_token_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> writeRefreshToken(String value) async {
    if (value.isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'Refresh token must not be empty.',
      );
    }
    await _storage.write(key: _refreshKey, value: value);
  }

  @override
  Future<void> clear() => _storage.deleteAll();
}

final class MemorySessionStore implements SessionStore {
  String? _refreshToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> writeRefreshToken(String value) async {
    _refreshToken = value;
  }

  @override
  Future<void> clear() async {
    _refreshToken = null;
  }
}
