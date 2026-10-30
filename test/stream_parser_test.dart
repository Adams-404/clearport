import 'package:clearport/models/app_settings.dart';
import 'package:clearport/services/stream_parser.dart';
import 'package:clearport/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamParser', () {
    test('parses OpenAI SSE deltas split across chunks', () {
      final parser = StreamParser();
      expect(parser.add('data: {"choices":[{"delta":{"content":"Hel'), isEmpty);
      expect(
        parser.add(
          'lo"}}]}\n\ndata: {"choices":[{"delta":{"content":"!"}}]}\n\n',
        ),
        ['Hello', '!'],
      );
    });

    test('stops at [DONE]', () {
      final parser = StreamParser();
      final deltas = parser.add(
        'data: {"choices":[{"delta":{"content":"Hi"}}]}\n'
        'data: [DONE]\n'
        'data: {"choices":[{"delta":{"content":"ignored"}}]}\n',
      );
      expect(deltas, ['Hi']);
      expect(parser.done, isTrue);
    });

    test('joins multiple data fields into one SSE event', () {
      final parser = StreamParser();
      expect(
        parser.add('data: {"choices":[\n' 'data: {"delta":{"content":"joined"}}]}\n\n'),
        ['joined'],
      );
    });

    test('waits for the event boundary across arbitrary chunk splits', () {
      final parser = StreamParser();
      expect(parser.add('data: {"response":"par'), isEmpty);
      expect(parser.add('tial"}\r'), isEmpty);
      expect(parser.add('\n\r'), isEmpty);
      expect(parser.add('\n'), ['partial']);
    });

    test('ignores comments and SSE metadata fields', () {
      final parser = StreamParser();
      expect(
        parser.add(': keepalive\nevent: message\nid: 7\nretry: 1000\ndata: ok\n\n'),
        ['ok'],
      );
    });

    test('understands Ollama native shapes', () {
      final parser = StreamParser();
      expect(
        parser.add(
          '{"message":{"role":"assistant","content":"Hey"},"done":false}\n',
        ),
        ['Hey'],
      );
      expect(parser.add('{"response":" there"}\n'), [' there']);
    });

    test('passes through plain text lines', () {
      final parser = StreamParser();
      expect(parser.add('hello\n'), ['hello\n']);
    });

    test('surfaces an error payload', () {
      final parser = StreamParser();
      final deltas = parser.add(
        'data: {"error":{"message":"model not found"}}\n\n',
      );
      expect(deltas, isEmpty);
      expect(parser.errorMessage, 'model not found');
      expect(parser.done, isTrue);
    });

    test('raw mode emits chunks untouched', () {
      final parser = StreamParser(rawMode: true);
      expect(parser.add('partial '), ['partial ']);
    });

    test('flushes a final line without a newline', () {
      final parser = StreamParser();
      parser.add('data: {"choices":[{"delta":{"content":"tail"}}]}');
      expect(parser.flush(), ['tail']);
    });
  });

  group('AppSettings.normalizeBaseUrl', () {
    test('keeps a clean base URL', () {
      expect(
        AppSettings.normalizeBaseUrl('http://127.0.0.1:8080/v1'),
        'http://127.0.0.1:8080/v1',
      );
    });

    test('trims a pasted chat-completions path', () {
      expect(
        AppSettings.normalizeBaseUrl(
          'http://127.0.0.1:8080/v1/chat/completions/',
        ),
        'http://127.0.0.1:8080/v1',
      );
    });

    test('adds a scheme and removes trailing slashes', () {
      expect(
        AppSettings.normalizeBaseUrl('192.168.1.20:8080/v1//'),
        'http://192.168.1.20:8080/v1',
      );
    });

    test('falls back to the default when empty', () {
      expect(AppSettings.normalizeBaseUrl('   '), AppSettings.defaultBaseUrl);
    });
  });

  group('titleFromMessage', () {
    test('collapses whitespace and truncates', () {
      expect(titleFromMessage('  hello \n  world '), 'hello world');
      expect(titleFromMessage('a' * 80).endsWith('…'), isTrue);
      expect(titleFromMessage('a' * 80).length, 45);
    });
  });
}
