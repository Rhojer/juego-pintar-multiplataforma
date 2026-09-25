import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../widgets/player_avatar.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with TickerProviderStateMixin {
  int _countdown = 8; // seconds until next round auto-advance
  Timer? _timer;
  late final AnimationController _slideCtrl;
  late final List<Animation<Offset>> _slideAnims;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();

    final gameState = ref.read(gameProvider);
    _isGameOver = gameState != null &&
        (gameState.currentRound >= gameState.totalRounds ||
            gameState.status == GameStatus.results &&
                gameState.players.every((p) => !p.isDrawing));

    // Build slide animations for leaderboard entries
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnims = List.generate(
      8,
      (i) => Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _slideCtrl,
          curve: Interval(i * 0.1, (i * 0.1 + 0.5).clamp(0, 1), curve: Curves.elasticOut),
        ),
      ),
    );
    _slideCtrl.forward();

    // Auto-advance countdown (only for mid-game results)
    if (!_isGameOver) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _countdown--);
        if (_countdown <= 0) {
          t.cancel();
          if (mounted) context.go('/game');
        }
      });

      // Also listen for the next turn starting from the server
      // The server will send 'turn-started' which navigates us forward
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _playAgain() {
    // Request play again – the server should restart the game
    ref.read(gameProvider.notifier).setReady();
    context.go('/lobby');
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sorted = gameState.sortedByScore;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.cardColor, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(gameState),
              if (gameState.lastWord != null) _buildWordReveal(gameState.lastWord!),
              const SizedBox(height: 16),
              Expanded(child: _buildLeaderboard(sorted, gameState.myId)),
              _buildBottomBar(gameState),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameState gameState) {
    final isEnd = _isGameOver;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            isEnd ? '🏆 ¡Fin del Juego! 🏆' : '⏱️ ¡Fin de la Ronda!',
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isEnd ? AppColors.secondary : Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (!isEnd)
            Text(
              'Ronda ${gameState.currentRound} de ${gameState.totalRounds}',
              style: GoogleFonts.nunito(color: Colors.white54, fontSize: 14),
            ),
          if (isEnd)
            Text(
              VzlaMessages.gameOver,
              style: GoogleFonts.nunito(
                color: AppColors.secondary.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWordReveal(String word) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Text(
            'La palabra era: ',
            style: GoogleFonts.nunito(color: Colors.white54, fontSize: 15),
          ),
          Text(
            word.toUpperCase(),
            style: GoogleFonts.nunito(
              color: AppColors.secondary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(List<Player> sorted, String myId) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sorted.length,
      itemBuilder: (ctx, index) {
        final player = sorted[index];
        final isMe = player.id == myId;
        final anim = index < _slideAnims.length ? _slideAnims[index] : null;

        Widget card = _LeaderboardCard(
          rank: index + 1,
          player: player,
          isMe: isMe,
        );

        if (anim != null) {
          card = SlideTransition(position: anim, child: card);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: card,
        );
      },
    );
  }

  Widget _buildBottomBar(GameState gameState) {
    if (_isGameOver) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            Text(
              '¡Qué vaina tan chévere, panas!',
              style: GoogleFonts.nunito(color: Colors.white54),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _playAgain,
                icon: const Icon(Icons.replay_rounded),
                label: Text(
                  '¡Jugar de nuevo!',
                  style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => context.go('/'),
              child: Text(
                'Volver al inicio',
                style: GoogleFonts.nunito(color: Colors.white38),
              ),
            ),
          ],
        ),
      );
    }

    // Mid-game: show countdown
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Center(
            child: Text(
              'Siguiente ronda en $_countdown segundos...',
              style: GoogleFonts.nunito(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            _timer?.cancel();
            context.go('/game');
          },
          child: Text(
            'Continuar ahora →',
            style: GoogleFonts.nunito(color: Colors.white54),
          ),
        ),
      ],
    );
  }
}

// ─────────────────── Leaderboard Card ───────────────────

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.rank,
    required this.player,
    required this.isMe,
  });

  final int rank;
  final Player player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final rankEmoji = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '#$rank';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withOpacity(0.2)
            : rank == 1
                ? AppColors.secondary.withOpacity(0.12)
                : AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppColors.primary
              : rank == 1
                  ? AppColors.secondary.withOpacity(0.5)
                  : Colors.white12,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: Text(
              rankEmoji,
              style: GoogleFonts.nunito(
                fontSize: rank <= 3 ? 22 : 16,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          PlayerAvatar(nickname: player.nickname, size: 40, score: null),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              player.nickname + (isMe ? ' (tú)' : ''),
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 16,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.score}',
                style: GoogleFonts.nunito(
                  color: rank == 1 ? AppColors.secondary : AppColors.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'puntos',
                style: GoogleFonts.nunito(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
