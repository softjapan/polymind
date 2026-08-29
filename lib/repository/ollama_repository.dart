import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:langchain/langchain.dart' as lc;
import 'package:langchain_ollama/langchain_ollama.dart';

import 'package:polymind/model/chat_message.dart';
import 'package:polymind/model/provider_config.dart';
import 'package:polymind/repository/llm_repository.dart';

/// Ollama 用 LLM Repository
class OllamaRepository implements LlmRepository {
  OllamaRepository(this._config)
      : _chatModel = ChatOllama(
          baseUrl: '${_config.endpoint}/api',
          defaultOptions: ChatOllamaOptions(
            model: _config.model,
            temperature: _config.temperature,
          ),
        );

  final ProviderConfig _config;
  final ChatOllama _chatModel;
  final http.Client _httpClient = http.Client();

  @override
  bool get supportsImageGeneration => false;

  @override
  Future<String> generate({required List<ChatMessage> history}) async {
    final prompt = lc.PromptValue.chat(await _buildPrompt(history));
    final result = await _chatModel.invoke(prompt);
    return result.outputAsString;
  }

  @override
  Stream<String> stream({required List<ChatMessage> history}) async* {
    final prompt = lc.PromptValue.chat(await _buildPrompt(history));
    var buffer = '';
    await for (final chunk in _chatModel.stream(prompt)) {
      final delta = chunk.output.contentAsString;
      if (delta.isEmpty) continue;
      buffer += delta;
      yield buffer;
    }
  }

  @override
  Future<String> generateImage({required String prompt}) {
    throw UnsupportedError('Ollama does not support image generation.');
  }

  @override
  Future<List<String>> listModels() async {
    final baseUrl = _normalizeUrl(_config.endpoint);
    final uri = Uri.parse('$baseUrl/api/tags');
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw StateError(
        'Failed to list models: ${response.statusCode} ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final models = decoded['models'] as List<dynamic>? ?? [];
    final names = models
        .whereType<Map<String, dynamic>>()
        .map((m) => m['name'] as String?)
        .whereType<String>()
        .toList()
      ..sort();
    return names;
  }

  static String _normalizeUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<List<lc.ChatMessage>> _buildPrompt(
    List<ChatMessage> history,
  ) async {
    final prompt = <lc.ChatMessage>[];
    for (final message in history) {
      if (!message.isComplete) continue;
      if (message.sender == ChatSender.user) {
        prompt.add(await _buildHumanMessage(message));
      } else if (message.sender == ChatSender.assistant) {
        prompt.add(lc.ChatMessage.aiText(message.text));
      }
    }
    return prompt;
  }

  static Future<lc.ChatMessage> _buildHumanMessage(ChatMessage message) async {
    if (!message.hasUserImage) {
      return lc.ChatMessage.humanText(message.text);
    }
    final imageContent = await _encodeUserImage(message.userImagePath!);
    if (imageContent == null) {
      return lc.ChatMessage.humanText(message.text);
    }
    return lc.HumanChatMessage(
      content: lc.ChatMessageContent.multiModal([
        lc.ChatMessageContent.text(message.text),
        imageContent,
      ]),
    );
  }

  static Future<lc.ChatMessageContent?> _encodeUserImage(String path) async {
    final file = io.File(path);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    final mimeType = path.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    return lc.ChatMessageContent.image(
      data: base64Encode(bytes),
      mimeType: mimeType,
    );
  }
}
