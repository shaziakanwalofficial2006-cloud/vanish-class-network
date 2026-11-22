
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance =
  DatabaseService._internal();

  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'vanish_network.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sender TEXT NOT NULL,
            text TEXT NOT NULL,
            created_at_ms INTEGER NOT NULL,
            sent_at_ms INTEGER,
            expires_at_ms INTEGER,
            status TEXT NOT NULL,
            is_mine INTEGER NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  // Save a new message or update an existing message.
  Future<int> saveMessage({
    required String id,
    required String sender,
    required String text,
    required DateTime createdAt,
    DateTime? sentAt,
    DateTime? expiresAt,
    required String status,
    required bool isMine,
  }) async {
    final db = await database;

    return await db.insert(
      'messages',
      {
        'id': id,
        'sender': sender,
        'text': text,
        'created_at_ms': createdAt.millisecondsSinceEpoch,
        'sent_at_ms': sentAt?.millisecondsSinceEpoch,
        'expires_at_ms': expiresAt?.millisecondsSinceEpoch,
        'status': status,
        'is_mine': isMine ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all saved messages.
  Future<List<Map<String, Object?>>> getAllMessages() async {
    final db = await database;

    return await db.query(
      'messages',
      orderBy: 'created_at_ms ASC',
    );
  }

  // Get offline messages waiting to be sent.
  Future<List<Map<String, Object?>>> getWaitingMessages() async {
    final db = await database;

    return await db.query(
      'messages',
      where: 'status IN (?, ?)',
      whereArgs: ['queued', 'waiting'],
      orderBy: 'created_at_ms ASC',
    );
  }

  // Update message status.
  Future<int> updateMessageStatus(
      String id,
      String newStatus,
      ) async {
    final db = await database;

    return await db.update(
      'messages',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete messages whose expiry time has passed.
  Future<int> deleteExpiredMessages({
    DateTime? now,
  }) async {
    final db = await database;

    final currentTime =
        (now ?? DateTime.now()).millisecondsSinceEpoch;

    return await db.delete(
      'messages',
      where: 'expires_at_ms IS NOT NULL AND expires_at_ms <= ?',
      whereArgs: [currentTime],
    );
  }

  // Delete one message by ID.
  Future<int> deleteMessage(String id) async {
    final db = await database;

    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
