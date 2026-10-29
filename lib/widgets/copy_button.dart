import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Small icon button that copies [text] and briefly confirms.
class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    required this.text,
    this.size = 16,
    this.tooltip = 'Copy',
  });

  final String text;
  final double size;
  final String tooltip;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: _copied ? 'Copied' : widget.tooltip,
      child: InkResponse(
        onTap: _copy,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              key: ValueKey(_copied),
              size: widget.size,
              color: _copied ? palette.accent : palette.muted,
            ),
          ),
        ),
      ),
    );
  }
}
