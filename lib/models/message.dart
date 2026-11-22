
class Message {
  final String id;
  final String sender;
  final String text;

  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? expiresAt;

  final String status;
  final bool isMine;

  Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.sentAt,
    this.expiresAt,
    required this.status,
    required this.isMine,
  });

  // Convert message into SQLite format.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'text': text,
      'created_at_ms': createdAt.millisecondsSinceEpoch,
      'sent_at_ms': sentAt?.millisecondsSinceEpoch,
      'expires_at_ms': expiresAt?.millisecondsSinceEpoch,
      'status': status,
      'is_mine': isMine ? 1 : 0,
    };
  }

  // Read message from SQLite.
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      sender: map['sender'] as String,
      text: map['text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at_ms'] as int,
      ),
      sentAt: map['sent_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
        map['sent_at_ms'] as int,
      ),
      expiresAt: map['expires_at_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
        map['expires_at_ms'] as int,
      ),
      status: map['status'] as String,
      isMine: map['is_mine'] == 1,
    );
  }

  // Create a message from a relay message event.
  factory Message.fromRelayJson(
      Map<String, dynamic> json, {
        required bool isMine,
      }) {
    final sentAtMs = (json['sent_at'] as num).toInt();
    final expiresAtMs = (json['expires_at'] as num).toInt();

    return Message(
      id: json['id'] as String,
      sender: json['sender'] as String,
      text: json['text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(sentAtMs),
      sentAt: DateTime.fromMillisecondsSinceEpoch(sentAtMs),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
      status: 'received',
      isMine: isMine,
    );
  }

  // Calculate remaining time using relay-adjusted time.
  Duration remainingTimeAt(int serverNowMilliseconds) {
    if (expiresAt == null) return Duration.zero;

    final remaining =
        expiresAt!.millisecondsSinceEpoch - serverNowMilliseconds;

    return Duration(
      milliseconds: remaining > 0 ? remaining : 0,
    );
  }

  // Check expiry using relay-adjusted time.
  bool isExpiredAt(int serverNowMilliseconds) {
    if (expiresAt == null) return false;

    return expiresAt!.millisecondsSinceEpoch <=
        serverNowMilliseconds;
  }

  // Temporary local-clock getters for existing demo code.
  // We'll replace their use when connecting ChatScreen to RelayService.
  Duration get remainingTime {
    if (expiresAt == null) return Duration.zero;

    final remaining = expiresAt!.difference(DateTime.now());

    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isExpired {
    if (expiresAt == null) return false;

    return !expiresAt!.isAfter(DateTime.now());
  }
}
