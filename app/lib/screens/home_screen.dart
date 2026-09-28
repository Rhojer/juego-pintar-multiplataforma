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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, Color(0xFF0D1B3E)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildFloatingTitle(),
                  const SizedBox(height: 8),
                  Text(
                    '¡El juego de dibujo venezolano!',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  _buildAvatarSelector(),
                  const SizedBox(height: 32),
                  _buildNicknameField(),
                  const SizedBox(height: 20),
                  if (_savedSession != null && _isConnecting) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Reconectando a sala ${_savedSession!['roomCode']}...',
                              style: GoogleFonts.nunito(
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
                              style: GoogleFonts.nunito(
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
                  _buildPrivateButton(),
                  const SizedBox(height: 40),
                  _buildFooter(),
                ],
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
      child: Column(
        children: [
          Text(
            'Rayando',
            style: GoogleFonts.nunito(
              fontSize: 52,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ).createShader(const Rect.fromLTWH(0, 0, 300, 60)),
            ),
          ),
          const Text('🇻🇪', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }

  Widget _buildAvatarSelector() {
    final currentAvatar = VzlaAvatars.getById(_selectedAvatar);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tu avatar: ',
              style: GoogleFonts.nunito(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: currentAvatar.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: currentAvatar.color, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: Image.asset(
                      currentAvatar.assetPath,
                      width: 20,
                      height: 20,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Text(currentAvatar.emoji, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    currentAvatar.name,
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: VzlaAvatars.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final av = VzlaAvatars.all[i];
              final isSelected = av.id == _selectedAvatar;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedAvatar = av.id);
                  SessionStorage.saveAvatar(av.id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 56 : 46,
                  height: isSelected ? 56 : 46,
                  decoration: BoxDecoration(
                    color: av.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white30,
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: av.color.withOpacity(0.7),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      av.assetPath,
                      width: isSelected ? 56 : 46,
                      height: isSelected ? 56 : 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          av.emoji,
                          style: TextStyle(
                            fontSize: isSelected ? 26 : 22,
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
        const SizedBox(height: 6),
        Text(
          currentAvatar.subtitle,
          style: GoogleFonts.nunito(
            color: Colors.white54,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameField() {
    return TextFormField(
      controller: _nicknameCtrl,
      validator: _validateNickname,
      maxLength: AppConstants.maxNicknameLength,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: '¿Cómo te llamas, pana?',
        prefixIcon: const Icon(Icons.person_outline, color: AppColors.secondary),
        counterText: '',
        labelText: 'Apodo',
      ),
    );
  }

  Widget _buildPlayButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isConnecting ? null : _joinPublic,
        icon: _isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow_rounded, size: 26),
        label: Text(
          _isConnecting ? 'Conectando...' : '¡Jugar!',
          style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildPrivateButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _isConnecting ? null : _showPrivateSheet,
        icon: const Icon(Icons.lock_outline, color: AppColors.secondary),
        label: Text(
          '🔒 Sala privada',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.secondary, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      '¡Chévere pana! Mínimo ${AppConstants.minPlayers} jugadores para empezar.',
      style: const TextStyle(color: Colors.white38, fontSize: 12),
      textAlign: TextAlign.center,
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
