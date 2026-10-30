import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../utils/conversation_search.dart';

import '../models/conversation.dart';
import '../state/app_state.dart';
import '../services/conversation_transfer.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'app_scope.dart';

class HistorySheet extends StatefulWidget {
  const HistorySheet({super.key});

  @override
  State<HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<HistorySheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() { _search.dispose(); super.dispose(); }

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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final state = AppScope.of(context);

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.66,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
            child: Row(
              children: [
                Text(
                  'Chats',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(tooltip: 'Import backup', onPressed: () => _import(context, state), icon: const Icon(Icons.file_download_outlined), visualDensity: VisualDensity.compact),
                IconButton(tooltip: 'Export all chats', onPressed: () => _export(context, state.conversations), icon: const Icon(Icons.file_upload_outlined), visualDensity: VisualDensity.compact),
                TextButton.icon(
                  onPressed: () {
                    state.newChat();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('New chat'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
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
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Clear search', onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded, size: 18)),
                isDense: true, filled: true, fillColor: palette.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.accent)),
              ),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: state,
              builder: (context, _) {
                final conversations = searchConversations(state.history, _search.text);
                if (conversations.isEmpty) {
                  return Center(
                    child: Text(
                      _search.text.trim().isEmpty ? 'No conversations yet.' : 'No matching conversations.',
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
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
                      onRename: () => _rename(context, state, conversation),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, List<Conversation> conversations) async {
    if (conversations.isEmpty) return;
    final location = await getSaveLocation(suggestedName: conversations.length == 1 ? 'clearport-chat.json' : 'clearport-backup.json', acceptedTypeGroups: [const XTypeGroup(label: 'JSON backup', extensions: ['json'])]);
    if (location == null) return;
    try {
      await File(location.path).writeAsString(ConversationTransfer.encode(conversations), flush: true);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup exported successfully.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export backup: $error')));
    }
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final file = await openFile(acceptedTypeGroups: [const XTypeGroup(label: 'JSON backup', extensions: ['json'])]);
    if (file == null) return;
    try {
      final incoming = ConversationTransfer.decode(await file.readAsString());
      if (!context.mounted) return;
      if (incoming.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This backup contains no conversations.'))); return; }
      final replace = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        title: const Text('Restore conversations'),
        content: Text('${incoming.length} conversation(s) found. Merge keeps your current chats. Replace removes current chats first.', style: const TextStyle(fontSize: 14, height: 1.45)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Merge')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error), child: const Text('Replace all')),
        ],
      ));
      if (replace == null || !context.mounted) return;
      if (replace) {
        final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
          backgroundColor: dialogContext.palette.surface,
          title: const Text('Replace all conversations?'),
          content: const Text('This permanently replaces the conversations currently stored on this device. Export a backup first if you may need them.'),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error), child: const Text('Replace'))],
        ));
        if (confirmed != true || !context.mounted) return;
      }
      state.importConversations(incoming, replace: replace);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(replace ? 'Conversations restored.' : 'Conversations merged into your history.')));
    } on FormatException catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid backup: ${error.message}')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not import backup: $error')));
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
          SnackBar(content: const Text('Chat deleted.'), action: SnackBarAction(
            label: 'Undo',
            onPressed: () => state.restoreConversation(removed),
          )),
        );
      }
    }
  }

  Future<void> _rename(BuildContext context, AppState state, Conversation conversation) async {
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.palette.surface,
        title: const Text('Rename chat'),
        content: TextField(controller: controller, autofocus: true, maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Chat title'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value)),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (title != null && context.mounted) {
      if (title.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A chat title cannot be empty.')));
      } else {
        state.renameConversation(conversation.id, title);
      }
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? palette.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
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
                IconButton(onPressed: onRename, tooltip: 'Rename chat', visualDensity: VisualDensity.compact, icon: Icon(Icons.edit_outlined, size: 17, color: palette.muted)),
                IconButton(onPressed: onExport, tooltip: 'Export chat', visualDensity: VisualDensity.compact, icon: Icon(Icons.ios_share_rounded, size: 17, color: palette.muted)),
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
