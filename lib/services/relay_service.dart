
import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class RelayService {
  static const String relayUrl =
      'wss://vanish-relay-sawaira.bonto.page/ws';

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  Timer? _heartbeatTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = false;

  int _reconnectAttempt = 0;

  String? _deviceId;
  String? _userName;

  int _serverClockOffsetMs = 0;
  bool _hasServerTime = false;

  final List<int> _reconnectDelays = [1, 2, 4, 8];

  int get serverClockOffsetMs => _serverClockOffsetMs;

  bool get hasServerTime => _hasServerTime;

  bool get isConnected => _isConnected;

  int get serverNowMilliseconds {
    return DateTime.now().millisecondsSinceEpoch +
        _serverClockOffsetMs;
  }

  Duration remainingUntil(int expiresAtMilliseconds) {
    final remaining =
        expiresAtMilliseconds - serverNowMilliseconds;

    return Duration(
      milliseconds: remaining > 0 ? remaining : 0,
    );
  }

  final StreamController<Map<String, dynamic>> _events =
  StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  // Initial connection.
  Future<void> connect({
    required String deviceId,
    required String name,
  }) async {
    if (_isConnected || _isConnecting) return;

    final cleanName = name.trim();

    if (cleanName.isEmpty || cleanName.length > 30) {
      throw ArgumentError(
        'Name must contain 1 to 30 characters',
      );
    }

    if (deviceId.trim().isEmpty) {
      throw ArgumentError('Device ID cannot be empty');
    }

    _deviceId = deviceId;
    _userName = cleanName;
    _shouldReconnect = true;
    _reconnectAttempt = 0;

    try {
      await _openConnection();
    } catch (error) {
      _events.add({
        'type': 'connection_error',
        'message': error.toString(),
      });

      _scheduleReconnect();
      rethrow;
    }
  }

  // Open a WebSocket connection and join the relay.
  Future<void> _openConnection() async {
    if (!_shouldReconnect ||
        _isConnected ||
        _isConnecting ||
        _channel != null) {
      return;
    }

    _isConnecting = true;

    final channel =
    WebSocketChannel.connect(Uri.parse(relayUrl));

    _channel = channel;

    try {
      print('VANISH: Connecting to relay...');
      await channel.ready.timeout(
        const Duration(seconds: 20),
      );
      print('VANISH: WebSocket connected successfully!');

      if (!_shouldReconnect || !identical(_channel, channel)) {
        await channel.sink.close();
        return;
      }

      _subscription = channel.stream.listen(
            (data) {
          _handleIncoming(channel, data);
        },
        onError: (error) {
          _handleConnectionLost(
            channel,
            'Connection error: $error',
          );
        },
        onDone: () {
          _handleConnectionLost(
            channel,
            'Connection closed',
          );
        },
        cancelOnError: true,
      );

      _send({
        'type': 'join',
        'protocol': 1,
        'device_id': _deviceId,
        'name': _userName,
      });
    } catch (error) {
      print('VANISH: WebSocket connection failed: $error');

      if (identical(_channel, channel)) {
        _channel = null;
        _stopHeartbeat();

        await _subscription?.cancel();
        _subscription = null;

        await channel.sink.close();
      }

      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  // Send a message to the relay.
  void sendMessage({
    required String id,
    required String text,
    required String sender,
  }) {
    if (!_isConnected) {
      throw StateError('Not connected to relay');
    }

    final cleanText = text.trim();

    if (cleanText.isEmpty || cleanText.length > 500) {
      throw ArgumentError(
        'Message must contain 1 to 500 characters',
      );
    }

    _send({
      'type': 'message',
      'id': id,
      'sender': sender,
      'text': cleanText,
    });
  }

  // Send JSON data through WebSocket.
  void _send(Map<String, dynamic> data) {
    final channel = _channel;

    if (channel == null) {
      throw StateError('WebSocket is not available');
    }

    channel.sink.add(jsonEncode(data));
  }

  // Handle incoming relay events.
  void _handleIncoming(
      WebSocketChannel channel,
      dynamic data,
      ) {
    if (!identical(_channel, channel)) return;

    try {
      final decoded = jsonDecode(data as String);

      final event =
      Map<String, dynamic>.from(decoded as Map);

      if (event['type'] == 'welcome') {
        final serverTime = event['server_time'];

        if (serverTime is! num) {
          _events.add({
            'type': 'protocol_error',
            'message': 'Welcome event has invalid server_time',
          });
          return;
        }

        final phoneTime =
            DateTime.now().millisecondsSinceEpoch;

        _serverClockOffsetMs =
            serverTime.toInt() - phoneTime;

        _hasServerTime = true;
        _isConnected = true;

        // Reset retry count after a successful connection.
        _reconnectAttempt = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;

        _events.add(event);

        _startHeartbeat();
      } else if (event['type'] == 'pong') {
        _pongTimeoutTimer?.cancel();
        _pongTimeoutTimer = null;

        _events.add(event);
      } else {
        _events.add(event);
      }
    } catch (error) {
      _events.add({
        'type': 'parse_error',
        'message': error.toString(),
      });
    }
  }

  // Start heartbeat every 15 seconds.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();

    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
          (_) {
        if (!_isConnected) return;

        try {
          _send({'type': 'ping'});

          // Do not reset the timeout with every new ping.
          _pongTimeoutTimer ??= Timer(
            const Duration(seconds: 30),
                () {
              final channel = _channel;

              if (channel != null) {
                _handleConnectionLost(
                  channel,
                  'Heartbeat timeout',
                );

                channel.sink.close();
              }
            },
          );
        } catch (error) {
          final channel = _channel;

          if (channel != null) {
            _handleConnectionLost(
              channel,
              'Heartbeat error: $error',
            );

            channel.sink.close();
          }
        }
      },
    );
  }

  // Stop heartbeat timers.
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _pongTimeoutTimer?.cancel();

    _heartbeatTimer = null;
    _pongTimeoutTimer = null;
  }

  // Handle unexpected disconnection.
  void _handleConnectionLost(
      WebSocketChannel channel,
      String reason,
      ) {
    // Ignore events from an old connection.
    if (!identical(_channel, channel)) return;

    _stopHeartbeat();

    _isConnected = false;
    _channel = null;
    _subscription = null;

    _events.add({
      'type': 'disconnected',
      'message': reason,
    });

    _scheduleReconnect();
  }

  // Schedule automatic reconnection.
  void _scheduleReconnect() {
    if (!_shouldReconnect ||
        _isConnected ||
        _isConnecting ||
        _reconnectTimer != null) {
      return;
    }

    final delayIndex = _reconnectAttempt
        .clamp(0, _reconnectDelays.length - 1);

    final seconds = _reconnectDelays[delayIndex];

    _reconnectAttempt++;

    _events.add({
      'type': 'reconnecting',
      'attempt': _reconnectAttempt,
      'delay': seconds,
    });

    _reconnectTimer = Timer(
      Duration(seconds: seconds),
          () async {
        _reconnectTimer = null;

        if (!_shouldReconnect) return;

        try {
          await _openConnection();
        } catch (error) {
          _events.add({
            'type': 'connection_error',
            'message': error.toString(),
          });

          _scheduleReconnect();
        }
      },
    );
  }

  // Disconnect manually and stop automatic reconnection.
  Future<void> disconnect() async {
    _shouldReconnect = false;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _stopHeartbeat();

    _isConnected = false;

    final subscription = _subscription;
    final channel = _channel;

    _subscription = null;
    _channel = null;

    await subscription?.cancel();
    await channel?.sink.close();
  }

  // Dispose the service.
  Future<void> dispose() async {
    await disconnect();

    _hasServerTime = false;

    await _events.close();
  }
}

