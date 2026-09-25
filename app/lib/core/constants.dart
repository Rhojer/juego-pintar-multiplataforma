import 'package:flutter/material.dart';

/// Application-wide constants for Rayando Venezuela
class AppConstants {
  AppConstants._();

  /// VPS del servidor Rayando Venezuela (HTTPS / WSS seguro)
  static const String serverUrl = 'https://koda-assist.duckdns.org';

  static const int maxPlayers = 8;
  static const int minPlayers = 2;
  static const int roundTime = 80;
  static const int maxRounds = 5;
  static const int pointsForCorrectGuess = 100;
  static const int maxNicknameLength = 15;
  static const int strokeSendInterval = 5; // send every N new points
}

/// Venezuelan-themed color palette
class AppColors {
  AppColors._();

  // Primary palette - Venezuelan flag inspired
  static const Color primary = Color(0xFFFF5722); // Deep orange / brick red
  static const Color secondary = Color(0xFFFFD600); // Venezuelan yellow
  static const Color accent = Color(0xFF1E88E5); // Venezuelan blue

  // Background shades
  static const Color background = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF16213E);
  static const Color cardColor = Color(0xFF0F3460);

  // State colors
  static const Color correct = Color(0xFF4CAF50);
  static const Color wrong = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFB300);

  // Chat colors
  static const Color systemMessage = Color(0xFF90CAF9);
  static const Color correctGuessMessage = Color(0xFF69F0AE);

  // Drawing palette
  static const List<Color> drawingColors = [
    Color(0xFF000000), // Black
    Color(0xFFFFFFFF), // White
    Color(0xFFF44336), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFFFFEB3B), // Yellow
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFF9C27B0), // Purple
    Color(0xFF795548), // Brown
    Color(0xFFE91E63), // Pink
    Color(0xFF00BCD4), // Cyan
    Color(0xFF607D8B), // Grey
  ];

  // Timer colors
  static const Color timerGreen = Color(0xFF4CAF50);
  static const Color timerYellow = Color(0xFFFFB300);
  static const Color timerRed = Color(0xFFF44336);
}

/// Venezuelan-flavored system messages
class VzlaMessages {
  VzlaMessages._();

  static const String playerJoined = '¡Llegó otro pana al lobby!';
  static const String playerLeft = 'Se fue un pana... ¡qué vaina!';
  static const String gameStarting = '¡Chévere! ¡El juego está comenzando!';
  static const String correctGuess = '¡Exacto, mi pana! Adivinaste.';
  static const String turnStartDrawing = '¡Te tocó dibujar, dale!';
  static const String turnEndWord = 'La palabra era: ';
  static const String waitingPlayers = 'Esperando que todos estén listos...';
  static const String allReady = '¡Todos listos! ¡Arrancamos!';
  static const String youGuessedIt = '¡Adivinaste, chévere!';
  static const String roundOver = '¡Se acabó la ronda, pana!';
  static const String gameOver = '¡Eso es todo, panas! ¡Fin del juego!';
  static const String disconnected = '¡Se fue la luz! Desconectado del servidor.';
  static const String connectionError = '¡Qué vaina! No se pudo conectar.';
}
