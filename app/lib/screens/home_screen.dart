import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/vzla_avatar.dart';
import '../providers/game_provider.dart';
import '../services/socket_service.dart';
import '../services/session_storage.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
  with SingleTickerProviderStateMixin {
  final _nicknameCtrl = TextEditingController();
  final _roomCodeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isConnecting = false;
  Map<String, String>? _savedSession;
  String _selectedAvatar = 'arepa';
  late final AnimationController _animCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );

    // Pre-connect socket after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SocketService().connect();
      _checkSavedSession();
    });

    final socket = SocketService();

    // Listen for join errors
    socket.onJoinError.listen((msg) {
      if (mounted) {
        _connectTimeoutTimer?.cancel();
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.wrong,
          ),
        );
      }
    });

    // Navigate to lobby or game when room is joined
    socket.onRoomJoined.listen((data) {
      if (mounted) {
        _connectTimeoutTimer?.cancel();
        setState(() => _isConnecting = false);
        final roomMap = data['room'] is Map ? data['room'] as Map : null;
        final status = (data['status'] ?? roomMap?['status']) as String?;
        if (status == 'playing') {
          context.go('/game');
        } else {
          context.go('/lobby');
        }
      }
    });

    // Reconnection events
    socket.onReconnectedSuccess.listen((data) {
      if (mounted) {
        _connectTimeoutTimer?.cancel();
        setState(() => _isConnecting = false);
        final status = data['status'] as String?;
        if (status == 'playing') {
          context.go('/game');
        } else {
          context.go('/lobby');
        }
      }
    });

    socket.onReconnectFailed.listen((msg) {
      if (mounted) {
        _connectTimeoutTimer?.cancel();
        setState(() {
          _isConnecting = false;
          _savedSession = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    });
  }

  void _checkSavedSession() async {
    final savedAvatar = await SessionStorage.getAvatar();
    if (mounted) {
      setState(() => _selectedAvatar = savedAvatar);
    }

    final session = await SessionStorage.getSession();
    if (session != null && mounted) {
      setState(() {
        _savedSession = session;
        if (session['nickname'] != null && session['nickname']!.isNotEmpty) {
          _nicknameCtrl.text = session['nickname']!;
        }
        if (session['avatar'] != null && session['avatar']!.isNotEmpty) {
          _selectedAvatar = session['avatar']!;
        }
        _isConnecting = true;
      });
      _startConnectingTimeout();
      SocketService().reconnectPlayer(
        roomCode: session['roomCode']!,
        sessionToken: session['sessionToken']!,
      );
    }
  }

  void _cancelReconnection() {
    _connectTimeoutTimer?.cancel();
    SessionStorage.clearSession();
    setState(() {
      _isConnecting = false;
      _savedSession = null;
    });
  }

  Timer? _connectTimeoutTimer;

  void _startConnectingTimeout() {
    _connectTimeoutTimer?.cancel();
    _connectTimeoutTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isConnecting) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tardó mucho en responder, intenta de nuevo pana.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _connectTimeoutTimer?.cancel();
    _animCtrl.dispose();
    _nicknameCtrl.dispose();
    _roomCodeCtrl.dispose();
    super.dispose();
  }

  String? _validateNickname(String? value) {
    if (value == null || value.trim().isEmpty) return '¡Pon tu nombre, pana!';
    if (value.trim().length < 2) return 'Mínimo 2 caracteres';
    if (value.trim().length > AppConstants.maxNicknameLength) {
      return 'Máximo ${AppConstants.maxNicknameLength} caracteres';
    }
    return null;
  }

  void _joinPublic() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isConnecting = true);
    _startConnectingTimeout();
    ref.read(gameProvider.notifier).joinPublic(
      _nicknameCtrl.text.trim(),
      avatar: _selectedAvatar,
    );
  }

  void _showPrivateSheet() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PrivateRoomSheet(
        nickname: _nicknameCtrl.text.trim(),
        avatar: _selectedAvatar,
        onConnecting: () {
          setState(() => _isConnecting = true);
          _startConnectingTimeout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF141B36),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Badge superior "Edición Fiesta Criolla"
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('★', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            const SizedBox(width: 6),
                            Text(
                              'EDICIÓN FIESTA CRIOLLA',
                              style: GoogleFonts.rubik(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('★', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildFloatingTitle(),
                      const SizedBox(height: 6),
                      Text(
                        '¡El juego de dibujar, reírte y vacilar adivinando con tus panas!',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Tarjeta Principal Táctil (Stitch Arcade Card 2.5D)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.borderSubtle, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF050C27),
                              offset: Offset(0, 8),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildAvatarSelector(),
                            const SizedBox(height: 24),
                            _buildNicknameField(),
                            const SizedBox(height: 20),
                            if (_savedSession != null && _isConnecting) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.primary),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Reconectando a sala ${_savedSession!['roomCode']}...',
                                        style: GoogleFonts.rubik(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _cancelReconnection,
                                      child: Text(
                                        'Cancelar',
                                        style: GoogleFonts.nunitoSans(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildPlayButton(),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildPrivateButton()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(),
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

  Widget _buildFloatingTitle() {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'RAYANDO',
            style: GoogleFonts.rubik(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: AppColors.primary,
              shadows: const [
                Shadow(
                  color: Color(0xFFC79100),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0xFFB71C1C), offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              '¡CHÉVERE!',
              style: GoogleFonts.rubik(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSelector() {
    final currentAvatar = VzlaAvatars.getById(_selectedAvatar);

    return Column(
      children: [
        // Avatar grande destacado con halo 2.5D
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardColor,
            border: Border.all(color: AppColors.primary, width: 3.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Color(0xFF090D1C),
                offset: Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: Image.asset(
                  currentAvatar.assetPath,
                  width: 98,
                  height: 98,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    currentAvatar.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.brush_rounded, size: 13, color: Color(0xFF0A112C)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          currentAvatar.name,
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          currentAvatar.subtitle,
          style: GoogleFonts.nunitoSans(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        // Carrusel selector de miniaturas
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VzlaAvatars.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final av = VzlaAvatars.all[i];
              final isSelected = av.id == _selectedAvatar;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedAvatar = av.id);
                  SessionStorage.saveAvatar(av.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isSelected ? 54 : 44,
                  height: isSelected ? 54 : 44,
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      av.assetPath,
                      width: isSelected ? 54 : 44,
                      height: isSelected ? 54 : 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          av.emoji,
                          style: TextStyle(
                            fontSize: isSelected ? 24 : 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.accent, size: 18),
            const SizedBox(width: 6),
            Text(
              '¿Cuál es tu apodo, pana?',
              style: GoogleFonts.rubik(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nicknameCtrl,
          validator: _validateNickname,
          maxLength: AppConstants.maxNicknameLength,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Ej. CheoElMecánico',
            hintStyle: GoogleFonts.nunitoSans(color: AppColors.textMuted, fontSize: 14),
            counterText: '',
            filled: true,
            fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9999),
              borderSide: const BorderSide(color: AppColors.borderSubtle, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9999),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
            prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFC79100),
              offset: Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isConnecting ? null : _joinPublic,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: const Color(0xFF0B1124),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          ),
          child: _isConnecting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Color(0xFF0B1124), strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 28, color: Color(0xFF0B1124)),
                    const SizedBox(width: 8),
                    Text(
                      '¡JUGAR AHORA!',
                      style: GoogleFonts.rubik(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: const Color(0xFF0B1124),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.bolt_rounded, size: 20, color: Color(0xFF0B1124)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPrivateButton() {
    return SizedBox(
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF090D1C),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isConnecting ? null : _showPrivateSheet,
          icon: const Icon(Icons.lock_outline_rounded, size: 18, color: Colors.white),
          label: Text(
            'Crear o Unirse a Sala Privada',
            style: GoogleFonts.rubik(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cardColor,
            elevation: 0,
            side: const BorderSide(color: AppColors.borderSubtle, width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.correct,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Partidas en vivo disponibles • Mínimo ${AppConstants.minPlayers} panas para empezar',
          style: GoogleFonts.nunitoSans(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── Private Room Sheet ───────────────────────────

class _PrivateRoomSheet extends ConsumerStatefulWidget {
  const _PrivateRoomSheet({
    required this.nickname,
    this.avatar = 'arepa',
    required this.onConnecting,
  });

  final String nickname;
  final String avatar;
  final VoidCallback onConnecting;

  @override
  ConsumerState<_PrivateRoomSheet> createState() => _PrivateRoomSheetState();
}

class _PrivateRoomSheetState extends ConsumerState<_PrivateRoomSheet> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _createRoom() {
    widget.onConnecting();
    ref.read(gameProvider.notifier).createPrivate(
          widget.nickname,
          avatar: widget.avatar,
        );
    Navigator.of(context).pop();
  }

  void _joinRoom() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Pon el código de sala, pana!')),
      );
      return;
    }
    widget.onConnecting();
    ref.read(gameProvider.notifier).joinPrivate(
          widget.nickname,
          code,
          avatar: widget.avatar,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sala Privada 🔒',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createRoom,
              icon: const Icon(Icons.add_home_rounded),
              label: const Text('Crear sala nueva'),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'Unirse a sala existente:',
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'Código de sala',
              prefixIcon: const Icon(Icons.tag, color: AppColors.accent),
              filled: true,
              fillColor: AppColors.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(8),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _joinRoom,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Unirse'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
