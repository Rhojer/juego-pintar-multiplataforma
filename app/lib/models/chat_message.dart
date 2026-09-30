import 'package:flutter/foundation.dart';

/// Represents a single message in the game chat
@immutable
class ChatMessage {
  const ChatMessage({
    required this.nickname,
    required this.text,
    required this.timestamp,
    this.isCorrect = false,
    this.isSystem = false,
    this.isClose = false,
  });

  final String nickname;
  final String text;

  /// True when this message announces a correct guess
  final bool isCorrect;

  /// True for server system notifications (player joined, etc.)
  final bool isSystem;

  /// True when a guess was close to the target word
  final bool isClose;

  final DateTime timestamp;

  factory ChatMessage.system(String text) => ChatMessage(
        nickname: '',
        text: text,
        isSystem: true,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.close({
    String nickname = '',
    required String text,
  }) =>
      ChatMessage(
        nickname: nickname,
        text: text,
        isClose: true,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.correct({
    required String nickname,
    required String text,
  }) =>
      ChatMessage(
        nickname: nickname,
        text: text,
        isCorrect: true,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.guess({
    required String nickname,
    required String text,
  }) =>
      ChatMessage(
        nickname: nickname,
        text: text,
        timestamp: DateTime.now(),
      );

  @override
  String toString() => 'ChatMessage($nickname: $text)';
}
