import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:polymind/model/agent_config.dart';
import 'package:polymind/model/chat_message.dart';

/// SQLite によるチャット履歴永続化
class ChatDatabase {
  ChatDatabase._();

  static ChatDatabase? _instance;
  Database? _db;

  static ChatDatabase get instance => _instance ??= ChatDatabase._();

  Future<Database> get database async => _db ??= await _initDb();

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'chat_history.db'),
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            provider TEXT NOT NULL,
            model TEXT NOT NULL,
            agent_id TEXT,
            system_prompt_snapshot TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            sender TEXT NOT NULL,
            text TEXT NOT NULL,
            status TEXT NOT NULL,
            image_url TEXT,
            alt_text TEXT,
            user_image_path TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (conversation_id) REFERENCES conversations(id)
              ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE agents (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            emoji TEXT,
            system_prompt TEXT NOT NULL,
            tools TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await _seedDefaultAgents(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN user_image_path TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE agents (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              emoji TEXT,
              system_prompt TEXT NOT NULL,
              tools TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.execute(
            'ALTER TABLE conversations ADD COLUMN agent_id TEXT',
          );
          await db.execute(
            'ALTER TABLE conversations ADD COLUMN system_prompt_snapshot TEXT',
          );
        }
        if (oldVersion < 4) {
          final count = Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM agents'),
              ) ??
              0;
          // 既にエージェントが存在する場合（ユーザーが自作済み）は上書きしない
          if (count == 0) {
            await _seedDefaultAgents(db);
          }
        }
      },
    );
  }

  /// 初回起動時にプリインストールされる、汎用的で実用性の高いエージェント群
  static Future<void> _seedDefaultAgents(DatabaseExecutor db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final presets = <Map<String, String>>[
      {
        'id': 'builtin-writing-assistant',
        'name': '文章校正・リライト',
        'emoji': '📝',
        'system_prompt':
            'あなたはプロの文章校正・編集アシスタントです。ユーザーが入力した文章の誤字脱字・文法・言い回しを改善し、'
                'より自然で読みやすい文章に校正してください。元の意図やトーンは保ったまま、具体的な修正案を提示して'
                'ください。ユーザーが入力した言語と同じ言語で応答してください。',
      },
      {
        'id': 'builtin-code-reviewer',
        'name': 'コードレビュアー',
        'emoji': '💻',
        'system_prompt':
            'あなたは経験豊富なソフトウェアエンジニアとしてコードレビューを行います。提示されたコードのバグ・'
                'セキュリティ上の懸念・可読性・設計上の改善点を指摘し、具体的な修正案を示してください。良い点が'
                'あれば簡潔に触れつつ、要点を絞ったレビューを心がけてください。',
      },
      {
        'id': 'builtin-translator',
        'name': '翻訳アシスタント',
        'emoji': '🌐',
        'system_prompt':
            'あなたはプロの翻訳者です。ユーザーが入力したテキストを、指定された言語（指定がなければ文脈から'
                '適切に判断してください）へ、原文のニュアンス・トーン・専門用語を正確に保ったまま翻訳してくだ'
                'さい。直訳ではなく、自然な表現を優先してください。',
      },
      {
        'id': 'builtin-summarizer',
        'name': '要約アシスタント',
        'emoji': '📚',
        'system_prompt':
            'あなたは要約のプロフェッショナルです。ユーザーが入力した長文やドキュメントを、要点を漏らさず'
                '簡潔に要約してください。可能であれば箇条書きを使い、重要な結論や数値は必ず含めてください。',
      },
      {
        'id': 'builtin-brainstorm-partner',
        'name': 'アイデア出しパートナー',
        'emoji': '💡',
        'system_prompt':
            'あなたは創造的なブレインストーミングパートナーです。ユーザーのテーマや課題に対して、多様な視点'
                'から複数のアイデアを提案してください。突飛なアイデアも歓迎し、批判は後回しにして量と多様性を'
                '優先してください。各アイデアには一言で理由や着眼点を添えてください。',
      },
      {
        'id': 'builtin-plain-explainer',
        'name': 'やさしい解説者',
        'emoji': '🎓',
        'system_prompt':
            'あなたは難しい概念を誰にでもわかりやすく説明する先生です。専門用語を避け、身近な例えを使いながら、'
                '段階的に説明してください。相手の前提知識がわからない場合は簡単な言葉から始め、必要に応じて'
                '確認の質問を挟んでください。',
      },
    ];

    for (final preset in presets) {
      await db.insert('agents', {
        'id': preset['id'],
        'name': preset['name'],
        'emoji': preset['emoji'],
        'system_prompt': preset['system_prompt'],
        'tools': null,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  // --- Conversations ---

  Future<String> createConversation({
    required String id,
    required String title,
    required String provider,
    required String model,
    String? agentId,
    String? systemPromptSnapshot,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('conversations', {
      'id': id,
      'title': title,
      'provider': provider,
      'model': model,
      'agent_id': agentId,
      'system_prompt_snapshot': systemPromptSnapshot,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    return db.query('conversations', orderBy: 'updated_at DESC');
  }

  Future<Map<String, dynamic>?> getConversation(String id) async {
    final db = await database;
    final rows = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> updateConversationTitle(String id, String title) async {
    final db = await database;
    await db.update(
      'conversations',
      {'title': title, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> touchConversation(String id) async {
    final db = await database;
    await db.update(
      'conversations',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  // --- Messages ---

  Future<void> insertMessage({
    required String id,
    required String conversationId,
    required ChatMessage message,
  }) async {
    final db = await database;
    await db.insert('messages', {
      'id': id,
      'conversation_id': conversationId,
      'sender': message.sender.name,
      'text': message.text,
      'status': message.status.name,
      'image_url': message.imageUrl,
      'alt_text': message.altText,
      'user_image_path': message.userImagePath,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateMessage({
    required String id,
    required String text,
    required String status,
    String? imageUrl,
    String? altText,
  }) async {
    final db = await database;
    await db.update(
      'messages',
      {
        'text': text,
        'status': status,
        if (imageUrl != null) 'image_url': imageUrl,
        if (altText != null) 'alt_text': altText,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(_rowToMessage).toList();
  }

  ChatMessage _rowToMessage(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      sender: ChatSender.values.firstWhere((e) => e.name == row['sender']),
      text: row['text'] as String,
      status: ChatMessageStatus.values
          .firstWhere((e) => e.name == row['status']),
      imageUrl: row['image_url'] as String?,
      altText: row['alt_text'] as String?,
      userImagePath: row['user_image_path'] as String?,
    );
  }

  // --- Agents ---

  Future<void> createAgent(AgentConfig agent) async {
    final db = await database;
    await db.insert('agents', agent.toRow());
  }

  Future<void> updateAgent(AgentConfig agent) async {
    final db = await database;
    await db.update(
      'agents',
      agent.toRow(),
      where: 'id = ?',
      whereArgs: [agent.id],
    );
  }

  Future<void> deleteAgent(String id) async {
    final db = await database;
    await db.delete('agents', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AgentConfig>> getAgents() async {
    final db = await database;
    final rows = await db.query('agents', orderBy: 'created_at ASC');
    return rows.map(AgentConfig.fromRow).toList();
  }
}
