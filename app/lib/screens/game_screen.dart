import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../services/socket_service.dart';
import '../widgets/chat_message_widget.dart';
import '../widgets/player_avatar.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _guessCtrl = TextEditingController();
  final _chatScrollCtrl = ScrollController();
  bool _guessedCorrectly = false;

  @override
  void initState() {
    super.initState();
    // Navigate to results on turn end and game end
    SocketService().onTurnEnded.listen((_) {
      if (mounted) context.go('/results');
    });
    SocketService().onGameEnded.listen((_) {
      if (mounted) context.go('/results');
    });
    // Track if I guessed correctly
    SocketService().onCorrectGuess.listen((data) {
      final state = ref.read(gameProvider);
      if (state == null) return;
      if (data['playerId'] == state.myId) {
        setState(() => _guessedCorrectly = true);
      }
    });
    SocketService().onTurnStarted.listen((_) {
      setState(() => _guessedCorrectly = false);
    });
  }

  @override
  void dispose() {
    _guessCtrl.dispose();
    _chatScrollCtrl.dispose();
    super.dispose();
  }

  void _sendGuess() {
    final text = _guessCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(gameProvider.notifier).sendGuess(text);
    _guessCtrl.clear();
    // Auto-scroll chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollCtrl.hasClients) {
        _chatScrollCtrl.animateTo(
          _chatScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final isLandscape = MediaQuery.of(context).size.aspectRatio > 1;

    if (gameState == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(gameState: gameState),
            Expanded(
              child: isLandscape
                  ? _LandscapeLayout(
                      gameState: gameState,
                      guessCtrl: _guessCtrl,
                      chatScrollCtrl: _chatScrollCtrl,
                      guessedCorrectly: _guessedCorrectly,
                      onSendGuess: _sendGuess,
                    )
                  : _PortraitLayout(
                      gameState: gameState,
                      guessCtrl: _guessCtrl,
                      chatScrollCtrl: _chatScrollCtrl,
                      guessedCorrectly: _guessedCorrectly,
                      onSendGuess: _sendGuess,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// LAYOUTS
// ═══════════════════════════════════════════════════════════

class _PortraitLayout extends ConsumerWidget {
  const _PortraitLayout({
    required this.gameState,
    required this.guessCtrl,
    required this.chatScrollCtrl,
    required this.guessedCorrectly,
    required this.onSendGuess,
  });

  final GameState gameState;
  final TextEditingController guessCtrl;
  final ScrollController chatScrollCtrl;
  final bool guessedCorrectly;
  final VoidCallback onSendGuess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Canvas takes ~55% of the available height
        Expanded(
          flex: 55,
          child: DrawingCanvas(isDrawing: gameState.amIDrawing),
        ),
        if (gameState.amIDrawing) const DrawingToolbar(),
        // Chat takes the rest
        Expanded(
          flex: 45,
          child: ChatPanel(
            gameState: gameState,
            guessCtrl: guessCtrl,
            scrollCtrl: chatScrollCtrl,
            guessedCorrectly: guessedCorrectly,
            onSendGuess: onSendGuess,
          ),
        ),
      ],
    );
  }
}

class _LandscapeLayout extends ConsumerWidget {
  const _LandscapeLayout({
    required this.gameState,
    required this.guessCtrl,
    required this.chatScrollCtrl,
    required this.guessedCorrectly,
    required this.onSendGuess,
  });

  final GameState gameState;
  final TextEditingController guessCtrl;
  final ScrollController chatScrollCtrl;
  final bool guessedCorrectly;
  final VoidCallback onSendGuess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Canvas
        Expanded(
          flex: 60,
          child: Column(
            children: [
              Expanded(child: DrawingCanvas(isDrawing: gameState.amIDrawing)),
              if (gameState.amIDrawing) const DrawingToolbar(),
            ],
          ),
        ),
        // Chat panel
        SizedBox(
          width: 280,
          child: ChatPanel(
            gameState: gameState,
            guessCtrl: guessCtrl,
            scrollCtrl: chatScrollCtrl,
            guessedCorrectly: guessedCorrectly,
            onSendGuess: onSendGuess,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════════════════════

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.gameState});
  final GameState gameState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final timerColor = timer > 40
        ? AppColors.timerGreen
        : timer > 15
            ? AppColors.timerYellow
            : AppColors.timerRed;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Round info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Ronda ${gameState.currentRound}/${gameState.totalRounds}',
              style: GoogleFonts.nunito(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Word / hint area
          Expanded(child: _WordDisplay(gameState: gameState)),
          const SizedBox(width: 10),
          // Timer
          _TimerWidget(seconds: timer, color: timerColor),
        ],
      ),
    );
  }
}

class _WordDisplay extends StatelessWidget {
  const _WordDisplay({required this.gameState});
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    if (gameState.amIDrawing && gameState.currentWord != null) {
      return Column(
        children: [
          Text(
            '¡Dibuja esto!',
            style: GoogleFonts.nunito(color: Colors.white54, fontSize: 11),
          ),
          Text(
            gameState.currentWord!.toUpperCase(),
            style: GoogleFonts.nunito(
              color: AppColors.secondary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    final hint = gameState.wordHint;
    final len = gameState.wordLength;

    return Column(
      children: [
        Text(
          '${gameState.currentDrawerNickname} está dibujando',
          style: GoogleFonts.nunito(color: Colors.white54, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          hint ?? List.generate(len, (_) => '_ ').join().trim(),
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TimerWidget extends StatelessWidget {
  const _TimerWidget({required this.seconds, required this.color});
  final int seconds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color, width: 2.5),
      ),
      child: Center(
        child: Text(
          '$seconds',
          style: GoogleFonts.nunito(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// DRAWING CANVAS
// ═══════════════════════════════════════════════════════════

class DrawingCanvas extends ConsumerWidget {
  const DrawingCanvas({super.key, required this.isDrawing});
  final bool isDrawing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawState = ref.watch(drawingProvider);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isDrawing
            ? GestureDetector(
                onPanStart: (details) {
                  ref.read(drawingProvider.notifier).startStroke(
                        details.localPosition.dx,
                        details.localPosition.dy,
                      );
                },
                onPanUpdate: (details) {
                  ref.read(drawingProvider.notifier).addPoint(
                        details.localPosition.dx,
                        details.localPosition.dy,
                      );
                },
                onPanEnd: (_) {
                  ref.read(drawingProvider.notifier).endStroke();
                },
                child: CustomPaint(
                  painter: _CanvasPainter(
                    strokes: drawState.strokes,
                    activeStroke: drawState.activeStroke,
                  ),
                  child: const SizedBox.expand(),
                ),
              )
            : CustomPaint(
                painter: _CanvasPainter(
                  strokes: drawState.strokes,
                  activeStroke: drawState.activeStroke,
                ),
                child: const SizedBox.expand(),
              ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({required this.strokes, this.activeStroke});

  final List<Map<String, dynamic>> strokes;
  final Map<String, dynamic>? activeStroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!);
    }
  }

  void _paintStroke(Canvas canvas, Map<String, dynamic> stroke) {
    final rawPoints = stroke['points'] as List<dynamic>?;
    if (rawPoints == null || rawPoints.isEmpty) return;

    final isEraser = stroke['isEraser'] as bool? ?? false;
    final color = isEraser ? Colors.white : _hexToColor(stroke['color'] as String? ?? '#000000');
    final strokeWidth = (stroke['strokeWidth'] as num?)?.toDouble() ?? 4.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = isEraser ? BlendMode.src : BlendMode.srcOver;

    final points = rawPoints.map<Offset>((p) {
      final pm = p as Map<String, dynamic>;
      return Offset(
        (pm['x'] as num).toDouble(),
        (pm['y'] as num).toDouble(),
      );
    }).toList();

    if (points.length == 1) {
      canvas.drawCircle(points.first, strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      if (i < points.length - 1) {
        final mid = Offset(
          (points[i].dx + points[i + 1].dx) / 2,
          (points[i].dy + points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return Colors.black;
  }

  @override
  bool shouldRepaint(_CanvasPainter old) =>
      old.strokes != strokes || old.activeStroke != activeStroke;
}

// ═══════════════════════════════════════════════════════════
// DRAWING TOOLBAR
// ═══════════════════════════════════════════════════════════

class DrawingToolbar extends ConsumerStatefulWidget {
  const DrawingToolbar({super.key});

  @override
  ConsumerState<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends ConsumerState<DrawingToolbar> {
  int _selectedColorIndex = 0;
  int _selectedSizeIndex = 1; // 0=thin, 1=medium, 2=thick
  static const _sizes = [3.0, 6.0, 14.0];
  static const _sizeIcons = [Icons.remove, Icons.horizontal_rule, Icons.rectangle];

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(drawingProvider.notifier);
    final isEraser = ref.watch(drawingProvider).activeStroke == null &&
        ref.read(drawingProvider.notifier).isEraser;

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color palette row
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppColors.drawingColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (ctx, i) {
                final color = AppColors.drawingColors[i];
                final selected = _selectedColorIndex == i && !isEraser;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColorIndex = i);
                    notifier.setColor(
                      '#${color.value.toRadixString(16).substring(2).toUpperCase()}',
                    );
                    notifier.setEraser(false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: selected ? 34 : 28,
                    height: selected ? 34 : 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.white30,
                        width: selected ? 3 : 1,
                      ),
                      boxShadow: selected
                          ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)]
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Tools row: sizes + eraser + clear
          Row(
            children: [
              // Stroke sizes
              ...List.generate(_sizes.length, (i) {
                final selected = _selectedSizeIndex == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSizeIndex = i);
                    notifier.setStrokeWidth(_sizes[i]);
                    notifier.setEraser(false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent : AppColors.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppColors.accent : Colors.white12,
                      ),
                    ),
                    child: Icon(_sizeIcons[i], color: Colors.white, size: 18),
                  ),
                );
              }),
              // Eraser
              GestureDetector(
                onTap: () {
                  notifier.setEraser(true);
                  notifier.setStrokeWidth(18);
                },
                child: Consumer(builder: (_, ref2, __) {
                  final erasing = ref2.watch(drawingProvider.notifier).isEraser;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: erasing ? AppColors.primary : AppColors.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: erasing ? AppColors.primary : Colors.white12,
                      ),
                    ),
                    child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 18),
                  );
                }),
              ),
              const Spacer(),
              // Clear button
              GestureDetector(
                onTap: () {
                  ref.read(drawingProvider.notifier).clearAndNotifyServer();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.wrong.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.wrong.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: AppColors.wrong, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Borrar',
                        style: GoogleFonts.nunito(
                          color: AppColors.wrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CHAT PANEL
// ═══════════════════════════════════════════════════════════

class ChatPanel extends ConsumerWidget {
  const ChatPanel({
    super.key,
    required this.gameState,
    required this.guessCtrl,
    required this.scrollCtrl,
    required this.guessedCorrectly,
    required this.onSendGuess,
  });

  final GameState gameState;
  final TextEditingController guessCtrl;
  final ScrollController scrollCtrl;
  final bool guessedCorrectly;
  final VoidCallback onSendGuess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatProvider);
    final inputDisabled = gameState.amIDrawing || guessedCorrectly;

    // Auto-scroll to bottom when messages change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Player score strip
          _PlayerScoreStrip(players: gameState.sortedByScore, myId: gameState.myId),
          // Chat messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      '¡Empieza a adivinar, pana!',
                      style: GoogleFonts.nunito(color: Colors.white24),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) => ChatMessageWidget(message: messages[i]),
                  ),
          ),
          // Guess input
          _GuessInput(
            controller: guessCtrl,
            disabled: inputDisabled,
            guessedCorrectly: guessedCorrectly,
            isDrawing: gameState.amIDrawing,
            onSend: onSendGuess,
          ),
        ],
      ),
    );
  }
}

class _PlayerScoreStrip extends StatelessWidget {
  const _PlayerScoreStrip({required this.players, required this.myId});
  final List<dynamic> players;
  final String myId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: AppColors.cardColor,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: players.length,
        itemBuilder: (ctx, i) {
          final p = players[i];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PlayerAvatar(
              nickname: p.nickname,
              size: 36,
              score: p.score,
              isMe: p.id == myId,
              isDrawing: p.isDrawing,
              hasGuessed: p.hasGuessed,
            ),
          );
        },
      ),
    );
  }
}

class _GuessInput extends StatelessWidget {
  const _GuessInput({
    required this.controller,
    required this.disabled,
    required this.guessedCorrectly,
    required this.isDrawing,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool disabled;
  final bool guessedCorrectly;
  final bool isDrawing;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    String hintText;
    if (isDrawing) {
      hintText = '¡Estás dibujando!';
    } else if (guessedCorrectly) {
      hintText = VzlaMessages.youGuessedIt;
    } else {
      hintText = '¡Adivina la palabra, pana!';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !disabled,
              onSubmitted: (_) => onSend(),
              textInputAction: TextInputAction.send,
              style: GoogleFonts.nunito(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: guessedCorrectly ? AppColors.correct : Colors.white38,
                  fontSize: 13,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: AppColors.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: disabled ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: disabled ? Colors.white12 : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: disabled ? Colors.white24 : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
