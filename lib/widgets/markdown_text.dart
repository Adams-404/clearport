import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../theme.dart';
import 'copy_button.dart';

/// Renders model output as GitHub-flavoured Markdown without enabling HTML.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.text, {super.key, this.trailing, this.style});

  final String text;
  final Widget? trailing;
  final TextStyle? style;

  static const _mono = TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: ['Menlo', 'Consolas', 'Roboto Mono'],
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final base = (style ?? theme.textTheme.bodyMedium!).copyWith(
      fontSize: 15.2,
      height: 1.5,
      color: theme.colorScheme.onSurface,
    );
    final inlineCode = _mono.copyWith(
      fontSize: 13.4,
      height: 1.45,
      backgroundColor: palette.surfaceAlt,
      color: theme.colorScheme.onSurface,
    );

    final blocks = _parseBlocks(text);
    final children = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block is _CodeBlock) {
        children.add(_CodeBlockView(code: block.code, language: block.language));
      } else if (block is _MarkdownBlock && block.source.trim().isNotEmpty) {
        children.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: MarkdownBody(
              data: block.source,
              selectable: true,
              softLineBreak: true,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: base,
                a: base.copyWith(
                  color: palette.accent,
                  decoration: TextDecoration.underline,
                ),
                code: inlineCode,
                h1: base.copyWith(fontSize: 23, fontWeight: FontWeight.w700),
                h2: base.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                h3: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                blockquote: base.copyWith(color: palette.muted),
                blockquoteDecoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  border: Border(
                    left: BorderSide(color: palette.accent, width: 3),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    if (trailing != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: trailing!,
        ),
      );
    }
    if (children.isEmpty && trailing != null) {
      return Align(alignment: Alignment.centerLeft, child: trailing!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

sealed class _Block {
  const _Block();
}

class _MarkdownBlock extends _Block {
  const _MarkdownBlock(this.source);
  final String source;
}

class _CodeBlock extends _Block {
  const _CodeBlock(this.code, this.language);
  final String code;
  final String language;
}

/// Splits fenced code from Markdown. An unfinished fence is treated as code
/// while streaming, so partial model output remains renderable.
List<_Block> _parseBlocks(String source) {
  final blocks = <_Block>[];
  final fence = RegExp(r'```([^\n`]*)\n?([\s\S]*?)(?:```|$)');
  var cursor = 0;

  for (final match in fence.allMatches(source)) {
    if (match.start > cursor) {
      blocks.add(_MarkdownBlock(source.substring(cursor, match.start)));
    }
    final language = (match.group(1) ?? '').trim();
    final code = (match.group(2) ?? '').trimRight();
    if (code.isNotEmpty) blocks.add(_CodeBlock(code, language));
    cursor = match.end;
  }
  if (cursor < source.length) {
    blocks.add(_MarkdownBlock(source.substring(cursor)));
  }
  if (blocks.isEmpty && source.isNotEmpty) {
    blocks.add(_MarkdownBlock(source));
  }
  return blocks;
}

class _CodeBlockView extends StatelessWidget {
  const _CodeBlockView({required this.code, required this.language});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: palette.codeBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    language.isEmpty ? 'code' : language,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MarkdownText._mono.copyWith(
                      fontSize: 11,
                      letterSpacing: 0.4,
                      color: palette.muted,
                    ),
                  ),
                ),
                CopyButton(text: code, size: 14),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: MarkdownText._mono.copyWith(
                fontSize: 12.8,
                height: 1.55,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blinking caret shown while text is streaming in.
class StreamingCursor extends StatefulWidget {
  const StreamingCursor({super.key});

  @override
  State<StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.25,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 2.2,
        height: 15,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          color: context.palette.accent,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
