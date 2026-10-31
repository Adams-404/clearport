import 'package:flutter/material.dart';

import '../theme.dart';

class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isStreaming,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isStreaming;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  cursorWidth: 1.6,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontSize: 15.2,
                    height: 1.35,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: isStreaming
                        ? 'Generating…'
                        : 'Message your local model',
                    labelText: 'Message',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final canSend = value.text.trim().isNotEmpty;
                return _SendButton(
                  isStreaming: isStreaming,
                  enabled: canSend,
                  onSend: onSend,
                  onStop: onStop,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isStreaming,
    required this.enabled,
    required this.onSend,
    required this.onStop,
  });

  final bool isStreaming;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = isStreaming || enabled;
    final background = isStreaming
        ? palette.surfaceAlt
        : enabled
        ? palette.accent
        : palette.surfaceAlt;
    final foreground = isStreaming
        ? palette.muted
        : enabled
        ? Theme.of(context).colorScheme.onPrimary
        : palette.muted.withValues(alpha: 0.55);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: isStreaming ? palette.border : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: !active
              ? null
              : isStreaming
              ? onStop
              : onSend,
          child: Semantics(
            button: true,
            enabled: active,
            label: isStreaming ? 'Stop generating' : 'Send message',
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  isStreaming ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                  key: ValueKey(isStreaming),
                  size: isStreaming ? 20 : 22,
                  color: foreground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
