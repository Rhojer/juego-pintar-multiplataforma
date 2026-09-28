import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants.dart';
import 'session_storage.dart';

/// Singleton service that manages the Socket.IO connection and exposes
/// strongly-typed event streams to the rest of the app.
class SocketService {
  SocketService._internal();
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  // ──────────────────────────── Socket ────────────────────────────

  IO.Socket? _socket;
  bool _connected = false;
  bool _listenersRegistered = false;

  bool get isConnected => _connected;
  String get socketId => _socket?.id ?? '';

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
  final _chooseWordCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _drawerChoosingCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnectedSuccessCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnectFailedCtrl = StreamController<String>.broadcast();

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
  Stream<Map<String, dynamic>> get onWordChoices => _chooseWordCtrl.stream;
  Stream<Map<String, dynamic>> get onDrawerChoosing => _drawerChoosingCtrl.stream;
  Stream<Map<String, dynamic>> get onReconnectedSuccess => _reconnectedSuccessCtrl.stream;
  Stream<String> get onReconnectFailed => _reconnectFailedCtrl.stream;

  // ──────────────────────────── Connect / Disconnect ────────────────────────────

  void connect() {
    if (_connected && _socket?.connected == true) return;

    if (_socket == null) {
      _socket = IO.io(
        AppConstants.serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)
            .build(),
      );
      _registerListeners();
    } else if (_socket?.connected == false) {
      _socket?.connect();
    }
  }

  void _ensureConnected(void Function() action) {
    connect();
    if (_connected && _socket?.connected == true) {
      action();
    } else {
      _socket?.once('connect', (_) {
        action();
      });
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _connected = false;
  }

  void _registerListeners() {
    if (_listenersRegistered || _socket == null) return;
    _listenersRegistered = true;

    _socket!.onConnect((_) {
      _connected = true;
    });

    _socket!.onDisconnect((_) {
      _connected = false;
    });

    _socket!.onConnectError((data) {
      _connected = false;
      _joinErrorCtrl.add(VzlaMessages.connectionError);
    });

    // ── Room events ──
    _socket!.on('room-joined', (data) {
      final map = _toMap(data);
      final roomCode = map['roomCode'] as String? ?? '';
      final playerMap = map['player'] is Map ? map['player'] as Map : null;
      final sessionToken = (map['sessionToken'] ?? playerMap?['sessionToken']) as String? ?? '';
      final nickname = (map['nickname'] ?? playerMap?['nickname']) as String? ?? '';

      if (roomCode.isNotEmpty && sessionToken.isNotEmpty) {
        SessionStorage.saveSession(
          roomCode: roomCode,
          sessionToken: sessionToken,
          nickname: nickname,
        );
      }
      _roomJoinedCtrl.add(map);
    });

    _socket!.on('reconnected-success', (data) {
      final map = _toMap(data);
      final roomCode = map['roomCode'] as String? ?? '';
      final sessionToken = map['sessionToken'] as String? ?? '';
      final nickname = map['nickname'] as String? ?? '';

      if (roomCode.isNotEmpty && sessionToken.isNotEmpty) {
        SessionStorage.saveSession(
          roomCode: roomCode,
          sessionToken: sessionToken,
          nickname: nickname,
        );
      }
      _reconnectedSuccessCtrl.add(map);
    });

    _socket!.on('reconnect-failed', (data) {
      final msg = data is Map ? data['message'] as String? : data.toString();
      SessionStorage.clearSession();
      _reconnectFailedCtrl.add(msg ?? 'Sesión expirada o no encontrada.');
    });

    _socket!.on('player-joined', (data) {
      _playerJoinedCtrl.add(_toMap(data));
    });

    _socket!.on('player-left', (data) {
      _playerLeftCtrl.add(_toMap(data));
    });

    _socket!.on('player-ready', (data) {
      _playerReadyCtrl.add(_toMap(data));
    });

    _socket!.on('player-ready-update', (data) {
      _playerReadyCtrl.add(_toMap(data));
    });

    _socket!.on('join-error', (data) {
      final msg = data is Map ? data['message'] as String? : data.toString();
      _joinErrorCtrl.add(msg ?? '¡Error al unirse!');
    });

    // ── Game flow events ──
    _socket!.on('game-started', (data) {
      _gameStartedCtrl.add(_toMap(data));
    });

    _socket!.on('turn-started', (data) {
      _turnStartedCtrl.add(_toMap(data));
    });

    _socket!.on('turn-ended', (data) {
      _turnEndedCtrl.add(_toMap(data));
    });

    _socket!.on('game-ended', (data) {
      SessionStorage.clearSession();
      _gameEndedCtrl.add(_toMap(data));
    });

    _socket!.on('game-over', (data) {
      SessionStorage.clearSession();
      _gameEndedCtrl.add(_toMap(data));
    });

    _socket!.on('timer-tick', (data) {
      final seconds = data is int ? data : (data as Map)['seconds'] as int? ?? 0;
      _timerTickCtrl.add(seconds);
    });

    _socket!.on('timer-tick-data', (data) {
      final seconds = data is int ? data : (data as Map)['seconds'] as int? ?? 0;
      _timerTickCtrl.add(seconds);
    });

    // ── Drawing events ──
    _socket!.on('drawing-data', (data) {
      _drawingDataCtrl.add(_toMap(data));
    });

    _socket!.on('canvas-cleared', (_) {
      _canvasClearedCtrl.add(null);
    });

    // ── Chat / guessing events ──
    _socket!.on('chat-message', (data) {
      _chatMessageCtrl.add(_toMap(data));
    });

    _socket!.on('correct-guess', (data) {
      _correctGuessCtrl.add(_toMap(data));
    });

    _socket!.on('word-hint-update', (data) {
      final hint = data is Map ? (data['wordHint'] ?? data['hint']) as String? : data.toString();
      _wordHintUpdateCtrl.add(hint ?? '');
    });

    _socket!.on('hint-update', (data) {
      final hint = data is Map ? (data['wordHint'] ?? data['hint']) as String? : data.toString();
      _wordHintUpdateCtrl.add(hint ?? '');
    });

    _socket!.on('choose-word', (data) {
      _chooseWordCtrl.add(_toMap(data));
    });

    _socket!.on('drawer-choosing', (data) {
      _drawerChoosingCtrl.add(_toMap(data));
    });
  }

  // ──────────────────────────── Emit Methods ────────────────────────────

  /// Join the public matchmaking queue
  void joinPublic(String nickname) {
    _ensureConnected(() {
      _socket?.emit('join-public', {'nickname': nickname});
    });
  }

  /// Create a new private room
  void createPrivate(String nickname) {
    _ensureConnected(() {
      _socket?.emit('create-private', {'nickname': nickname});
    });
  }

  /// Join an existing private room by code
  void joinPrivate(String nickname, String roomCode) {
    _ensureConnected(() {
      _socket?.emit('join-private', {'nickname': nickname, 'roomCode': roomCode.toUpperCase()});
    });
  }

  /// Signal that the local player is ready to start (toggles ready state)
  void setReady() {
    _ensureConnected(() {
      _socket?.emit('player-ready');
    });
  }

  /// Drawer picks a word from the offered list
  void chooseWord(String word) {
    _ensureConnected(() {
      _socket?.emit('word-chosen', {'word': word});
    });
  }

  /// Send an incremental batch of stroke points to the server
  void sendDrawingData(List<Map<String, dynamic>> strokes) {
    _socket?.emit('drawing-data', {'strokes': strokes});
  }

  /// Tell all other clients to clear the canvas
  void clearCanvas() {
    _socket?.emit('clear-canvas');
  }

  /// Send a guess (or a chat message if not in drawing phase)
  void sendGuess(String text) {
    _ensureConnected(() {
      _socket?.emit('guess', {'text': text});
    });
  }

  /// Attempt to reconnect to an existing room session
  void reconnectPlayer({required String roomCode, required String sessionToken}) {
    _ensureConnected(() {
      _socket?.emit('reconnect-player', {
        'roomCode': roomCode,
        'sessionToken': sessionToken,
      });
    });
  }

  /// Explicitly leaves the room and clears local session
  void leaveRoom() {
    _socket?.emit('leave-room');
    SessionStorage.clearSession();
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
    _chooseWordCtrl.close();
    _drawerChoosingCtrl.close();
    _reconnectedSuccessCtrl.close();
    _reconnectFailedCtrl.close();
  }
}
