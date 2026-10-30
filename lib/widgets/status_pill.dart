import 'package:flutter/material.dart';

import '../services/chat_api.dart';
import '../theme.dart';

String statusHeadline(ServerStatus status, String model) {
  switch (status.health) {
    case ServerHealth.unknown:
      return 'Not checked';
    case ServerHealth.checking:
      return 'Checking…';
    case ServerHealth.online:
      return model.isEmpty ? 'Connected' : 'Connected · $model';
    case ServerHealth.reachable:
      return switch (status.issue) {
        ServerIssue.unauthorized => 'Authentication failed',
        ServerIssue.endpointNotFound => 'Endpoint not found',
        ServerIssue.noModels => 'No models loaded',
        ServerIssue.httpError => 'Server returned an error',
        _ => 'Server reachable',
      };
    case ServerHealth.offline:
      return switch (status.issue) {
        ServerIssue.connectionRefused => 'Connection refused',
        ServerIssue.timeout => 'Connection timed out',
        _ => 'Offline',
      };
  }
}

Color statusColor(ServerStatus status, AppPalette palette) {
  switch (status.health) {
    case ServerHealth.online:
      return palette.accent;
    case ServerHealth.checking:
    case ServerHealth.reachable:
      return const Color(0xFFE0A84B);
    case ServerHealth.unknown:
      return palette.muted;
    case ServerHealth.offline:
      return const Color(0xFFFF7B72);
  }
}

/// Animated dot used in the header and the empty state.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.status, this.size = 7});

  final ServerStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, context.palette);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: status.health == ServerHealth.online
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Compact status line under the chat title. Tap to re-check the server.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    required this.model,
    required this.onTap,
  });

  final ServerStatus status;
  final String model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: status.message ?? 'Tap to check the server',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusDot(status: status),
              const SizedBox(width: 6),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    statusHeadline(status, model),
                    key: ValueKey('${status.health}-$model'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                      color: palette.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
