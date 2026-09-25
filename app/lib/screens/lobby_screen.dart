import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import '../services/socket_service.dart';
import '../widgets/player_avatar.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to game when it starts
    SocketService().onGameStarted.listen((_) {
      if (mounted) context.go('/game');
    });
  }

  void _toggleReady() {
    ref.read(gameProvider.notifier).setReady();
  }

  void _copyRoomCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Código copiado al portapapeles, pana! 📋',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppColors.correct,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final me = gameState.me;
    final allReady = gameState.players.isNotEmpty &&
        gameState.players.every((p) => p.isReady);
    final readyCount = gameState.players.where((p) => p.isReady).length;
    final enoughPlayers = gameState.players.length >= AppConstants.minPlayers;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Color(0xFF0D1B3E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(gameState),
              if (gameState.isPrivate) _buildRoomCode(gameState.roomCode),
              _buildStatusBar(readyCount, gameState.players.length, allReady, enoughPlayers),
              Expanded(child: _buildPlayerGrid(gameState.players, gameState.myId)),
              _buildReadyButton(me),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameState gameState) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70),
            onPressed: () {
              SocketService().disconnect();
              context.go('/');
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sala de Espera',
                  style: GoogleFonts.nunito(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${gameState.players.length}/${AppConstants.maxPlayers} jugadores conectados',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          const Text('🎨', style: TextStyle(fontSize: 32)),
        ],
      ),
    );
  }

  Widget _buildRoomCode(String code) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Código de sala privada',
                  style: GoogleFonts.nunito(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  code,
                  style: GoogleFonts.nunito(
                    color: AppColors.secondary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.secondary),
            tooltip: 'Copiar código',
            onPressed: () => _copyRoomCode(code),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(int ready, int total, bool allReady, bool enough) {
    String message;
    Color color;

    if (!enough) {
      message = 'Se necesitan al menos ${AppConstants.minPlayers} jugadores';
      color = AppColors.warning;
    } else if (allReady) {
      message = VzlaMessages.allReady;
      color = AppColors.correct;
    } else {
      message = '$ready/$total listos — ${VzlaMessages.waitingPlayers}';
      color = AppColors.accent;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            allReady && enough ? Icons.celebration_rounded : Icons.hourglass_top_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: GoogleFonts.nunito(color: color, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerGrid(List<Player> players, String myId) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: AppConstants.maxPlayers,
      itemBuilder: (ctx, index) {
        if (index < players.length) {
          return _PlayerCard(player: players[index], isMe: players[index].id == myId);
        }
        return _EmptySlot(index: index);
      },
    );
  }

  Widget _buildReadyButton(Player? me) {
    final isReady = me?.isReady ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: ElevatedButton.icon(
            onPressed: _toggleReady,
            icon: Icon(isReady ? Icons.close_rounded : Icons.check_rounded, size: 24),
            label: Text(
              isReady ? 'Cancelar' : '¡Estoy listo!',
              style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isReady ? AppColors.wrong : AppColors.correct,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────── Player Card ───────────────────

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player, required this.isMe});
  final Player player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: player.isReady
            ? AppColors.correct.withOpacity(0.15)
            : AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppColors.secondary
              : player.isReady
                  ? AppColors.correct
                  : Colors.white12,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            PlayerAvatar(
              nickname: player.nickname,
              size: 36,
              score: null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.nickname + (isMe ? ' (tú)' : ''),
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    player.isReady ? '✅ Listo' : '⏳ Esperando...',
                    style: TextStyle(
                      color: player.isReady ? AppColors.correct : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: const Center(
        child: Icon(Icons.person_add_outlined, color: Colors.white12, size: 24),
      ),
    );
  }
}
