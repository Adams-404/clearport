import 'dart:async';
import 'dart:convert';

import 'package:clearport/models/app_settings.dart';
import 'package:clearport/services/store.dart';
import 'package:clearport/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _DelayedStore implements Store {
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  final secondWriteStarted = Completer<void>();
  final snapshots = <Map<String, dynamic>>[];

  int activeWrites = 0;
  int maxConcurrentWrites = 0;

  @override
  Future<Map<String, dynamic>?> read() async => null;

  @override
  Future<void> write(Map<String, dynamic> data) async {
    // Copy the map to model a store that consumes the supplied snapshot.
    snapshots.add(jsonDecode(jsonEncode(data)) as Map<String, dynamic>);
    activeWrites++;
    if (activeWrites > maxConcurrentWrites) {
      maxConcurrentWrites = activeWrites;
    }

    try {
      if (snapshots.length == 1) {
        firstWriteStarted.complete();
        await releaseFirstWrite.future;
      } else if (snapshots.length == 2) {
        secondWriteStarted.complete();
      }
    } finally {
      activeWrites--;
    }
  }
}

void main() {
  test('serializes writes and preserves each requested snapshot', () async {
    final store = _DelayedStore();
    final state = AppState(store: store);

    state.updateSettings(const AppSettings(model: 'first-model'));
    state.flush();

    state.updateSettings(const AppSettings(model: 'second-model'));
    state.flush();

    await store.firstWriteStarted.future;
    expect(store.snapshots, hasLength(1));
    expect(
      (store.snapshots.first['settings'] as Map<String, dynamic>)['model'],
      'first-model',
    );

    // The second write is queued while the first one is still pending.
    expect(store.activeWrites, 1);
    expect(store.secondWriteStarted.isCompleted, isFalse);

    store.releaseFirstWrite.complete();
    await store.secondWriteStarted.future;

    expect(store.maxConcurrentWrites, 1);
    expect(store.snapshots, hasLength(2));
    expect(
      (store.snapshots.last['settings'] as Map<String, dynamic>)['model'],
      'second-model',
    );

    state.dispose();
  });
}
