import 'package:polymind/model/chat_message.dart';

/// LLM プロバイダーの抽象インターフェース
abstract class LlmRepository {
  /// テキスト応答をストリーミングで取得
  Stream<String> stream({required List<ChatMessage> history});

  /// テキスト応答を一括取得
  Future<String> generate({required List<ChatMessage> history});

  /// 画像を生成（未対応プロバイダーは UnsupportedError を投げる）
  Future<String> generateImage({required String prompt});

  /// 画像生成をサポートしているか
  bool get supportsImageGeneration;

  /// 利用可能なモデル一覧を取得
  Future<List<String>> listModels();
}
