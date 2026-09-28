import 'package:flutter/material.dart';

/// Represents an iconic Venezuelan avatar available for player selection.
class VzlaAvatar {
  const VzlaAvatar({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.subtitle,
    required this.assetPath,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;
  final String subtitle;
  final String assetPath;
}

class VzlaAvatars {
  static const List<VzlaAvatar> all = [
    VzlaAvatar(
      id: 'arepa',
      name: 'Arepa',
      emoji: '🫓',
      color: Color(0xFFFFB300),
      subtitle: 'La reina del desayuno',
      assetPath: 'assets/avatars/arepa.jpg',
    ),
    VzlaAvatar(
      id: 'harina_pan',
      name: 'Harina P.A.N.',
      emoji: '🌽',
      color: Color(0xFFFFD600),
      subtitle: 'El paquete amarillo',
      assetPath: 'assets/avatars/harina_pan.jpg',
    ),
    VzlaAvatar(
      id: 'tequeno',
      name: 'Tequeño',
      emoji: '🧀',
      color: Color(0xFFFBC02D),
      subtitle: 'No hay fiesta sin él',
      assetPath: 'assets/avatars/tequeno.jpg',
    ),
    VzlaAvatar(
      id: 'mototaxi',
      name: 'Mototaxi',
      emoji: '🛵',
      color: Color(0xFF0288D1),
      subtitle: '¡Por la orillita, pana!',
      assetPath: 'assets/avatars/mototaxi.jpg',
    ),
    VzlaAvatar(
      id: 'malta',
      name: 'Malta',
      emoji: '🥤',
      color: Color(0xFF5D4037),
      subtitle: 'Bien fría con leche',
      assetPath: 'assets/avatars/malta.jpg',
    ),
    VzlaAvatar(
      id: 'chivo',
      name: 'Chivo',
      emoji: '🐐',
      color: Color(0xFF8D6E63),
      subtitle: 'Chivo en coco maracucho',
      assetPath: 'assets/avatars/chivo.jpg',
    ),
    VzlaAvatar(
      id: 'baseball',
      name: 'Béisbol',
      emoji: '⚾',
      color: Color(0xFFD32F2F),
      subtitle: '¡Pelotero de corazón!',
      assetPath: 'assets/avatars/baseball.jpg',
    ),
    VzlaAvatar(
      id: 'iguana',
      name: 'Iguana',
      emoji: '🦎',
      color: Color(0xFF43A047),
      subtitle: 'Caimán de árbol',
      assetPath: 'assets/avatars/iguana.jpg',
    ),
    VzlaAvatar(
      id: 'guacamaya',
      name: 'Guacamaya',
      emoji: '🦜',
      color: Color(0xFFE91E63),
      subtitle: 'Colores del cielo caraqueño',
      assetPath: 'assets/avatars/guacamaya.jpg',
    ),
    VzlaAvatar(
      id: 'desierto',
      name: 'Médanos',
      emoji: '🏜️',
      color: Color(0xFFFB8C00),
      subtitle: 'Médanos de Coro',
      assetPath: 'assets/avatars/desierto.jpg',
    ),
  ];

  static VzlaAvatar getById(String? id) {
    if (id == null || id.isEmpty) return all.first;
    return all.firstWhere((a) => a.id == id, orElse: () => all.first);
  }
}
