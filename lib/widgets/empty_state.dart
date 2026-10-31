import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chat_api.dart';
import '../theme.dart';
import 'status_pill.dart';
import 'theme_art.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.status,
    required this.baseUrl,
    required this.model,
    required this.onRefresh,
    required this.onSuggestion,
  });

  final ServerStatus status;
  final String baseUrl;
  final String model;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSuggestion;

  static const _suggestions = [
    ('Explain code', 'Explain this code:\n\n'),
    ('Summarize text', 'Summarize the following:\n\n'),
    ('Brainstorm', 'Brainstorm five ideas for '),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            if (palette.spooky)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: SpiderWebPainter(
                        web: Colors.white,
                        spider: palette.accent,
                      ),
                    ),
                  ),
                ),
              ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - 56),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ThemeMark(),
                        const SizedBox(height: 18),
                        Text(
                          'Clearport',
                          style: theme.textTheme.titleLarge!.copyWith(
                            fontSize: 26,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          palette.spooky
                              ? 'Something is listening on 127.0.0.1.'
                              : 'A quiet chat with your local models.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: palette.muted),
                        ),
                        const SizedBox(height: 28),
                        _ConnectionCard(
                          status: status,
                          baseUrl: baseUrl,
                          model: model,
                          onRefresh: onRefresh,
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final suggestion in _suggestions)
                              ActionChip(
                                label: Text(suggestion.$1),
                                onPressed: () => onSuggestion(suggestion.$2),
                                backgroundColor: palette.surface,
                                side: BorderSide(color: palette.border),
                                shape: const StadiumBorder(),
                                labelStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: theme.colorScheme.onSurface,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.status,
    required this.baseUrl,
    required this.model,
    required this.onRefresh,
  });

  final ServerStatus status;
  final String baseUrl;
  final String model;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final detail = status.message ?? baseUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          StatusDot(status: status, size: 8),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusHeadline(status, model),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    fontFamily: 'monospace',
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: 'Check server',
            visualDensity: VisualDensity.compact,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: status.health == ServerHealth.checking
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: palette.accent,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      key: const ValueKey('refresh'),
                      size: 18,
                      color: palette.muted,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
