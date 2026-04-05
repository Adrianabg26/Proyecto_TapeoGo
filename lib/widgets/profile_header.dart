/// profile_header.dart
///
/// Widget de presentación que muestra la cabecera del perfil del usuario
/// con su avatar, nombre, rango, nivel y barra de progreso de XP.
///
/// Recibe todos los datos ya procesados como parámetros para mantener
/// la separación entre la lógica de negocio y la presentación visual.
/// La pantalla de perfil es responsable de calcular y pasar estos valores.
///
/// Es un StatelessWidget porque no gestiona estado propio.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class ProfileHeader extends StatelessWidget {
  /// Nombre completo del usuario para el título principal.
  final String fullName;

  /// Nombre de usuario para el subtítulo con arroba.
  final String username;

  /// Nivel numérico calculado a partir del XP total.
  final int level;

  /// Título del rango actual (ej: 'Tapeador Experto').
  final String rankTitle;

  /// XP total acumulado para mostrar bajo la barra de progreso.
  final int xpTotal;

  /// Progreso hacia el siguiente nivel, valor entre 0.0 y 1.0.
  final double xpProgress;

  /// URL del avatar del usuario almacenado en Supabase Storage.
  /// Opcional: si es null se muestra el icono de persona por defecto.
  final String? avatarUrl;

  const ProfileHeader({
    super.key,
    required this.fullName,
    required this.username,
    required this.level,
    required this.rankTitle,
    required this.xpTotal,
    required this.xpProgress,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
      child: Row(
        children: [
          // Avatar con anillo de color según el rango del usuario.
          // El container exterior actúa como borde dinámico cuyo color
          // cambia según el rango para reforzar la progresión visual.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _getRankColor(rankTitle),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 35,
                backgroundColor: Colors.orange[50],
                // Si el usuario tiene foto de perfil la mostramos,
                // si no usamos el icono de persona por defecto
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 45, color: Colors.orange)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.titleOrange,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@$username',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _buildLevelBadge(level),
                    const SizedBox(width: 8),
                    _buildRankBadge(rankTitle),
                  ],
                ),
                const SizedBox(height: 15),

                _buildProgressBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SUB-WIDGETS PRIVADOS
  // Se extraen como métodos separados para mantener el método build
  // limpio y legible, evitando un árbol de widgets demasiado profundo.
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildLevelBadge(int lvl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'NIVEL $lvl',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRankBadge(String rank) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRankIcon(rank),
        const SizedBox(width: 4),
        Text(
          rank,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.subtitleOrange,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: xpProgress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '$xpTotal XP acumulados',
          style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODOS DE APOYO: Lógica visual de rangos
  // Determinan el icono y el color según el rango del usuario.
  // Se mantienen sincronizados con los seis rangos definidos en
  // el getter userRank de ProfileModel.
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildRankIcon(String rank) {
    IconData icon;
    Color color;

    switch (rank) {
      case 'Leyenda del Tapeo':
        icon = Icons.workspace_premium;
        color = const Color(0xFFFFD700);
        break;
      case 'Rey de la Barra':
        icon = Icons.workspace_premium;
        color = const Color(0xFFFFD700);
        break;
      case 'Experto Gourmet':
        icon = Icons.stars;
        color = const Color(0xFFC0C0C0);
        break;
      case 'Tapeador Experto':
        icon = Icons.stars;
        color = const Color(0xFFC0C0C0);
        break;
      case 'Aprendiz de Tapa':
        icon = Icons.emoji_events_outlined;
        color = const Color(0xFFCD7F32);
        break;
      default:
        // Tapeador Amateur — rango inicial
        icon = Icons.emoji_events_outlined;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 18);
  }

  Color _getRankColor(String rank) {
    if (rank == 'Leyenda del Tapeo') return const Color(0xFFFFD700);
    if (rank == 'Rey de la Barra') return const Color(0xFFFFD700);
    if (rank == 'Experto Gourmet') return const Color(0xFFC0C0C0);
    if (rank == 'Tapeador Experto') return const Color(0xFFC0C0C0);
    if (rank == 'Aprendiz de Tapa') return const Color(0xFFCD7F32);
    return Colors.orange;
  }
}