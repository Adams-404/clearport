import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import 'stream_parser.dart';

enum ServerHealth { unknown, checking, online, reachable, offline }

enum ServerIssue {
  none,
  connectionRefused,
  timeout,
  unauthorized,
  endpointNotFound,
  noModels,
  httpError,
  unreachable,
}

class ServerStatus {
  const ServerStatus({
    required this.health,
    this.model,
    this.models = const [],
    this.message,
    this.hint,
    this.endpoint,
    this.issue = ServerIssue.none,
  });

  final ServerHealth health;
  final String? model;
  final List<String> models;
  final String? message;
  final String? hint;
  final String? endpoint;
  final ServerIssue issue;

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

  /// Probes the OpenAI-compatible model endpoint and returns actionable diagnostics.
  Future<ServerStatus> checkStatus({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endpoint = _safeEndpoint(modelsUri);
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
        if (models.isEmpty) {
          return ServerStatus(
            health: ServerHealth.reachable,
            issue: ServerIssue.noModels,
            endpoint: endpoint,
            message: 'The server responded, but it did not report any models.',
            hint: 'Load a model in llama.cpp, then check that the server exposes '
                'the OpenAI-compatible /v1/models endpoint.',
          );
        }
        return ServerStatus(
          health: ServerHealth.online,
          models: models,
          model: models.first,
          endpoint: endpoint,
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ServerStatus(
          health: ServerHealth.reachable,
          issue: ServerIssue.unauthorized,
          endpoint: endpoint,
          message: 'The server is reachable, but it rejected the API key.',
          hint: 'Check the API key in Clearport, or remove it if your local '
              'server does not require authentication.',
        );
      }
      if (response.statusCode == 404) {
        return ServerStatus(
          health: ServerHealth.reachable,
          issue: ServerIssue.endpointNotFound,
          endpoint: endpoint,
          message: 'The server responded, but the /models endpoint was not found.',
          hint: 'For llama.cpp, start llama-server with its OpenAI-compatible '
              'API and use the base URL ending in /v1, not /v1/models.',
        );
      }
      return ServerStatus(
        health: ServerHealth.reachable,
        issue: ServerIssue.httpError,
        endpoint: endpoint,
        message: 'The server responded with HTTP ${response.statusCode}.',
        hint: 'Check the server log for the HTTP error and confirm that the '
            'configured URL points to the API server.',
      );
    } on TimeoutException {
      return ServerStatus(
        health: ServerHealth.offline,
        issue: ServerIssue.timeout,
        endpoint: endpoint,
        message: 'The server did not respond within ${timeout.inSeconds} seconds.',
        hint: 'Confirm the server is running and listening on the configured '
            'port. Check that the phone and host can reach each other.',
      );
    } on SocketException catch (error) {
      final refused = error.osError?.errorCode == 111 ||
          error.osError?.errorCode == 61 ||
          error.osError?.errorCode == 10061;
      return ServerStatus(
        health: ServerHealth.offline,
        issue: refused ? ServerIssue.connectionRefused : ServerIssue.unreachable,
        endpoint: endpoint,
        message: refused
            ? 'The connection was refused. Nothing is accepting connections at this address.'
            : 'Could not reach the server. ${error.osError?.message ?? error.message}',
        hint: refused
            ? 'Start llama-server in Termux and confirm its port. If it runs on '
                'another device, use that device’s LAN IP instead of 127.0.0.1.'
            : 'Check the host address, port, Wi-Fi connection and firewall. '
                'On Android, 127.0.0.1 refers to the phone itself.',
      );
    } on HttpException catch (error) {
      return ServerStatus(
        health: ServerHealth.offline,
        issue: ServerIssue.unreachable,
        endpoint: endpoint,
        message: 'The HTTP connection failed: ${error.message}',
        hint: 'Check the server address and confirm that it speaks HTTP.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String _safeEndpoint(Uri uri) {
    // Never display URL credentials, query parameters or fragments.
    return uri.replace(userInfo: '', query: null, fragment: null).toString();
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
        if (settings.maxOutputTokens != null && settings.maxOutputTokens! >= 1 && settings.maxOutputTokens! <= 32768) 'max_tokens': settings.maxOutputTokens,
        if (settings.topP != null && settings.topP! >= 0 && settings.topP! <= 1) 'top_p': settings.topP,
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
