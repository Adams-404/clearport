import 'chat_message.dart';

/// A saved chat thread.
class Conversation {
  Conversation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.title = 'New chat',
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  final String id;
  final DateTime createdAt;
  DateTime updatedAt;
  String title;
  final List<ChatMessage> messages;

  bool get isEmpty => messages.isEmpty;

  /// First user line, trimmed to something that fits in a list row.
  String get preview {
    for (final message in messages.reversed) {
      if (message.isUser) {
        final line = message.content.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (line.isNotEmpty) return line;
      }
    }
    return 'Empty conversation';
  }

  void touch() => updatedAt = DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  static Conversation fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();
    final messages = (json['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return Conversation(
      id: json['id'] as String? ?? created.microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'New chat',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created,
      messages: messages,
    );
  }
}
