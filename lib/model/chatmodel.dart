import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:polymind/model/agent_config.dart';
import 'package:polymind/model/chat_message.dart';
import 'package:polymind/model/provider_config.dart';
import 'package:polymind/repository/llm_repository.dart';
import 'package:polymind/repository/openai_repository.dart';
import 'package:polymind/repository/ollama_repository.dart';
import 'package:polymind/repository/gemini_repository.dart';
import 'package:polymind/repository/claude_repository.dart';
import 'package:polymind/repository/chat_database.dart';
import 'package:polymind/repository/secure_settings.dart';
import 'package:uuid/uuid.dart';

/// Chat Model — LLM 通信 + DB 永続化
class ChatModel extends ChangeNotifier {
  ChatModel() {
    _init();
  }

  LlmRepository? _repository;
  ProviderConfig? _config;
  final ChatDatabase _db = ChatDatabase.instance;
  final SecureSettings _settings = SecureSettings();
  final Uuid _uuid = const Uuid();

  bool _initialized = false;
  StreamSubscription<String>? _streamSubscription;
  Completer<void>? _streamCompleter;
  Object? _generationToken;
  int _idSeed = 0;
  final List<ChatMessage> _messages = [];
  String? _currentConversationId;
  bool _conversationPersisted = false;
  List<Map<String, dynamic>> _conversations = [];
  List<AgentConfig> _agents = [];
  AgentConfig? _selectedAgentForNewChat;
  String? _currentSystemPromptSnapshot;
  AgentConfig? _activeAgentForDisplay;

  UnmodifiableListView<ChatMessage> get messages =>
      UnmodifiableListView(_messages);

  List<Map<String, dynamic>> get conversations =>
      UnmodifiableListView(_conversations);

  List<AgentConfig> get agents => UnmodifiableListView(_agents);
  AgentConfig? get selectedAgentForNewChat => _selectedAgentForNewChat;
  AgentConfig? get activeAgentForDisplay => _activeAgentForDisplay;

  String? get currentConversationId => _currentConversationId;
  ProviderConfig? get config => _config;
  bool get isInitialized => _initialized;
  bool get isConfigured => _config != null && _config!.isValid;

  /// 現在のプロバイダーが画像生成に対応しているか
  bool get supportsImageGeneration =>
      _repository?.supportsImageGeneration ?? false;

  /// 応答を生成中かどうか（最後のメッセージが未完了のアシスタント発言）
  bool get isGenerating {
    if (_messages.isEmpty) return false;
    final last = _messages.last;
    return last.sender == ChatSender.assistant && !last.isComplete;
  }

  VoidCallback? onMessageAdded;
  VoidCallback? onMessageUpdated;

  void setScrollCallback(VoidCallback callback) => onMessageAdded = callback;
  void setUpdateCallback(VoidCallback callback) => onMessageUpdated = callback;

  Future<void> _init() async {
    _config = await _settings.load();
    if (_config != null && _config!.isValid) {
      _buildRepository();
    }
    await refreshConversations();
    _agents = await _db.getAgents();
    _initialized = true;
    notifyListeners();
  }

  /// 新規会話用に選択中のエージェントを変更する
  void selectAgent(AgentConfig? agent) {
    _selectedAgentForNewChat = agent;
    notifyListeners();
  }

  /// エージェントを新規作成する
  Future<void> createAgent(AgentConfig agent) async {
    await _db.createAgent(agent);
    _agents = await _db.getAgents();
    notifyListeners();
  }

  /// エージェントを更新する
  Future<void> updateAgent(AgentConfig agent) async {
    await _db.updateAgent(agent);
    _agents = await _db.getAgents();
    notifyListeners();
  }

  /// エージェントを削除する
  Future<void> deleteAgent(String id) async {
    await _db.deleteAgent(id);
    _agents = await _db.getAgents();
    if (_selectedAgentForNewChat?.id == id) {
      _selectedAgentForNewChat = null;
    }
    notifyListeners();
  }

  /// 設定を更新して Repository を再構築
  Future<void> updateConfig(ProviderConfig config) async {
    await _settings.save(config);
    _config = config;
    _buildRepository();
    notifyListeners();
  }

  void _buildRepository() {
    if (_config == null) return;
    switch (_config!.provider) {
      case LlmProvider.openai:
        _repository = OpenAiRepository(_config!);
        break;
      case LlmProvider.ollama:
        _repository = OllamaRepository(_config!);
        break;
      case LlmProvider.gemini:
        _repository = GeminiRepository(_config!);
        break;
      case LlmProvider.claude:
        _repository = ClaudeRepository(_config!);
        break;
      case LlmProvider.other:
        // OpenAI API 互換のエンドポイントとして扱う
        _repository = OpenAiRepository(_config!);
        break;
    }
  }

  /// 会話一覧を更新
  Future<void> refreshConversations() async {
    _conversations = await _db.getConversations();
    notifyListeners();
  }

  /// 新規会話を開始
  ///
  /// DB への保存は最初のメッセージ送信まで遅延させる。
  /// 即時保存すると、メッセージを送らずに何度も「New Chat」をタップした際に
  /// 空の会話が DB に残り続けてしまうため。
  Future<void> startNewConversation() async {
    _currentConversationId = _uuid.v4();
    _conversationPersisted = false;
    _messages.clear();
    _idSeed = 0;
    _currentSystemPromptSnapshot = null;
    _activeAgentForDisplay = null;
    notifyListeners();
  }

  /// 既存の会話をロード
  Future<void> loadConversation(String conversationId) async {
    _currentConversationId = conversationId;
    _conversationPersisted = true;
    final loaded = await _db.getMessages(conversationId);
    _messages
      ..clear()
      ..addAll(loaded);
    // idSeed を復元
    _idSeed = _messages.length;

    final row = await _db.getConversation(conversationId);
    _currentSystemPromptSnapshot = row?['system_prompt_snapshot'] as String?;
    final agentId = row?['agent_id'] as String?;
    _activeAgentForDisplay = agentId == null
        ? null
        : _agents.cast<AgentConfig?>().firstWhere(
              (a) => a?.id == agentId,
              orElse: () => null,
            );

    notifyListeners();

    if (onMessageAdded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageAdded!();
      });
    }
  }

  /// 会話を削除
  Future<void> deleteConversation(String conversationId) async {
    await _db.deleteConversation(conversationId);
    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
      _conversationPersisted = false;
      _messages.clear();
      _currentSystemPromptSnapshot = null;
      _activeAgentForDisplay = null;
    }
    await refreshConversations();
  }

  /// チャット送信
  Future<void> sendChat(String rawInput, {String? imagePath}) async {
    if (_repository == null) {
      _handleAssistantError(
        'プロバイダーが設定されていません。設定画面でプロバイダーとAPIキーを設定してください。',
      );
      return;
    }

    final request =
        _ChatRequest.parse(rawInput, hasAttachment: imagePath != null);
    if (request == null) return;

    // 会話がなければ新規作成（DB書き込みは行わない）
    if (_currentConversationId == null) {
      await startNewConversation();
    }

    await _ensureConversationTitle(request.displayText);

    final placeholder = request.type == _ChatTaskType.image
        ? 'rendering image...'
        : 'thinking...';
    await _addUserMessage(
      request.displayText,
      placeholder: placeholder,
      imagePath: imagePath,
    );

    await _generateReply(type: request.type, prompt: request.prompt);
  }

  /// 応答を停止する
  ///
  /// ストリーミング用の Subscription を直接 cancel することで、次のチャンクを
  /// 待たずに即座に中断する。チャンク間隔が空く場面（通信の遅延・停止）でも
  /// フラグのポーリングに頼らないため確実に止まる。画像生成中は基になる
  /// HTTP リクエスト自体は中断できないが、_generationToken を無効化して
  /// 結果を無視し、UI 上は即座に完了扱いにする。
  void stopGenerating() {
    if (!isGenerating) return;
    _generationToken = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_streamCompleter != null && !_streamCompleter!.isCompleted) {
      _streamCompleter!.complete();
    }
    _completeAsStopped();
  }

  Future<void> _completeAsStopped() async {
    if (_messages.isEmpty) return;
    final lastIndex = _messages.length - 1;
    final lastMessage = _messages[lastIndex];
    if (lastMessage.sender != ChatSender.assistant || lastMessage.isComplete) {
      return;
    }

    final text = lastMessage.isStreaming && lastMessage.text.trim().isNotEmpty
        ? lastMessage.text
        : 'Stopped.';
    _messages[lastIndex] = lastMessage.copyWith(
      text: text,
      status: ChatMessageStatus.complete,
    );
    notifyListeners();

    if (_currentConversationId != null) {
      await _db.updateMessage(
        id: lastMessage.id,
        text: text,
        status: ChatMessageStatus.complete.name,
      );
    }

    if (onMessageUpdated != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageUpdated!();
      });
    }
  }

  /// 最後のアシスタント応答を破棄して再生成する
  Future<void> regenerateLastResponse() async {
    if (_repository == null || _messages.isEmpty) return;
    final last = _messages.last;
    if (last.sender != ChatSender.assistant || !last.isComplete) return;

    final isImage = last.hasImage;
    final prompt = isImage ? (last.altText ?? '') : '';

    _messages.removeLast();
    if (_currentConversationId != null) {
      await _db.deleteMessage(last.id);
    }

    final placeholder = ChatMessage(
      id: _nextId(),
      sender: ChatSender.assistant,
      text: isImage ? 'rendering image...' : 'thinking...',
      status: ChatMessageStatus.loading,
    );
    _messages.add(placeholder);
    notifyListeners();
    if (_currentConversationId != null) {
      await _db.insertMessage(
        id: placeholder.id,
        conversationId: _currentConversationId!,
        message: placeholder,
      );
    }
    if (onMessageAdded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageAdded!();
      });
    }

    await _generateReply(
      type: isImage ? _ChatTaskType.image : _ChatTaskType.text,
      prompt: prompt,
    );
  }

  /// ユーザーメッセージを編集し、以降のメッセージを破棄して再送信する
  Future<void> editAndResend(String messageId, String newText) async {
    if (_repository == null) return;
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final target = _messages[index];
    if (target.sender != ChatSender.user) return;

    final request = _ChatRequest.parse(newText);
    if (request == null) return;

    final removed = _messages.sublist(index);
    _messages.removeRange(index, _messages.length);
    notifyListeners();
    if (_currentConversationId != null) {
      for (final m in removed) {
        await _db.deleteMessage(m.id);
      }
    }

    await _ensureConversationTitle(request.displayText);

    final placeholder = request.type == _ChatTaskType.image
        ? 'rendering image...'
        : 'thinking...';
    await _addUserMessage(
      request.displayText,
      placeholder: placeholder,
      imagePath: target.userImagePath,
    );

    await _generateReply(type: request.type, prompt: request.prompt);
  }

  /// メッセージを1件削除する（生成中のメッセージは対象外）
  Future<void> deleteMessage(String id) async {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final target = _messages[index];
    if (target.sender == ChatSender.assistant && !target.isComplete) return;

    _messages.removeAt(index);
    notifyListeners();
    await _db.deleteMessage(id);
  }

  /// 会話タイトルを変更する
  Future<void> renameConversation(String conversationId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _db.updateConversationTitle(conversationId, trimmed);
    await refreshConversations();
  }

  /// 最初のメッセージ送信時に会話をDBへ保存する（新規作成 or 題名更新）
  Future<void> _ensureConversationTitle(String displayText) async {
    if (_messages.isNotEmpty) return;
    final title = displayText.trim().isEmpty
        ? 'Photo'
        : (displayText.length > 30
            ? '${displayText.substring(0, 30)}...'
            : displayText);
    if (_conversationPersisted) {
      await _db.updateConversationTitle(_currentConversationId!, title);
    } else {
      _currentSystemPromptSnapshot = _selectedAgentForNewChat?.systemPrompt;
      _activeAgentForDisplay = _selectedAgentForNewChat;
      await _db.createConversation(
        id: _currentConversationId!,
        title: title,
        provider: (_config?.provider ?? LlmProvider.openai).name,
        model: _config?.model ?? '',
        agentId: _selectedAgentForNewChat?.id,
        systemPromptSnapshot: _currentSystemPromptSnapshot,
      );
      _conversationPersisted = true;
    }
    await refreshConversations();
  }

  Future<void> _generateReply({
    required _ChatTaskType type,
    required String prompt,
  }) async {
    if (_repository == null) return;
    final token = Object();
    _generationToken = token;
    try {
      if (type == _ChatTaskType.image) {
        if (!_repository!.supportsImageGeneration) {
          _handleAssistantError(
            'このプロバイダーは画像生成に対応していません。',
          );
          return;
        }
        final imageUrl = await _repository!.generateImage(prompt: prompt);
        // stopGenerating() で無効化されていれば結果は破棄する
        if (_generationToken != token) return;
        await _completeWithImage(
          imageUrl: imageUrl,
          description: prompt,
        );
        return;
      }

      final historySnapshot = List<ChatMessage>.from(_messages);
      var latestContent = '';
      final completer = Completer<void>();
      _streamCompleter = completer;

      _streamSubscription = _repository!
          .stream(
            history: historySnapshot,
            systemPrompt: _currentSystemPromptSnapshot,
          )
          .listen(
        (partial) {
          if (partial.isEmpty) return;
          latestContent = partial;
          _addStreamingUpdate(latestContent);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object e, StackTrace st) {
          if (!completer.isCompleted) completer.completeError(e, st);
        },
        cancelOnError: true,
      );

      await completer.future;
      _streamSubscription = null;
      _streamCompleter = null;

      // stopGenerating() 経由で中断済みなら、UI は既に確定済みなのでここでは何もしない
      if (_generationToken != token) return;

      if (latestContent.isEmpty) {
        final finalHistory = List<ChatMessage>.from(_messages);
        latestContent = await _repository!.generate(
          history: finalHistory,
          systemPrompt: _currentSystemPromptSnapshot,
        );
        if (_generationToken != token) return;
        if (latestContent.isNotEmpty) {
          _addStreamingUpdate(latestContent);
        }
      }

      await _completeStreaming(latestContent);
    } catch (e) {
      if (_generationToken != token) return;
      final safeMsg = type == _ChatTaskType.image
          ? 'Failed to generate image. Please check your settings and try again.'
          : 'An unexpected error occurred. Please check your connection and settings.';
      debugPrint('ChatModel error: $e');
      _handleAssistantError(safeMsg);
    } finally {
    }
  }

  Future<void> _addUserMessage(
    String txt, {
    String placeholder = 'thinking...',
    String? imagePath,
  }) async {
    final sanitized = txt.trim();
    if (sanitized.isEmpty && imagePath == null) return;

    final userMsg = ChatMessage(
      id: _nextId(),
      sender: ChatSender.user,
      text: sanitized,
      status: ChatMessageStatus.complete,
      userImagePath: imagePath,
    );
    final aiMsg = ChatMessage(
      id: _nextId(),
      sender: ChatSender.assistant,
      text: placeholder,
      status: ChatMessageStatus.loading,
    );

    _messages.addAll([userMsg, aiMsg]);
    notifyListeners();

    // DB に保存
    if (_currentConversationId != null) {
      await _db.insertMessage(
        id: userMsg.id,
        conversationId: _currentConversationId!,
        message: userMsg,
      );
      await _db.insertMessage(
        id: aiMsg.id,
        conversationId: _currentConversationId!,
        message: aiMsg,
      );
      await _db.touchConversation(_currentConversationId!);
    }

    if (onMessageAdded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageAdded!();
      });
    }
  }

  void _addStreamingUpdate(String partialContent) {
    if (_messages.isEmpty) return;

    final lastIndex = _messages.length - 1;
    final lastMessage = _messages[lastIndex];
    if (lastMessage.sender != ChatSender.assistant || lastMessage.hasImage) {
      return;
    }

    _messages[lastIndex] = lastMessage.copyWith(
      text: partialContent,
      status: ChatMessageStatus.streaming,
    );
    notifyListeners();

    if (onMessageUpdated != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageUpdated!();
      });
    }
  }

  Future<void> _completeStreaming(String content) async {
    if (_messages.isEmpty) return;

    final lastIndex = _messages.length - 1;
    final lastMessage = _messages[lastIndex];
    if (lastMessage.sender != ChatSender.assistant || lastMessage.hasImage) {
      return;
    }

    final finalText = content.isEmpty ? lastMessage.text : content;
    _messages[lastIndex] = lastMessage.copyWith(
      text: finalText,
      status: ChatMessageStatus.complete,
    );
    notifyListeners();

    // DB 更新
    if (_currentConversationId != null) {
      await _db.updateMessage(
        id: lastMessage.id,
        text: finalText,
        status: ChatMessageStatus.complete.name,
      );
    }

    if (onMessageUpdated != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageUpdated!();
      });
    }
  }

  void _handleAssistantError(String message) {
    if (_messages.isNotEmpty &&
        _messages.last.sender == ChatSender.assistant &&
        !_messages.last.isComplete) {
      // loading/streaming メッセージをエラーメッセージに置き換え
      final lastId = _messages.last.id;
      _messages[_messages.length - 1] = _messages.last.copyWith(
        text: message,
        status: ChatMessageStatus.complete,
      );
      notifyListeners();

      // DB も更新
      if (_currentConversationId != null) {
        _db.updateMessage(
          id: lastId,
          text: message,
          status: ChatMessageStatus.complete.name,
        );
      }
    } else {
      // 置き換え対象がない場合は新規追加
      final errorMsg = ChatMessage(
        id: _nextId(),
        sender: ChatSender.assistant,
        text: message,
        status: ChatMessageStatus.complete,
      );
      _messages.add(errorMsg);
      notifyListeners();

      if (_currentConversationId != null) {
        _db.insertMessage(
          id: errorMsg.id,
          conversationId: _currentConversationId!,
          message: errorMsg,
        );
      }
    }

    if (onMessageAdded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageAdded!();
      });
    }
  }

  Future<void> _completeWithImage({
    required String imageUrl,
    required String description,
  }) async {
    if (_messages.isEmpty) return;

    final lastIndex = _messages.length - 1;
    final lastMessage = _messages[lastIndex];
    if (lastMessage.sender != ChatSender.assistant) return;

    _messages[lastIndex] = lastMessage.copyWith(
      text: description.isEmpty ? 'Generated image.' : 'Generated image:',
      altText: description.isNotEmpty ? description : null,
      imageUrl: imageUrl,
      status: ChatMessageStatus.complete,
    );
    notifyListeners();

    if (_currentConversationId != null) {
      await _db.updateMessage(
        id: lastMessage.id,
        text: _messages[lastIndex].text,
        status: ChatMessageStatus.complete.name,
        imageUrl: imageUrl,
        altText: description.isNotEmpty ? description : null,
      );
    }

    if (onMessageUpdated != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMessageUpdated!();
      });
    }
  }

  /// 外部から addUserMessage を呼ぶ場合（テスト用）
  void addUserMessage(String txt, {String placeholder = 'thinking...'}) {
    _addUserMessage(txt, placeholder: placeholder);
  }

  String _nextId() {
    _idSeed += 1;
    return '${_currentConversationId ?? 'tmp'}_$_idSeed';
  }
}

final chatProvider = ChangeNotifierProvider((ref) => ChatModel());

enum _ChatTaskType { text, image }

class _ChatRequest {
  const _ChatRequest({
    required this.type,
    required this.displayText,
    required this.prompt,
  });

  final _ChatTaskType type;
  final String displayText;
  final String prompt;

  static _ChatRequest? parse(String input, {bool hasAttachment = false}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      // 画像添付があれば、キャプションなしのVision送信として扱う
      return hasAttachment
          ? const _ChatRequest(
              type: _ChatTaskType.text,
              displayText: '',
              prompt: '',
            )
          : null;
    }

    final lower = trimmed.toLowerCase();
    const prefixes = ['/image', '/img', 'image:', 'img:'];
    for (final prefix in prefixes) {
      if (lower.startsWith(prefix)) {
        final prompt = trimmed.substring(prefix.length).trim();
        if (prompt.isEmpty) break;
        return _ChatRequest(
          type: _ChatTaskType.image,
          displayText: trimmed,
          prompt: prompt,
        );
      }
    }

    return _ChatRequest(
      type: _ChatTaskType.text,
      displayText: trimmed,
      prompt: trimmed,
    );
  }
}
