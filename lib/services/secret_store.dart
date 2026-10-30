import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores secrets using the platform's encrypted storage implementation.
abstract interface class SecretStore {
  Future<String?> read();
  Future<void> write(String value);
}

class FlutterSecretStore implements SecretStore {
  FlutterSecretStore()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
      );

  final FlutterSecureStorage _storage;
  static const _key = 'clearport.api_key';

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) async {
    if (value.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: value);
    }
  }
}

/// In-memory implementation for tests and non-platform state instances.
class MemorySecretStore implements SecretStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value.isEmpty ? null : value;
  }
}
