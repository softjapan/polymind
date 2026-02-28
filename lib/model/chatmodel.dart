import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chatgpt/model/chat_message.dart';
import 'package:flutter_chatgpt/model/provider_config.dart';
import 'package:flutter_chatgpt/repository/llm_repository.dart';
import 'package:flutter_chatgpt/repository/openai_repository.dart';
import 'package:flutter_chatgpt/repository/ollama_repository.dart';
import 'package:flutter_chatgpt/repository/chat_database.dart';
import 'package:flutter_chatgpt/repository/secure_settings.dart';
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

  int _idSeed = 0;
  final List<ChatMessage> _messages = [];
  String? _currentConversationId;
  List<Map<String, dynamic>> _conversations = [];

  UnmodifiableListView<ChatMessage> get messages =>
      UnmodifiableListView(_messages);

  List<Map<String, dynamic>> get conversations =>
      UnmodifiableListView(_conversations);

  String? get currentConversationId => _currentConversationId;
  ProviderConfig? get config => _config;
  bool get isConfigured => _config != null && _config!.isValid;

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
    }
  }

  /// 会話一覧を更新
  Future<void> refreshConversations() async {
    _conversations = await _db.getConversations();
    notifyListeners();
  }

  /// 新規会話を開始
  Future<void> startNewConversation() async {
    final id = _uuid.v4();
    await _db.createConversation(
      id: id,
      title: 'New Chat',
      provider: (_config?.provider ?? LlmProvider.openai).name,
      model: _config?.model ?? '',
    );
    _currentConversationId = id;
    _messages.clear();
    _idSeed = 0;
    await refreshConversations();
  }

  /// 既存の会話をロード
  Future<void> loadConversation(String conversationId) async {
    _currentConversationId = conversationId;
    final loaded = await _db.getMessages(conversationId);
    _messages
      ..clear()
      ..addAll(loaded);
    // idSeed を復元
    _idSeed = _messages.length;
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
      _messages.clear();
    }
    await refreshConversations();
  }

  /// チャット送信
  Future<void> sendChat(String rawInput) async {
    if (_repository == null) return;

    final request = _ChatRequest.parse(rawInput);
    if (request == null) return;

    // 会話がなければ新規作成
    if (_currentConversationId == null) {
      await startNewConversation();
      // 最初のメッセージをタイトルにする
      final title = request.displayText.length > 30
          ? '${request.displayText.substring(0, 30)}...'
          : request.displayText;
      await _db.updateConversationTitle(_currentConversationId!, title);
      await refreshConversations();
    }

    final placeholder = request.type == _ChatTaskType.image
        ? 'rendering image...'
        : 'thinking...';
    await _addUserMessage(request.displayText, placeholder: placeholder);

    try {
      if (request.type == _ChatTaskType.image) {
        if (!_repository!.supportsImageGeneration) {
          _handleAssistantError(
            'このプロバイダーは画像生成に対応していません。',
          );
          return;
        }
        final imageUrl =
            await _repository!.generateImage(prompt: request.prompt);
        await _completeWithImage(
          imageUrl: imageUrl,
          description: request.prompt,
        );
        return;
      }

      final historySnapshot = List<ChatMessage>.from(_messages);
      var latestContent = '';

      await for (final partial
          in _repository!.stream(history: historySnapshot)) {
        if (partial.isEmpty) continue;
        latestContent = partial;
        _addStreamingUpdate(latestContent);
      }

      if (latestContent.isEmpty) {
        final finalHistory = List<ChatMessage>.from(_messages);
        latestContent = await _repository!.generate(history: finalHistory);
        if (latestContent.isNotEmpty) {
          _addStreamingUpdate(latestContent);
        }
      }

      await _completeStreaming(latestContent);
    } catch (e) {
      _handleAssistantError(
        request.type == _ChatTaskType.image
            ? 'Failed to generate image: $e'
            : 'An unexpected error occurred: $e',
      );
    }
  }

  Future<void> _addUserMessage(
    String txt, {
    String placeholder = 'thinking...',
  }) async {
    final sanitized = txt.trim();
    if (sanitized.isEmpty) return;

    final userMsg = ChatMessage(
      id: _nextId(),
      sender: ChatSender.user,
      text: sanitized,
      status: ChatMessageStatus.complete,
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

  static _ChatRequest? parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

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
