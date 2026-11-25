import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jejaku/features/auth/models/auth_session.dart';
import 'package:jejaku/features/auth/services/auth_session_codec.dart';
import 'package:jejaku/features/auth/services/session_store.dart';

/// Keeps the session in the platform keystore (iOS Keychain, Android
/// Keystore-backed encrypted storage) through `flutter_secure_storage`.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    AuthSessionCodec codec = const AuthSessionCodec(),
  })  : _storage = storage,
        _codec = codec;

  static const _key = 'jezaku.auth.session';

  final FlutterSecureStorage _storage;
  final AuthSessionCodec _codec;

  @override
  bool get isPersistent => true;

  @override
  Future<AuthSession?> read() async {
    try {
      return _codec.decode(await _storage.read(key: _key));
    } on Object {
      // A keystore that cannot be read (restored backup, changed device
      // lock) means signing in again, not a crash.
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    try {
      await _storage.write(key: _key, value: _codec.encode(session));
    } on Object {
      // Best effort: the session still works until the app closes.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // Best effort.
    }
  }
}
