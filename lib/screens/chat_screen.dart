import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/chat_api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_scope.dart';
import '../widgets/composer.dart';
import '../widgets/empty_state.dart';
import '../widgets/history_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/status_pill.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  AppState? _state;
  String? _lastConversationId;
  bool _stickToBottom = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state != null) return;
    final state = AppScope.of(context);
    _state = state;
    _lastConversationId = state.activeId;
    state.addListener(_onStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (state.status.health == ServerHealth.unknown) {
        state.refreshStatus();
      }
      _scrollToBottom(animate: false);
    });
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _state?.removeListener(_onStateChanged);
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = _state;
    if (state == null) return;
    if (state.activeId != _lastConversationId) {
      _lastConversationId = state.activeId;
      _stickToBottom = true;
      _scrollToBottom(animate: false);
      return;
    }
    if (state.isStreaming && _stickToBottom) {
      _scrollToBottom(animate: false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 64;
    if (atBottom != _stickToBottom) {
      setState(() => _stickToBottom = atBottom);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if ((_scroll.position.pixels - target).abs() < 2) return;
      if (animate) {
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  void _send() {
    final state = _state;
    if (state == null || state.isStreaming) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;

    _input.clear();
    _stickToBottom = true;
    HapticFeedback.lightImpact();
    state.send(text);
    _inputFocus.requestFocus();
    _scrollToBottom();
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = TextEditingController(text: message.content);
    final replacement = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'Your message'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Send')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || replacement == null || replacement.trim().isEmpty) return;
    _stickToBottom = true;
    await _state?.editMessage(message.id, replacement);
    _scrollToBottom();
  }

  void _useSuggestion(String prompt) {
    _input.text = prompt;
    _input.selection = TextSelection.collapsed(offset: prompt.length);
    _inputFocus.requestFocus();
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (!mounted) return;
    _state?.refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final conversation = state.activeConversation;
            final messages = conversation?.messages ?? const <ChatMessage>[];

            return Column(
              children: [
                _Header(
                  conversation: conversation,
                  status: state.status,
                  model: state.modelLabel,
                  onRefresh: () => state.refreshStatus(),
                  onHistory: () => HistorySheet.show(context),
                  onNewChat: state.newChat,
                  onSettings: _openSettings,
                ),
                _ProgressLine(active: state.isStreaming),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: messages.isEmpty
                            ? EmptyState(
                                status: state.status,
                                baseUrl: state.settings.baseUrl,
                                model: state.modelLabel,
                                onRefresh: () => state.refreshStatus(),
                                onSuggestion: _useSuggestion,
                              )
                            : ListView.builder(
                                controller: _scroll,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  16,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isLast = index == messages.length - 1;
                                  final showActions = !state.isStreaming;
                                  return MessageBubble(
                                    key: ValueKey(message.id),
                                    message: message,
                                    isStreaming:
                                        state.streamingMessageId == message.id,
                                    showActions: showActions,
                                    onRegenerate:
                                        showActions && isLast && !message.isUser
                                        ? state.regenerate
                                        : null,
                                    onEdit: message.isUser && showActions
                                        ? (_) => _editMessage(message)
                                        : null,
                                  );
                                },
                              ),
                      ),
                      Positioned(
                        right: 16,
                        bottom: 14,
                        child: _JumpToLatest(
                          visible: !_stickToBottom,
                          onTap: () {
                            _stickToBottom = true;
                            setState(() {});
                            _scrollToBottom();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Composer(
                  controller: _input,
                  focusNode: _inputFocus,
                  isStreaming: state.isStreaming,
                  onSend: _send,
                  onStop: state.stopStreaming,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.conversation,
    required this.status,
    required this.model,
    required this.onRefresh,
    required this.onHistory,
    required this.onNewChat,
    required this.onSettings,
  });

  final Conversation? conversation;
  final ServerStatus status;
  final String model;
  final VoidCallback onRefresh;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.border.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.menu_rounded,
            tooltip: 'Chats',
            onTap: onHistory,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation?.title ?? 'Clearport',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  StatusPill(status: status, model: model, onTap: onRefresh),
                ],
              ),
            ),
          ),
          _HeaderButton(
            icon: Icons.tune_rounded,
            tooltip: 'Settings',
            onTap: onSettings,
          ),
          _HeaderButton(
            icon: Icons.add_rounded,
            tooltip: 'New chat',
            onTap: onNewChat,
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 21),
      color: highlight ? palette.accent : palette.muted,
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: active
            ? LinearProgressIndicator(
                key: const ValueKey('streaming'),
                minHeight: 1.6,
                backgroundColor: Colors.transparent,
                color: context.palette.accent,
              )
            : const SizedBox(
                key: ValueKey('idle'),
                height: 1.6,
                width: double.infinity,
              ),
      ),
    );
  }
}

class _JumpToLatest extends StatelessWidget {
  const _JumpToLatest({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.5),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Material(
            color: palette.surface,
            shape: CircleBorder(side: BorderSide(color: palette.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_downward_rounded,
                  size: 18,
                  color: palette.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
