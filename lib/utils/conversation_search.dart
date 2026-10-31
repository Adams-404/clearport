import '../models/conversation.dart';

/// Filters conversations by title or message content, newest activity first.
List<Conversation> searchConversations(
  Iterable<Conversation> conversations,
  String query,
) {
  final needle = query.trim().toLowerCase();
  final matches = conversations.where((conversation) {
    if (needle.isEmpty) return !conversation.isEmpty;
    if (conversation.title.toLowerCase().contains(needle)) return true;
    return conversation.messages.any(
      (message) => message.content.toLowerCase().contains(needle),
    );
  }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return matches;
}
