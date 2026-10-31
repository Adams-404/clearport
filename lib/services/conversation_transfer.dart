import 'dart:convert';

import '../models/conversation.dart';

/// Portable, versioned backup format for Clearport conversations.
class ConversationTransfer {
  static const format = 'clearport.conversations';
  static const version = 1;

  /// Encodes one or more conversations in the documented backup envelope.
  static String encode(Iterable<Conversation> conversations) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'conversations': conversations.map((item) => item.toJson()).toList(),
    });
  }

  /// Decodes and validates the complete backup before returning any data.
  static List<Conversation> decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('This file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The backup must be a JSON object.');
    }
    if (decoded['format'] != format) {
      throw const FormatException(
        'This is not a Clearport conversation backup.',
      );
    }
    if (decoded['version'] != version) {
      throw FormatException(
        'Unsupported backup version: ${decoded['version'] ?? 'missing'}.',
      );
    }
    final raw = decoded['conversations'];
    if (raw is! List) {
      throw const FormatException('The backup has no conversations list.');
    }

    final ids = <String>{};
    final result = <Conversation>[];
    for (final item in raw) {
      if (item is! Map) {
        throw const FormatException('A conversation entry is malformed.');
      }
      final json = Map<String, dynamic>.from(item);
      final id = json['id'];
      final title = json['title'];
      final createdAt = json['createdAt'];
      final updatedAt = json['updatedAt'];
      final messages = json['messages'];
      if (id is! String || id.trim().isEmpty || !ids.add(id)) {
        throw const FormatException(
          'Conversation IDs must be unique and non-empty.',
        );
      }
      if (title is! String ||
          createdAt is! String ||
          DateTime.tryParse(createdAt) == null ||
          updatedAt is! String ||
          DateTime.tryParse(updatedAt) == null ||
          messages is! List) {
        throw const FormatException('A conversation contains invalid fields.');
      }
      for (final message in messages) {
        if (message is! Map ||
            message['id'] is! String ||
            (message['id'] as String).trim().isEmpty ||
            !const ['user', 'assistant'].contains(message['role']) ||
            message['content'] is! String ||
            message['createdAt'] is! String ||
            DateTime.tryParse(message['createdAt'] as String) == null ||
            (message['isError'] != null && message['isError'] is! bool)) {
          throw const FormatException('A message in the backup is malformed.');
        }
      }
      result.add(Conversation.fromJson(json));
    }
    return result;
  }
}
