import 'dart:convert';

/// Turns a byte stream from an AI server into plain text deltas.
///
/// Understands OpenAI-compatible SSE, Ollama's newline-delimited JSON shapes,
/// and plain text lines. Input chunks may end at any byte-decoding boundary.
class StreamParser {
  StreamParser({this.rawMode = false});

  /// When true (a `text/plain` response), chunks are emitted untouched.
  final bool rawMode;

  final StringBuffer _buffer = StringBuffer();
  final List<String> _sseData = [];
  bool done = false;
  String? errorMessage;

  /// Feeds a decoded chunk and returns any text deltas from completed records.
  List<String> add(String chunk) {
    if (rawMode) return chunk.isEmpty ? const [] : [chunk];

    _buffer.write(chunk);
    var input = _buffer.toString();
    final deltas = <String>[];

    while (!done) {
      final newline = input.indexOf('\n');
      if (newline == -1) break;
      var line = input.substring(0, newline);
      input = input.substring(newline + 1);
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      _handleLine(line, deltas);
    }

    _buffer
      ..clear()
      ..write(done ? '' : input);
    return deltas;
  }

  /// Processes a final unterminated line and any pending SSE event.
  List<String> flush() {
    if (rawMode || done) return const [];
    final deltas = <String>[];
    final rest = _buffer.toString();
    _buffer.clear();
    if (rest.isNotEmpty) _handleLine(rest, deltas);
    if (!done) _dispatchSseEvent(deltas);
    return deltas;
  }

  void _handleLine(String line, List<String> deltas) {
    if (line.isEmpty) {
      _dispatchSseEvent(deltas);
      return;
    }

    // SSE comments and metadata fields do not contribute to the data payload.
    if (line.startsWith(':')) return;
    if (line.startsWith('data:')) {
      var value = line.substring(5);
      // The SSE grammar removes at most one optional leading space.
      if (value.startsWith(' ')) value = value.substring(1);
      _sseData.add(value);
      return;
    }
    if (line.startsWith('event:') ||
        line.startsWith('id:') ||
        line.startsWith('retry:')) {
      return;
    }

    // A non-SSE line is a standalone Ollama JSON or plain-text record.
    // Flush any preceding SSE event first, preserving stream order.
    _dispatchSseEvent(deltas);
    if (done) return;
    _processPayload(line, false, deltas);
  }

  void _dispatchSseEvent(List<String> deltas) {
    if (_sseData.isEmpty) return;
    final payload = _sseData.join('\n');
    _sseData.clear();
    _processPayload(payload, true, deltas);
  }

  void _processPayload(String payload, bool isSseData, List<String> deltas) {
    if (payload.isEmpty) return;
    if (payload == '[DONE]') {
      done = true;
      _buffer.clear();
      _sseData.clear();
      return;
    }

    if (payload.startsWith('{') || payload.startsWith('[')) {
      try {
        final decoded = jsonDecode(payload);
        final error = _extractError(decoded);
        if (error != null) {
          errorMessage = error;
          done = true;
          _buffer.clear();
          _sseData.clear();
          return;
        }
        final text = _extractText(decoded);
        if (text != null && text.isNotEmpty) deltas.add(text);
        return;
      } on FormatException {
        // Not JSON after all: pass the original payload through as text.
      }
    }

    deltas.add(isSseData ? payload : '$payload\n');
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
