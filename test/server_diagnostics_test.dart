import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clearport/services/chat_api.dart';

Future<ServerStatus> probe(
  Future<void> Function(HttpRequest request) respond, {
  String apiKey = '',
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await respond(request);
  });
  try {
    return await ChatApi(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      apiKey: apiKey,
    ).checkStatus();
  } finally {
    await server.close(force: true);
  }
}

void main() {
  group('ChatApi connection diagnostics', () {
    test('identifies a rejected API key without exposing it', () async {
      final status = await probe((request) async {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
      }, apiKey: 'top-secret');

      expect(status.issue, ServerIssue.unauthorized);
      expect(status.message, contains('rejected the API key'));
      expect(status.endpoint, isNot(contains('top-secret')));
      expect(status.hint, isNotNull);
    });

    test('identifies a missing models endpoint', () async {
      final status = await probe((request) async {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      expect(status.issue, ServerIssue.endpointNotFound);
      expect(status.hint, contains('/v1'));
    });

    test('distinguishes a reachable server with no models', () async {
      final status = await probe((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'data': []}));
        await request.response.close();
      });

      expect(status.health, ServerHealth.reachable);
      expect(status.issue, ServerIssue.noModels);
      expect(status.endpoint, endsWith('/v1/models'));
    });

    test('reports a loaded model as online', () async {
      final status = await probe((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'data': [
              {'id': 'qwen2.5-1.5b'},
            ],
          }),
        );
        await request.response.close();
      });

      expect(status.health, ServerHealth.online);
      expect(status.model, 'qwen2.5-1.5b');
    });

    test('identifies a refused local connection', () async {
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();

      final status = await ChatApi(
        baseUrl: 'http://127.0.0.1:$port/v1',
      ).checkStatus();

      expect(status.health, ServerHealth.offline);
      expect(status.issue, ServerIssue.connectionRefused);
      expect(status.hint, contains('Start llama-server'));
    });

    test('redacts query parameters from the displayed endpoint', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'data': []}));
        await request.response.close();
      });
      try {
        final status = await ChatApi(
          baseUrl: 'http://127.0.0.1:${server.port}/v1?token=secret',
        ).checkStatus();
        expect(status.endpoint, isNot(contains('secret')));
      } finally {
        await server.close(force: true);
      }
    });
  });
}
