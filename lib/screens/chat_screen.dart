
import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/message_bubble.dart';
import '../models/message.dart';
import '../services/message_service.dart';
import '../services/relay_service.dart';

class ChatScreen extends StatefulWidget {
  final String userName;

  const ChatScreen({
    super.key,
    required this.userName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController messageController =
  TextEditingController();

  final ScrollController scrollController = ScrollController();

  final MessageService messageService = MessageService();
  final RelayService relayService = RelayService();

  final List<Message> messages = [];

  final Set<String> seenMessageIds = {};
  final Set<String> myMessageIds = {};

  StreamSubscription<Map<String, dynamic>>? relaySubscription;

  Timer? countdownTimer;

  String connectionStatus = 'Connecting...';
  List<String> onlineMembers = [];
  bool isSending = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    loadSavedMessages();
    listenToRelay();
    connectToRelay();

    countdownTimer = Timer.periodic(
      const Duration(milliseconds: 500),
          (_) {
        removeExpiredMessages();

        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      removeExpiredMessages();

      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> loadSavedMessages() async {
    final savedMessages = await messageService.loadMessages();

    if (!mounted) return;

    final validMessages = relayService.hasServerTime
        ? savedMessages.where((message) {
      return !message.isExpiredAt(
        relayService.serverNowMilliseconds,
      );
    }).toList()
        : savedMessages;

    if (relayService.hasServerTime) {
      for (final message in savedMessages) {
        if (message.isExpiredAt(
          relayService.serverNowMilliseconds,
        )) {
          await messageService.removeMessage(message.id);
        }
      }
    }

    if (!mounted) return;

    setState(() {
      messages
        ..clear()
        ..addAll(validMessages);

      seenMessageIds.clear();
      myMessageIds.clear();

      for (final message in validMessages) {
        seenMessageIds.add(message.id);

        if (message.isMine) {
          myMessageIds.add(message.id);
        }
      }
    });
  }

  void listenToRelay() {
    relaySubscription = relayService.events.listen(
      handleRelayEvent,
    );
  }

  Future<void> connectToRelay() async {
    try {
      await relayService.connect(
        deviceId: DateTime.now().microsecondsSinceEpoch.toString(),
        name: widget.userName,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        connectionStatus = 'Connection failed';
      });

      debugPrint('Relay connection error: $error');
    }
  }

  Future<void> handleRelayEvent(
      Map<String, dynamic> event,
      ) async {
    final type = event['type'];

    if (type == 'welcome') {
      if (!mounted) return;

      setState(() {
        connectionStatus = 'Connected';
      });

      await removeExpiredMessages();
      await sendQueuedMessages();

    } else if (type == 'presence') {
      final members = event['members'];

      if (members is List) {
        if (!mounted) return;

        setState(() {
          onlineMembers = members
              .map((member) => member.toString())
              .toList();
        });
      }

    } else if (type == 'message') {
      await receiveMessage(event);

    } else if (type == 'delivered') {
      final id = event['id']?.toString();

      if (id != null) {
        await messageService.updateStatus(id, 'delivered');

        if (!mounted) return;

        final index = messages.indexWhere(
              (message) => message.id == id,
        );

        if (index != -1) {
          setState(() {
            final old = messages[index];

            messages[index] = Message(
              id: old.id,
              sender: old.sender,
              text: old.text,
              createdAt: old.createdAt,
              sentAt: old.sentAt,
              expiresAt: old.expiresAt,
              status: 'delivered',
              isMine: old.isMine,
            );
          });
        }
      }

    } else if (type == 'expired') {
      final id = event['id']?.toString();

      if (id != null) {
        await messageService.removeMessage(id);

        if (!mounted) return;

        setState(() {
          messages.removeWhere(
                (message) => message.id == id,
          );

          seenMessageIds.remove(id);
          myMessageIds.remove(id);
        });
      }

    } else if (type == 'reconnecting') {
      if (!mounted) return;

      final delay = event['delay'] ?? 1;

      setState(() {
        connectionStatus = 'Reconnecting in ${delay}s...';
      });

    } else if (type == 'disconnected') {
      if (!mounted) return;

      setState(() {
        connectionStatus = 'Disconnected';
        onlineMembers = [];
      });

    } else if (type == 'connection_error') {
      if (!mounted) return;

      setState(() {
        connectionStatus = 'Connection error';
      });

    } else if (type == 'error') {
      if (!mounted) return;

      setState(() {
        connectionStatus =
        'Relay error: ${event['code'] ?? 'unknown'}';
      });

    } else if (type == 'protocol_error' ||
        type == 'parse_error') {
      if (!mounted) return;

      setState(() {
        connectionStatus = 'Protocol error';
      });
    }
  }

  Future<void> receiveMessage(
      Map<String, dynamic> event,
      ) async {
    try {
      final id = event['id'] as String;

      final isOwnMessage = myMessageIds.contains(id);

      if (seenMessageIds.contains(id) && !isOwnMessage) {
        return;
      }

      if (!relayService.hasServerTime) return;

      final message = Message.fromRelayJson(
        event,
        isMine: isOwnMessage,
      );

      if (message.isExpiredAt(
        relayService.serverNowMilliseconds,
      )) {
        return;
      }

      if (isOwnMessage) {
        final index = messages.indexWhere(
              (item) => item.id == id,
        );

        if (index != -1) {
          setState(() {
            messages[index] = message;
          });
        }

        await messageService.removeMessage(id);
      } else {
        seenMessageIds.add(id);
      }

      await messageService.saveMessage(message);

      if (!mounted) return;

      if (!isOwnMessage) {
        setState(() {
          messages.add(message);
        });
      }

      scrollToBottom();
    } catch (error) {
      debugPrint('Message receive error: $error');
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty || isSending) return;

    if (text.length > 500) {
      showMessage(
        'Message cannot exceed 500 characters',
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();

    final message = Message(
      id: id,
      sender: widget.userName,
      text: text,
      createdAt: now,
      expiresAt: null,
      status: 'queued',
      isMine: true,
    );

    try {
      await messageService.saveMessage(message);

      if (!mounted) return;

      setState(() {
        messages.add(message);
        seenMessageIds.add(id);
        myMessageIds.add(id);
      });

      messageController.clear();
      scrollToBottom();

      if (relayService.isConnected) {
        relayService.sendMessage(
          id: id,
          text: text,
          sender: widget.userName,
        );

        await messageService.updateStatus(
          id,
          'sent',
        );
      }
    } catch (error) {
      showMessage(
        'Unable to send message: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> sendQueuedMessages() async {
    if (!relayService.isConnected) return;

    final waitingMessages =
    await messageService.loadWaitingMessages();

    for (final message in waitingMessages) {
      if (DateTime.now()
          .difference(message.createdAt)
          .inSeconds >=
          30) {
        await messageService.removeMessage(message.id);

        if (mounted) {
          setState(() {
            messages.removeWhere(
                  (item) => item.id == message.id,
            );

            seenMessageIds.remove(message.id);
            myMessageIds.remove(message.id);
          });
        }

        continue;
      }

      try {
        relayService.sendMessage(
          id: message.id,
          text: message.text,
          sender: widget.userName,
        );

        await messageService.updateStatus(
          message.id,
          'sent',
        );
      } catch (error) {
        debugPrint(
          'Queued message error: $error',
        );
        break;
      }
    }
  }

  Future<void> removeExpiredMessages() async {
    if (!relayService.hasServerTime) return;

    final now = relayService.serverNowMilliseconds;

    final expired = messages.where((message) {
      return message.expiresAt != null &&
          message.isExpiredAt(now);
    }).toList();

    // Delete expired records from SQLite using relay time.
    await messageService.removeExpiredMessages(
      serverNowMilliseconds: now,
    );

    if (expired.isEmpty) return;

    if (!mounted) return;

    setState(() {
      messages.removeWhere(
            (message) => message.isExpiredAt(now),
      );

      for (final message in expired) {
        seenMessageIds.remove(message.id);
        myMessageIds.remove(message.id);
      }
    });
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void showMessage(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
      ),
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    relaySubscription?.cancel();
    relayService.dispose();

    messageController.dispose();
    scrollController.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class Chat',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              connectionStatus,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            if (onlineMembers.isNotEmpty)
              Text(
                '${onlineMembers.length} online: ${onlineMembers.join(', ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF5EEAD4),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final navigator = Navigator.of(context);

              await relayService.disconnect();

              if (!mounted) return;

              navigator.pop();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Leave chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF134E4A),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  size: 17,
                  color: Color(0xFF5EEAD4),
                ),
                SizedBox(width: 8),
                Text(
                  'Messages expire after 30 seconds',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 55,
                    color: Colors.white24,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'No messages yet',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Send your first message!',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];

                final remaining =
                relayService.hasServerTime &&
                    message.expiresAt != null
                    ? message
                    .remainingTimeAt(
                  relayService
                      .serverNowMilliseconds,
                )
                    .inMilliseconds
                    : 0;

                final secondsLeft =
                ((remaining + 999) ~/ 1000)
                    .clamp(0, 30);

                return MessageBubble(
                  sender: message.sender,
                  message: message.text,
                  timeLeft: message.expiresAt == null
                      ? 'Waiting'
                      : '${secondsLeft}s',
                  isMine: message.isMine,
                  status: message.status,
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              18,
            ),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    maxLength: 500,
                    textCapitalization:
                    TextCapitalization.sentences,
                    onSubmitted: (_) => sendMessage(),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Write a message...',
                      filled: true,
                      fillColor: const Color(0xFF334155),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                      const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color(0xFF14B8A6),
                  child: IconButton(
                    onPressed: sendMessage,
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
