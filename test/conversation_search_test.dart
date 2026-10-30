import 'package:flutter_test/flutter_test.dart';

import 'package:clearport/models/chat_message.dart';
import 'package:clearport/models/conversation.dart';
import 'package:clearport/utils/conversation_search.dart';

void main() {
  final older = Conversation(
    id: 'older',
    title: 'Project notes',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
    messages: [
      ChatMessage(
        id: 'm1',
        role: MessageRole.user,
        content: 'Explain vector databases',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
  final newer = Conversation(
    id: 'newer',
    title: 'Weekend ideas',
    createdAt: DateTime.utc(2026, 1, 3),
    updatedAt: DateTime.utc(2026, 1, 5),
    messages: [
      ChatMessage(
        id: 'm2',
        role: MessageRole.assistant,
        content: 'Try a local model with Flutter',
        createdAt: DateTime.utc(2026, 1, 3),
      ),
    ],
  );
  final empty = Conversation(
    id: 'empty',
    title: 'New chat',
    createdAt: DateTime.utc(2026, 1, 6),
    updatedAt: DateTime.utc(2026, 1, 6),
  );

  test('matches titles case-insensitively', () {
    expect(searchConversations([older, newer], 'PROJECT'), [older]);
  });

  test('matches message content case-insensitively', () {
    expect(searchConversations([older, newer], 'VECTOR DATABASES'), [older]);
  });

  test('trims query whitespace and returns newest activity first', () {
    expect(searchConversations([older, newer], '  '), [newer, older]);
  });

  test('returns no results for unmatched text', () {
    expect(searchConversations([older, newer], 'not present'), isEmpty);
  });

  test('does not include empty drafts in history results', () {
    expect(searchConversations([empty, older], ''), [older]);
  });
}
