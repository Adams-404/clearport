import 'package:clearport/services/secret_store.dart';
import 'package:clearport/services/store.dart';
import 'package:clearport/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FailingSecretStore implements SecretStore {
  @override
  Future<String?> read() async => throw StateError('Keystore unavailable');

  @override
  Future<void> write(String value) async =>
      throw StateError('Keystore unavailable');
}

void main() {
  group('secure API key migration', () {
    test(
      'moves a legacy key into secure storage and removes it from JSON',
      () async {
        final store = Store.memory({
          'version': 1,
          'settings': {
            'baseUrl': 'http://127.0.0.1:8080/v1',
            'apiKey': 'legacy-secret',
          },
          'activeId': null,
          'conversations': [],
        });
        final secrets = MemorySecretStore();
        final state = AppState(store: store, secretStore: secrets);
  
        await state.load();
  
        expect(state.settings.apiKey, 'legacy-secret');
        expect(secrets.value, 'legacy-secret');
        expect(state.secretStorageError, isNull);
        final saved = await store.read();
        final savedSettings = saved!['settings'] as Map<String, dynamic>;
        expect(savedSettings, isNot(contains('apiKey')));
      },
    );

    test(
      'keeps legacy JSON untouched when secure storage is unavailable',
      () async {
        final original = {
          'version': 1,
          'settings': {
            'baseUrl': 'http://127.0.0.1:8080/v1',
            'apiKey': 'legacy-secret',
          },
          'activeId': null,
          'conversations': [],
        };
        final store = Store.memory(original);
        final state = AppState(
          store: store,
          secretStore: _FailingSecretStore(),
        );
  
        await state.load();
  
        expect(state.settings.apiKey, 'legacy-secret');
        expect(state.secretStorageError, isNotNull);
        final saved = await store.read();
        expect(saved!['settings'], original['settings']);
      },
    );
  });
}
