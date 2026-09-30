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
      name: 'Arepita Feliz',
      emoji: '🫓',
      color: Color(0xFFFFB300),
      subtitle: "Rellena con queso 'e mano",
      assetPath: 'assets/avatars/arepa.jpg',
    ),
    VzlaAvatar(
      id: 'malta',
      name: 'Malta Heladita',
      emoji: '🥤',
      color: Color(0xFF5D4037),
      subtitle: 'Con espuma burbujeante',
      assetPath: 'assets/avatars/malta.jpg',
    ),
    VzlaAvatar(
      id: 'aguacate',
      name: 'Aguacate Sifrino',
      emoji: '🥑',
      color: Color(0xFF43A047),
      subtitle: 'Con lentes de sol chévere',
      assetPath: 'assets/avatars/aguacate.jpg',
    ),
    VzlaAvatar(
      id: 'chivo',
      name: 'Chivo Falconiano',
      emoji: '🐐',
      color: Color(0xFF8D6E63),
      subtitle: 'Con sombrero de cogollo',
      assetPath: 'assets/avatars/chivo.jpg',
    ),
    VzlaAvatar(
      id: 'baseball',
      name: 'Pelota Jonronera',
      emoji: '⚾',
      color: Color(0xFFD32F2F),
      subtitle: 'Costuras rojas y gorrita',
      assetPath: 'assets/avatars/baseball.jpg',
    ),
    VzlaAvatar(
      id: 'mototaxi',
      name: 'Mototaxi Autopista',
      emoji: '🛵',
      color: Color(0xFF0288D1),
      subtitle: 'Haciendo pirueta caraqueña',
      assetPath: 'assets/avatars/mototaxi.jpg',
    ),
    VzlaAvatar(
      id: 'iguana',
      name: 'Iguana Soleada',
      emoji: '🦎',
      color: Color(0xFF2E7D32),
      subtitle: 'Relajada sobre el muro',
      assetPath: 'assets/avatars/iguana.jpg',
    ),
    VzlaAvatar(
      id: 'desierto',
      name: 'Médano Larense',
      emoji: '🏜️',
      color: Color(0xFFFB8C00),
      subtitle: 'Duna con cactus y sol',
      assetPath: 'assets/avatars/desierto.jpg',
    ),
    VzlaAvatar(
      id: 'tequeno',
      name: 'Tequeño Rumbero',
      emoji: '🧀',
      color: Color(0xFFFBC02D),
      subtitle: 'Estirando queso con tártara',
      assetPath: 'assets/avatars/tequeno.jpg',
    ),
    VzlaAvatar(
      id: 'harina_pan',
      name: 'Harina P.A.M',
      emoji: '🌽',
      color: Color(0xFFFFD600),
      subtitle: 'El corazón de las arepas desde 1960',
      assetPath: 'assets/avatars/harina_pan.jpg',
    ),
    VzlaAvatar(
      id: 'guacamaya',
      name: 'Guacamaya Tricolor',
      emoji: '🦜',
      color: Color(0xFFE91E63),
      subtitle: 'Radiante vuelo en Caracas',
      assetPath: 'assets/avatars/guacamaya.jpg',
    ),
    VzlaAvatar(
      id: 'caraota',
      name: 'Caraotica Criolla',
      emoji: '🍲',
      color: Color(0xFF212121),
      subtitle: 'Grano negro con vaporcito',
      assetPath: 'assets/avatars/caraota.jpg',
    ),
  ];

  static VzlaAvatar getById(String? id) {
    if (id == null || id.isEmpty) return all.first;
    return all.firstWhere((a) => a.id == id, orElse: () => all.first);
  }
}
