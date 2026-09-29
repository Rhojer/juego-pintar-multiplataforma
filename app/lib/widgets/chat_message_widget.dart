import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';

/// Renders a single [ChatMessage] with correct styling based on type.
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({super.key, required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _SystemMessage(text: message.text);
    if (message.isCorrect) return _CorrectMessage(message: message);
    if (message.text.toLowerCase().contains('cerca')) {
      return _CloseGuessMessage(message: message);
    }
    return _RegularMessage(message: message);
  }
}

// ─────────────────── System Message ───────────────────

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withOpacity(0.6),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.nunitoSans(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Correct Guess Message ───────────────────

class _CorrectMessage extends StatelessWidget {
  const _CorrectMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.correct.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.correct, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.correct.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text,
              style: GoogleFonts.rubik(
                color: AppColors.correct,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.correct,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              '¡ACIERTO!',
              style: GoogleFonts.rubik(
                color: const Color(0xFF050C27),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Close Guess Message ───────────────────

class _CloseGuessMessage extends StatelessWidget {
  const _CloseGuessMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.secondary.withOpacity(0.6), width: 1.2),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.nunitoSans(fontSize: 13, color: Colors.white),
                children: [
                  TextSpan(
                    text: '${message.nickname}: ',
                    style: GoogleFonts.rubik(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: message.text,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────── Regular Message ───────────────────

class _RegularMessage extends StatelessWidget {
  const _RegularMessage({required this.message});
  final ChatMessage message;

  Color _nicknameColor(String nickname) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      const Color(0xFF80DEEA),
      const Color(0xFFFF8A65),
      const Color(0xFFA5D6A7),
      const Color(0xFFFFD54F),
    ];
    final idx = nickname.isEmpty ? 0 : nickname.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.nunitoSans(fontSize: 13, color: Colors.white),
          children: [
            TextSpan(
              text: '${message.nickname}: ',
              style: GoogleFonts.rubik(
                color: _nicknameColor(message.nickname),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            TextSpan(
              text: message.text,
              style: GoogleFonts.nunitoSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
