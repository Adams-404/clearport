import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme.dart';
import 'copy_button.dart';
import 'markdown_text.dart';
import 'typing_dots.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isStreaming,
    this.showActions = false,
    this.onRegenerate,
  });

  final ChatMessage message;
  final bool isStreaming;
  final bool showActions;
  final VoidCallback? onRegenerate;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: widget.message.isUser
              ? _UserMessage(message: widget.message)
              : _AssistantMessage(
                  message: widget.message,
                  isStreaming: widget.isStreaming,
                  showActions: widget.showActions,
                  onRegenerate: widget.onRegenerate,
                ),
        ),
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
          border: Border.all(color: palette.accent.withValues(alpha: 0.28)),
        ),
        child: SelectableText(
          message.content,
          style: theme.textTheme.bodyMedium!.copyWith(
            fontSize: 15.2,
            height: 1.45,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.message,
    required this.isStreaming,
    required this.showActions,
    this.onRegenerate,
  });

  final ChatMessage message;
  final bool isStreaming;
  final bool showActions;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    if (message.isError) {
      return _ErrorBubble(message: message.content, onRetry: onRegenerate);
    }

    final empty = message.content.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (empty && isStreaming)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: TypingDots(),
          )
        else if (!empty)
          MarkdownText(
            message.content,
            trailing: isStreaming ? const StreamingCursor() : null,
          ),
        if (showActions && !isStreaming && !empty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CopyButton(text: message.content, size: 15),
                if (onRegenerate != null)
                  _ActionIcon(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Regenerate',
                    onTap: onRegenerate!,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 15, color: context.palette.muted),
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: error.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: error),
              const SizedBox(width: 7),
              Text(
                'Request failed',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            message,
            style: theme.textTheme.bodyMedium!.copyWith(
              fontSize: 13.4,
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (onRetry != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: error,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }
}
