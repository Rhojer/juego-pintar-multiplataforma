import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants.dart';

/// Singleton service that manages the Socket.IO connection and exposes
/// strongly-typed event streams to the rest of the app.
class SocketService {
  SocketService._internal();
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  // ──────────────────────────── Socket ────────────────────────────

  late IO.Socket _socket;
  bool _connected = false;

  bool get isConnected => _connected;
  String get socketId => _socket.id ?? '';

  // ──────────────────────────── StreamControllers ────────────────────────────

  final _roomJoinedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _playerJoinedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _playerLeftCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStartedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _turnStartedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _drawingDataCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _canvasClearedCtrl = StreamController<void>.broadcast();
  final _chatMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _correctGuessCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _turnEndedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _gameEndedCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _timerTickCtrl = StreamController<int>.broadcast();
  final _joinErrorCtrl = StreamController<String>.broadcast();
  final _wordHintUpdateCtrl = StreamController<String>.broadcast();
  final _playerReadyCtrl = StreamController<Map<String, dynamic>>.broadcast();

  // ──────────────────────────── Public Streams ────────────────────────────

  Stream<Map<String, dynamic>> get onRoomJoined => _roomJoinedCtrl.stream;
  Stream<Map<String, dynamic>> get onPlayerJoined => _playerJoinedCtrl.stream;
  Stream<Map<String, dynamic>> get onPlayerLeft => _playerLeftCtrl.stream;
  Stream<Map<String, dynamic>> get onGameStarted => _gameStartedCtrl.stream;
  Stream<Map<String, dynamic>> get onTurnStarted => _turnStartedCtrl.stream;
  Stream<Map<String, dynamic>> get onDrawingData => _drawingDataCtrl.stream;
  Stream<void> get onCanvasCleared => _canvasClearedCtrl.stream;
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onCorrectGuess => _correctGuessCtrl.stream;
  Stream<Map<String, dynamic>> get onTurnEnded => _turnEndedCtrl.stream;
  Stream<Map<String, dynamic>> get onGameEnded => _gameEndedCtrl.stream;
  Stream<int> get onTimerTick => _timerTickCtrl.stream;
  Stream<String> get onJoinError => _joinErrorCtrl.stream;
  Stream<String> get onWordHintUpdate => _wordHintUpdateCtrl.stream;
  Stream<Map<String, dynamic>> get onPlayerReady => _playerReadyCtrl.stream;

  // ──────────────────────────── Connect / Disconnect ────────────────────────────

  void connect() {
    if (_connected) return;

    _socket = IO.io(
      AppConstants.serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket.connect();
    _registerListeners();
  }

  void disconnect() {
    if (!_connected) return;
    _socket.disconnect();
    _connected = false;
  }

  void _registerListeners() {
    _socket.onConnect((_) {
      _connected = true;
    });

    _socket.onDisconnect((_) {
      _connected = false;
    });

    _socket.onConnectError((data) {
      _connected = false;
      _joinErrorCtrl.add(VzlaMessages.connectionError);
    });

    // ── Room events ──
    _socket.on('room-joined', (data) {
      _roomJoinedCtrl.add(_toMap(data));
    });

    _socket.on('player-joined', (data) {
      _playerJoinedCtrl.add(_toMap(data));
    });

    _socket.on('player-left', (data) {
      _playerLeftCtrl.add(_toMap(data));
    });

    _socket.on('player-ready', (data) {
      _playerReadyCtrl.add(_toMap(data));
    });

    _socket.on('join-error', (data) {
      final msg = data is Map ? data['message'] as String? : data.toString();
      _joinErrorCtrl.add(msg ?? '¡Error al unirse!');
    });

    // ── Game flow events ──
    _socket.on('game-started', (data) {
      _gameStartedCtrl.add(_toMap(data));
    });

    _socket.on('turn-started', (data) {
      _turnStartedCtrl.add(_toMap(data));
    });

    _socket.on('turn-ended', (data) {
      _turnEndedCtrl.add(_toMap(data));
    });

    _socket.on('game-ended', (data) {
      _gameEndedCtrl.add(_toMap(data));
    });

    _socket.on('timer-tick', (data) {
      final seconds = data is int ? data : (data as Map)['seconds'] as int? ?? 0;
      _timerTickCtrl.add(seconds);
    });

    // ── Drawing events ──
    _socket.on('drawing-data', (data) {
      _drawingDataCtrl.add(_toMap(data));
    });

    _socket.on('canvas-cleared', (_) {
      _canvasClearedCtrl.add(null);
    });

    // ── Chat / guessing events ──
    _socket.on('chat-message', (data) {
      _chatMessageCtrl.add(_toMap(data));
    });

    _socket.on('correct-guess', (data) {
      _correctGuessCtrl.add(_toMap(data));
    });

    _socket.on('word-hint-update', (data) {
      final hint = data is Map ? data['hint'] as String? : data.toString();
      _wordHintUpdateCtrl.add(hint ?? '');
    });
  }

  // ──────────────────────────── Emit Methods ────────────────────────────

  /// Join the public matchmaking queue
  void joinPublic(String nickname) {
    _socket.emit('join-public', {'nickname': nickname});
  }

  /// Create a new private room
  void createPrivate(String nickname) {
    _socket.emit('create-private', {'nickname': nickname});
  }

  /// Join an existing private room by code
  void joinPrivate(String nickname, String roomCode) {
    _socket.emit('join-private', {'nickname': nickname, 'roomCode': roomCode.toUpperCase()});
  }

  /// Signal that the local player is ready to start
  void setReady() {
    _socket.emit('set-ready');
  }

  /// Send an incremental batch of stroke points to the server
  void sendDrawingData(List<Map<String, dynamic>> strokes) {
    _socket.emit('drawing-data', {'strokes': strokes});
  }

  /// Tell all other clients to clear the canvas
  void clearCanvas() {
    _socket.emit('clear-canvas');
  }

  /// Send a guess (or a chat message if not in drawing phase)
  void sendGuess(String text) {
    _socket.emit('send-guess', {'text': text});
  }

  // ──────────────────────────── Helpers ────────────────────────────

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Close all stream controllers — call this when the app is disposed.
  void dispose() {
    _roomJoinedCtrl.close();
    _playerJoinedCtrl.close();
    _playerLeftCtrl.close();
    _gameStartedCtrl.close();
    _turnStartedCtrl.close();
    _drawingDataCtrl.close();
    _canvasClearedCtrl.close();
    _chatMessageCtrl.close();
    _correctGuessCtrl.close();
    _turnEndedCtrl.close();
    _gameEndedCtrl.close();
    _timerTickCtrl.close();
    _joinErrorCtrl.close();
    _wordHintUpdateCtrl.close();
    _playerReadyCtrl.close();
  }
}
