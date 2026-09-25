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
    return _RegularMessage(message: message);
  }
}

// ─────────────────── System Message ───────────────────

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                color: AppColors.systemMessage,
                fontSize: 12,
                fontStyle: FontStyle.italic,
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
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.correct.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.correct.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message.text,
              style: GoogleFonts.nunito(
                color: AppColors.correctGuessMessage,
                fontSize: 13,
                fontWeight: FontWeight.w700,
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
      AppColors.secondary,
      AppColors.accent,
      AppColors.primary,
      const Color(0xFF80DEEA),
      const Color(0xFFCE93D8),
      const Color(0xFFA5D6A7),
      const Color(0xFFFFCC80),
    ];
    final idx = nickname.isEmpty ? 0 : nickname.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.nunito(fontSize: 13, color: Colors.white),
          children: [
            TextSpan(
              text: '${message.nickname}: ',
              style: TextStyle(
                color: _nicknameColor(message.nickname),
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: message.text,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
