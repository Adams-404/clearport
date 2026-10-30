import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import 'stream_parser.dart';

enum ServerHealth { unknown, checking, online, reachable, offline }

class ServerStatus {
  const ServerStatus({
    required this.health,
    this.model,
    this.models = const [],
    this.message,
  });

  final ServerHealth health;

  /// First model reported by the server, if any.
  final String? model;
  final List<String> models;

  /// Detail for the "reachable but not healthy" states.
  final String? message;

  bool get isOnline => health == ServerHealth.online;
}

/// Lets the UI abort an in-flight request instantly.
class CancelToken {
  bool cancelled = false;
  void Function()? _onCancel;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    _onCancel?.call();
  }

  void _bind(void Function() callback) {
    _onCancel = callback;
    // Cancellation may happen before the HTTP client is attached.
    if (cancelled) callback();
  }
}

class ChatApiException implements Exception {
  ChatApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Minimal OpenAI-compatible client for a local AI server.
class ChatApi {
  ChatApi({required String baseUrl, String apiKey = ''})
    : baseUrl = AppSettings.normalizeBaseUrl(baseUrl),
      apiKey = apiKey.trim();

  final String baseUrl;
  final String apiKey;

  Uri get chatUri => Uri.parse('$baseUrl/chat/completions');
  Uri get modelsUri => Uri.parse('$baseUrl/models');

  /// Probes `/models` to drive the status indicator.
  Future<ServerStatus> checkStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(modelsUri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (apiKey.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }
      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);

      if (response.statusCode == 200) {
        final models = _parseModels(body);
        return ServerStatus(
          health: ServerHealth.online,
          models: models,
          model: models.isEmpty ? null : models.first,
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ServerStatus(
          health: ServerHealth.reachable,
          message: 'Server is up, but the API key was rejected.',
        );
      }
      return ServerStatus(
        health: ServerHealth.reachable,
        message:
            'Server responded (HTTP ${response.statusCode}) '
            'but /models is unavailable.',
      );
    } on TimeoutException {
      return const ServerStatus(
        health: ServerHealth.offline,
        message: 'The server did not respond in time.',
      );
    } on SocketException catch (error) {
      return ServerStatus(
        health: ServerHealth.offline,
        message: _socketMessage(error),
      );
    } on HttpException catch (error) {
      return ServerStatus(health: ServerHealth.offline, message: error.message);
    } finally {
      client.close(force: true);
    }
  }

  /// Streams a completion, calling [onDelta] with each text fragment.
  ///
  /// The future completes when the stream ends. Cancelling [token] closes the
  /// socket immediately and completes normally.
  Future<void> streamChat({
    required AppSettings settings,
    required List<ChatMessage> messages,
    required void Function(String delta) onDelta,
    CancelToken? token,
  }) async {
    if (token?.cancelled ?? false) return;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    token?._bind(() => client.close(force: true));

    try {
      if (token?.cancelled ?? false) return;
      final request = await client.postUrl(chatUri);
      if (token?.cancelled ?? false) return;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      if (apiKey.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      }

      final payload = <String, dynamic>{
        'stream': true,
        'temperature': settings.temperature,
        if (settings.model.trim().isNotEmpty) 'model': settings.model.trim(),
        'messages': [
          if (settings.systemPrompt.trim().isNotEmpty)
            {'role': 'system', 'content': settings.systemPrompt.trim()},
          for (final message in messages)
            {'role': message.role.wireName, 'content': message.content},
        ],
      };
      request.write(jsonEncode(payload));
      if (token?.cancelled ?? false) return;

      final response = await request.close();
      if (token?.cancelled ?? false) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.transform(utf8.decoder).join();
        throw ChatApiException(
          _describeHttpError(response.statusCode, body),
          statusCode: response.statusCode,
        );
      }

      final mime = response.headers.contentType?.mimeType ?? '';
      final parser = StreamParser(rawMode: mime == 'text/plain');

      // This is an idle timeout: it resets whenever the server emits data.
      // A quiet stream lasting 120 seconds is treated as an unresponsive server.
      await for (final chunk
          in response
              .transform(utf8.decoder)
              .timeout(const Duration(seconds: 120))) {
        if (token?.cancelled ?? false) break;
        for (final delta in parser.add(chunk)) {
          onDelta(delta);
        }
        if (parser.done) break;
      }

      if (!(token?.cancelled ?? false) && !parser.done) {
        for (final delta in parser.flush()) {
          onDelta(delta);
        }
      }
      if (parser.errorMessage != null && !(token?.cancelled ?? false)) {
        throw ChatApiException(parser.errorMessage!);
      }
    } on SocketException catch (error) {
      if (token?.cancelled ?? false) return;
      throw ChatApiException(_socketMessage(error));
    } on TimeoutException {
      if (token?.cancelled ?? false) return;
      throw ChatApiException(
        'The server stopped responding. Is it still running?',
      );
    } on HttpException catch (error) {
      if (token?.cancelled ?? false) return;
      throw ChatApiException(error.message);
    } on HandshakeException catch (error) {
      if (token?.cancelled ?? false) return;
      throw ChatApiException('TLS handshake failed: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  List<String> _parseModels(String body) {
    try {
      final decoded = jsonDecode(body);
      final raw = switch (decoded) {
        {'data': final List data} => data,
        {'models': final List models} => models,
        final List list => list,
        _ => const [],
      };
      final names = <String>[];
      for (final entry in raw) {
        if (entry is Map) {
          final id = entry['id'] ?? entry['name'] ?? entry['model'];
          if (id is String && id.trim().isNotEmpty) names.add(id.trim());
        } else if (entry is String && entry.trim().isNotEmpty) {
          names.add(entry.trim());
        }
      }
      return names;
    } catch (_) {
      return const [];
    }
  }

  String _describeHttpError(int status, String body) {
    var detail = body.trim();
    if (detail.startsWith('{')) {
      try {
        final decoded = jsonDecode(detail);
        if (decoded is Map) {
          final error = decoded['error'];
          if (error is String) {
            detail = error;
          } else if (error is Map && error['message'] is String) {
            detail = error['message'] as String;
          } else if (decoded['message'] is String) {
            detail = decoded['message'] as String;
          }
        }
      } catch (_) {
        // Keep the raw body.
      }
    }
    if (detail.length > 240) detail = '${detail.substring(0, 240)}…';
    final hint = status == 404
        ? ' Check that the URL points at an OpenAI-compatible server (usually ending in /v1).'
        : '';
    return 'HTTP $status${detail.isEmpty ? '' : ' · $detail'}$hint';
  }

  String _socketMessage(SocketException error) {
    final reason = error.osError?.message ?? error.message;
    return 'Could not reach $baseUrl. $reason';
  }
}
