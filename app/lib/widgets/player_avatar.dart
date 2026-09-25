import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';

/// Circular avatar displaying the player's initial, score badge,
/// and optional drawing/guessed indicators.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.nickname,
    required this.size,
    this.score,
    this.isMe = false,
    this.isDrawing = false,
    this.hasGuessed = false,
  });

  final String nickname;

  /// Diameter of the avatar circle
  final double size;

  /// When non-null, displays a score badge below the avatar.
  final int? score;

  final bool isMe;
  final bool isDrawing;
  final bool hasGuessed;

  /// Deterministically picks a color from the palette based on the nickname
  Color _avatarColor() {
    final palette = [
      AppColors.primary,
      AppColors.accent,
      AppColors.secondary,
      const Color(0xFF7E57C2),
      const Color(0xFF26A69A),
      const Color(0xFFEF5350),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
    ];
    final idx = nickname.isEmpty ? 0 : nickname.codeUnitAt(0) % palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor();
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
    final fontSize = size * 0.42;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Main circle
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMe ? Colors.white : Colors.white24,
                  width: isMe ? 2.5 : 1,
                ),
                boxShadow: isMe
                    ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                    : null,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            // Drawing pencil badge
            if (isDrawing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: size * 0.35,
                  height: size * 0.35,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('✏️', style: TextStyle(fontSize: 9))),
                ),
              ),
            // Guessed check badge
            if (hasGuessed && !isDrawing)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: size * 0.35,
                  height: size * 0.35,
                  decoration: const BoxDecoration(
                    color: AppColors.correct,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Text('✅', style: TextStyle(fontSize: 8))),
                ),
              ),
          ],
        ),
        // Score badge
        if (score != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$score',
              style: GoogleFonts.nunito(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
