import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/chat_api.dart';
import '../services/secret_store.dart';
import '../services/store.dart';
import '../utils/format.dart';

/// Owns settings, saved conversations, streaming state and server health.
class AppState extends ChangeNotifier {
  AppState({
    Store? store,
    SecretStore? secretStore,
    ChatApi Function(AppSettings settings)? apiFactory,
  }) : _store = store ?? Store.memory(),
       _secretStore = secretStore ?? MemorySecretStore(),
       _apiFactory =
           apiFactory ??
           ((settings) =>
               ChatApi(baseUrl: settings.baseUrl, apiKey: settings.apiKey));

  static const _persistDelay = Duration(milliseconds: 700);
  static const _streamFlushInterval = Duration(milliseconds: 45);

  final Store _store;
  final SecretStore _secretStore;
  bool _secretStorageReady = false;
  String? secretStorageError;
  final ChatApi Function(AppSettings settings) _apiFactory;

  AppSettings settings = const AppSettings();
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);
  final List<Conversation> conversations = [];
  String? activeId;

  ServerStatus status = const ServerStatus(health: ServerHealth.unknown);
  bool isStreaming = false;
  String? streamingMessageId;

  final StringBuffer _pending = StringBuffer();
  ChatMessage? _streamingMessage;
  Conversation? _streamingConversation;
  CancelToken? _cancelToken;
  bool _cancelled = false;
  bool _checking = false;
  bool _disposed = false;
  int _seq = 0;

  Timer? _persistTimer;
  Timer? _flushTimer;
  Timer? _pollTimer;
  DateTime _lastPersist = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _persistQueue = Future<void>.value();
  AppLifecycleListener? _lifecycle;

  Conversation? get activeConversation {
    for (final conversation in conversations) {
      if (conversation.id == activeId) return conversation;
    }
    return conversations.isEmpty ? null : conversations.first;
  }

  /// Non-empty conversations, most recent first.
  List<Conversation> get history {
    final list = conversations.where((c) => !c.isEmpty).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// What to show in the status pill.
  String get modelLabel {
    final configured = settings.model.trim();
    if (configured.isNotEmpty) return configured;
    return status.model ?? '';
  }

  Future<void> load() async {
    final data = await _store.read();
    if (data != null) {
      final rawSettings = data['settings'];
      if (rawSettings is Map) {
        settings = AppSettings.fromJson(Map<String, dynamic>.from(rawSettings));
      }
      final rawConversations = data['conversations'];
      if (rawConversations is List) {
        conversations.addAll(
          rawConversations.whereType<Map>().map(
            (json) => Conversation.fromJson(Map<String, dynamic>.from(json)),
          ),
        );
      }
      activeId = data['activeId'] as String?;
    }

    // Read the platform secret first. A legacy key is migrated before the
    // plaintext settings file is rewritten without it.
    final rawSettings = data?['settings'];
    final legacyKey = rawSettings is Map && rawSettings['apiKey'] is String
        ? rawSettings['apiKey'] as String
        : '';
    try {
      final storedKey = await _secretStore.read();
      final key = storedKey ?? legacyKey;
      if (storedKey == null && legacyKey.isNotEmpty) {
        await _secretStore.write(legacyKey);
      }
      settings = settings.copyWith(apiKey: key);
      _secretStorageReady = true;
      secretStorageError = null;
      if (legacyKey.isNotEmpty) await _persist();
    } catch (_) {
      // Keep the original file untouched if migration cannot be completed.
      _secretStorageReady = false;
      settings = settings.copyWith(apiKey: legacyKey);
      secretStorageError =
          'Secure storage is unavailable. Your existing API key has not '
          'been migrated or removed. Check device security settings and '
          'restart Clearport.';
    }

    // A process can be killed before an in-flight request reaches its
    // completion handler. Keep any partial answer, but discard empty
    // assistant placeholders left behind by an interrupted generation.
    var recoveredInterruptedGeneration = false;
    for (final conversation in conversations) {
      final originalMessageCount = conversation.messages.length;
      conversation.messages.removeWhere(
        (message) => !message.isUser && message.content.trim().isEmpty,
      );
      recoveredInterruptedGeneration =
          conversation.messages.length < originalMessageCount ||
          recoveredInterruptedGeneration;
    }

    if (conversations.isEmpty) _createConversation();
    if (activeId == null ||
        !conversations.any((conversation) => conversation.id == activeId)) {
      activeId = conversations.first.id;
    }
    themeMode.value = settings.themeMode;
    if (recoveredInterruptedGeneration) {
      _schedulePersist(force: true);
    }
    _notify();
    unawaited(refreshStatus());
  }

  /// Starts the health poll and lifecycle hooks. Call once after [load].
  void start() {
    _lifecycle ??= AppLifecycleListener(
      onPause: _handleAppPaused,
      onResume: () => unawaited(refreshStatus(silent: true)),
    );
    _pollTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isStreaming) unawaited(refreshStatus(silent: true));
    });
  }

  // ---------------------------------------------------------------------------
  // Conversations
  // ---------------------------------------------------------------------------

  Conversation _createConversation() {
    final now = DateTime.now();
    final conversation = Conversation(
      id: _nextId('c'),
      createdAt: now,
      updatedAt: now,
    );
    conversations.add(conversation);
    activeId = conversation.id;
    return conversation;
  }

  void newChat() {
    if (isStreaming) stopStreaming();
    final current = activeConversation;
    if (current != null && current.isEmpty) {
      _notify();
      return;
    }
    _createConversation();
    _schedulePersist(force: true);
    _notify();
  }

  void selectConversation(String id) {
    if (id == activeId) return;
    if (!conversations.any((conversation) => conversation.id == id)) return;
    if (isStreaming) stopStreaming();
    activeId = id;
    _schedulePersist(force: true);
    _notify();
  }

  /// Removes a conversation and returns it, so the UI can offer an undo.
  Conversation? removeConversation(String id) {
    final index = conversations.indexWhere((c) => c.id == id);
    if (index == -1) return null;
    if (_streamingConversation?.id == id) stopStreaming();

    final removed = conversations.removeAt(index);
    if (activeId == id) {
      activeId = conversations.isEmpty
          ? _createConversation().id
          : conversations.first.id;
    }
    _schedulePersist(force: true);
    _notify();
    return removed;
  }

  /// Imports conversations after the caller has explicitly selected merge or replace.
  /// Existing conversation IDs are remapped during a merge to avoid overwriting data.
  void importConversations(
    List<Conversation> incoming, {
    required bool replace,
  }) {
    if (isStreaming) stopStreaming();
    if (replace) {
      conversations
        ..clear()
        ..addAll(incoming);
    } else {
      final usedIds = conversations.map((c) => c.id).toSet();
      for (final item in incoming) {
        var id = item.id;
        if (usedIds.contains(id)) {
          id = _nextId('import');
        }
        usedIds.add(id);
        conversations.add(
          Conversation(
            id: id,
            title: item.title,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            messages: item.messages
                .map(
                  (message) => ChatMessage(
                    id: _nextId('m'),
                    role: message.role,
                    content: message.content,
                    createdAt: message.createdAt,
                    isError: message.isError,
                  ),
                )
                .toList(),
          ),
        );
      }
    }
    if (conversations.isEmpty) {
      _createConversation();
    } else {
      activeId = conversations.first.id;
    }
    _schedulePersist(force: true);
    _notify();
  }

  void renameConversation(String id, String title) {
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) return;
    final index = conversations.indexWhere(
      (conversation) => conversation.id == id,
    );
    if (index == -1) return;
    conversations[index].title = nextTitle;
    conversations[index].touch();
    _schedulePersist(force: true);
    _notify();
  }

  void restoreConversation(Conversation conversation) {
    conversations.add(conversation);
    activeId = conversation.id;
    _schedulePersist(force: true);
    _notify();
  }

  void clearAllConversations() {
    if (isStreaming) stopStreaming();
    conversations.clear();
    _createConversation();
    _schedulePersist(force: true);
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------------

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || isStreaming) return;

    final conversation = activeConversation ?? _createConversation();
    if (conversation.title == 'New chat') {
      conversation.title = titleFromMessage(content);
    }
    conversation.messages.add(
      ChatMessage(
        id: _nextId('m'),
        role: MessageRole.user,
        content: content,
        createdAt: DateTime.now(),
      ),
    );
    conversation.touch();

    final assistant = _newAssistantMessage(conversation);
    _prepareStream(conversation, assistant);
    await _runStream();
  }

  /// Replaces a user message and invalidates every later turn before replying.
  Future<void> editMessage(String messageId, String replacement) async {
    final content = replacement.trim();
    if (isStreaming || content.isEmpty) return;
    final conversation = activeConversation;
    if (conversation == null) return;
    final index = conversation.messages.indexWhere((m) => m.id == messageId);
    if (index < 0 || !conversation.messages[index].isUser) return;

    final message = conversation.messages[index];
    message.content = content;
    conversation.messages.removeRange(index + 1, conversation.messages.length);
    if (index == 0 && conversation.title == 'New chat') {
      conversation.title = titleFromMessage(content);
    }
    conversation.touch();
    final assistant = _newAssistantMessage(conversation);
    _prepareStream(conversation, assistant);
    await _runStream();
  }

  /// Drops the trailing assistant turn and asks again.
  Future<void> regenerate() async {
    if (isStreaming) return;
    final conversation = activeConversation;
    if (conversation == null) return;

    while (conversation.messages.isNotEmpty &&
        !conversation.messages.last.isUser) {
      conversation.messages.removeLast();
    }
    if (conversation.messages.isEmpty) return;

    final assistant = _newAssistantMessage(conversation);
    _prepareStream(conversation, assistant);
    await _runStream();
  }

  ChatMessage _newAssistantMessage(Conversation conversation) {
    final message = ChatMessage(
      id: _nextId('m'),
      role: MessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );
    conversation.messages.add(message);
    conversation.touch();
    return message;
  }

  void _prepareStream(Conversation conversation, ChatMessage assistant) {
    _streamingConversation = conversation;
    _streamingMessage = assistant;
    streamingMessageId = assistant.id;
    isStreaming = true;
    _cancelled = false;
    _pending.clear();
    _cancelToken = CancelToken();
    _notify();
    _schedulePersist();
  }

  Future<void> _runStream() async {
    final conversation = _streamingConversation;
    final assistant = _streamingMessage;
    if (conversation == null || assistant == null) return;

    final token = _cancelToken;
    final history = conversation.messages
        .where((message) => message.id != assistant.id)
        .toList();

    try {
      await _apiFactory(settings).streamChat(
        settings: settings,
        messages: history,
        token: token,
        onDelta: (delta) {
          // Ignore callbacks from an obsolete request or a conversation that
          // has since been removed/replaced.
          if (!_cancelled &&
              _cancelToken == token &&
              _streamingMessage == assistant &&
              _streamingConversation == conversation &&
              conversations.contains(conversation) &&
              conversation.messages.any(
                (message) => message.id == assistant.id,
              )) {
            _appendDelta(delta);
          }
        },
      );
      _flushPending();
      if (!_cancelled && assistant.content.trim().isEmpty) {
        assistant.content = 'The server returned an empty response.';
        assistant.isError = true;
      }
    } on ChatApiException catch (error) {
      if (!_cancelled) {
        _flushPending();
        assistant.content = error.message;
        assistant.isError = true;
      }
    } catch (error) {
      if (!_cancelled) {
        _flushPending();
        assistant.content = 'Something went wrong: $error';
        assistant.isError = true;
      }
    } finally {
      _flushTimer?.cancel();
      _flushTimer = null;
      _flushPending();

      if (_cancelled && assistant.content.trim().isEmpty) {
        conversation.messages.removeWhere((m) => m.id == assistant.id);
      }

      conversation.touch();
      isStreaming = false;
      streamingMessageId = null;
      _streamingMessage = null;
      _streamingConversation = null;
      _cancelToken = null;
      _cancelled = false;
      _schedulePersist(force: true);
      _notify();
      if (assistant.isError) unawaited(refreshStatus(silent: true));
    }
  }

  void stopStreaming() {
    if (!isStreaming) return;
    _cancelled = true;
    _cancelToken?.cancel();
    _flushPending();
    _notify();
  }

  void _appendDelta(String delta) {
    _pending.write(delta);
    _flushTimer ??= Timer(_streamFlushInterval, () {
      _flushTimer = null;
      _flushPending();
    });
  }

  /// Coalesces token updates so the UI rebuilds at a steady, smooth rate
  /// instead of once per token.
  void _flushPending() {
    if (_pending.isEmpty) return;
    final target = _streamingMessage;
    if (target == null) {
      _pending.clear();
      return;
    }
    target.content += _pending.toString();
    _pending.clear();
    _streamingConversation?.touch();
    _notify();
    if (DateTime.now().difference(_lastPersist) > const Duration(seconds: 3)) {
      unawaited(_persist());
    }
  }

  // ---------------------------------------------------------------------------
  // Settings & status
  // ---------------------------------------------------------------------------

  void updateSettings(AppSettings next) {
    final connectionChanged =
        next.baseUrl != settings.baseUrl || next.apiKey != settings.apiKey;
    settings = next;
    if (themeMode.value != next.themeMode) themeMode.value = next.themeMode;
    if (connectionChanged) {
      status = const ServerStatus(health: ServerHealth.unknown);
    }
    _schedulePersist();
    _notify();
  }

  Future<void> refreshStatus({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) {
      status = const ServerStatus(health: ServerHealth.checking);
      _notify();
    }
    try {
      status = await _apiFactory(settings).checkStatus();
    } catch (error) {
      status = ServerStatus(health: ServerHealth.offline, message: '$error');
    } finally {
      _checking = false;
      _notify();
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _schedulePersist({bool force = false}) {
    _persistTimer?.cancel();
    if (force) {
      _persistTimer = null;
      unawaited(_persist());
      return;
    }
    _persistTimer = Timer(_persistDelay, () {
      _persistTimer = null;
      unawaited(_persist());
    });
  }

  Future<void> _persist() {
    _lastPersist = DateTime.now();

    // Capture the state now, not when this write reaches the front of the
    // queue. Later mutations must not change an already-requested snapshot.
    final apiKey = settings.apiKey;
    final snapshot = <String, dynamic>{
      'version': 1,
      'settings': settings.toJson(),
      'activeId': activeId,
      'conversations': conversations.map((c) => c.toJson()).toList(),
    };

    // Keep writes in request order. Recover the queue after a failed write so
    // one storage error cannot prevent all future persistence attempts.
    _persistQueue = _persistQueue
        .then((_) async {
          if (!_secretStorageReady) return;
          try {
            await _secretStore.write(apiKey);
            await _store.write(snapshot);
            secretStorageError = null;
          } catch (_) {
            // Never persist a secret in the JSON settings file as a fallback.
            secretStorageError =
                'Could not save the API key securely. It remains in memory '
                'for this session, but was not written to disk.';
            _notify();
          }
        })
        .catchError((Object _) {});
    return _persistQueue;
  }

  /// Persist the latest state when the app is backgrounded without
  /// cancelling an in-flight response. Background execution is controlled by
  /// the operating system; pausing the UI should not deliberately abort a
  /// request that may continue to complete.
  void _handleAppPaused() {
    flush();
  }

  /// Writes immediately; used when the app goes to the background.
  void flush() {
    _flushPending();
    _persistTimer?.cancel();
    _persistTimer = null;
    unawaited(_persist());
  }

  String _nextId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _persistTimer?.cancel();
    _flushTimer?.cancel();
    _pollTimer?.cancel();
    _lifecycle?.dispose();
    themeMode.dispose();
    super.dispose();
  }
}
