import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/vzla_avatar.dart';
import '../providers/game_provider.dart';
import '../services/socket_service.dart';
import '../services/session_storage.dart';
import '../widgets/avatar_album_dialog.dart';

/// Redesigned LobbyScreen matching Google Stitch "Sala de Espera de Jugadores"
class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  StreamSubscription? _gameStartedSub;
  StreamSubscription? _turnStartedSub;
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  DateTime? _lastReadyClick;

  // Regional criollo tags for player slots
  final List<String> _criolloRegions = [
    'Caracas 🦜',
    'Maracay 🧀',
    'Valencia 🥛',
    'Barquisimeto 🍋',
    'Maracaibo ⚡',
    'Margarita 🏖️',
    'Mérida 🏔️',
    'Puerto La Cruz ⚓',
  ];

  @override
  void initState() {
    super.initState();
    // Navigate to game when game-started or turn-started fires
    _gameStartedSub = SocketService().onGameStarted.listen((_) {
      if (mounted) context.go('/game');
    });
    _turnStartedSub = SocketService().onTurnStarted.listen((_) {
      if (mounted) context.go('/game');
    });
    _checkSessionOrRedirect();
  }

  void _checkSessionOrRedirect() async {
    final current = ref.read(gameProvider);
    if (current != null) return;

    final session = await SessionStorage.getSession();
    if (session != null && mounted) {
      SocketService().reconnectPlayer(
        roomCode: session['roomCode']!,
        sessionToken: session['sessionToken']!,
      );
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && ref.read(gameProvider) == null) {
          context.go('/');
        }
      });
    } else {
      if (mounted) context.go('/');
    }
  }

  @override
  void dispose() {
    _gameStartedSub?.cancel();
    _turnStartedSub?.cancel();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _toggleReady() {
    final now = DateTime.now();
    if (_lastReadyClick != null && now.difference(_lastReadyClick!).inMilliseconds < 400) {
      return;
    }
    _lastReadyClick = now;
    ref.read(gameProvider.notifier).setReady();
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF050C27), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.rubik(
                  color: const Color(0xFF050C27),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyRoomCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    _showToast('¡Código #$code copiado! 📋');
  }

  void _copyRoomLink(String code) {
    final link = 'https://rhojer.github.io/juego-pintar-multiplataforma/#/?code=$code';
    Clipboard.setData(ClipboardData(text: link));
    _showToast('¡Enlace de sala copiado! 🔗');
  }

  void _shareWhatsApp(String code) {
    final link = 'https://rhojer.github.io/juego-pintar-multiplataforma/#/?code=$code';
    final text = '¡Pana, únete a la partida de Rayando! Entra con el código $code aquí: $link 🎨🇻🇪';
    Clipboard.setData(ClipboardData(text: text));
    _showToast('¡Mensaje de WhatsApp copiado para tus panas! 📲');
  }

  void _sendChatMessage() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    ref.read(gameProvider.notifier).sendGuess(text);
  }

  void _showQRModal(String code) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => _QRDialog(
        code: code,
        onCopyLink: () => _copyRoomLink(code),
      ),
    );
  }

  void _confirmLeaveRoom() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.borderSubtle, width: 2),
        ),
        title: Text(
          '¿Abandonar la sala? 🚪',
          style: GoogleFonts.rubik(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Si sales de la sala tendrás que volver a unirte con el código.',
          style: GoogleFonts.nunitoSans(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Quedarme',
              style: GoogleFonts.rubik(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              SocketService().disconnect();
              context.go('/');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.wrong,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Salir',
              style: GoogleFonts.rubik(color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState?>(gameProvider, (prev, next) {
      if (next?.status == GameStatus.playing && mounted) {
        context.go('/game');
      }
    });

    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Conectando a la sala...',
                style: GoogleFonts.nunitoSans(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  SessionStorage.clearSession();
                  context.go('/');
                },
                child: Text(
                  'Volver al inicio',
                  style: GoogleFonts.rubik(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final me = gameState.me;
    final players = gameState.players;
    final readyCount = players.where((p) => p.isReady).length;
    final isHost = players.isNotEmpty && players.first.id == gameState.myId;
    final enoughPlayers = players.length >= AppConstants.minPlayers;
    final allReady = players.isNotEmpty && players.every((p) => p.isReady);
    final readyPercentage = players.isEmpty ? 0 : ((readyCount / players.length) * 100).toInt();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.4,
            colors: [
              Color(0xFF131A35),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  // 1. Sticky Top Navigation Bar
                  _buildTopBar(gameState),

                  // 2. Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Hero Banner & Progress
                          _buildHeroBanner(
                            isPrivate: gameState.isPrivate,
                            connected: players.length,
                            readyCount: readyCount,
                            readyPercentage: readyPercentage,
                            enoughPlayers: enoughPlayers,
                            allReady: allReady,
                          ),
                          const SizedBox(height: 14),

                          // Room Invitation & Share Card
                          _buildInvitationCard(gameState.roomCode),
                          const SizedBox(height: 16),

                          // 8-Slots Interactive Player Roster (Grid Bento)
                          _buildPlayerRosterSection(
                            players: players,
                            myId: gameState.myId,
                            roomCode: gameState.roomCode,
                          ),
                          const SizedBox(height: 16),

                          // Game Rules Summary
                          _buildGameRulesCard(gameState),
                          const SizedBox(height: 16),

                          // Lobby Fast-Chat (Cháchara de la Sala)
                          _buildLobbyChatCard(),
                          const SizedBox(height: 100), // Space for sticky bottom CTA
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Sticky Bottom CTA Dock
      bottomSheet: _buildStickyBottomDock(
        me: me,
        isHost: isHost,
        enoughPlayers: enoughPlayers,
        allReady: allReady,
        roomCode: gameState.roomCode,
      ),
    );
  }

  // ────────────────────────── 1. Top Navigation Bar ──────────────────────────
  Widget _buildTopBar(GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 2)),
        boxShadow: [
          BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          // Brand Logo
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0xFF6D5100), offset: Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.brush_rounded, color: Color(0xFF050C27), size: 18),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RAYANDO',
                style: GoogleFonts.rubik(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 0.5,
                  height: 1,
                ),
              ),
              Text(
                '¡EDICIÓN CRIOLLA! 🇻🇪',
                style: GoogleFonts.rubik(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Room Code Pill Badge with copy action
          InkWell(
            onTap: () => _copyRoomCode(gameState.roomCode),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '#${gameState.roomCode}',
                    style: GoogleFonts.rubik(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Exit / Salir button
          InkWell(
            onTap: _confirmLeaveRoom,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFD73B00),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF862200), offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Salir',
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 2. Hero Banner & Progress ──────────────────────
  Widget _buildHeroBanner({
    required bool isPrivate,
    required int connected,
    required int readyCount,
    required int readyPercentage,
    required bool enoughPlayers,
    required bool allReady,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSubtle, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPrivate ? 'SALA PRIVADA DE PANAS' : 'SALA PÚBLICA DE PANAS',
                      style: GoogleFonts.rubik(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFD73B00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isPrivate ? 'Privada 🔥' : 'En Vivo ⚡',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'ESPERANDO POR EL ZAPEROCO...',
                  style: GoogleFonts.rubik(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    height: 1.1,
                  ),
                ),
              ),
              const Text('🎨', style: TextStyle(fontSize: 26)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Invita a tus panas o comparte el código para arrancar la partida criolla.',
            style: GoogleFonts.nunitoSans(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Progress Track Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_rounded, color: AppColors.accent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$connected de 8 Panas Conectados',
                          style: GoogleFonts.rubik(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      allReady && enoughPlayers ? '¡TODOS LISTOS! 🎉' : '$readyPercentage% LISTOS',
                      style: GoogleFonts.rubik(
                        color: allReady && enoughPlayers ? AppColors.correct : AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Custom Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 10,
                    color: AppColors.surface,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (connected / AppConstants.maxPlayers).clamp(0.05, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.accent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mínimo ${AppConstants.minPlayers} para jugar',
                      style: GoogleFonts.nunitoSans(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Máximo 8 panas',
                      style: GoogleFonts.nunitoSans(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 3. Invitation Card ──────────────────────────────
  Widget _buildInvitationCard(String code) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;

        final codeSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CÓDIGO DE ENTRADA',
              style: GoogleFonts.rubik(
                color: AppColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _copyRoomCode(code),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          code,
                          style: GoogleFonts.rubik(
                            color: AppColors.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // QR Modal Trigger
                InkWell(
                  onTap: () => _showQRModal(code),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ],
        );

        final shareButton = Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0xFFC79100), offset: Offset(0, 4)),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => _shareWhatsApp(code),
            icon: const Icon(Icons.share_rounded, color: Color(0xFF050C27), size: 18),
            label: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMPARTIR',
                  style: GoogleFonts.rubik(
                    color: const Color(0xFF050C27),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'WhatsApp 📲',
                  style: GoogleFonts.rubik(
                    color: const Color(0xFF050C27),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        );

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 4)),
            ],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    codeSection,
                    const SizedBox(height: 12),
                    shareButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: codeSection),
                    const SizedBox(width: 10),
                    Expanded(child: shareButton),
                  ],
                ),
        );
      },
    );
  }

  // ────────────────────────── 4. Player Roster (Grid Bento) ───────────────────
  Widget _buildPlayerRosterSection({
    required List<Player> players,
    required String myId,
    required String roomCode,
  }) {
    final isNarrow = MediaQuery.of(context).size.width < 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.diversity_3_rounded, color: AppColors.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  'SLOTS DE PANAS (${players.length}/8)',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            Text(
              'Tap para ver álbum',
              style: GoogleFonts.nunitoSans(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: isNarrow ? 1.48 : 1.85,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: AppConstants.maxPlayers,
          itemBuilder: (ctx, index) {
            if (index < players.length) {
              final player = players[index];
              final isMe = player.id == myId;
              final isHost = index == 0;
              final region = _criolloRegions[index % _criolloRegions.length];

              return _buildFilledSlotCard(
                player: player,
                isMe: isMe,
                isHost: isHost,
                region: region,
                level: (index * 7 + 12) % 45 + 5,
              );
            }
            return _buildEmptySlotCard(index, roomCode);
          },
        ),
      ],
    );
  }

  Widget _buildFilledSlotCard({
    required Player player,
    required bool isMe,
    required bool isHost,
    required String region,
    required int level,
  }) {
    final avatarObj = VzlaAvatars.getById(player.avatar);

    return InkWell(
      onTap: () {
        if (isMe) {
          AvatarAlbumDialog.show(
            context,
            currentAvatarId: player.avatar ?? 'arepa',
            onAvatarSelected: (newId) {
              SessionStorage.saveAvatar(newId);
            },
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe
                ? AppColors.primary
                : player.isReady
                    ? AppColors.correct
                    : AppColors.borderSubtle,
            width: isMe ? 2.5 : 1.5,
          ),
          boxShadow: [
            const BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 3)),
            if (isMe)
              BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Avatar with ready check badge
                Stack(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isMe ? AppColors.primary : AppColors.accent,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          avatarObj.assetPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(avatarObj.emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      right: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: player.isReady ? AppColors.correct : const Color(0xFF555E7C),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.cardColor, width: 1.5),
                        ),
                        child: Icon(
                          player.isReady ? Icons.check : Icons.hourglass_empty,
                          size: 8,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.nickname + (isMe ? ' (Tú)' : ''),
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isHost) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '👑 Host',
                                style: GoogleFonts.rubik(
                                  color: const Color(0xFF050C27),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        player.isReady ? '¡LISTO! ✅' : 'ESPERANDO... ⏳',
                        style: GoogleFonts.rubik(
                          color: player.isReady ? AppColors.correct : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Footer with Region and Level
            Container(
              padding: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF293664), width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isHost ? 'Anfitrión 👑' : region,
                    style: GoogleFonts.nunitoSans(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Niv. $level',
                    style: GoogleFonts.rubik(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
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

  Widget _buildEmptySlotCard(int index, String roomCode) {
    return InkWell(
      onTap: () => _shareWhatsApp(roomCode),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accent.withOpacity(0.35),
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, color: AppColors.accent, size: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Invitar pana +',
              style: GoogleFonts.rubik(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Slot ${index + 1} Libre',
              style: GoogleFonts.nunitoSans(
                color: AppColors.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── 5. Game Rules Card ──────────────────────────────
  Widget _buildGameRulesCard(GameState gameState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'REGLAS DE LA PARTIDA',
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  'Ajustes de Host 🔒',
                  style: GoogleFonts.rubik(
                    color: AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildRuleItem(
                  icon: Icons.replay_rounded,
                  iconColor: AppColors.accent,
                  title: '${gameState.totalRounds} Rondas',
                  subtitle: 'Totales',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRuleItem(
                  icon: Icons.timer_rounded,
                  iconColor: AppColors.primary,
                  title: '${AppConstants.roundTime} Segundos',
                  subtitle: 'Por dibujo',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRuleItem(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: AppColors.secondary,
                  title: 'Ronda Loca',
                  subtitle: 'Activada 💥',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Text('🫓', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: 'Diccionario: ',
                      style: GoogleFonts.nunitoSans(color: Colors.white70, fontSize: 11),
                      children: [
                        TextSpan(
                          text: 'Chucherías, Jerga y Comida Criolla',
                          style: GoogleFonts.rubik(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: GoogleFonts.rubik(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.nunitoSans(
              color: AppColors.textMuted,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 6. Lobby Fast-Chat ─────────────────────────────
  Widget _buildLobbyChatCard() {
    final chatMessages = ref.watch(chatProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'CHÁCHARA DE LA SALA',
                    style: GoogleFonts.rubik(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                'En vivo 🟢',
                style: GoogleFonts.nunitoSans(
                  color: AppColors.correct,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Chat messages container
          Container(
            height: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: chatMessages.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¡Saluda a tus panas antes de arrancar la partida!',
                        style: GoogleFonts.nunitoSans(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: chatMessages.length,
                    itemBuilder: (ctx, i) {
                      final msg = chatMessages[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${msg.nickname}: ',
                              style: GoogleFonts.rubik(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                msg.text,
                                style: GoogleFonts.nunitoSans(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          // Input pill
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: TextField(
                    controller: _chatCtrl,
                    style: GoogleFonts.nunitoSans(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Manda un recado al grupo...',
                      hintStyle: GoogleFonts.nunitoSans(color: AppColors.textMuted, fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendChatMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _sendChatMessage,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF005E6A), offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded, color: Color(0xFF050C27), size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ────────────────────────── 7. Sticky Bottom CTA Dock ───────────────────────
  Widget _buildStickyBottomDock({
    required Player? me,
    required bool isHost,
    required bool enoughPlayers,
    required bool allReady,
    required String roomCode,
  }) {
    final isReady = me?.isReady ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderSubtle, width: 2)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, offset: Offset(0, -6), blurRadius: 16),
        ],
      ),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primary Action Button (Tactile 3D Neo-Pop)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isHost && allReady && enoughPlayers
                            ? const Color(0xFFC79100)
                            : isReady
                                ? const Color(0xFF862200)
                                : const Color(0xFFC79100),
                        offset: const Offset(0, 5),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      if (isHost && allReady && enoughPlayers) {
                        _toggleReady();
                      } else {
                        _toggleReady();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isHost && allReady && enoughPlayers
                          ? AppColors.primary
                          : isReady
                              ? const Color(0xFFD73B00)
                              : AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isHost && allReady && enoughPlayers
                              ? Icons.rocket_launch_rounded
                              : isReady
                                  ? Icons.close_rounded
                                  : Icons.bolt_rounded,
                          color: isReady && !(isHost && allReady && enoughPlayers)
                              ? Colors.white
                              : const Color(0xFF050C27),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isHost && allReady && enoughPlayers
                              ? '¡ARRANCAR PARTIDA! 🚀'
                              : isReady
                                  ? 'CANCELAR LISTO ✕'
                                  : '¡ESTOY LISTO! ⚡',
                          style: GoogleFonts.rubik(
                            color: isReady && !(isHost && allReady && enoughPlayers)
                                ? Colors.white
                                : const Color(0xFF050C27),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary actions: WhatsApp + Direct Link Copy
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareWhatsApp(roomCode),
                      icon: const Icon(Icons.share_rounded, size: 16, color: AppColors.accent),
                      label: Text(
                        'Invitar por WhatsApp',
                        style: GoogleFonts.rubik(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSubtle),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => _copyRoomLink(roomCode),
                    icon: const Icon(Icons.link_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      'Copiar link',
                      style: GoogleFonts.rubik(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────── QR Code Dialog ───────────────────────────────────
class _QRDialog extends StatelessWidget {
  const _QRDialog({required this.code, required this.onCopyLink});

  final String code;
  final VoidCallback onCopyLink;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.primary, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 10)),
            BoxShadow(color: Colors.black54, blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Text(
                  'ESCANEA Y ÚNETE',
                  style: GoogleFonts.rubik(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Apunta la cámara de tu celular para entrar de una a la sala de Rayando.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunitoSans(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Simulated Stylized QR Card with Venezuelan Arepa Center
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: _QRCodePainter(),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF050C27), width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 6),
                      ],
                    ),
                    child: const Center(
                      child: Text('🫓', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Code Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                'CÓDIGO: #$code',
                style: GoogleFonts.rubik(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Close & Copy Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Cerrar', style: GoogleFonts.rubik(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onCopyLink();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Copiar link',
                      style: GoogleFonts.rubik(color: const Color(0xFF050C27), fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QRCodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF050C27)
      ..style = PaintingStyle.fill;

    // Corner Finder Patterns
    _drawFinderPattern(canvas, 10, 10, 45, paint);
    _drawFinderPattern(canvas, size.width - 55, 10, 45, paint);
    _drawFinderPattern(canvas, 10, size.height - 55, 45, paint);

    // Decorative modules
    final randomOffsets = [
      const Offset(70, 20), const Offset(85, 20), const Offset(100, 20),
      const Offset(70, 35), const Offset(95, 35),
      const Offset(20, 70), const Offset(35, 70), const Offset(20, 85),
      const Offset(70, 70), const Offset(100, 85), const Offset(115, 70),
      const Offset(130, 20), const Offset(145, 35), const Offset(130, 50),
      const Offset(70, 130), const Offset(85, 145), const Offset(70, 160),
      const Offset(130, 130), const Offset(145, 145), const Offset(160, 130),
      const Offset(130, 100), const Offset(145, 85), const Offset(160, 100),
      const Offset(130, 160), const Offset(150, 160),
    ];

    for (final off in randomOffsets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(off.dx, off.dy, 10, 10), const Radius.circular(2.5)),
        paint,
      );
    }
  }

  void _drawFinderPattern(Canvas canvas, double x, double y, double size, Paint paint) {
    // Outer square
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, size, size), const Radius.circular(8)),
      paint,
    );
    // Inner white
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 7, y + 7, size - 14, size - 14), const Radius.circular(6)),
      whitePaint,
    );
    // Center dot
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 14, y + 14, size - 28, size - 28), const Radius.circular(4)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
