import 'package:flutter/foundation.dart';
import 'player.dart';

/// The overall status of the game session
enum GameStatus {
  waiting,  // In lobby, waiting for players to be ready
  playing,  // Active game round in progress
  results,  // Showing round/game results
}

/// Represents a single drawing stroke received from the server or generated locally
@immutable
class DrawStroke {
  const DrawStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  final List<Map<String, double>> points; // [{x: double, y: double}]
  final String color; // hex string e.g. '#FF5722'
  final double strokeWidth;
  final bool isEraser;

  factory DrawStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>;
    return DrawStroke(
      points: rawPoints.map<Map<String, double>>((p) {
        final pm = p as Map<String, dynamic>;
        return {
          'x': (pm['x'] as num).toDouble(),
          'y': (pm['y'] as num).toDouble(),
        };
      }).toList(),
      color: json['color'] as String? ?? '#000000',
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 4.0,
      isEraser: json['isEraser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points,
        'color': color,
        'strokeWidth': strokeWidth,
        'isEraser': isEraser,
      };
}

/// Full game state managed by the GameNotifier
@immutable
class GameState {
  const GameState({
    required this.roomCode,
    required this.isPrivate,
    required this.players,
    required this.status,
    required this.currentRound,
    required this.totalRounds,
    required this.currentDrawerNickname,
    required this.wordLength,
    required this.timeLeft,
    required this.myId,
    required this.myNickname,
    this.wordHint,
    this.currentWord,       // Only populated for the drawer
    this.lastWord,          // Set at end of turn so guessers can see it
  });

  final String roomCode;
  final bool isPrivate;
  final List<Player> players;
  final GameStatus status;
  final int currentRound;
  final int totalRounds;
  final String currentDrawerNickname;
  final int wordLength;
  final int timeLeft;
  final String myId;
  final String myNickname;

  /// Underscores and revealed letters shown to guessers: e.g. "_ _ v _ l _"
  final String? wordHint;

  /// Full word — only given to the drawer by the server
  final String? currentWord;

  /// The word revealed after the turn ends
  final String? lastWord;

  // ──────────────────────────────── Derived ────────────────────────────────

  bool get amIDrawing => currentDrawerNickname == myNickname;

  bool get isMyTurn => amIDrawing;

  Player? get me => players.where((p) => p.id == myId).firstOrNull;

  bool get iHaveGuessed => me?.hasGuessed ?? false;

  List<Player> get sortedByScore {
    final sorted = [...players];
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  // ──────────────────────────────── fromJson ────────────────────────────────

  factory GameState.initial({required String myId, required String myNickname}) {
    return GameState(
      roomCode: '',
      isPrivate: false,
      players: const [],
      status: GameStatus.waiting,
      currentRound: 0,
      totalRounds: 5,
      currentDrawerNickname: '',
      wordLength: 0,
      timeLeft: 80,
      myId: myId,
      myNickname: myNickname,
    );
  }

  // ──────────────────────────────── copyWith ────────────────────────────────

  GameState copyWith({
    String? roomCode,
    bool? isPrivate,
    List<Player>? players,
    GameStatus? status,
    int? currentRound,
    int? totalRounds,
    String? currentDrawerNickname,
    int? wordLength,
    int? timeLeft,
    String? myId,
    String? myNickname,
    String? wordHint,
    String? currentWord,
    String? lastWord,
    bool clearCurrentWord = false,
    bool clearLastWord = false,
  }) {
    return GameState(
      roomCode: roomCode ?? this.roomCode,
      isPrivate: isPrivate ?? this.isPrivate,
      players: players ?? this.players,
      status: status ?? this.status,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      currentDrawerNickname: currentDrawerNickname ?? this.currentDrawerNickname,
      wordLength: wordLength ?? this.wordLength,
      timeLeft: timeLeft ?? this.timeLeft,
      myId: myId ?? this.myId,
      myNickname: myNickname ?? this.myNickname,
      wordHint: wordHint ?? this.wordHint,
      currentWord: clearCurrentWord ? null : (currentWord ?? this.currentWord),
      lastWord: clearLastWord ? null : (lastWord ?? this.lastWord),
    );
  }

  @override
  String toString() => 'GameState(room: $roomCode, status: $status, '
      'round: $currentRound/$totalRounds, drawer: $currentDrawerNickname)';
}
