/// profile_header.dart
///
/// Widget que muestra la cabecera del perfil del usuario:
/// avatar, nombre completo, username, píldora de rango y barra de XP.
///
/// Al pulsar la píldora del rango se abre un BottomSheet con la escalera
/// completa de rangos, mostrando el progreso del usuario sin consultas
/// adicionales a Supabase — usa los datos ya cargados en el perfil.
///
/// Es un StatelessWidget porque recibe todos los datos como parámetros
/// desde ProfileScreen — no gestiona estado propio.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class ProfileHeader extends StatelessWidget {
  final String fullName;
  final String username;
  final int level;
  final String rankTitle;
  final int xpTotal;
  final double xpProgress;
  final String? avatarUrl;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    super.key,
    required this.fullName,
    required this.username,
    required this.level,
    required this.rankTitle,
    required this.xpTotal,
    required this.xpProgress,
    this.avatarUrl,
    this.onAvatarTap,
  });

  // true si el usuario tiene foto de perfil guardada en Supabase Storage.
  bool get _hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  // Inicial del nombre para el avatar cuando no hay foto.
  String get _initial => fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

  // ─────────────────────────────────────────────────────────────────────────
  // GETTER: _xpToNextLabel
  // Texto descriptivo del XP restante para el siguiente rango.
  // Sincronizado con los umbrales definidos en ProfileModel.userRank
  // para que el texto sea siempre coherente con la píldora de rango.
  // ─────────────────────────────────────────────────────────────────────────
  String get _xpToNextLabel {
    if (xpTotal >= 5000) return '¡Leyenda del Tapeo alcanzado!';
    if (xpTotal >= 2000) return '${5000 - xpTotal} XP para Leyenda del Tapeo';
    if (xpTotal >= 1000) return '${2000 - xpTotal} XP para Rey de la Barra';
    if (xpTotal >= 500)  return '${1000 - xpTotal} XP para Experto Gourmet';
    if (xpTotal >= 100)  return '${500 - xpTotal} XP para Tapeador Experto';
    return '${100 - xpTotal} XP para Aprendiz de Tapa';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [

        // Avatar pulsable — abre el selector de imagen en EditProfileScreen.
        GestureDetector(
          onTap: onAvatarTap,
          child: _buildAvatar(72),
        ),

        const SizedBox(width: 14),

        // Columna de información del usuario a la derecha del avatar.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Nombre + píldora de rango a la derecha ──
              // Expanded en el nombre le da todo el ancho disponible.
              // La píldora queda anclada a la derecha sin forzar el layout
              // ni cortar el nombre con ellipsis innecesariamente.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Píldora de rango — al pulsar abre el BottomSheet de rangos.
                  GestureDetector(
                    onTap: () => _showRankInfo(context),
                    child: _buildRankPill(),
                  ),
                ],
              ),

              // ── Username solo ──
              // Separado del nombre para que la píldora no compita
              // visualmente con el username en pantallas pequeñas.
              Text(
                username,
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 6),

              // ── Sección de XP ──
              // Barra de progreso + nivel actual + XP restante para el siguiente rango.
              _buildXpSection(),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildAvatar
  // Avatar circular con imagen de Supabase Storage o inicial del nombre.
  //
  // El icono de cámara solo aparece cuando onAvatarTap está definido —
  // es decir, cuando la pantalla permite editar el perfil (ProfileScreen).
  // No aparece en contextos de solo lectura como el modal de medallas.
  //
  // Los tamaños del icono e inicial son proporcionales al parámetro size
  // para mantener coherencia visual si el avatar se usa en distintos
  // tamaños en el futuro.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAvatar(double size) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            // Carga la imagen desde Supabase Storage si existe URL.
            image: _hasAvatar
                ? DecorationImage(
                    image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // Muestra la inicial solo cuando no hay imagen disponible.
          child: !_hasAvatar
              ? Center(
                  child: Text(
                    _initial,
                    style: TextStyle(
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              : null,
        ),

        // Icono de cámara superpuesto — solo visible cuando la pantalla
        // permite edición del perfil (onAvatarTap != null).
        if (onAvatarTap != null)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: size * 0.18,
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildRankPill
  // Píldora compacta con el rango actual del usuario.
  //
  // El icono principal cambia según el nivel para transmitir progresión:
  // trofeo básico → estrellas → premium. El icono de info al final
  // indica visualmente al usuario que la píldora es interactiva y
  // abre más información al pulsarla.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRankPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono de rango — cambia según el nivel del usuario.
          Icon(_rankIcon, color: AppColors.primary, size: 12),
          const SizedBox(width: 4),
          // Nombre del rango actual.
          Text(
            rankTitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          // Icono de info — indica al usuario que la píldora es pulsable.
          Icon(
            Icons.info_outline_rounded,
            size: 11,
            color: AppColors.primary.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildXpSection
  // Barra de progreso XP con nivel actual y texto de XP restante.
  //
  // xpProgress viene calculado como getter de ProfileModel (0.0–1.0)
  // sin necesidad de consultas adicionales a Supabase.
  // clamp(0.0, 1.0) evita desbordamientos visuales de la barra si el
  // valor calculado supera ligeramente los límites por redondeo.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildXpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // Barra de progreso XP del nivel actual.
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: xpProgress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 12,
          ),
        ),

        const SizedBox(height: 8),

        // Nivel actual y XP restante para el siguiente rango en la misma fila.
        Row(
          children: [
            Text(
              'Nivel $level',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            // Separador visual entre nivel y XP restante.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('•', style: TextStyle(color: Colors.grey[400])),
            ),
            // XP restante para el siguiente rango — se trunca con ellipsis
            // en pantallas muy estrechas para no desbordar el layout.
            Expanded(
              child: Text(
                _xpToNextLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GETTER: _rankIcon
  // Devuelve el icono correspondiente al rango actual del usuario.
  // La progresión de icono transmite visualmente la jerarquía de rangos:
  // trofeo básico → estrellas → premium (workspace_premium).
  // ─────────────────────────────────────────────────────────────────────────
  IconData get _rankIcon {
    switch (rankTitle) {
      case 'Leyenda del Tapeo':
      case 'Rey de la Barra':
        return Icons.workspace_premium;
      case 'Experto Gourmet':
      case 'Tapeador Experto':
        return Icons.stars;
      default:
        return Icons.emoji_events_outlined;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _showRankInfo
  // BottomSheet con la escalera completa de rangos al pulsar la píldora.
  //
  // No requiere consultas a Supabase — usa xpTotal y rankTitle ya cargados
  // en memoria por AuthNotifier, aplicando el principio de Single Source
  // of Truth y evitando latencia de red al abrir el modal.
  //
  // Cada fila de rango muestra tres estados visuales:
  // - Badge "Actual": rango en el que se encuentra el usuario ahora.
  // - Check verde: rango ya superado y desbloqueado.
  // - Candado gris: rango aún no alcanzado.
  //
  // Al pie del modal se muestra el bloque "Cómo ganar XP" para que el
  // usuario entienda el sistema sin necesidad de pantallas adicionales.
  // ─────────────────────────────────────────────────────────────────────────
  void _showRankInfo(BuildContext context) {
    final List<Map<String, dynamic>> rangos = [
      {'title': 'Tapeador Amateur', 'xp': 0,    'icon': Icons.emoji_events_outlined},
      {'title': 'Aprendiz de Tapa', 'xp': 100,  'icon': Icons.emoji_events_outlined},
      {'title': 'Tapeador Experto', 'xp': 500,  'icon': Icons.stars},
      {'title': 'Experto Gourmet',  'xp': 1000, 'icon': Icons.stars},
      {'title': 'Rey de la Barra',  'xp': 2000, 'icon': Icons.workspace_premium},
      {'title': 'Leyenda del Tapeo','xp': 5000, 'icon': Icons.workspace_premium},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Pastilla indicadora de BottomSheet deslizable.
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Escalera de Rangos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tapea más para subir de rango',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),

            // Fila por cada rango con su estado visual diferenciado.
            ...rangos.map((rango) {
              final bool isActual = rango['title'] == rankTitle;
              final bool isDesbloqueado = xpTotal >= (rango['xp'] as int);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  // Fondo naranja suave para el rango actual, gris para el resto.
                  color: isActual ? Colors.orange[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActual
                        ? Colors.orange.withValues(alpha: 0.4)
                        : Colors.grey[200]!,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Icono del rango — naranja si desbloqueado, gris si bloqueado.
                    Icon(
                      rango['icon'] as IconData,
                      size: 20,
                      color: isDesbloqueado
                          ? AppColors.primary
                          : Colors.grey[300],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rango['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActual
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isActual
                                  ? AppColors.primary
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            '${rango['xp']} XP',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),

                    // Indicador de estado: badge "Actual", check verde o candado.
                    if (isActual)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Actual',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isDesbloqueado)
                      Icon(Icons.check_rounded,
                          color: Colors.green[400], size: 18)
                    else
                      Icon(Icons.lock_outline_rounded,
                          color: Colors.grey[300], size: 18),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // ── Bloque "Cómo ganar XP" ──
            // Situado en el BottomSheet de rangos porque es el contexto
            // mental correcto — el usuario ya está pensando en su progreso.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CÓMO GANAR XP',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Filas de las tres formas de ganar XP en TapeoGo.
                  _xpRow(Icons.gps_fixed_rounded,
                      'Check-in verificado por GPS', '+20 XP'),
                  _xpRow(Icons.location_off_rounded,
                      'Check-in sin verificar', '+5 XP'),
                  _xpRow(Icons.emoji_events_rounded,
                      'Desbloquear una medalla', '+XP bonus'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Texto resumen del XP restante — una sola vez al pie del modal.
            Text(
              _xpToNextLabel,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _xpRow
  // Fila reutilizable para el bloque "Cómo ganar XP" del BottomSheet.
  // Muestra icono corporativo, descripción de la acción y XP obtenido
  // alineado a la derecha para facilitar la comparación visual entre filas.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _xpRow(IconData icon, String label, String xp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          // Descripción de la acción — ocupa todo el espacio disponible.
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
          // XP obtenido — negrita para destacarlo frente a la descripción.
          Text(
            xp,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}