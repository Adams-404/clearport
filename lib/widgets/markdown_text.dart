import 'package:flutter/material.dart';

import '../theme.dart';
import 'copy_button.dart';

/// A tiny markdown renderer: fenced code blocks, **bold**, *italic* and
/// inline `code`. Deliberately small — a chat client, not a document viewer.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.text, {super.key, this.trailing, this.style});

  final String text;

  /// Optional inline widget appended to the last paragraph (stream cursor).
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
        children.add(
          _CodeBlockView(code: block.code, language: block.language),
        );
        continue;
      }
      final isLast = i == blocks.length - 1;
      final textBlock = block as _TextBlock;
      children.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
          child: Text.rich(
            TextSpan(
              children: [
                ..._inlineSpans(textBlock.text, base, inlineCode),
                if (isLast && trailing != null)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: trailing!,
                  ),
              ],
            ),
            style: base,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<InlineSpan> _inlineSpans(String text, TextStyle base, TextStyle code) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(`[^`\n]+`|\*\*[^*\n]+\*\*|\*[^*\n]+\*)');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('`')) {
        spans.add(
          TextSpan(text: token.substring(1, token.length - 1), style: code),
        );
      } else if (token.startsWith('**')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w600),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}

sealed class _Block {
  const _Block();
}

class _TextBlock extends _Block {
  const _TextBlock(this.text);
  final String text;
}

class _CodeBlock extends _Block {
  const _CodeBlock(this.code, this.language);
  final String code;
  final String language;
}

List<_Block> _parseBlocks(String source) {
  final blocks = <_Block>[];
  final fence = RegExp(r'```([^\n`]*)\n?([\s\S]*?)(?:```|$)');
  var cursor = 0;

  for (final match in fence.allMatches(source)) {
    if (match.start > cursor) {
      _addTextBlocks(source.substring(cursor, match.start), blocks);
    }
    final language = (match.group(1) ?? '').trim();
    final code = (match.group(2) ?? '').trimRight();
    if (code.isNotEmpty) blocks.add(_CodeBlock(code, language));
    cursor = match.end;
  }
  if (cursor < source.length) {
    _addTextBlocks(source.substring(cursor), blocks);
  }
  if (blocks.isEmpty) blocks.add(_TextBlock(source));
  return blocks;
}

void _addTextBlocks(String raw, List<_Block> blocks) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return;
  for (final part in trimmed.split(RegExp(r'\n\s*\n'))) {
    final paragraph = part.trim();
    if (paragraph.isNotEmpty) blocks.add(_TextBlock(paragraph));
  }
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
            child: Text(
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
