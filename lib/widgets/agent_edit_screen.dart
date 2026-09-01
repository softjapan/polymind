import 'package:flutter/material.dart';
import 'package:polymind/constants.dart';
import 'package:polymind/model/agent_config.dart';
import 'package:uuid/uuid.dart';

/// エージェントの新規作成・編集フォーム
///
/// 呼び出し側は Navigator.push の戻り値（AgentConfig?）を見て
/// 作成/更新をハンドリングする。
class AgentEditScreen extends StatefulWidget {
  const AgentEditScreen({super.key, this.existing});

  final AgentConfig? existing;

  @override
  State<AgentEditScreen> createState() => _AgentEditScreenState();
}

class _AgentEditScreenState extends State<AgentEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _emojiController = TextEditingController(text: existing?.emoji ?? '');
    _promptController =
        TextEditingController(text: existing?.systemPrompt ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final prompt = _promptController.text.trim();
    if (name.isEmpty || prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and system prompt are required.')),
      );
      return;
    }
    final emoji = _emojiController.text.trim();
    final now = DateTime.now();
    final existing = widget.existing;
    final result = existing == null
        ? AgentConfig(
            id: const Uuid().v4(),
            name: name,
            emoji: emoji.isEmpty ? null : emoji,
            systemPrompt: prompt,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: name,
            emoji: emoji.isEmpty ? null : emoji,
            systemPrompt: prompt,
            updatedAt: now,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Agent' : 'New Agent'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _emojiController,
            maxLength: 2,
            decoration: const InputDecoration(
              labelText: 'Emoji (optional)',
              hintText: '🗾',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Kansai-ben Assistant',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'System Prompt',
              hintText: 'Describe how this agent should behave...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This prompt is sent to the AI at the start of every '
            'conversation started with this agent.',
            style: TextStyle(fontSize: 12, color: context.colors.gray),
          ),
        ],
      ),
    );
  }
}
