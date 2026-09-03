import 'package:flutter/foundation.dart';

/// 対応する LLM プロバイダー
enum LlmProvider {
  /// OpenAI API
  openai,

  /// Ollama (ローカル LLM)
  ollama,

  /// Google Gemini API
  gemini,

  /// Anthropic Claude API
  claude,

  /// その他の OpenAI API 互換プロバイダー
  other,
}

/// プロバイダー設定データ
@immutable
class ProviderConfig {
  const ProviderConfig({
    required this.provider,
    required this.endpoint,
    required this.model,
    this.imageModel,
    this.apiKey,
    this.temperature = 0.7,
  });

  final LlmProvider provider;
  final String endpoint;
  final String model;
  final String? imageModel;
  final String? apiKey;

  /// 応答の多様性（0.0〜1.0）
  final double temperature;

  /// 設定が有効かどうか
  bool get isValid {
    if (endpoint.isEmpty || model.isEmpty) return false;
    switch (provider) {
      case LlmProvider.openai:
      case LlmProvider.gemini:
      case LlmProvider.claude:
      case LlmProvider.other:
        return apiKey != null && apiKey!.isNotEmpty;
      case LlmProvider.ollama:
        return true; // Ollama は API キー不要
    }
  }

  /// デフォルト設定
  static const defaultOpenAi = ProviderConfig(
    provider: LlmProvider.openai,
    endpoint: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini-2024-07-18',
    imageModel: 'gpt-image-1',
  );

  static const defaultOllama = ProviderConfig(
    provider: LlmProvider.ollama,
    endpoint: 'http://localhost:11434',
    model: 'llama3.2',
  );

  static const defaultGemini = ProviderConfig(
    provider: LlmProvider.gemini,
    endpoint: 'https://generativelanguage.googleapis.com',
    model: 'gemini-2.5-flash',
  );

  static const defaultClaude = ProviderConfig(
    provider: LlmProvider.claude,
    endpoint: 'https://api.anthropic.com',
    model: 'claude-sonnet-4-5',
  );

  static const defaultOther = ProviderConfig(
    provider: LlmProvider.other,
    endpoint: '',
    model: '',
  );

  ProviderConfig copyWith({
    LlmProvider? provider,
    String? endpoint,
    String? model,
    String? imageModel,
    String? apiKey,
    double? temperature,
  }) {
    return ProviderConfig(
      provider: provider ?? this.provider,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      imageModel: imageModel ?? this.imageModel,
      apiKey: apiKey ?? this.apiKey,
      temperature: temperature ?? this.temperature,
    );
  }
}
