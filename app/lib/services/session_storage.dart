import 'package:shared_preferences/shared_preferences.dart';

/// Helper to persist and retrieve active game sessions in local storage.
class SessionStorage {
  SessionStorage._();

  static const String _keyRoomCode = 'rayando_room_code';
  static const String _keySessionToken = 'rayando_session_token';
  static const String _keyNickname = 'rayando_nickname';

  /// Saves the active room session.
  static Future<void> saveSession({
    required String roomCode,
    required String sessionToken,
    required String nickname,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRoomCode, roomCode);
      await prefs.setString(_keySessionToken, sessionToken);
      await prefs.setString(_keyNickname, nickname);
    } catch (e) {
      // Ignore storage errors on restricted environments
    }
  }

  /// Retrieves the active room session if present, or null.
  static Future<Map<String, String>?> getSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomCode = prefs.getString(_keyRoomCode);
      final sessionToken = prefs.getString(_keySessionToken);
      final nickname = prefs.getString(_keyNickname);

      if (roomCode != null &&
          roomCode.isNotEmpty &&
          sessionToken != null &&
          sessionToken.isNotEmpty) {
        return {
          'roomCode': roomCode,
          'sessionToken': sessionToken,
          'nickname': nickname ?? '',
        };
      }
    } catch (e) {
      // Return null on failure
    }
    return null;
  }

  /// Clears the active room session.
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRoomCode);
      await prefs.remove(_keySessionToken);
      await prefs.remove(_keyNickname);
    } catch (e) {
      // Ignore
    }
  }
}
