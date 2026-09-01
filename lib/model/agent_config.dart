import 'package:flutter/foundation.dart';

/// カスタマイズ可能なエージェント（システムプロンプトのプリセット）
@immutable
class AgentConfig {
  const AgentConfig({
    required this.id,
    required this.name,
    required this.systemPrompt,
    required this.createdAt,
    required this.updatedAt,
    this.emoji,
  });

  final String id;
  final String name;
  final String? emoji;
  final String systemPrompt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AgentConfig copyWith({
    String? name,
    String? emoji,
    String? systemPrompt,
    DateTime? updatedAt,
  }) {
    return AgentConfig(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AgentConfig.fromRow(Map<String, dynamic> row) {
    return AgentConfig(
      id: row['id'] as String,
      name: row['name'] as String,
      emoji: row['emoji'] as String?,
      systemPrompt: row['system_prompt'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'system_prompt': systemPrompt,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}
