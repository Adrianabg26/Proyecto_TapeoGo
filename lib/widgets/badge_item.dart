/// badge_item.dart
///
/// Widget reutilizable que representa visualmente una medalla individual
/// en la pantalla de perfil del usuario.
///
/// Muestra el estado de la medalla mediante cambios visuales:
/// naranja y con sombra si está desbloqueada, gris y sin sombra
/// si todavía está bloqueada.
///
/// Es un StatelessWidget porque solo renderiza la información
/// que recibe como parámetros, sin gestionar estado propio.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class BadgeItem extends StatelessWidget {
  /// Nombre descriptivo de la medalla que se muestra bajo el icono.
  final String name;

  /// Indica si el usuario ha desbloqueado esta medalla.
  /// Controla el color, la sombra y el peso del texto.
  final bool isUnlocked;

  /// URL de la imagen de la medalla almacenada en Supabase Storage.
  /// Campo opcional: si es null se muestra el icono por defecto.
  final String? imageUrl;

  const BadgeItem({
    super.key,
    required this.name,
    required this.isUnlocked,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Círculo de la medalla con color y sombra según estado
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            // Naranja suave si desbloqueada, gris apagado si bloqueada
            color: isUnlocked ? Colors.orange[50] : Colors.grey[200],
            shape: BoxShape.circle,
            border: Border.all(
              color: isUnlocked ? Colors.orange : Colors.grey[400]!,
              width: 2,
            ),
            // Sombra sutil solo en medallas desbloqueadas para
            // reforzar visualmente la diferencia con las bloqueadas
            boxShadow: isUnlocked
                ? [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          // Si hay imagen en Supabase Storage la mostramos,
          // si no usamos el icono de trofeo por defecto
          child: imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    imageUrl!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    // Si la imagen falla por red mostramos el icono
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.emoji_events,
                      color: isUnlocked ? Colors.orange : Colors.grey[400],
                      size: 35,
                    ),
                  ),
                )
              : Icon(
                  Icons.emoji_events,
                  color: isUnlocked ? Colors.orange : Colors.grey[400],
                  size: 35,
                ),
        ),

        const SizedBox(height: 8),

        // Nombre de la medalla con protección contra textos largos.
        // maxLines y overflow evitan errores de Layout Overflow
        // si el nombre de una medalla es demasiado largo.
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
            color: isUnlocked ? AppColors.titleOrange : AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}