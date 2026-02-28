import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:langchain/langchain.dart' as lc;
import 'package:langchain_openai/langchain_openai.dart';

import 'package:flutter_chatgpt/model/chat_message.dart';
import 'package:flutter_chatgpt/model/provider_config.dart';
import 'package:flutter_chatgpt/repository/llm_repository.dart';

/// OpenAI 用 LLM Repository
class OpenAiRepository implements LlmRepository {
  OpenAiRepository(this._config)
      : _chatModel = ChatOpenAI(
          apiKey: _config.apiKey ?? '',
          baseUrl: _normalizeUrl(_config.endpoint),
          defaultOptions: ChatOpenAIOptions(
            model: _config.model,
            temperature: 0,
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
    final prompt = lc.PromptValue.chat(_buildPrompt(history));
    final result = await _chatModel.invoke(prompt);
    return result.outputAsString;
  }

  @override
  Stream<String> stream({required List<ChatMessage> history}) {
    final prompt = lc.PromptValue.chat(_buildPrompt(history));
    var buffer = '';
    return _chatModel.stream(prompt).map((chunk) {
      final delta = chunk.output.content;
      if (delta.isEmpty) return buffer;
      buffer += delta;
      return buffer;
    });
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

  static String _normalizeUrl(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static List<lc.ChatMessage> _buildPrompt(List<ChatMessage> history) {
    final prompt = <lc.ChatMessage>[];
    for (final message in history) {
      if (!message.isComplete) continue;
      if (message.sender == ChatSender.user) {
        prompt.add(lc.ChatMessage.humanText(message.text));
      } else if (message.sender == ChatSender.assistant) {
        if (message.hasImage) {
          final description = message.altText?.trim().isNotEmpty == true
              ? message.altText!.trim()
              : 'Generated an image.';
          prompt.add(lc.ChatMessage.ai('Generated image: $description'));
        } else {
          prompt.add(lc.ChatMessage.ai(message.text));
        }
      }
    }
    return prompt;
  }
}
