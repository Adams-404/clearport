enum MessageRole {
  user,
  assistant;

  String get wireName => name;

  static MessageRole fromWire(String? value) =>
      value == 'user' ? MessageRole.user : MessageRole.assistant;
}

/// A single message in a conversation.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.isError = false,
  });

  final String id;
  final MessageRole role;
  String content;
  final DateTime createdAt;

  /// Set when the server could not answer; the bubble renders it as an
  /// inline error with a retry action.
  bool isError;

  bool get isUser => role == MessageRole.user;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.wireName,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    if (isError) 'isError': true,
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    id:
        json['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString(),
    role: MessageRole.fromWire(json['role'] as String?),
    content: json['content'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    isError: json['isError'] as bool? ?? false,
  );
}
