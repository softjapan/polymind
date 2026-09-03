import 'package:flutter/material.dart';
import 'package:polymind/constants.dart';
import 'package:polymind/model/agent_config.dart';
import 'package:polymind/model/chatmodel.dart';
import 'package:polymind/model/chat_message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polymind/widgets/ai_message.dart';
import 'package:polymind/widgets/loading.dart';
import 'package:polymind/widgets/user_input.dart';
import 'package:polymind/widgets/user_message.dart';
import 'package:polymind/widgets/settings_screen.dart';
import 'package:polymind/widgets/conversation_drawer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PolyMind',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const _HomePage(),
    );
  }
}

class _HomePage extends ConsumerStatefulWidget {
  const _HomePage();

  @override
  ConsumerState<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<_HomePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _chatController = TextEditingController();
  bool _hasOpenedSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatModel = ref.read(chatProvider);
      chatModel.setScrollCallback(_scrollToBottom);
      chatModel.setUpdateCallback(_scrollToBottom);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatModel = ref.watch(chatProvider);

    // 初期化完了まではローディング表示
    if (!chatModel.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!chatModel.isConfigured && !_hasOpenedSettings) {
      _hasOpenedSettings = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSettings();
      });
    }

    final providerName = chatModel.config?.provider.name.toUpperCase();
    final modelName = chatModel.config?.model ?? 'Not configured';

    return SafeArea(
      top: false,
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (providerName != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    providerName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  modelName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (chatModel.activeAgentForDisplay != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.colors.inputBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${chatModel.activeAgentForDisplay!.emoji ?? '🤖'} '
                    '${chatModel.activeAgentForDisplay!.name}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.colors.darkGray,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'New Chat',
              onPressed: () => chatModel.startNewConversation(),
              icon: const Icon(Icons.edit_note_rounded),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        drawer: const ConversationDrawer(),
        body: _ChatBody(
          scrollController: _scrollController,
          chatController: _chatController,
          messages: chatModel.messages,
          chatModel: chatModel,
        ),
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.scrollController,
    required this.chatController,
    required this.messages,
    required this.chatModel,
  });

  final ScrollController scrollController;
  final TextEditingController chatController;
  final List<ChatMessage> messages;
  final ChatModel chatModel;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: messages.isEmpty
                ? _EmptyState(
                    supportsImageGeneration: chatModel.supportsImageGeneration,
                    chatModel: chatModel,
                  )
                : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessageWidget(
                    messages[index],
                    isLast: index == messages.length - 1,
                  ),
                ),
          ),
        ),
        UserInput(chatcontroller: chatController),
      ],
    );
  }

  Widget _buildMessageWidget(ChatMessage message, {required bool isLast}) {
    switch (message.sender) {
      case ChatSender.user:
        return UserMessage(
          key: ValueKey(message.id),
          text: message.text,
          imagePath: message.userImagePath,
          onEdit: (newText) => chatModel.editAndResend(message.id, newText),
          onDelete: () => chatModel.deleteMessage(message.id),
        );
      case ChatSender.assistant:
        if (message.isLoading) {
          return Loading(key: ValueKey(message.id), text: message.text);
        }
        return AiMessage(
          key: ValueKey(message.id),
          text: message.text,
          imageUrl: message.imageUrl,
          altText: message.altText,
          isStreaming: message.isStreaming,
          onDelete: () => chatModel.deleteMessage(message.id),
          onRegenerate: isLast && !message.isStreaming
              ? () => chatModel.regenerateLastResponse()
              : null,
        );
    }
  }
}

/// Item 5: Empty state with welcome message
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.supportsImageGeneration,
    required this.chatModel,
  });

  final bool supportsImageGeneration;
  final ChatModel chatModel;

  Future<void> _pickAgent(BuildContext context) async {
    final selected = await showModalBottomSheet<AgentConfig?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('No agent'),
                onTap: () => Navigator.of(ctx).pop<AgentConfig?>(null),
              ),
              for (final agent in chatModel.agents)
                ListTile(
                  leading: Text(
                    agent.emoji?.isNotEmpty == true ? agent.emoji! : '🤖',
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(agent.name),
                  onTap: () => Navigator.of(ctx).pop<AgentConfig?>(agent),
                ),
            ],
          ),
        );
      },
    );
    // ボトムシートを閉じた（キャンセル）場合と「No agent」を選んだ場合を区別できないが、
    // どちらも「選択なし」として扱って問題ない設計にしている。
    chatModel.selectAgent(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedAgent = chatModel.selectedAgentForNewChat;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: context.colors.gray,
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.colors.darkGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              supportsImageGeneration
                  ? 'Type a message below to chat with AI.\n'
                      'Use /image <prompt> to generate images.'
                  : 'Type a message below to chat with AI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.gray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ActionChip(
              avatar: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: context.colors.accent,
              ),
              label: Text(
                selectedAgent == null
                    ? 'No agent selected'
                    : '${selectedAgent.emoji ?? '🤖'} ${selectedAgent.name}',
              ),
              onPressed: () => _pickAgent(context),
            ),
          ],
        ),
      ),
    );
  }
}
