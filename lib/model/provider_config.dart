import 'package:flutter/foundation.dart';

/// 対応する LLM プロバイダー
enum LlmProvider {
  /// OpenAI API
  openai,

  /// Ollama (ローカル LLM)
  ollama,
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
  });

  final LlmProvider provider;
  final String endpoint;
  final String model;
  final String? imageModel;
  final String? apiKey;

  /// 設定が有効かどうか
  bool get isValid {
    if (endpoint.isEmpty || model.isEmpty) return false;
    if (provider == LlmProvider.openai) {
      return apiKey != null && apiKey!.isNotEmpty;
    }
    return true; // Ollama は API キー不要
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

  ProviderConfig copyWith({
    LlmProvider? provider,
    String? endpoint,
    String? model,
    String? imageModel,
    String? apiKey,
  }) {
    return ProviderConfig(
      provider: provider ?? this.provider,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      imageModel: imageModel ?? this.imageModel,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}
