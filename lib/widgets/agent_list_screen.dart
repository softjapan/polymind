import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polymind/constants.dart';
import 'package:polymind/model/agent_config.dart';
import 'package:polymind/model/chatmodel.dart';
import 'package:polymind/widgets/agent_edit_screen.dart';

/// エージェント（システムプロンプトのプリセット）の管理画面
class AgentListScreen extends ConsumerWidget {
  const AgentListScreen({super.key});

  Future<void> _createAgent(BuildContext context, ChatModel chatModel) async {
    final result = await Navigator.of(context).push<AgentConfig>(
      MaterialPageRoute(builder: (_) => const AgentEditScreen()),
    );
    if (result != null) {
      await chatModel.createAgent(result);
    }
  }

  Future<void> _editAgent(
    BuildContext context,
    ChatModel chatModel,
    AgentConfig agent,
  ) async {
    final result = await Navigator.of(context).push<AgentConfig>(
      MaterialPageRoute(builder: (_) => AgentEditScreen(existing: agent)),
    );
    if (result != null) {
      await chatModel.updateAgent(result);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete agent?'),
        content: Text('This will permanently delete "$name".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatModel = ref.watch(chatProvider);
    final agents = chatModel.agents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
        actions: [
          IconButton(
            tooltip: 'New Agent',
            onPressed: () => _createAgent(context, chatModel),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: agents.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy_outlined,
                      size: 56,
                      color: context.colors.gray,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No agents yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create an agent to give the AI a custom system '
                      'prompt you can reuse across conversations.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.gray),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: agents.length,
              itemBuilder: (context, index) {
                final agent = agents[index];
                return Dismissible(
                  key: ValueKey(agent.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: Colors.red.shade400,
                    child:
                        const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context, agent.name),
                  onDismissed: (_) => chatModel.deleteAgent(agent.id),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          context.colors.accent.withValues(alpha: 0.12),
                      child: Text(
                        agent.emoji?.isNotEmpty == true
                            ? agent.emoji!
                            : '🤖',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    title: Text(
                      agent.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      agent.systemPrompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.colors.darkGray),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _editAgent(context, chatModel, agent),
                  ),
                );
              },
            ),
    );
  }
}
