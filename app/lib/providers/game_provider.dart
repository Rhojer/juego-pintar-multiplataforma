import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../services/socket_service.dart';
import '../core/constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GAME PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Central game state notifier that wires socket events to immutable GameState.
class GameNotifier extends Notifier<GameState?> {
  final _socket = SocketService();
  final List<StreamSubscription> _subs = [];

  @override
  GameState? build() {
    // Ensure socket is connected
    _socket.connect();
    _listenToSocket();

    // Clean up on dispose
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
    });
    return null;
  }

  void _listenToSocket() {
    _subs.addAll([
      _socket.onRoomJoined.listen(_onRoomJoined),
      _socket.onPlayerJoined.listen(_onPlayerJoined),
      _socket.onPlayerLeft.listen(_onPlayerLeft),
      _socket.onPlayerReady.listen(_onPlayerReady),
      _socket.onGameStarted.listen(_onGameStarted),
      _socket.onTurnStarted.listen(_onTurnStarted),
      _socket.onTurnEnded.listen(_onTurnEnded),
      _socket.onGameEnded.listen(_onGameEnded),
      _socket.onTimerTick.listen(_onTimerTick),
      _socket.onCorrectGuess.listen(_onCorrectGuess),
      _socket.onWordHintUpdate.listen(_onWordHintUpdate),
    ]);
  }

  // ─── Event Handlers ───

  void _onRoomJoined(Map<String, dynamic> data) {
    final roomMap = data['room'] is Map ? Map<String, dynamic>.from(data['room'] as Map) : null;
    final rawPlayers = data['players'] ?? roomMap?['players'];
    final players = _parsePlayers(rawPlayers);

    final myPlayer = data['player'] is Map ? Map<String, dynamic>.from(data['player'] as Map) : null;
    final nickname = data['nickname'] as String? ?? myPlayer?['nickname'] as String? ?? '';
    final roomCode = data['roomCode'] as String? ?? roomMap?['code'] as String? ?? '';
    final isPrivate = data['isPrivate'] as bool? ?? roomMap?['isPrivate'] as bool? ?? false;
    final totalRounds = (data['totalRounds'] as num?)?.toInt() ??
        (roomMap?['totalRounds'] as num?)?.toInt() ??
        AppConstants.maxRounds;

    state = GameState.initial(
      myId: _socket.socketId,
      myNickname: nickname,
    ).copyWith(
      roomCode: roomCode,
      isPrivate: isPrivate,
      players: players,
      totalRounds: totalRounds,
    );
    // Notify chat
    ref.read(chatProvider.notifier).addSystem(VzlaMessages.playerJoined);
  }

  void _onPlayerJoined(Map<String, dynamic> data) {
    final player = Player.fromJson(data['player'] as Map<String, dynamic>);
    final current = state;
    if (current == null) return;
    final updated = [...current.players.where((p) => p.id != player.id), player];
    state = current.copyWith(players: updated);
    ref.read(chatProvider.notifier).addSystem(
          '${player.nickname} ${VzlaMessages.playerJoined}',
        );
  }

  void _onPlayerLeft(Map<String, dynamic> data) {
    final id = data['playerId'] as String?;
    final nickname = data['nickname'] as String? ?? '¿Quién?';
    final current = state;
    if (current == null || id == null) return;
    state = current.copyWith(
      players: current.players.where((p) => p.id != id).toList(),
    );
    ref.read(chatProvider.notifier).addSystem('$nickname ${VzlaMessages.playerLeft}');
  }

  void _onPlayerReady(Map<String, dynamic> data) {
    final current = state;
    if (current == null) return;

    if (data['players'] is List) {
      final updatedPlayers = _parsePlayers(data['players']);
      state = current.copyWith(players: updatedPlayers);
      return;
    }

    final id = data['playerId'] as String?;
    final isReady = data['isReady'] as bool? ?? true;
    if (id == null) return;
    final updated = current.players.map((p) {
      return p.id == id ? p.copyWith(isReady: isReady) : p;
    }).toList();
    state = current.copyWith(players: updated);
  }

  void _onGameStarted(Map<String, dynamic> data) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(
      status: GameStatus.playing,
      currentRound: 1,
      totalRounds: (data['totalRounds'] as num?)?.toInt() ?? current.totalRounds,
    );
    ref.read(chatProvider.notifier).addSystem(VzlaMessages.gameStarting);
    // Clear the drawing canvas
    ref.read(drawingProvider.notifier).clear();
  }

  void _onTurnStarted(Map<String, dynamic> data) {
    final current = state;
    if (current == null) return;

    final drawerNickname = data['drawerNickname'] as String? ?? '';
    final word = data['word'] as String?;           // Only for the drawer
    final wordHint = data['wordHint'] as String?;   // Dashes for guessers
    final wordLen = (data['wordLength'] as num?)?.toInt() ?? 0;
    final round = (data['round'] as num?)?.toInt() ?? current.currentRound;
    final timeLeft = (data['timeLeft'] as num?)?.toInt() ?? AppConstants.roundTime;

    // Parse updated player list (scores might have been reset/updated)
    final rawPlayers = data['players'];
    final players = rawPlayers != null ? _parsePlayers(rawPlayers) : current.players;
    // Mark the current drawer
    final markedPlayers = players.map((p) {
      return p.copyWith(isDrawing: p.nickname == drawerNickname, hasGuessed: false);
    }).toList();

    state = current.copyWith(
      status: GameStatus.playing,
      currentRound: round,
      currentDrawerNickname: drawerNickname,
      wordLength: wordLen,
      wordHint: word != null ? null : wordHint, // drawer sees full word
      currentWord: word,
      timeLeft: timeLeft,
      players: markedPlayers,
      clearLastWord: true,
    );

    ref.read(timerProvider.notifier).state = timeLeft;
    ref.read(drawingProvider.notifier).clear();
    ref.read(chatProvider.notifier).addSystem(
          word != null
              ? '${VzlaMessages.turnStartDrawing} La palabra: "$word"'
              : '¡$drawerNickname está dibujando! Adivina la palabra.',
        );
  }

  void _onTurnEnded(Map<String, dynamic> data) {
    final current = state;
    if (current == null) return;

    final word = data['word'] as String? ?? '';
    final rawPlayers = data['players'];
    final players = rawPlayers != null ? _parsePlayers(rawPlayers) : current.players;

    state = current.copyWith(
      status: GameStatus.results,
      lastWord: word,
      players: players,
      clearCurrentWord: true,
    );

    ref.read(chatProvider.notifier).addSystem(
          '${VzlaMessages.turnEndWord}"$word". ¡Qué vaina!',
        );
  }

  void _onGameEnded(Map<String, dynamic> data) {
    final current = state;
    if (current == null) return;

    final rawPlayers = data['players'];
    final players = rawPlayers != null ? _parsePlayers(rawPlayers) : current.players;

    state = current.copyWith(
      status: GameStatus.results,
      players: players,
    );

    ref.read(chatProvider.notifier).addSystem(VzlaMessages.gameOver);
  }

  void _onTimerTick(int seconds) {
    ref.read(timerProvider.notifier).state = seconds;
    final current = state;
    if (current != null) {
      state = current.copyWith(timeLeft: seconds);
    }
  }

  void _onCorrectGuess(Map<String, dynamic> data) {
    final guesserNickname = data['nickname'] as String? ?? '';
    final guesserMsgId = data['playerId'] as String?;
    final current = state;
    if (current == null) return;

    // Mark player as having guessed
    if (guesserMsgId != null) {
      final updated = current.players.map((p) {
        return p.id == guesserMsgId ? p.copyWith(hasGuessed: true) : p;
      }).toList();
      state = current.copyWith(players: updated);
    }

    ref.read(chatProvider.notifier).addCorrect(
          nickname: guesserNickname,
          text: '¡$guesserNickname adivinó la palabra! ✅',
        );
  }

  void _onWordHintUpdate(String hint) {
    final current = state;
    if (current == null || current.amIDrawing) return;
    state = current.copyWith(wordHint: hint);
  }

  // ─── Public Actions ───

  void joinPublic(String nickname) {
    _socket.joinPublic(nickname);
  }

  void createPrivate(String nickname) {
    _socket.createPrivate(nickname);
  }

  void joinPrivate(String nickname, String roomCode) {
    _socket.joinPrivate(nickname, roomCode);
  }

  void setReady() {
    _socket.setReady();
    final current = state;
    if (current == null) return;
    final me = current.me;
    if (me == null) return;
    final updated = current.players.map((p) {
      return p.id == me.id ? p.copyWith(isReady: !p.isReady) : p;
    }).toList();
    state = current.copyWith(players: updated);
  }

  void sendGuess(String text) {
    _socket.sendGuess(text);
  }

  // ─── Helpers ───

  List<Player> _parsePlayers(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Player.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    }
    return [];
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState?>(GameNotifier.new);

// ═══════════════════════════════════════════════════════════════════════════════
// CHAT PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([]);

  final _socket = SocketService();
  late final StreamSubscription _chatSub;
  late final StreamSubscription _joinErrSub;

  void init() {
    _chatSub = _socket.onChatMessage.listen((data) {
      final nickname = data['nickname'] as String? ?? '';
      final text = data['text'] as String? ?? '';
      addMessage(ChatMessage.guess(nickname: nickname, text: text));
    });

    _joinErrSub = _socket.onJoinError.listen((msg) {
      addSystem('⚠️ $msg');
    });
  }

  @override
  void dispose() {
    _chatSub.cancel();
    _joinErrSub.cancel();
    super.dispose();
  }

  void addMessage(ChatMessage msg) {
    state = [...state, msg];
  }

  void addSystem(String text) {
    state = [...state, ChatMessage.system(text)];
  }

  void addCorrect({required String nickname, required String text}) {
    state = [...state, ChatMessage.correct(nickname: nickname, text: text)];
  }

  void clear() => state = [];
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  final notifier = ChatNotifier()..init();
  return notifier;
});

// ═══════════════════════════════════════════════════════════════════════════════
// DRAWING PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// State for the drawing canvas — a list of completed strokes plus the active one.
class DrawingState {
  const DrawingState({
    this.strokes = const [],
    this.activeStroke,
  });

  final List<Map<String, dynamic>> strokes; // completed strokes
  final Map<String, dynamic>? activeStroke; // currently being drawn

  DrawingState copyWith({
    List<Map<String, dynamic>>? strokes,
    Map<String, dynamic>? activeStroke,
    bool clearActive = false,
  }) {
    return DrawingState(
      strokes: strokes ?? this.strokes,
      activeStroke: clearActive ? null : (activeStroke ?? this.activeStroke),
    );
  }
}

class DrawingNotifier extends StateNotifier<DrawingState> {
  DrawingNotifier() : super(const DrawingState());

  final _socket = SocketService();
  late final StreamSubscription _drawingSub;
  late final StreamSubscription _clearSub;

  /// Buffer for the current stroke's points before sending
  final List<Map<String, double>> _pointBuffer = [];
  String _color = '#000000';
  double _strokeWidth = 4.0;
  bool _isEraser = false;

  void init() {
    _drawingSub = _socket.onDrawingData.listen((data) {
      final rawStrokes = data['strokes'] as List<dynamic>?;
      if (rawStrokes == null) return;
      final newStrokes = rawStrokes
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      state = state.copyWith(strokes: [...state.strokes, ...newStrokes]);
    });

    _clearSub = _socket.onCanvasCleared.listen((_) {
      clear();
    });
  }

  @override
  void dispose() {
    _drawingSub.cancel();
    _clearSub.cancel();
    super.dispose();
  }

  // ─── Tool selection ───

  void setColor(String hexColor) => _color = hexColor;
  void setStrokeWidth(double width) => _strokeWidth = width;
  void setEraser(bool value) => _isEraser = value;

  String get currentColor => _color;
  double get currentStrokeWidth => _strokeWidth;
  bool get isEraser => _isEraser;

  // ─── Drawing actions ───

  void startStroke(double x, double y) {
    _pointBuffer.clear();
    _pointBuffer.add({'x': x, 'y': y});
    state = state.copyWith(
      activeStroke: _buildStroke([_pointBuffer.first]),
    );
  }

  void addPoint(double x, double y) {
    _pointBuffer.add({'x': x, 'y': y});
    // Update visual immediately
    state = state.copyWith(activeStroke: _buildStroke(List.from(_pointBuffer)));

    // Send every N points for bandwidth efficiency
    if (_pointBuffer.length % AppConstants.strokeSendInterval == 0) {
      _flushBuffer();
    }
  }

  void endStroke() {
    if (_pointBuffer.isEmpty) return;
    final stroke = _buildStroke(List.from(_pointBuffer));
    _socket.sendDrawingData([stroke]);
    state = state.copyWith(
      strokes: [...state.strokes, stroke],
      clearActive: true,
    );
    _pointBuffer.clear();
  }

  void clear() {
    state = const DrawingState();
    _pointBuffer.clear();
  }

  void clearAndNotifyServer() {
    clear();
    _socket.clearCanvas();
  }

  void _flushBuffer() {
    if (_pointBuffer.isEmpty) return;
    final stroke = _buildStroke(List.from(_pointBuffer));
    _socket.sendDrawingData([stroke]);
  }

  Map<String, dynamic> _buildStroke(List<Map<String, double>> points) => {
        'points': points,
        'color': _isEraser ? '#FFFFFF' : _color,
        'strokeWidth': _strokeWidth,
        'isEraser': _isEraser,
      };
}

final drawingProvider = StateNotifierProvider<DrawingNotifier, DrawingState>((ref) {
  final notifier = DrawingNotifier()..init();
  return notifier;
});

// ═══════════════════════════════════════════════════════════════════════════════
// TIMER PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

final timerProvider = StateProvider<int>((ref) => AppConstants.roundTime);
