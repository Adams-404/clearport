import 'dart:convert';
import 'dart:io';

import 'package:clearport/models/app_settings.dart';
import 'package:clearport/models/chat_message.dart';
import 'package:clearport/services/chat_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local server integration', () {
    late HttpServer server;
    late String baseUrl;
    late Map<String, dynamic> receivedPayload;

    setUp(() async {
      receivedPayload = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}/v1';
      server.listen((request) async {
        if (request.uri.path == '/v1/models') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'data': [
                {'id': 'smoke-model'},
              ],
            }),
          );
          await request.response.close();
          return;
        }

        if (request.uri.path == '/v1/chat/completions') {
          receivedPayload = jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'text/event-stream',
          );
          request.response.write(
            'data: ${jsonEncode({'choices': [{'delta': {'content': 'Hello'}}]})}\n\n',
          );
          request.response.write(
            'data: ${jsonEncode({'choices': [{'delta': {'content': ' from Clearport'}}]})}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('discovers a model and completes a streamed chat request', () async {
      final api = ChatApi(baseUrl: baseUrl, apiKey: 'local-test-key');
      final status = await api.checkStatus();

      expect(status.health, ServerHealth.online);
      expect(status.models, ['smoke-model']);

      final deltas = <String>[];
      await api.streamChat(
        settings: const AppSettings(
          model: 'smoke-model',
          systemPrompt: 'Be concise.',
          temperature: 0.2,
          maxOutputTokens: 128,
          topP: 0.9,
        ),
        messages: [
          ChatMessage(
            id: 'user-1',
            role: MessageRole.user,
            content: 'Say hello.',
            createdAt: DateTime.utc(2026),
          ),
        ],
        onDelta: deltas.add,
      );

      expect(deltas.join(), 'Hello from Clearport');
      expect(receivedPayload['model'], 'smoke-model');
      expect(receivedPayload['stream'], isTrue);
      expect(receivedPayload['temperature'], 0.2);
      expect(receivedPayload['max_tokens'], 128);
      expect(receivedPayload['top_p'], 0.9);
      expect(receivedPayload['messages'], [
        {'role': 'system', 'content': 'Be concise.'},
        {'role': 'user', 'content': 'Say hello.'},
      ]);
    });
  });

  test('settings survive serialization with app preferences intact', () {
    const settings = AppSettings(
      baseUrl: 'http://127.0.0.1:8080/v1',
      model: 'smoke-model',
      apiKey: 'local-test-key',
      systemPrompt: 'Be concise.',
      temperature: 0.2,
      maxOutputTokens: 128,
      topP: 0.9,
      themeMode: ThemeMode.dark,
    );

    final restored = AppSettings.fromJson(
      jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
    );

    expect(restored.baseUrl, settings.baseUrl);
    expect(restored.model, settings.model);
    expect(restored.apiKey, settings.apiKey);
    expect(restored.systemPrompt, settings.systemPrompt);
    expect(restored.temperature, settings.temperature);
    expect(restored.maxOutputTokens, settings.maxOutputTokens);
    expect(restored.topP, settings.topP);
    expect(restored.themeMode, ThemeMode.dark);
  });

  test('Android allows cleartext only for loopback hosts', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    final networkConfig = await File(
      'android/app/src/main/res/xml/network_security_config.xml',
    ).readAsString();

    expect(
      manifest,
      contains('android:networkSecurityConfig="@xml/network_security_config"'),
    );
    expect(manifest, isNot(contains('android:usesCleartextTraffic="true"')));
    expect(
      networkConfig,
      contains('<domain includeSubdomains="false">127.0.0.1</domain>'),
    );
    expect(
      networkConfig,
      contains('<domain includeSubdomains="false">localhost</domain>'),
    );
    expect(
      networkConfig,
      contains('<base-config cleartextTrafficPermitted="false"'),
    );
  });
}
