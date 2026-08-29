import 'package:flutter/foundation.dart';

/// 種類を表す列挙体
enum ChatSender {
  /// ユーザーからのメッセージ
  user,

  /// AI からのメッセージ
  assistant,
}

/// メッセージの状態を表す列挙体
enum ChatMessageStatus {
  /// コンテンツ生成待機中（ローディング）
  loading,

  /// ストリーミング中（部分的な出力）
  streaming,

  /// 応答完了
  complete,
}

/// チャットメッセージのデータモデル
@immutable
class ChatMessage {
  /// コンストラクタ
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.status,
    this.imageUrl,
    this.altText,
    this.userImagePath,
  });

  /// メッセージを一意に識別する ID
  final String id;

  /// メッセージの送信者
  final ChatSender sender;

  /// メッセージ本文
  final String text;

  /// 画像URL（画像生成結果用）
  final String? imageUrl;

  /// 画像の説明や代替テキスト
  final String? altText;

  /// ユーザーが添付した画像のローカルファイルパス（Vision 入力用）
  final String? userImagePath;

  /// メッセージの状態
  final ChatMessageStatus status;

  /// ローディング中かどうか
  bool get isLoading => status == ChatMessageStatus.loading;

  /// ストリーミング中かどうか
  bool get isStreaming => status == ChatMessageStatus.streaming;

  /// 完了済みかどうか
  bool get isComplete => status == ChatMessageStatus.complete;

  /// 画像メッセージかどうか
  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  /// ユーザーが画像を添付しているかどうか
  bool get hasUserImage => userImagePath != null && userImagePath!.isNotEmpty;

  /// メッセージのコピーを作成
  ChatMessage copyWith({
    String? id,
    ChatSender? sender,
    String? text,
    ChatMessageStatus? status,
    String? imageUrl,
    String? altText,
    String? userImagePath,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      altText: altText ?? this.altText,
      userImagePath: userImagePath ?? this.userImagePath,
      status: status ?? this.status,
    );
  }
}
