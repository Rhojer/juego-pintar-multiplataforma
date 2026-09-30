import 'package:shared_preferences/shared_preferences.dart';

/// Helper to persist and retrieve active game sessions in local storage.
class SessionStorage {
  SessionStorage._();

  static const String _keyRoomCode = 'rayando_room_code';
  static const String _keySessionToken = 'rayando_session_token';
  static const String _keyNickname = 'rayando_nickname';
  static const String _keyAvatar = 'rayando_avatar';

  /// Saves the chosen avatar preference.
  static Future<void> saveAvatar(String avatar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAvatar, avatar);
    } catch (_) {}
  }

  /// Saves the chosen nickname.
  static Future<void> saveNickname(String nickname) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNickname, nickname);
    } catch (_) {}
  }

  /// Retrieves the saved nickname preference.
  static Future<String> getNickname() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nick = prefs.getString(_keyNickname);
      if (nick != null && nick.isNotEmpty) return nick;
    } catch (_) {}
    return '';
  }

  /// Retrieves the saved avatar preference, defaulting to 'arepa'.
  static Future<String> getAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatar = prefs.getString(_keyAvatar);
      if (avatar != null && avatar.isNotEmpty) return avatar;
    } catch (_) {}
    return 'arepa';
  }

  /// Saves the active room session.
  static Future<void> saveSession({
    required String roomCode,
    required String sessionToken,
    required String nickname,
    String? avatar,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRoomCode, roomCode);
      await prefs.setString(_keySessionToken, sessionToken);
      await prefs.setString(_keyNickname, nickname);
      if (avatar != null && avatar.isNotEmpty) {
        await prefs.setString(_keyAvatar, avatar);
      }
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
      final avatar = prefs.getString(_keyAvatar);

      if (roomCode != null &&
          roomCode.isNotEmpty &&
          sessionToken != null &&
          sessionToken.isNotEmpty) {
        return {
          'roomCode': roomCode,
          'sessionToken': sessionToken,
          'nickname': nickname ?? '',
          'avatar': avatar ?? 'arepa',
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
      // Keep avatar and nickname preference for user convenience
    } catch (e) {
      // Ignore
    }
  }
}
