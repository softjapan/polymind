import 'package:langchain/langchain.dart' as lc;
import 'package:langchain_ollama/langchain_ollama.dart';

import 'package:flutter_chatgpt/model/chat_message.dart';
import 'package:flutter_chatgpt/model/provider_config.dart';
import 'package:flutter_chatgpt/repository/llm_repository.dart';

/// Ollama 用 LLM Repository
class OllamaRepository implements LlmRepository {
  OllamaRepository(this._config)
      : _chatModel = ChatOllama(
          baseUrl: '${_config.endpoint}/api',
          defaultOptions: ChatOllamaOptions(
            model: _config.model,
            temperature: 0,
          ),
        );

  // ignore: unused_field
  final ProviderConfig _config;
  final ChatOllama _chatModel;

  @override
  bool get supportsImageGeneration => false;

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
  Future<String> generateImage({required String prompt}) {
    throw UnsupportedError('Ollama does not support image generation.');
  }

  static List<lc.ChatMessage> _buildPrompt(List<ChatMessage> history) {
    final prompt = <lc.ChatMessage>[];
    for (final message in history) {
      if (!message.isComplete) continue;
      if (message.sender == ChatSender.user) {
        prompt.add(lc.ChatMessage.humanText(message.text));
      } else if (message.sender == ChatSender.assistant) {
        prompt.add(lc.ChatMessage.ai(message.text));
      }
    }
    return prompt;
  }
}
