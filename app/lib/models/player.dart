import 'package:flutter/foundation.dart';

/// Represents a player in the game room
@immutable
class Player {
  const Player({
    required this.id,
    required this.nickname,
    this.score = 0,
    this.isReady = false,
    this.isDrawing = false,
    this.hasGuessed = false,
  });

  final String id;
  final String nickname;
  final int score;
  final bool isReady;
  final bool isDrawing;
  final bool hasGuessed;

  /// Creates a [Player] from a JSON map received from the server
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      isReady: json['isReady'] as bool? ?? false,
      isDrawing: json['isDrawing'] as bool? ?? false,
      hasGuessed: json['hasGuessed'] as bool? ?? false,
    );
  }

  /// Serializes this [Player] to a JSON map
  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'score': score,
        'isReady': isReady,
        'isDrawing': isDrawing,
        'hasGuessed': hasGuessed,
      };

  /// Returns a copy of this [Player] with the given fields replaced
  Player copyWith({
    String? id,
    String? nickname,
    int? score,
    bool? isReady,
    bool? isDrawing,
    bool? hasGuessed,
  }) {
    return Player(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      score: score ?? this.score,
      isReady: isReady ?? this.isReady,
      isDrawing: isDrawing ?? this.isDrawing,
      hasGuessed: hasGuessed ?? this.hasGuessed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Player && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Player(id: $id, nickname: $nickname, score: $score)';
}
