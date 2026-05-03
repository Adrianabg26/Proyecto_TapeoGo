/// badges_grid.dart
///
/// Widget que organiza las medallas del catálogo en una cuadrícula
/// de tres columnas en la pestaña de medallas del perfil.
///
/// Gestiona tres estados:
///   - Carga: shimmer con 9 círculos — forma exacta de las medallas reales.
///   - Vacío: mensaje informativo si no hay medallas en el catálogo.
///   - Con datos: grid responsive calculado con LayoutBuilder.
///
/// Es un StatelessWidget porque no gestiona estado propio —
/// consume el estado de BadgeNotifier mediante context.watch.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/badge_notifier.dart';
import '../widgets/shimmer_placeholder.dart';
import 'badge_item.dart';

class BadgesGrid extends StatelessWidget {
  final VoidCallback onGoToExplore;

  const BadgesGrid({super.key, required this.onGoToExplore});

  @override
  Widget build(BuildContext context) {
    // context.watch suscribe este widget a BadgeNotifier.
    // Cuando se desbloquea una medalla nueva el grid se reconstruye
    // automáticamente mostrando el nuevo estado sin acción del usuario.
    final badgeNotifier = context.watch<BadgeNotifier>();
    final allBadges = badgeNotifier.allBadges;
    final myBadges = badgeNotifier.myBadges;

    // ── Estado de carga ──
    // 9 shimmer placeholders con la forma exacta de las medallas reales.
    // Reduce la sensación de espera frente a un spinner genérico —
    // el usuario percibe la estructura del contenido antes de que llegue.
    if (badgeNotifier.isLoading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.9,
        ),
        itemCount: 9,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Círculo shimmer que imita el tamaño real de la medalla.
              ShimmerPlaceholder.circular(width: 62, height: 62),
              const SizedBox(height: 7),
              // Barra shimmer que imita el nombre de la medalla.
              ShimmerPlaceholder.rectangular(width: 55, height: 9),
            ],
          ),
        ),
      );
    }

    // ── Estado vacío ──
    // Solo ocurre si la tabla 'badges' de Supabase está vacía.
    // En producción no debería darse — el catálogo es fijo.
    if (allBadges.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'No hay medallas disponibles',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // ── Estado con datos: grid responsive ──
    // LayoutBuilder proporciona el ancho disponible en tiempo de ejecución
    // para calcular el tamaño de cada medalla de forma adaptativa.
    // Así el grid escala correctamente en cualquier tamaño de pantalla
    // sin necesidad de valores de tamaño fijos hardcodeados.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula el ancho de cada celda dividiendo el espacio disponible
        // entre las 3 columnas, descontando el padding lateral.
        final double cellWidth = (constraints.maxWidth - 16) / 3;

        // El círculo de la medalla ocupa el 62% del ancho de la celda
        // para dejar margen visual entre medallas adyacentes.
        final double circleSize = cellWidth * 0.62;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.9,
          ),
          itemCount: allBadges.length,
          itemBuilder: (context, index) {
            final badge = allBadges[index];

            // Cruza el catálogo completo con las medallas desbloqueadas
            // del usuario para determinar el estado visual de cada medalla.
            final bool isUnlocked =
                myBadges.any((ub) => ub.badgeId == badge.id);

            return BadgeItem(
              name: badge.name,
              imageUrl: badge.imageUrl,
              isUnlocked: isUnlocked,
              description: badge.description,
              requirementCount: badge.requirementCount,
              xpBonus: badge.xpBonus,
              circleSize: circleSize,
              onGoToExplore: onGoToExplore,
              // unlockedAt solo se pasa si la medalla está desbloqueada
              // para mostrar la fecha exacta en el modal de detalle.
              // Si está bloqueada se pasa null y el modal muestra
              // "Todavía no la has conseguido".
              unlockedAt: isUnlocked
                  ? myBadges
                      .firstWhere((ub) => ub.badgeId == badge.id)
                      .unlockedAt
                  : null,
            );
          },
        );
      },
    );
  }
}