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

/// Venezuelan-themed color palette aligned with Google Stitch DESIGN.md ("Tactile Neopop")
class AppColors {
  AppColors._();

  // Core brand accents
  static const Color primary = Color(0xFFFFC107); // Sunny golden yellow
  static const Color secondary = Color(0xFFFF5722); // Warm electric papaya orange
  static const Color accent = Color(0xFF00E5FF); // Electric cyan

  // Background and surface tiers (Midnight oceanic depths)
  static const Color background = Color(0xFF0A112C); // Canvas Base / Underlay
  static const Color surface = Color(0xFF141B36); // Shelves, chat dock, leaderboard rail
  static const Color cardColor = Color(0xFF1E284E); // Active cards, toolbars, modal containers
  static const Color surfaceElevated = Color(0xFF222844); // High elevation surfaces
  static const Color borderSubtle = Color(0xFF293664); // Crisp panel borders

  // Game telemetry & state colors
  static const Color correct = Color(0xFF00E676); // High-luminance emerald acierto
  static const Color wrong = Color(0xFFFF1744); // Crisp crimson error / penalty
  static const Color warning = Color(0xFFFFB300); // Amber warning / 15s timer
  static const Color textMuted = Color(0xFF8E9ECA); // Subtitles, metadata, timestamps

  // Chat colors
  static const Color systemMessage = Color(0xFFFFC107);
  static const Color correctGuessMessage = Color(0xFF00E676);

  // Drawing palette (12 vibrant circular wells from Stitch design)
  static const List<Color> drawingColors = [
    Color(0xFF000000), // Negro azabache
    Color(0xFFFFFFFF), // Blanco puro
    Color(0xFFFF1744), // Rojo carmesí
    Color(0xFFFF5722), // Naranja papaya
    Color(0xFFFFC107), // Amarillo arepa
    Color(0xFF00E676), // Verde esmeralda
    Color(0xFF00E5FF), // Turquesa cian
    Color(0xFF2979FF), // Azul rey
    Color(0xFFD500F9), // Morado neón
    Color(0xFFFF4081), // Rosa tropical
    Color(0xFF8D6E63), // Marrón cacao
    Color(0xFF455A64), // Gris pizarra
  ];

  // Timer colors
  static const Color timerGreen = Color(0xFF00E676);
  static const Color timerYellow = Color(0xFFFFC107);
  static const Color timerRed = Color(0xFFFF1744);
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
