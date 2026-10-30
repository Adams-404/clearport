import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clearport/models/app_settings.dart';
import 'package:clearport/services/chat_api.dart';

void main() {
  test('sends configured generation controls and omits unset values', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<Map<String, dynamic>>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      received.complete(jsonDecode(body) as Map<String, dynamic>);
      request.response.headers.contentType = ContentType('text', 'event-stream');
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    try {
      final api = ChatApi(baseUrl: 'http://127.0.0.1:${server.port}/v1');
      await api.streamChat(
        settings: const AppSettings(maxOutputTokens: 256, topP: 0.75),
        messages: const [],
        onDelta: (_) {},
      );
      final payload = await received.future;
      expect(payload['max_tokens'], 256);
      expect(payload['top_p'], 0.75);
      expect(payload['temperature'], 0.7);
    } finally {
      await server.close(force: true);
    }
  });

  test('omits unset generation controls from request payload', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<Map<String, dynamic>>();
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      received.complete(jsonDecode(body) as Map<String, dynamic>);
      request.response.headers.contentType = ContentType('text', 'event-stream');
      request.response.write('data: [DONE]\n\n');
      await request.response.close();
    });

    try {
      await ChatApi(baseUrl: 'http://127.0.0.1:${server.port}/v1').streamChat(
        settings: const AppSettings(),
        messages: const [],
        onDelta: (_) {},
      );
      final payload = await received.future;
      expect(payload.containsKey('max_tokens'), isFalse);
      expect(payload.containsKey('top_p'), isFalse);
    } finally {
      await server.close(force: true);
    }
  });
}
