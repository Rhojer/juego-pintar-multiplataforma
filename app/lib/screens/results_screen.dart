import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../services/socket_service.dart';
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
  StreamSubscription? _turnStartedSub;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();

    final gameState = ref.read(gameProvider);
    _isGameOver = gameState != null &&
        (gameState.currentRound >= gameState.totalRounds ||
            gameState.status == GameStatus.results &&
                gameState.players.every((p) => !p.isDrawing));

    // Listen for next turn starting from server
    _turnStartedSub = SocketService().onTurnStarted.listen((_) {
      _timer?.cancel();
      if (mounted) context.go('/game');
    });

    // Auto-advance countdown fallback (only for mid-game results)
    if (!_isGameOver) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _countdown--);
        if (_countdown <= 0) {
          t.cancel();
          if (mounted) context.go('/game');
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _turnStartedSub?.cancel();
    super.dispose();
  }

  void _playAgain() {
    ref.read(gameProvider.notifier).setReady();
    context.go('/lobby');
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    if (gameState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(gameProvider) == null) {
          context.go('/');
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final sorted = gameState.sortedByScore;
    final top3 = sorted.take(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(gameState),
              const SizedBox(height: 16),

              // Banner & Title
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: AppColors.secondary.withOpacity(0.5)),
                ),
                child: Text(
                  '🌶️ ¡TREMENDO ZAPEROGO! 🎺',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¡PARTIDA TERMINADA!',
                style: GoogleFonts.rubik(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                '¡Tenemos al Rey del Rayado! 👑',
                style: GoogleFonts.rubik(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '${gameState.totalRounds} de ${gameState.totalRounds} rondas completadas. Risas, dibujos chuecos y pura sabrosura criolla.',
                style: GoogleFonts.nunitoSans(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // 3D Podium
              if (top3.isNotEmpty) _build3DPodium(top3, gameState.myId),
              const SizedBox(height: 22),

              // Leaderboard Table
              _buildLeaderboardSection(sorted, gameState.myId),
              const SizedBox(height: 20),

              // Cuadro de Honor Criollo
              _buildCuadroDeHonor(sorted),
              const SizedBox(height: 24),

              // Bottom Actions
              _buildActionButtons(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(GameState gameState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              'RAYANDO',
              style: GoogleFonts.rubik(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'CRIOLLA',
                style: GoogleFonts.rubik(
                  color: const Color(0xFF0B1124),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardColor,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Text(
            'Ronda Final ${gameState.currentRound}/${gameState.totalRounds}',
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _build3DPodium(List<Player> top3, String myId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF050C27),
            offset: Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                'PODIO OFICIAL',
                style: GoogleFonts.rubik(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd Place
              if (top3.length > 1)
                Expanded(
                  child: _buildPedestal(
                    rank: 2,
                    player: top3[1],
                    color: const Color(0xFF8E9ECA),
                    pedestalHeight: 80,
                    myId: myId,
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),

              // 1st Place (Center)
              Expanded(
                flex: 12,
                child: _buildPedestal(
                  rank: 1,
                  player: top3[0],
                  color: AppColors.primary,
                  pedestalHeight: 110,
                  isWinner: true,
                  myId: myId,
                ),
              ),
              const SizedBox(width: 8),

              // 3rd Place
              if (top3.length > 2)
                Expanded(
                  child: _buildPedestal(
                    rank: 3,
                    player: top3[2],
                    color: AppColors.secondary,
                    pedestalHeight: 65,
                    myId: myId,
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPedestal({
    required int rank,
    required Player player,
    required Color color,
    required double pedestalHeight,
    bool isWinner = false,
    required String myId,
  }) {
    final isMe = player.id == myId;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isWinner)
          const Text('👑', style: TextStyle(fontSize: 24))
        else
          const SizedBox(height: 8),
        const SizedBox(height: 4),
        PlayerAvatar(
          nickname: player.nickname,
          avatar: player.avatar,
          size: isWinner ? 54 : 42,
          score: null,
          isMe: isMe,
        ),
        const SizedBox(height: 6),
        if (isWinner)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              '¡GRAN CAMPEÓN!',
              style: GoogleFonts.rubik(
                color: const Color(0xFF0B1124),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          player.nickname,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: isWinner ? 13 : 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${player.score} pts',
          style: GoogleFonts.rubik(
            color: isWinner ? AppColors.primary : AppColors.accent,
            fontSize: isWinner ? 14 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        // 3D Arched Pedestal block
        Container(
          height: pedestalHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isWinner
                ? const Color(0xFF8A6200)
                : const Color(0xFF1E284E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF050C27),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isWinner ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                '#$rank',
                style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardSection(List<Player> sorted, String myId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tabla Final de Jugadores',
              style: GoogleFonts.rubik(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${sorted.length} Panas en Sala',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            final player = sorted[index];
            final isMe = player.id == myId;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.accent.withOpacity(0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMe ? AppColors.accent : AppColors.borderSubtle,
                  width: isMe ? 2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF050C27),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? AppColors.primary
                          : index == 1
                              ? const Color(0xFF8E9ECA)
                              : index == 2
                                  ? AppColors.secondary
                                  : AppColors.cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.rubik(
                          color: index <= 2 ? const Color(0xFF0B1124) : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PlayerAvatar(
                    nickname: player.nickname,
                    avatar: player.avatar,
                    size: 34,
                    score: null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.nickname,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunitoSans(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: isMe ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TÚ',
                              style: GoogleFonts.rubik(
                                color: const Color(0xFF0B1124),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '${player.score}',
                    style: GoogleFonts.rubik(
                      color: index == 0 ? AppColors.primary : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'PTS',
                    style: GoogleFonts.rubik(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCuadroDeHonor(List<Player> sorted) {
    final winnerName = sorted.isNotEmpty ? sorted[0].nickname : 'Cheo';
    final secondName = sorted.length > 1 ? sorted[1].nickname : 'El Pana';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'Cuadro de Honor Criollo',
                style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildHonorCard(
                icon: '🖌️',
                title: 'PINCEL DE ORO',
                subtitle: winnerName,
                desc: 'Mejor dibujo de la partida',
                color: AppColors.primary,
              ),
              _buildHonorCard(
                icon: '⚡',
                title: 'RAYO ADIVINADOR',
                subtitle: secondName,
                desc: 'Adivinó en menos de 5 seg',
                color: AppColors.accent,
              ),
              _buildHonorCard(
                icon: '🌶️',
                title: 'RACHA CRIOLLA',
                subtitle: winnerName,
                desc: 'Máximo puntaje alcanzado',
                color: AppColors.secondary,
              ),
              _buildHonorCard(
                icon: '🚗',
                title: 'CACHICAMO',
                subtitle: 'Todos los panas',
                desc: 'Pura sabrosura criolla',
                color: AppColors.correct,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHonorCard({
    required String icon,
    required String title,
    required String subtitle,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.rubik(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            desc,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Tactile Yellow Button
        GestureDetector(
          onTap: _playAgain,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFFC79100),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, color: Color(0xFF0B1124), size: 22),
                const SizedBox(width: 8),
                Text(
                  '¡REVANCHA / OTRA PARTIDA! ⚡',
                  style: GoogleFonts.rubik(
                    color: const Color(0xFF0B1124),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary Button
        GestureDetector(
          onTap: () => context.go('/'),
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            ),
            child: Center(
              child: Text(
                'Volver al inicio',
                style: GoogleFonts.rubik(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

