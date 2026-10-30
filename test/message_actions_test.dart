import 'package:clearport/models/app_settings.dart';
import 'package:clearport/models/chat_message.dart';
import 'package:clearport/services/chat_api.dart';
import 'package:clearport/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingApi extends ChatApi {
  _RecordingApi(this.requests) : super(baseUrl: 'http://127.0.0.1:8080/v1');
  final List<List<ChatMessage>> requests;

  @override
  Future<ServerStatus> checkStatus({Duration timeout = const Duration(seconds: 5)}) async =>
      const ServerStatus(health: ServerHealth.online);

  @override
  Future<void> streamChat({
    required AppSettings settings,
    required List<ChatMessage> messages,
    required void Function(String delta) onDelta,
    CancelToken? token,
  }) async {
    requests.add(List.of(messages));
    onDelta('fresh reply');
  }
}

void main() {
  test('editing a user message removes the invalidated tail and regenerates', () async {
    final requests = <List<ChatMessage>>[];
    final state = AppState(apiFactory: (_) => _RecordingApi(requests));
    await state.load();

    await state.send('first prompt');
    await state.send('second prompt');
    final conversation = state.activeConversation!;
    final firstUser = conversation.messages.first;

    await state.editMessage(firstUser.id, 'edited prompt');

    expect(conversation.messages.map((m) => m.content).toList(),
        ['edited prompt', 'fresh reply']);
    expect(requests.last.map((m) => m.content).toList(), ['edited prompt']);
    expect(conversation.messages.first.isUser, isTrue);
    state.dispose();
  });

  test('editing rejects missing or assistant message IDs', () async {
    final state = AppState(apiFactory: (_) => _RecordingApi([]));
    await state.load();
    await state.send('prompt');
    final conversation = state.activeConversation!;
    final before = conversation.messages.map((m) => m.content).toList();

    await state.editMessage('missing', 'replacement');
    await state.editMessage(conversation.messages.last.id, 'replacement');

    expect(conversation.messages.map((m) => m.content).toList(), before);
    state.dispose();
  });

  test('regenerate replaces only the latest assistant response', () async {
    final requests = <List<ChatMessage>>[];
    final state = AppState(apiFactory: (_) => _RecordingApi(requests));
    await state.load();
    await state.send('first');
    await state.send('second');
    final conversation = state.activeConversation!;

    await state.regenerate();

    expect(conversation.messages.map((m) => m.content).toList(),
        ['first', 'fresh reply', 'second', 'fresh reply']);
    expect(requests.last.map((m) => m.content).toList(), ['first', 'fresh reply', 'second']);
    state.dispose();
  });
}
