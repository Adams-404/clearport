import 'dart:async';

import 'package:clearport/models/app_settings.dart';
import 'package:clearport/models/chat_message.dart';
import 'package:clearport/services/chat_api.dart';
import 'package:clearport/services/store.dart';
import 'package:clearport/state/app_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Emits a few tokens, then holds the request open like a slow generation.
class _SlowApi extends ChatApi {
  _SlowApi() : super(baseUrl: 'http://127.0.0.1:8080/v1');

  final release = Completer<void>();

  @override
  Future<ServerStatus> checkStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      const ServerStatus(health: ServerHealth.online, model: 'gemma-3-1b-it');

  @override
  Future<void> streamChat({
    required AppSettings settings,
    required List<ChatMessage> messages,
    required void Function(String delta) onDelta,
    CancelToken? token,
  }) async {
    onDelta('The ghost');
    onDelta(' is still');
    await release.future;
    onDelta(' here.');
  }
}

Map<String, dynamic> _savedConversation({
  required String partial,
  required bool withEmptyPlaceholder,
}) => {
  'settings': const AppSettings().toJson(),
  'activeId': 'c1',
  'conversations': [
    {
      'id': 'c1',
      'title': 'Interrupted',
      'createdAt': '2026-10-30T10:00:00.000',
      'updatedAt': '2026-10-30T10:01:00.000',
      'messages': [
        {
          'id': 'm1',
          'role': 'user',
          'content': 'Are you there?',
          'createdAt': '2026-10-30T10:00:00.000',
        },
        {
          'id': 'm2',
          'role': 'assistant',
          'content': partial,
          'createdAt': '2026-10-30T10:00:30.000',
        },
        if (withEmptyPlaceholder)
          {
            'id': 'm3',
            'role': 'assistant',
            'content': '',
            'createdAt': '2026-10-30T10:01:00.000',
          },
      ],
    },
  ],
};

void main() {
  test(
    'a restart keeps a partial answer and drops an empty placeholder',
    () async {
      final store = Store.memory(
        _savedConversation(partial: 'The ghost is', withEmptyPlaceholder: true),
      );
      final state = AppState(store: store);
      await state.load();

      final messages = state.conversations.single.messages;
      expect(messages, hasLength(2));
      expect(messages.last.content, 'The ghost is');
      expect(state.isStreaming, isFalse);
      expect(state.streamingMessageId, isNull);
    },
  );

  test('a restart never restores a streaming state', () async {
    final store = Store.memory(
      _savedConversation(
        partial: 'Half an answer',
        withEmptyPlaceholder: false,
      ),
    );
    final state = AppState(store: store);
    await state.load();

    expect(state.isStreaming, isFalse);
    expect(state.activeConversation!.messages.last.content, 'Half an answer');
  });

  testWidgets('pausing flushes the tokens received so far', (tester) async {
    final api = _SlowApi();
    final store = Store.memory();
    final state = AppState(store: store, apiFactory: (_) => api);
    await state.load();
    state.start();

    await tester.pumpWidget(const SizedBox.shrink());

    unawaited(state.send('Tell me a story'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Android walks down through these states before pausing the process.
    for (final lifecycle in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(lifecycle);
    }

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final saved = await store.read();
    final conversations = saved!['conversations'] as List;
    final messages = (conversations.single as Map)['messages'] as List;
    final assistant = messages.last as Map;

    expect(assistant['content'], 'The ghost is still');
    expect(assistant['isError'], isNot(true));

    api.release.complete();
    await tester.pumpAndSettle();
    state.dispose();
  });
}
