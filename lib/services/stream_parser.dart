import 'dart:convert';

/// Turns a byte stream from an AI server into plain text deltas.
///
/// Understands the common local-server shapes:
///  * OpenAI SSE: `data: {"choices":[{"delta":{"content":"Hi"}}]}`
///  * Ollama chat: `{"message":{"content":"Hi"},"done":false}`
///  * Ollama generate: `{"response":"Hi"}`
///  * Plain text chunks
///
/// The parser is deliberately tolerant: unknown JSON is ignored and
/// non-JSON payloads are passed through, so it keeps working with servers
/// that invent their own format.
class StreamParser {
  StreamParser({this.rawMode = false});

  /// When true (a `text/plain` response), chunks are emitted untouched.
  final bool rawMode;

  final StringBuffer _buffer = StringBuffer();
  bool done = false;
  String? errorMessage;

  /// Feeds a decoded chunk and returns any text deltas it completed.
  List<String> add(String chunk) {
    if (rawMode) return chunk.isEmpty ? const [] : [chunk];

    _buffer.write(chunk);
    var text = _buffer.toString();
    final deltas = <String>[];

    while (!done) {
      final newline = text.indexOf('\n');
      if (newline == -1) break;
      var line = text.substring(0, newline);
      text = text.substring(newline + 1);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      _handleLine(line, deltas);
    }

    _buffer
      ..clear()
      ..write(done ? '' : text);
    return deltas;
  }

  /// Handles a final line that arrived without a trailing newline.
  List<String> flush() {
    if (rawMode || done) return const [];
    final rest = _buffer.toString().trim();
    _buffer.clear();
    if (rest.isEmpty) return const [];
    final deltas = <String>[];
    _handleLine(rest, deltas);
    return deltas;
  }

  void _handleLine(String line, List<String> deltas) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return;
    // SSE comments and non-data fields.
    if (trimmed.startsWith(':') ||
        trimmed.startsWith('event:') ||
        trimmed.startsWith('id:') ||
        trimmed.startsWith('retry:')) {
      return;
    }

    final isDataField = trimmed.startsWith('data:');
    final payload = isDataField ? trimmed.substring(5).trim() : trimmed;
    if (payload.isEmpty) return;
    if (payload == '[DONE]') {
      done = true;
      return;
    }

    if (payload.startsWith('{') || payload.startsWith('[')) {
      try {
        final decoded = jsonDecode(payload);
        final error = _extractError(decoded);
        if (error != null) {
          errorMessage = error;
          done = true;
          return;
        }
        final text = _extractText(decoded);
        if (text != null && text.isNotEmpty) deltas.add(text);
        return;
      } on FormatException {
        // Not JSON after all — fall through and treat it as text.
      }
    }

    // Raw text. SSE data keeps its exact bytes; bare lines keep their newline.
    deltas.add(isDataField ? payload : '$payload\n');
  }

  String? _extractText(Object? decoded) {
    if (decoded is String) return decoded;
    if (decoded is! Map) return null;

    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final choice = choices.first;
      if (choice is Map) {
        final delta = choice['delta'];
        if (delta is Map && delta['content'] is String) {
          return delta['content'] as String;
        }
        if (delta is String) return delta;
        final message = choice['message'];
        if (message is Map && message['content'] is String) {
          return message['content'] as String;
        }
        if (choice['text'] is String) return choice['text'] as String;
      }
    }

    // Ollama's native /api/chat shape.
    final message = decoded['message'];
    if (message is Map && message['content'] is String) {
      return message['content'] as String;
    }

    for (final key in const ['response', 'content', 'token', 'delta', 'text']) {
      final value = decoded[key];
      if (value is String) return value;
    }
    return null;
  }

  String? _extractError(Object? decoded) {
    if (decoded is! Map) return null;
    final error = decoded['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    if (error is Map && error['message'] is String) {
      return (error['message'] as String).trim();
    }
    return null;
  }
}
