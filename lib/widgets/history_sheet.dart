import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../utils/conversation_search.dart';

import '../models/conversation.dart';
import '../state/app_state.dart';
import '../services/conversation_transfer.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'app_scope.dart';
import 'theme_art.dart';

class HistorySheet extends StatefulWidget {
  const HistorySheet({super.key});

  @override
  State<HistorySheet> createState() => _HistorySheetState();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const HistorySheet(),
    );
  }
}

class _HistorySheetState extends State<HistorySheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = AppScope.of(context);
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.72,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.82),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (palette.spooky)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: SpiderWebPainter(
                          web: Colors.white.withValues(alpha: 0.08),
                          spider: palette.accent.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                )
              else if (palette.mark == ThemeMarkKind.snowflake)
                Positioned(
                  top: -40,
                  right: -40,
                  child: IgnorePointer(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            palette.accent.withValues(alpha: 0.12),
                            palette.accent.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (palette.mark == ThemeMarkKind.marigold)
                Positioned(
                  top: -40,
                  right: -40,
                  child: IgnorePointer(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            palette.secondary.withValues(alpha: 0.12),
                            palette.secondary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: palette.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 14, 8),
                    child: Row(
                      children: [
                        Text(
                          'Chats',
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Import backup',
                          onPressed: () => _import(context, state),
                          icon: const Icon(Icons.file_download_outlined),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          tooltip: 'Export all chats',
                          onPressed: () =>
                              _export(context, state.conversations),
                          icon: const Icon(Icons.file_upload_outlined),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 4),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            state.newChat();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('New chat'),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent.withValues(
                              alpha: 0.15,
                            ),
                            foregroundColor: palette.accent,
                            elevation: 0,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search chats and messages',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: palette.muted.withValues(alpha: 0.75),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: palette.muted,
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                        isDense: true,
                        filled: true,
                        fillColor: palette.surfaceAlt.withValues(alpha: 0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: palette.border.withValues(alpha: 0.35),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: palette.border.withValues(alpha: 0.35),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: palette.accent.withValues(alpha: 0.7),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: state,
                      builder: (context, _) {
                        final conversations = searchConversations(
                          state.history,
                          _search.text,
                        );
                        if (conversations.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Opacity(
                                    opacity: 0.85,
                                    child: ThemeMark(size: 52),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _search.text.trim().isEmpty
                                        ? (palette.spooky
                                              ? 'The archives are silent.'
                                              : 'No conversations yet')
                                        : 'No matching conversations',
                                    style: theme.textTheme.titleSmall!.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _search.text.trim().isEmpty
                                        ? (palette.spooky
                                              ? 'Summon a new chat to begin.'
                                              : 'Start a new chat to begin exploring.')
                                        : 'Try searching for other words or messages.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: palette.muted,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
                          itemCount: conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = conversations[index];
                            return _ConversationTile(
                              conversation: conversation,
                              selected: conversation.id == state.activeId,
                              onTap: () {
                                state.selectConversation(conversation.id);
                                Navigator.of(context).pop();
                              },
                              onDelete: () =>
                                  _confirmDelete(context, state, conversation),
                              onExport: () => _export(context, [conversation]),
                              onRename: () =>
                                  _rename(context, state, conversation),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    List<Conversation> conversations,
  ) async {
    if (conversations.isEmpty) return;
    final location = await getSaveLocation(
      suggestedName: conversations.length == 1
          ? 'clearport-chat.json'
          : 'clearport-backup.json',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON backup', extensions: ['json']),
      ],
    );
    if (location == null) return;
    try {
      await File(
        location.path,
      ).writeAsString(ConversationTransfer.encode(conversations), flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export backup: $error')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON backup', extensions: ['json']),
      ],
    );
    if (file == null) return;
    try {
      final incoming = ConversationTransfer.decode(await file.readAsString());
      if (!context.mounted) return;
      if (incoming.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This backup contains no conversations.'),
          ),
        );
        return;
      }
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: dialogContext.palette.surface,
          title: const Text('Restore conversations'),
          content: Text(
            '${incoming.length} conversation(s) found. Merge keeps your current chats. Replace removes current chats first.',
            style: const TextStyle(fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Merge'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('Replace all'),
            ),
          ],
        ),
      );
      if (replace == null || !context.mounted) return;
      if (replace) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: dialogContext.palette.surface,
            title: const Text('Replace all conversations?'),
            content: const Text(
              'This permanently replaces the conversations currently stored on this device. Export a backup first if you may need them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                child: const Text('Replace'),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
      }
      state.importConversations(incoming, replace: replace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              replace
                  ? 'Conversations restored.'
                  : 'Conversations merged into your history.',
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid backup: ${error.message}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import backup: $error')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppState state,
    Conversation conversation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        title: const Text('Delete chat?'),
        content: Text(
          '“${conversation.title}” will be removed from this device.',
          style: const TextStyle(fontSize: 14, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final removed = state.removeConversation(conversation.id);
      if (removed != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Chat deleted.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => state.restoreConversation(removed),
            ),
          ),
        );
      }
    }
  }

  Future<void> _rename(
    BuildContext context,
    AppState state,
    Conversation conversation,
  ) async {
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Chat title'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && context.mounted) {
      if (title.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A chat title cannot be empty.')),
        );
      } else {
        state.renameConversation(conversation.id, title);
      }
    }
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onDelete,
    required this.onExport,
    required this.onRename,
  });

  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? (palette.spooky
                                    ? palette.accent
                                    : theme.colorScheme.onSurface)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${conversation.messages.length} messages · '
                        '${timeAgo(conversation.updatedAt)}',
                        style: TextStyle(fontSize: 11.5, color: palette.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRename,
                  tooltip: 'Rename chat',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: palette.muted,
                  ),
                ),
                IconButton(
                  onPressed: onExport,
                  tooltip: 'Export chat',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.ios_share_rounded,
                    size: 17,
                    color: palette.muted,
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete chat',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: palette.muted.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
