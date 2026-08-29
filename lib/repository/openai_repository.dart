import 'dart:convert';
import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:langchain/langchain.dart' as lc;
import 'package:langchain_openai/langchain_openai.dart';

import 'package:polymind/model/chat_message.dart';
import 'package:polymind/model/provider_config.dart';
import 'package:polymind/repository/llm_repository.dart';

/// OpenAI 用 LLM Repository
class OpenAiRepository implements LlmRepository {
  OpenAiRepository(this._config)
      : _chatModel = ChatOpenAI(
          apiKey: _config.apiKey ?? '',
          baseUrl: _normalizeUrl(_config.endpoint),
          defaultOptions: ChatOpenAIOptions(
            model: _config.model,
            temperature: _config.temperature,
            maxTokens: 2000,
          ),
        );

  final ProviderConfig _config;
  final ChatOpenAI _chatModel;
  final http.Client _httpClient = http.Client();

  @override
  bool get supportsImageGeneration => true;

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
  Future<String> generateImage({required String prompt}) async {
    final modelName = _config.imageModel ?? 'gpt-image-1';
    final baseUrl = _normalizeUrl(_config.endpoint);
    final uri = Uri.parse('$baseUrl/images/generations');

    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${_config.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelName,
        'prompt': prompt,
        'n': 1,
        'size': '1024x1024',
      }),
    );

    if (response.statusCode != 200) {
      throw StateError(
        'Image generation failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    if (data.isEmpty) {
      throw StateError('No image payload returned from API.');
    }

    final first = data.first as Map<String, dynamic>;
    final url = first['url'] as String?;
    final b64 = first['b64_json'] as String?;

    if (url != null && url.isNotEmpty) return url;
    if (b64 != null && b64.isNotEmpty) return 'data:image/png;base64,$b64';
    throw StateError('Image payload missing URL and base64 content.');
  }

  @override
  Future<List<String>> listModels() async {
    final baseUrl = _normalizeUrl(_config.endpoint);
    final uri = Uri.parse('$baseUrl/models');
    final response = await _httpClient.get(
      uri,
      headers: {'Authorization': 'Bearer ${_config.apiKey}'},
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Failed to list models: ${response.statusCode} ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List<dynamic>? ?? [];
    final ids = data
        .whereType<Map<String, dynamic>>()
        .map((m) => m['id'] as String?)
        .whereType<String>()
        .toList()
      ..sort();
    return ids;
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
        if (message.hasImage) {
          final description = message.altText?.trim().isNotEmpty == true
              ? message.altText!.trim()
              : 'Generated an image.';
          prompt.add(lc.ChatMessage.aiText('Generated image: $description'));
        } else {
          prompt.add(lc.ChatMessage.aiText(message.text));
        }
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
