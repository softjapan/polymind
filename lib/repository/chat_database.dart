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
      version: 3,
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
      },
    );
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
