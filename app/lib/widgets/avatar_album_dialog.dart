import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/vzla_avatar.dart';
import '../services/session_storage.dart';

/// Modal dialog showing the complete Stitch Creole Avatar Album
class AvatarAlbumDialog extends StatefulWidget {
  const AvatarAlbumDialog({
    super.key,
    required this.currentAvatarId,
    required this.onAvatarSelected,
  });

  final String currentAvatarId;
  final ValueChanged<String> onAvatarSelected;

  static Future<void> show(
    BuildContext context, {
    required String currentAvatarId,
    required ValueChanged<String> onAvatarSelected,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => AvatarAlbumDialog(
        currentAvatarId: currentAvatarId,
        onAvatarSelected: onAvatarSelected,
      ),
    );
  }

  @override
  State<AvatarAlbumDialog> createState() => _AvatarAlbumDialogState();
}

class _AvatarAlbumDialogState extends State<AvatarAlbumDialog> {
  late String _selectedId;
  String _selectedCategory = 'Todos';

  final Map<String, String> _catchphrases = {
    'arepa': '¡Pura masa con queso \'e mano!',
    'malta': '¡Bien fría con espuma burbujeante!',
    'aguacate': '¡Con lentes oscuros bien sifrino!',
    'chivo': '¡Chivo en coco maracucho con sombrero!',
    'baseball': '¡Pelotero de corazón y costuras rojas!',
    'mototaxi': '¡Pirueta por la orillita de la autopista!',
    'iguana': '¡Relajada tomando sol en el muro!',
    'desierto': '¡Duna dorada con sol y cactus!',
    'tequeno': '¡No hay rumba criolla sin tequeño!',
    'harina_pan': '¡Pura masa con sabor criollo desde 1960!',
    'guacamaya': '¡Vuelo tricolor en el cielo caraqueño!',
    'caraota': '¡Grano negro criollo con vaporcito!',
  };

  final Map<String, String> _tags = {
    'arepa': '★ Favorito',
    'malta': 'Bebida 🥤',
    'aguacate': 'Chévere 😎',
    'chivo': 'Falcón 🐐',
    'baseball': 'LVBP ⚾',
    'mototaxi': '¡Caballito! 🏍️',
    'iguana': 'Tropical 🦎',
    'desierto': 'Coro 🌵',
    'tequeno': '¡Quesúo! 🧀',
    'harina_pan': 'Épico 🫓',
    'guacamaya': 'El Ávila 🦜',
    'caraota': 'Pabellón 🍲',
  };

  final Map<String, String> _categories = {
    'arepa': 'Comida Criolla',
    'malta': 'Comida Criolla',
    'aguacate': 'Comida Criolla',
    'chivo': 'Criaturas & Personajes',
    'baseball': 'Cultura & Lugares',
    'mototaxi': 'Cultura & Lugares',
    'iguana': 'Criaturas & Personajes',
    'desierto': 'Cultura & Lugares',
    'tequeno': 'Comida Criolla',
    'harina_pan': 'Comida Criolla',
    'guacamaya': 'Criaturas & Personajes',
    'caraota': 'Comida Criolla',
  };

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentAvatarId;
  }

  List<VzlaAvatar> get _filteredAvatars {
    if (_selectedCategory == 'Todos') return VzlaAvatars.all;
    return VzlaAvatars.all.where((a) => _categories[a.id] == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final activeAvatar = VzlaAvatars.getById(_selectedId);
    final catchphrase = _catchphrases[_selectedId] ?? '¡Con todo el sabor criollo!';
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 850),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.borderSubtle, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0xFF050C27), offset: Offset(0, 10), blurRadius: 0),
            BoxShadow(color: Colors.black45, blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: Column(
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                border: Border(bottom: BorderSide(color: AppColors.borderSubtle, width: 2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFFC79100), offset: Offset(0, 2)),
                      ],
                    ),
                    child: const Center(
                      child: Text('🎨', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ÁLBUM DE AVATARES CRIOLLOS',
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: isDesktop ? 16 : 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
                              ),
                              child: Text(
                                '12/12',
                                style: GoogleFonts.rubik(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Elige tu pana gráfico para vacilar en la sala y en la pizarra',
                          style: GoogleFonts.nunitoSans(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ─── Body: Split view or scrollable ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Showcase del avatar activo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.borderSubtle),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF090D1C), offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Large Avatar Circle with halo
                          Container(
                            width: 86,
                            height: 86,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.cardColor,
                              border: Border.all(color: AppColors.primary, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 16,
                                ),
                                const BoxShadow(
                                  color: Color(0xFF090D1C),
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                activeAvatar.assetPath,
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(activeAvatar.emoji, style: const TextStyle(fontSize: 40)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _tags[_selectedId] ?? 'Criollo',
                                        style: GoogleFonts.rubik(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      activeAvatar.name,
                                      style: GoogleFonts.rubik(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  activeAvatar.subtitle,
                                  style: GoogleFonts.nunitoSans(
                                    color: AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: Text(
                                    '"$catchphrase"',
                                    style: GoogleFonts.rubik(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Filter category pill bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryChip('Todos', 'Todos (12)'),
                          const SizedBox(width: 8),
                          _buildCategoryChip('Comida Criolla', '🫓 Comida Criolla'),
                          const SizedBox(width: 8),
                          _buildCategoryChip('Criaturas & Personajes', '🦜 Criaturas & Panas'),
                          const SizedBox(width: 8),
                          _buildCategoryChip('Cultura & Lugares', '🌵 Cultura & Lugares'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid of 12 Avatars
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isDesktop ? 4 : 2,
                        childAspectRatio: isDesktop ? 0.95 : 0.88,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: _filteredAvatars.length,
                      itemBuilder: (ctx, i) {
                        final avatar = _filteredAvatars[i];
                        final isSelected = avatar.id == _selectedId;

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedId = avatar.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.surfaceElevated : AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.borderSubtle,
                                width: isSelected ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF090D1C),
                                  offset: Offset(0, isSelected ? 5 : 3),
                                ),
                                if (isSelected)
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.25),
                                    blurRadius: 10,
                                  ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top Tag
                                Align(
                                  alignment: Alignment.topRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.cardColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _tags[avatar.id] ?? 'Criollo',
                                      style: GoogleFonts.rubik(
                                        color: isSelected ? const Color(0xFF050C27) : AppColors.textMuted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                // Avatar circle image
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.white12,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      avatar.assetPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(avatar.emoji, style: const TextStyle(fontSize: 28)),
                                      ),
                                    ),
                                  ),
                                ),
                                // Name & Subtitle
                                Column(
                                  children: [
                                    Text(
                                      avatar.name,
                                      style: GoogleFonts.rubik(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      avatar.subtitle,
                                      style: GoogleFonts.nunitoSans(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                                // Equip button badge
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.cardColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected ? const Color(0xFFC79100) : const Color(0xFF090D1C),
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    isSelected ? '✓ EN USO' : 'EQUIPAR',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.rubik(
                                      color: isSelected ? const Color(0xFF050C27) : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ─── Bottom Actions ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
                border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderSubtle, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.rubik(color: Colors.white70, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFFC79100), offset: Offset(0, 4)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onAvatarSelected(_selectedId);
                          SessionStorage.saveAvatar(_selectedId);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF050C27)),
                        label: Text(
                          'GUARDAR AVATAR',
                          style: GoogleFonts.rubik(
                            color: const Color(0xFF050C27),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
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

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
          ),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0xFFC79100), offset: Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.rubik(
            color: isSelected ? const Color(0xFF050C27) : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
