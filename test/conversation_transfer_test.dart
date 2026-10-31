import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:clearport/models/chat_message.dart';
import 'package:clearport/models/conversation.dart';
import 'package:clearport/services/conversation_transfer.dart';

void main() {
  group('ConversationTransfer', () {
    final conversation = Conversation(
      id: 'chat-1',
      title: 'A saved chat',
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 3),
      messages: [
        ChatMessage(
          id: 'message-1',
          role: MessageRole.user,
          content: 'Hello',
          createdAt: DateTime.utc(2026, 1, 2, 1),
        ),
        ChatMessage(
          id: 'message-2',
          role: MessageRole.assistant,
          content: 'Hi there',
          createdAt: DateTime.utc(2026, 1, 2, 1, 1),
          isError: true,
        ),
      ],
    );

    test('round-trips conversations and message metadata', () {
      final restored = ConversationTransfer.decode(
        ConversationTransfer.encode([conversation]),
      );
      expect(restored, hasLength(1));
      expect(restored.single.id, conversation.id);
      expect(restored.single.title, conversation.title);
      expect(restored.single.createdAt, conversation.createdAt);
      expect(restored.single.updatedAt, conversation.updatedAt);
      expect(restored.single.messages, hasLength(2));
      expect(restored.single.messages.last.content, 'Hi there');
      expect(restored.single.messages.last.isError, isTrue);
    });

    test('supports an empty backup collection', () {
      expect(
        ConversationTransfer.decode(ConversationTransfer.encode([])),
        isEmpty,
      );
    });

    test('rejects invalid JSON and unknown formats', () {
      expect(() => ConversationTransfer.decode('{'), throwsFormatException);
      expect(
        () => ConversationTransfer.decode(
          jsonEncode({'format': 'other', 'version': 1, 'conversations': []}),
        ),
        throwsFormatException,
      );
    });

    test('rejects unsupported versions and malformed conversations', () {
      expect(
        () => ConversationTransfer.decode(
          jsonEncode({
            'format': ConversationTransfer.format,
            'version': 99,
            'conversations': [],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => ConversationTransfer.decode(
          jsonEncode({
            'format': ConversationTransfer.format,
            'version': 1,
            'conversations': [
              {'id': 'x'},
            ],
          }),
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate conversation IDs and malformed messages', () {
      final valid = conversation.toJson();
      expect(
        () => ConversationTransfer.decode(
          jsonEncode({
            'format': ConversationTransfer.format,
            'version': 1,
            'conversations': [valid, valid],
          }),
        ),
        throwsFormatException,
      );
      final invalid = conversation.toJson()
        ..['messages'] = [
          {
            'id': 'm',
            'role': 'system',
            'content': 'bad',
            'createdAt': '2026-01-01',
          },
        ];
      expect(
        () => ConversationTransfer.decode(
          jsonEncode({
            'format': ConversationTransfer.format,
            'version': 1,
            'conversations': [invalid],
          }),
        ),
        throwsFormatException,
      );
    });
  });
}
