import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polymind/constants.dart';
import 'package:polymind/model/chatmodel.dart';

class ConversationDrawer extends ConsumerStatefulWidget {
  const ConversationDrawer({super.key});

  @override
  ConsumerState<ConversationDrawer> createState() =>
      _ConversationDrawerState();
}

class _ConversationDrawerState extends ConsumerState<ConversationDrawer> {
  String _query = '';

  Future<void> _renameConversation(
    ChatModel chatModel,
    String id,
    String currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await chatModel.renameConversation(id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatModel = ref.watch(chatProvider);
    final allConversations = chatModel.conversations;
    final currentId = chatModel.currentConversationId;
    final conversations = _query.trim().isEmpty
        ? allConversations
        : allConversations
            .where(
              (c) => (c['title'] as String)
                  .toLowerCase()
                  .contains(_query.trim().toLowerCase()),
            )
            .toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.chat_rounded, color: context.colors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Conversations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // New Chat
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    chatModel.startNewConversation();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New Chat'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.accent,
                    side: BorderSide(color: context.colors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            if (allConversations.length > 4) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 14, color: context.colors.black),
                  decoration: InputDecoration(
                    hintText: 'Search conversations',
                    hintStyle: TextStyle(color: context.colors.gray),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: context.colors.inputBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 4),
            const Divider(height: 1),

            // List
            Expanded(
              child: conversations.isEmpty
                  ? Center(
                      child: Text(
                        allConversations.isEmpty
                            ? 'No conversations yet'
                            : 'No matches',
                        style: TextStyle(color: context.colors.gray),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final id = conv['id'] as String;
                        final title = conv['title'] as String;
                        final provider = conv['provider'] as String? ?? '';
                        final updatedAt = DateTime.fromMillisecondsSinceEpoch(
                          conv['updated_at'] as int,
                        );
                        final isSelected = id == currentId;

                        return Dismissible(
                          key: ValueKey(id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red.shade400,
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          confirmDismiss: (_) => showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete conversation?'),
                              content: Text(
                                'This will permanently delete "$title".',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(ctx).pop(true),
                                  child: Text(
                                    'Delete',
                                    style:
                                        TextStyle(color: Colors.red.shade600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (_) =>
                              chatModel.deleteConversation(id),
                          child: ListTile(
                            selected: isSelected,
                            selectedTileColor:
                                context.colors.accent.withValues(alpha: 0.08),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (provider.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          context.colors.accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      provider.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  _formatDate(updatedAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.darkGray,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.more_vert,
                                size: 18,
                                color: context.colors.gray,
                              ),
                              onPressed: () =>
                                  _renameConversation(chatModel, id, title),
                              tooltip: 'Rename',
                            ),
                            onTap: () {
                              chatModel.loadConversation(id);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }
}
