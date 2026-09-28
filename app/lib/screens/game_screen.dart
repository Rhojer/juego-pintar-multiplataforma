import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../services/socket_service.dart';
import '../services/session_storage.dart';
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
    // Navigate to final results ONLY when the whole game ends (all rounds completed)
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
      if (mounted) {
        setState(() => _guessedCorrectly = false);
      }
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
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.secondary),
              const SizedBox(height: 16),
              Text(
                'Reconectando a la partida...',
                style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  SessionStorage.clearSession();
                  context.go('/');
                },
                child: Text(
                  'Volver al inicio',
                  style: GoogleFonts.nunito(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final showWordChoices = gameState.amIDrawing &&
        gameState.isChoosingWord &&
        gameState.offeredWords != null &&
        gameState.offeredWords!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
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
            // 1. In-place Word Selection Overlay for the drawer (cannot be missed)
            if (showWordChoices)
              _WordSelectionOverlay(
                words: gameState.offeredWords!,
                onWordChosen: (chosenWord) {
                  ref.read(gameProvider.notifier).chooseWord(chosenWord);
                },
              ),
            // 2. Minimalist blurred scoreboard overlay at turn end
            if (gameState.showTurnEndOverlay)
              _TurnEndScoreboardOverlay(gameState: gameState),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          // Room code badge (tap to copy)
          if (gameState.roomCode.isNotEmpty)
            Tooltip(
              message: 'Toca para copiar código',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: gameState.roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('¡Código ${gameState.roomCode} copiado! Compártelo con tus panas.'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withOpacity(0.7), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy_rounded, color: AppColors.primary, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        gameState.roomCode,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Round info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Ronda ${gameState.currentRound}/${gameState.totalRounds}',
              style: GoogleFonts.nunito(
                color: AppColors.secondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Word / hint area
          Expanded(child: _WordDisplay(gameState: gameState)),
          const SizedBox(width: 8),
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
    // 1. Drawer is choosing words
    if (gameState.isChoosingWord) {
      if (gameState.amIDrawing) {
        return Column(
          children: [
            Text(
              '¡Te toca dibujar!',
              style: GoogleFonts.nunito(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Text(
              'ELIGE TU PALABRA',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      } else {
        return Column(
          children: [
            Text(
              'Turno de ${gameState.currentDrawerNickname}',
              style: GoogleFonts.nunito(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Eligiendo palabra...',
              style: GoogleFonts.nunito(
                color: AppColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      }
    }

    // 2. Normal drawing phase: drawer sees full word
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

    // 3. Guesser sees hint / dashes
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

class _WordSelectionDialog extends ConsumerWidget {
  const _WordSelectionDialog({
    required this.words,
    required this.onWordChosen,
  });

  final List<String> words;
  final ValueChanged<String> onWordChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.palette_rounded, color: AppColors.secondary, size: 26),
                const SizedBox(width: 8),
                Text(
                  '¡Te toca dibujar!',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Escoge una palabra antes de que se acabe el tiempo ($timer s):',
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ...words.map((word) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.secondary, width: 1.5),
                      ),
                    ),
                    onPressed: () => onWordChosen(word),
                    child: Text(
                      word.toUpperCase(),
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
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

  static const double virtualWidth = 800.0;
  static const double virtualHeight = 600.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawState = ref.watch(drawingProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasW = constraints.maxWidth;
                  final canvasH = constraints.maxHeight;

                  Widget canvasWidget = CustomPaint(
                    painter: _CanvasPainter(
                      strokes: drawState.strokes,
                      activeStroke: drawState.activeStroke,
                    ),
                    child: const SizedBox.expand(),
                  );

                  if (isDrawing) {
                    canvasWidget = GestureDetector(
                      onPanStart: (details) {
                        if (canvasW <= 0 || canvasH <= 0) return;
                        final vx = (details.localPosition.dx * (virtualWidth / canvasW)).clamp(0.0, virtualWidth);
                        final vy = (details.localPosition.dy * (virtualHeight / canvasH)).clamp(0.0, virtualHeight);
                        ref.read(drawingProvider.notifier).startStroke(vx, vy);
                      },
                      onPanUpdate: (details) {
                        if (canvasW <= 0 || canvasH <= 0) return;
                        final vx = (details.localPosition.dx * (virtualWidth / canvasW)).clamp(0.0, virtualWidth);
                        final vy = (details.localPosition.dy * (virtualHeight / canvasH)).clamp(0.0, virtualHeight);
                        ref.read(drawingProvider.notifier).addPoint(vx, vy);
                      },
                      onPanEnd: (_) {
                        ref.read(drawingProvider.notifier).endStroke();
                      },
                      child: canvasWidget,
                    );
                  }

                  return canvasWidget;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({required this.strokes, this.activeStroke});

  final List<Map<String, dynamic>> strokes;
  final Map<String, dynamic>? activeStroke;

  static const double virtualWidth = 800.0;
  static const double virtualHeight = 600.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.scale(size.width / virtualWidth, size.height / virtualHeight);

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, virtualWidth, virtualHeight),
      Paint()..color = Colors.white,
    );
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!);
    }
    canvas.restore();
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
  static const _sizes = [4.0, 8.0, 16.0];
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
                    notifier.setStrokeWidth(_sizes[_selectedSizeIndex]);
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
                  notifier.setStrokeWidth(24.0);
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
              avatar: p.avatar,
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

// ═══════════════════════════════════════════════════════════
// OVERLAYS (Word selection & Turn end scoreboard)
// ═══════════════════════════════════════════════════════════

class _WordSelectionOverlay extends ConsumerWidget {
  const _WordSelectionOverlay({
    required this.words,
    required this.onWordChosen,
  });

  final List<String> words;
  final ValueChanged<String> onWordChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);

    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.black.withOpacity(0.75),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: AppColors.surface,
                elevation: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.secondary, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.brush_rounded, color: AppColors.secondary, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            '¡Te toca dibujar!',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Elige una palabra antes de que se acabe el tiempo ($timer s):',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...words.map(
                        (word) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cardColor,
                                foregroundColor: Colors.white,
                                elevation: 4,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Colors.white24,
                                    width: 1,
                                  ),
                                ),
                              ),
                              onPressed: () => onWordChosen(word),
                              child: Text(
                                word.toUpperCase(),
                                style: GoogleFonts.nunito(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TurnEndScoreboardOverlay extends StatelessWidget {
  const _TurnEndScoreboardOverlay({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final sortedPlayers = [...gameState.players]
      ..sort((a, b) => b.score.compareTo(a.score));

    final revealedWord = gameState.currentWord?.trim();

    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.black.withOpacity(0.7),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                color: AppColors.surface,
                elevation: 20,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Round badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          'Ronda ${gameState.currentRound} de ${gameState.totalRounds}',
                          style: GoogleFonts.nunito(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '¡Fin del turno!',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (revealedWord != null && revealedWord.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'La palabra era: ',
                              style: GoogleFonts.nunito(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.secondary),
                              ),
                              child: Text(
                                revealedWord.toUpperCase(),
                                style: GoogleFonts.nunito(
                                  color: AppColors.secondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 12),
                      // Minimalist player list sorted by points
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedPlayers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final player = sortedPlayers[index];
                          final isMe = player.id == gameState.myId;
                          final pointsGained = player.pointsGained;

                          String rankBadge;
                          if (index == 0) {
                            rankBadge = '🥇';
                          } else if (index == 1) {
                            rankBadge = '🥈';
                          } else if (index == 2) {
                            rankBadge = '🥉';
                          } else {
                            rankBadge = '${index + 1}°';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.cardColor : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isMe ? AppColors.accent.withOpacity(0.5) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    rankBadge,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          player.nickname,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.nunito(
                                            color: Colors.white,
                                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          '(tú)',
                                          style: GoogleFonts.nunito(
                                            color: AppColors.secondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (pointsGained > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.correct.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.correct.withOpacity(0.6)),
                                    ),
                                    child: Text(
                                      '+$pointsGained pts',
                                      style: GoogleFonts.nunito(
                                        color: AppColors.correct,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                Text(
                                  '${player.score} pts',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      // Waiting for next turn status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Siguiente turno en breve...',
                            style: GoogleFonts.nunito(
                              color: Colors.white60,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

