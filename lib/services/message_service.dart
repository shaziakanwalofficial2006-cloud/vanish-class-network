
import '../models/message.dart';
import 'database_service.dart';

class MessageService {
  final DatabaseService _database = DatabaseService.instance;

  // Save a message locally.
  Future<bool> saveMessage(Message message) async {
    final result = await _database.saveMessage(
      id: message.id,
      sender: message.sender,
      text: message.text,
      createdAt: message.createdAt,
      sentAt: message.sentAt,
      expiresAt: message.expiresAt,
      status: message.status,
      isMine: message.isMine,
    );

    return result > 0;
  }

  // Load all messages from the database.
  Future<List<Message>> loadMessages() async {
    final records = await _database.getAllMessages();

    return records.map((record) {
      return Message.fromMap(
        Map<String, dynamic>.from(record),
      );
    }).toList();
  }

  // Load messages waiting to be sent.
  Future<List<Message>> loadWaitingMessages() async {
    final records = await _database.getWaitingMessages();

    return records.map((record) {
      return Message.fromMap(
        Map<String, dynamic>.from(record),
      );
    }).toList();
  }

  // Change the status of a message.
  Future<bool> updateStatus(
      String id,
      String status,
      ) async {
    final result = await _database.updateMessageStatus(
      id,
      status,
    );

    return result > 0;
  }

  // Delete expired messages permanently.

  Future<int> removeExpiredMessages({
    required int serverNowMilliseconds,
  }) async {
    return await _database.deleteExpiredMessages(
      now: DateTime.fromMillisecondsSinceEpoch(
        serverNowMilliseconds,
      ),
    );
  }

  // Delete a particular message.
  Future<bool> removeMessage(String id) async {
    final result = await _database.deleteMessage(id);

    return result > 0;
  }

  // Check whether a message has expired.
  bool hasExpired(Message message) {
    return message.isExpired;
  }
}
