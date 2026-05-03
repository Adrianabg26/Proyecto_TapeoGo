/// badge_item.dart
///
/// Widget reutilizable que representa visualmente una medalla individual
/// en el grid de la pantalla de perfil.
///
/// Gestiona dos estados visuales:
///   - Desbloqueada: imagen a color, nombre en naranja.
///   - Bloqueada: imagen en escala de grises con candado en la esquina.
///
/// Al pulsar la medalla muestra un BottomSheet con el detalle completo:
/// imagen, nombre, descripción, requisito, XP y fecha de desbloqueo.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';

class BadgeItem extends StatelessWidget {
  final String name;
  final bool isUnlocked;
  final String? imageUrl;
  final String description;
  final int requirementCount;
  final int xpBonus;
  final double circleSize;
  final DateTime? unlockedAt;

  // Callback para navegar al mapa desde el modal.
  // Se propaga desde BadgesGrid → ProfileScreen → MainScreen
  // para no acoplar este widget a la navegación directa.
  final VoidCallback onGoToExplore;

  const BadgeItem({
    super.key,
    required this.name,
    required this.isUnlocked,
    required this.description,
    required this.requirementCount,
    required this.xpBonus,
    required this.circleSize,
    required this.onGoToExplore,
    this.imageUrl,
    this.unlockedAt,
  });

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _showBadgeModal
  // BottomSheet con cabecera naranja corporativa y medalla emergente
  // sobre el borde entre la cabecera y el cuerpo blanco.
  //
  // La medalla "flota" sobre el borde mediante Transform.translate con
  // offset negativo en Y — crea el efecto visual de elemento emergente
  // sin necesidad de Stack a nivel de pantalla.
  //
  // showLockBadge: false en el modal porque el indicador de bloqueo
  // se muestra como icono separado junto al nombre, no como badge.
  // ─────────────────────────────────────────────────────────────────────────
  void _showBadgeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── Cabecera naranja ──
            // Fondo corporativo que actúa como base visual del modal.
            // El padding inferior de 48px reserva espacio para la medalla
            // emergente que se superpone con Transform.translate.
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
              child: const SizedBox.shrink(),
            ),

            // ── Medalla emergente ──
            // Transform.translate desplaza la medalla 44px hacia arriba
            // para que sobresalga sobre el borde de la cabecera naranja.
            Transform.translate(
              offset: const Offset(0, -44),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildMedalCircle(
                          size: 88, iconSize: 40, showLockBadge: false),
                    ),
                  ),

                  // Candado en esquina — solo si la medalla está bloqueada.
                  if (!isUnlocked)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.grey[200]!, width: 1.5),
                      ),
                      child: Icon(Icons.lock_rounded,
                          size: 13, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),

            // ── Cuerpo del modal ──
            // Transform.translate sube el cuerpo 32px para compensar
            // el espacio vacío que deja la medalla emergente.
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [

                    // Nombre de la medalla.
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Descripción de la medalla.
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          height: 1.5),
                    ),
                    const SizedBox(height: 16),

                    // Chips de requisito y XP bonus en fila.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildInfoChip(
                          icon: Icons.flag_rounded,
                          label: 'Meta: $requirementCount',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        // Chip de XP con colores dorados distintos al naranja.
                        _buildInfoChip(
                          icon: Icons.star_rounded,
                          label: '+$xpBonus XP',
                          color: const Color(0xFFC08000),
                          bgColor: const Color(0xFFFFF8E1),
                          borderColor: const Color(0xFFFFE082),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Divider(color: Colors.grey[100], height: 1),
                    const SizedBox(height: 14),

                    // Estado de la medalla: fecha de desbloqueo o mensaje de bloqueo.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isUnlocked
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          size: 14,
                          color: isUnlocked
                              ? AppColors.primary
                              : Colors.grey[400],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isUnlocked
                              ? 'Desbloqueada el ${DateFormat('dd/MM/yyyy').format(unlockedAt!)}'
                              : 'Todavía no la has conseguido',
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnlocked
                                ? AppColors.primary
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botón de exploración — cierra el modal y navega al mapa.
                    // onGoToExplore se propaga desde ProfileScreen para no
                    // acoplar BadgeItem a la navegación directa.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onGoToExplore();
                        },
                        icon: const Icon(Icons.map_outlined,
                            size: 18, color: Colors.white),
                        label: const Text(
                          'Explorar bares',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildInfoChip
  // Chip reutilizable para mostrar meta y XP en el modal de detalle.
  // bgColor y borderColor son opcionales para personalizar el chip de XP
  // con colores dorados distintos al naranja corporativo de la meta.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? bgColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: borderColor ?? color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildMedalCircle
  // Círculo de la medalla con dos estados visuales diferenciados:
  //
  // - Desbloqueada: imagen a color con ColorFilter.mode transparente.
  // - Bloqueada: imagen en escala de grises mediante matriz ColorFilter.
  //   La matriz de escala de grises [0.33, 0.33, 0.33...] desatura la
  //   imagen completamente sin necesitar un asset alternativo en gris —
  //   decisión de diseño que reduce el número de assets necesarios.
  //
  // showLockBadge controla la visibilidad del candado en la esquina:
  // - true en el grid de ProfileScreen — indica visualmente el bloqueo.
  // - false en el modal — el indicador de bloqueo es el icono de la fila.
  //
  // loadingBuilder muestra un fondo de color mientras la imagen de red
  // se descarga, evitando el destello blanco del placeholder por defecto.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMedalCircle({
    required double size,
    required double iconSize,
    bool showLockBadge = true,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          ClipOval(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? ColorFiltered(
                    colorFilter: isUnlocked
                        // Medalla desbloqueada — sin filtro de color.
                        ? const ColorFilter.mode(
                            Colors.transparent, BlendMode.saturation)
                        // Medalla bloqueada — matriz de escala de grises.
                        // Cada canal RGB se sustituye por el promedio de los tres,
                        // produciendo una imagen completamente desaturada.
                        : const ColorFilter.matrix([
                            0.33, 0.33, 0.33, 0, 0,
                            0.33, 0.33, 0.33, 0, 0,
                            0.33, 0.33, 0.33, 0, 0,
                            0,    0,    0,    1, 0,
                          ]),
                    child: Image.network(
                      imageUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      // Muestra fondo de color mientras se descarga la imagen.
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: size,
                          height: size,
                          color: isUnlocked
                              ? Colors.orange[50]
                              : Colors.grey[100],
                        );
                      },
                      // Fallback con icono si la imagen falla al cargar.
                      errorBuilder: (_, __, ___) => Icon(
                        isUnlocked
                            ? Icons.emoji_events
                            : Icons.lock_rounded,
                        color:
                            isUnlocked ? Colors.orange : Colors.grey[400],
                        size: iconSize,
                      ),
                    ),
                  )
                // Fallback con icono si no hay URL de imagen en la BD.
                : Icon(
                    isUnlocked ? Icons.emoji_events : Icons.lock_rounded,
                    color: isUnlocked ? Colors.orange : Colors.grey[400],
                    size: iconSize,
                  ),
          ),

          // Candado en esquina inferior derecha — solo en el grid.
          // El tamaño es proporcional al circleSize para escalar correctamente
          // en distintos tamaños de pantalla mediante LayoutBuilder.
          if (!isUnlocked && showLockBadge)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.grey[300]!, width: 1.2),
                ),
                child: Icon(Icons.lock_rounded,
                    size: size * 0.17, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showBadgeModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Círculo de la medalla con estado visual diferenciado.
            _buildMedalCircle(
              size: circleSize,
              iconSize: circleSize * 0.46,
            ),
            const SizedBox(height: 4),

            // Nombre de la medalla — naranja si desbloqueada, gris si bloqueada.
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isUnlocked ? FontWeight.bold : FontWeight.w500,
                color:
                    isUnlocked ? AppColors.titleOrange : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}