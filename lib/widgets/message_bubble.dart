
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String sender;
  final String message;
  final String timeLeft;
  final bool isMine;
  final String status;

  const MessageBubble({
    super.key,
    required this.sender,
    required this.message,
    required this.timeLeft,
    required this.isMine,
    this.status = 'sent',
  });

  @override
  Widget build(BuildContext context) {
    String statusText;

    switch (status.toLowerCase()) {
      case 'delivered':
        statusText = 'Delivered';
        break;
      case 'sent':
        statusText = 'Sent';
        break;
      case 'queued':
        statusText = 'Waiting to send';
        break;
      default:
        statusText = status;
    }

    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isMine
              ? const Color(0xFF0F766E)
              : const Color(0xFF263449),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sender,
              style: const TextStyle(
                color: Color(0xFF5EEAD4),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Colors.white60,
                ),
                const SizedBox(width: 5),
                Text(
                  '$timeLeft left',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (isMine) ...[
              const SizedBox(height: 5),
              Text(
                statusText,
                style: const TextStyle(
                  color: Color(0xFFCCFBF1),
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
