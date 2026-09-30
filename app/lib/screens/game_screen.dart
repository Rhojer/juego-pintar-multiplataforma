import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/game_state.dart';
import '../models/special_mode.dart';
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
                wordDetails: gameState.offeredWordDetails,
                specialMode: gameState.specialMode,
                onWordChosen: (chosenWord) {
                  ref.read(gameProvider.notifier).chooseWord(chosenWord);
                },
              ),
            // 2. Minimalist blurred scoreboard overlay at turn end
            if (gameState.showTurnEndOverlay)
              _TurnEndScoreboardOverlay(gameState: gameState),
            // 3. Special Mode Announcement Banner Overlay
            if (gameState.specialMode != null && !gameState.showTurnEndOverlay)
              _SpecialModeBannerOverlay(
                specialMode: gameState.specialMode!,
                isDrawer: gameState.amIDrawing,
                drawerNickname: gameState.currentDrawerNickname,
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
    final timerColor = timer > 30
        ? AppColors.timerGreen
        : timer > 15
            ? AppColors.timerYellow
            : AppColors.timerRed;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF050C27),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Logo Rayando con estilo arcade
          Text(
            'RAYANDO',
            style: GoogleFonts.rubik(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 10),
          // Room code badge (tap to copy)
          if (gameState.roomCode.isNotEmpty)
            Tooltip(
              message: 'Toca para copiar código',
              child: InkWell(
                borderRadius: BorderRadius.circular(9999),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: gameState.roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Código copiado! Pásaselo a tus panas.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: AppColors.borderSubtle, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'SALA: ',
                        style: GoogleFonts.rubik(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        gameState.roomCode,
                        style: GoogleFonts.rubik(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy_rounded, color: AppColors.accent, size: 12),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Round info pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cardColor,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.borderSubtle, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, size: 12, color: AppColors.secondary),
                const SizedBox(width: 4),
                Text(
                  'Ronda ${gameState.currentRound}/${gameState.totalRounds}',
                  style: GoogleFonts.rubik(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (gameState.specialMode != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: gameState.specialMode!.badgeColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: gameState.specialMode!.badgeColor, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: gameState.specialMode!.badgeColor.withOpacity(0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(gameState.specialMode!.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    gameState.specialMode!.name.toUpperCase(),
                    style: GoogleFonts.rubik(
                      color: gameState.specialMode!.badgeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 12),
          // Word / hint area
          Expanded(child: _WordDisplay(gameState: gameState)),
          const SizedBox(width: 10),
          // Radial Circular Timer
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
    final mode = gameState.specialMode;

    // 1. Drawer is choosing words
    if (gameState.isChoosingWord) {
      if (gameState.amIDrawing) {
        return Column(
          children: [
            Text(
              mode != null ? '${mode.emoji} ¡${mode.name.toUpperCase()}!' : '¡Te toca dibujar!',
              style: GoogleFonts.nunito(
                color: mode != null ? mode.badgeColor : AppColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
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
              mode != null
                  ? '${mode.emoji} Turno de ${gameState.currentDrawerNickname} (${mode.name})'
                  : 'Turno de ${gameState.currentDrawerNickname}',
              style: GoogleFonts.nunito(color: Colors.white54, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Eligiendo palabra...',
              style: GoogleFonts.nunito(
                color: mode != null ? mode.badgeColor : AppColors.secondary,
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
      final showOriginal = mode != null &&
          gameState.originalWord != null &&
          gameState.originalWord!.toLowerCase() != gameState.currentWord!.toLowerCase();

      return Column(
        children: [
          Text(
            mode != null
                ? '${mode.emoji} ¡Dibuja en ${mode.name}!'
                : '¡Dibuja esto!',
            style: GoogleFonts.nunito(
              color: mode != null ? mode.badgeColor : Colors.white54,
              fontSize: 11,
              fontWeight: mode != null ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            gameState.currentWord!.toUpperCase(),
            style: GoogleFonts.nunito(
              color: mode != null ? mode.badgeColor : AppColors.secondary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          if (showOriginal)
            Text(
              '(Dibujas: ${gameState.originalWord!.toUpperCase()})',
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
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
          mode != null
              ? '${mode.emoji} ${gameState.currentDrawerNickname} dibuja (${mode.name})'
              : '${gameState.currentDrawerNickname} está dibujando',
          style: GoogleFonts.nunito(
            color: mode != null ? mode.badgeColor : Colors.white54,
            fontSize: 11,
            fontWeight: mode != null ? FontWeight.w700 : FontWeight.normal,
          ),
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
    // Normalizing between 0 and 80s
    final progress = (seconds / 80.0).clamp(0.0, 1.0);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            backgroundColor: AppColors.cardColor,
            color: color,
            strokeWidth: 3.5,
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$seconds',
                style: GoogleFonts.rubik(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.cardColor, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF050C27),
                  offset: Offset(0, 6),
                  blurRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                children: [
                  LayoutBuilder(
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
                  if (!isDrawing)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141B36).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          'Sólo lectura',
                          style: GoogleFonts.nunitoSans(
                            color: Colors.black45,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 6,
                    left: 10,
                    child: Text(
                      '✏️ Rayando Canvas v2.0',
                      style: GoogleFonts.nunitoSans(
                        color: Colors.black26,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
  int _selectedColorIndex = 4; // Default to Yellow (#FFC107)
  int _selectedSizeIndex = 1; // 0=thin, 1=medium, 2=thick
  static const _sizes = [4.0, 8.0, 16.0];
  static const _sizeDotRadii = [3.0, 5.5, 9.0];

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(drawingProvider.notifier);
    final isEraser = ref.watch(drawingProvider).activeStroke == null &&
        ref.read(drawingProvider.notifier).isEraser;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF050C27),
            offset: Offset(0, -3),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Color palette row
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: AppColors.drawingColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final color = AppColors.drawingColors[i];
                final selected = _selectedColorIndex == i && !isEraser;
                return Center(
                  child: GestureDetector(
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
                      width: selected ? 36 : 28,
                      height: selected ? 36 : 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: selected ? 3.5 : 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.7),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // 2. Tools row: sizes + eraser + clear
          Row(
            children: [
              Text(
                'GROSOR:',
                style: GoogleFonts.rubik(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              // Stroke sizes
              ...List.generate(_sizes.length, (i) {
                final selected = _selectedSizeIndex == i && !isEraser;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSizeIndex = i);
                    notifier.setStrokeWidth(_sizes[i]);
                    notifier.setEraser(false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.borderSubtle,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: selected ? const Color(0xFFC79100) : const Color(0xFF050C27),
                          offset: const Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: _sizeDotRadii[i] * 2,
                        height: _sizeDotRadii[i] * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? const Color(0xFF0B1124) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: erasing ? AppColors.primary : AppColors.cardColor,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: erasing ? AppColors.primary : AppColors.borderSubtle,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: erasing ? const Color(0xFFC79100) : const Color(0xFF050C27),
                          offset: const Offset(0, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_fix_high_rounded,
                          color: erasing ? const Color(0xFF0B1124) : Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Borrador',
                          style: GoogleFonts.rubik(
                            color: erasing ? const Color(0xFF0B1124) : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.wrong.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(color: AppColors.wrong, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF4A0008),
                        offset: Offset(0, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded, color: AppColors.wrong, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Limpiar',
                        style: GoogleFonts.rubik(
                          color: AppColors.wrong,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 2)),
      ),
      child: Column(
        children: [
          // 1. Live status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Respuestas en Vivo',
                      style: GoogleFonts.rubik(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.correct,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'EN VIVO',
                      style: GoogleFonts.rubik(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.correct,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 2. Player score strip
          _PlayerScoreStrip(players: gameState.sortedByScore, myId: gameState.myId),
          // 3. Chat messages
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      '¡Empieza a adivinar, pana!',
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    itemCount: messages.length,
                    itemBuilder: (ctx, i) => ChatMessageWidget(message: messages[i]),
                  ),
          ),
          // 4. Guess input dock
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
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF131A35),
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: players.length,
        itemBuilder: (ctx, i) {
          final p = players[i];
          final isMe = p.id == myId;
          final isDrawing = p.isDrawing;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDrawing
                  ? AppColors.primary.withOpacity(0.15)
                  : isMe
                      ? AppColors.cardColor
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDrawing
                    ? AppColors.primary
                    : isMe
                        ? AppColors.accent.withOpacity(0.6)
                        : AppColors.borderSubtle,
                width: isDrawing || isMe ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerAvatar(
                  nickname: p.nickname,
                  avatar: p.avatar,
                  size: 30,
                  score: null,
                  isMe: isMe,
                  isDrawing: isDrawing,
                  hasGuessed: p.hasGuessed,
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${i + 1}° ',
                          style: GoogleFonts.rubik(
                            color: i == 0
                                ? AppColors.primary
                                : i == 1
                                    ? AppColors.textMuted
                                    : AppColors.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          p.nickname + (isMe ? ' (tú)' : ''),
                          style: GoogleFonts.nunitoSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${p.score} pts',
                      style: GoogleFonts.rubik(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
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
      hintText = '¡Estás dibujando, cheo!';
    } else if (guessedCorrectly) {
      hintText = '🎉 ¡Ya adivinaste, qué crack!';
    } else {
      hintText = '¡Escribe tu respuesta aquí...! 🚀';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF050C27),
            offset: Offset(0, -2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF050C27),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: guessedCorrectly
                      ? AppColors.correct
                      : AppColors.borderSubtle,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: TextField(
                  controller: controller,
                  enabled: !disabled,
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                  style: GoogleFonts.nunitoSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: GoogleFonts.nunitoSans(
                      color: guessedCorrectly ? AppColors.correct : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: disabled ? null : onSend,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: disabled ? const Color(0xFF293664) : AppColors.primary,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: disabled ? const Color(0xFF293664) : AppColors.primary,
                  width: 1.5,
                ),
                boxShadow: disabled
                    ? null
                    : const [
                        BoxShadow(
                          color: Color(0xFFC79100),
                          offset: Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enviar',
                    style: GoogleFonts.rubik(
                      color: disabled ? Colors.white38 : const Color(0xFF0B1124),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.send_rounded,
                    color: disabled ? Colors.white38 : const Color(0xFF0B1124),
                    size: 16,
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

// ═══════════════════════════════════════════════════════════
// OVERLAYS (Word selection & Turn end scoreboard)
// ═══════════════════════════════════════════════════════════

class _WordSelectionOverlay extends ConsumerWidget {
  const _WordSelectionOverlay({
    required this.words,
    required this.onWordChosen,
    this.wordDetails,
    this.specialMode,
  });

  final List<String> words;
  final List<Map<String, String>>? wordDetails;
  final ValueChanged<String> onWordChosen;
  final SpecialModeData? specialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final borderColor = specialMode?.badgeColor ?? AppColors.primary;

    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: const Color(0xFF0A112C).withOpacity(0.85),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 2.5),
                  boxShadow: [
                    if (specialMode != null)
                      BoxShadow(
                        color: borderColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    const BoxShadow(
                      color: Color(0xFF050C27),
                      offset: Offset(0, 10),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: specialMode != null ? borderColor.withOpacity(0.2) : AppColors.primary,
                            shape: BoxShape.circle,
                            border: specialMode != null ? Border.all(color: borderColor, width: 2) : null,
                          ),
                          child: specialMode != null
                              ? Text(specialMode!.emoji, style: const TextStyle(fontSize: 22))
                              : const Icon(Icons.brush_rounded, color: Color(0xFF0B1124), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                specialMode != null
                                    ? '¡TURNO ${specialMode!.name.toUpperCase()}!'
                                    : '¡TU TURNO, PANA!',
                                style: GoogleFonts.rubik(
                                  color: borderColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                'Elige tu palabra',
                                style: GoogleFonts.rubik(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Timer badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.cardColor,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: AppColors.secondary, width: 1.5),
                          ),
                          child: Text(
                            '${timer}s',
                            style: GoogleFonts.rubik(
                              color: AppColors.secondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      specialMode != null
                          ? specialMode!.subtitle
                          : 'Los panas en la sala están esperando. ¡Elige una palabra criolla y ponte a rayar!',
                      style: GoogleFonts.nunitoSans(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...words.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final word = entry.value;
                      final original = wordDetails?.firstWhere(
                        (d) => d['word']?.toLowerCase() == word.toLowerCase(),
                        orElse: () => <String, String>{},
                      )['original'];
                      final difficulty = idx == 0 ? 'Fácil' : idx == 1 ? 'Media' : 'Candela 🔥';
                      final pts = idx == 0 ? '+100 pts' : idx == 1 ? '+150 pts' : '+250 pts';
                      final isRecommended = idx == 1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => onWordChosen(word),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isRecommended ? AppColors.primary : AppColors.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isRecommended ? AppColors.primary : AppColors.borderSubtle,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isRecommended ? const Color(0xFFC79100) : const Color(0xFF090D1C),
                                  offset: const Offset(0, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isRecommended ? const Color(0xFF0B1124) : AppColors.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    idx == 0
                                        ? Icons.restaurant_rounded
                                        : idx == 1
                                            ? Icons.air_rounded
                                            : Icons.local_fire_department_rounded,
                                    size: 18,
                                    color: isRecommended ? AppColors.primary : AppColors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        word.toUpperCase(),
                                        style: GoogleFonts.rubik(
                                          color: isRecommended ? const Color(0xFF0B1124) : Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (original != null && original.toLowerCase() != word.toLowerCase())
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                                          child: Text(
                                            '(Dibujas: ${original.toUpperCase()})',
                                            style: GoogleFonts.nunitoSans(
                                              color: isRecommended
                                                  ? const Color(0xFF0B1124).withOpacity(0.85)
                                                  : AppColors.secondary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          Text(
                                            difficulty,
                                            style: GoogleFonts.rubik(
                                              color: isRecommended
                                                  ? const Color(0xFF0B1124).withOpacity(0.8)
                                                  : AppColors.accent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${word.length} Letras',
                                            style: GoogleFonts.nunitoSans(
                                              color: isRecommended
                                                  ? const Color(0xFF0B1124).withOpacity(0.7)
                                                  : AppColors.textMuted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isRecommended ? const Color(0xFF0B1124) : AppColors.surface,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    pts,
                                    style: GoogleFonts.rubik(
                                      color: isRecommended ? AppColors.primary : AppColors.secondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
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
    final top3 = sortedPlayers.take(3).toList();

    return Positioned.fill(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: const Color(0xFF0A112C).withOpacity(0.88),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.borderSubtle, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF050C27),
                      offset: Offset(0, 10),
                      blurRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Badge & Title
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '🎉 ¡FIEBRE CRIOLLA! 🎺',
                          style: GoogleFonts.rubik(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¡RONDA ${gameState.currentRound} TERMINADA!',
                        style: GoogleFonts.rubik(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Todos los panas ya soltaron el lápiz y adivinaron en esta vuelta.',
                        style: GoogleFonts.nunitoSans(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // 2. Word reveal pill
                      if (revealedWord != null && revealedWord.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary.withOpacity(0.6), width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'La palabra era: ',
                                style: GoogleFonts.nunitoSans(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                revealedWord.toUpperCase(),
                                style: GoogleFonts.rubik(
                                  color: AppColors.accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Podio de la Ronda (Top 3)
                      if (top3.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '🏆 Podio de la Ronda',
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.cardColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Puntos acumulados',
                                style: GoogleFonts.nunitoSans(
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 2nd Place (Left)
                            if (top3.length > 1)
                              Expanded(
                                child: _buildPodiumSlot(
                                  rank: 2,
                                  player: top3[1],
                                  color: const Color(0xFF8E9ECA),
                                  isCenter: false,
                                  myId: gameState.myId,
                                ),
                              )
                            else
                              const Spacer(),
                            const SizedBox(width: 8),

                            // 1st Place (Center - Highest)
                            Expanded(
                              flex: 12,
                              child: _buildPodiumSlot(
                                rank: 1,
                                player: top3[0],
                                color: AppColors.primary,
                                isCenter: true,
                                myId: gameState.myId,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 3rd Place (Right)
                            if (top3.length > 2)
                              Expanded(
                                child: _buildPodiumSlot(
                                  rank: 3,
                                  player: top3[2],
                                  color: AppColors.secondary,
                                  isCenter: false,
                                  myId: gameState.myId,
                                ),
                              )
                            else
                              const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4. Posiciones Generales
                      Row(
                        children: [
                          const Icon(Icons.format_list_numbered_rounded, color: AppColors.accent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Posiciones Generales (${sortedPlayers.length} Panas)',
                            style: GoogleFonts.rubik(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedPlayers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final player = sortedPlayers[index];
                          final isMe = player.id == gameState.myId;
                          final pointsGained = player.pointsGained;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.accent.withOpacity(0.12)
                                  : AppColors.cardColor.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isMe
                                    ? AppColors.accent
                                    : AppColors.borderSubtle.withOpacity(0.5),
                                width: isMe ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? AppColors.primary
                                        : index == 1
                                            ? const Color(0xFF8E9ECA)
                                            : index == 2
                                                ? AppColors.secondary
                                                : AppColors.surfaceElevated,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.rubik(
                                        color: index <= 2 ? const Color(0xFF0B1124) : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PlayerAvatar(
                                  nickname: player.nickname,
                                  avatar: player.avatar,
                                  size: 28,
                                  score: null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          player.nickname,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.nunitoSans(
                                            color: Colors.white,
                                            fontWeight: isMe ? FontWeight.w800 : FontWeight.w700,
                                            fontSize: 13,
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
                                if (pointsGained > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.correct.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(9999),
                                      border: Border.all(color: AppColors.correct, width: 1),
                                    ),
                                    child: Text(
                                      '+$pointsGained',
                                      style: GoogleFonts.rubik(
                                        color: AppColors.correct,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                Text(
                                  '${player.score} pts',
                                  style: GoogleFonts.rubik(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // 5. Footer waiting for next turn
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Siguiente turno en breve...',
                            style: GoogleFonts.nunitoSans(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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

  static Widget _buildPodiumSlot({
    required int rank,
    required dynamic player,
    required Color color,
    required bool isCenter,
    required String myId,
  }) {
    final isMe = player.id == myId;
    final pointsGained = player.pointsGained as int? ?? 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isCenter ? 12 : 8),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: isCenter ? 2.5 : 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF050C27),
            offset: Offset(0, isCenter ? 6 : 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1)
            const Text('👑', style: TextStyle(fontSize: 18))
          else
            Text(
              rank == 2 ? '🥈' : '🥉',
              style: const TextStyle(fontSize: 14),
            ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              PlayerAvatar(
                nickname: player.nickname,
                avatar: player.avatar,
                size: isCenter ? 46 : 38,
                score: null,
                isMe: isMe,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: GoogleFonts.rubik(
                      color: const Color(0xFF0B1124),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            player.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: isCenter ? 12 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (pointsGained > 0) ...[
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isCenter
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                '+$pointsGained pts',
                style: GoogleFonts.rubik(
                  color: isCenter ? AppColors.primary : AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${player.score} pts',
            style: GoogleFonts.rubik(
              color: isCenter ? AppColors.primary : Colors.white,
              fontSize: isCenter ? 13 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SPECIAL MODE ANNOUNCEMENT BANNER OVERLAY
// ═══════════════════════════════════════════════════════════

class _SpecialModeBannerOverlay extends StatefulWidget {
  const _SpecialModeBannerOverlay({
    required this.specialMode,
    required this.isDrawer,
    required this.drawerNickname,
  });

  final SpecialModeData specialMode;
  final bool isDrawer;
  final String drawerNickname;

  @override
  State<_SpecialModeBannerOverlay> createState() => _SpecialModeBannerOverlayState();
}

class _SpecialModeBannerOverlayState extends State<_SpecialModeBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _scaleAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack);
    _animCtrl.forward();

    // Auto dismiss full banner after 4.5 seconds
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (mounted && !_dismissed) {
        _animCtrl.reverse().then((_) {
          if (mounted) setState(() => _dismissed = true);
        });
      }
    });
  }

  @override
  void didUpdateWidget(_SpecialModeBannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.specialMode.id != widget.specialMode.id) {
      _dismissed = false;
      _animCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Center(
        child: AnimatedBuilder(
          animation: _animCtrl,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _slideAnim.value) * -60),
              child: Transform.scale(
                scale: 0.8 + 0.2 * _scaleAnim.value,
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () {
              _animCtrl.reverse().then((_) {
                if (mounted) setState(() => _dismissed = true);
              });
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: widget.specialMode.badgeColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: widget.specialMode.badgeColor.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                    const BoxShadow(
                      color: Color(0xFF050C27),
                      offset: Offset(0, 8),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: widget.specialMode.badgeColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.specialMode.badgeColor, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          widget.specialMode.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.specialMode.badgeColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '¡TURNO ESPECIAL!',
                                  style: GoogleFonts.rubik(
                                    color: Colors.black87,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.specialMode.name.toUpperCase(),
                            style: GoogleFonts.rubik(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.specialMode.subtitle,
                            style: GoogleFonts.nunito(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

