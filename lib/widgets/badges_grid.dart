/// badges_grid.dart
///
/// Widget que organiza y muestra todas las medallas del catálogo
/// en una cuadrícula de tres columnas en la pantalla de perfil.
///
/// Consume el estado de [BadgeNotifier] mediante context.watch
/// para reconstruirse automáticamente cuando cambia el estado
/// de las medallas, por ejemplo tras desbloquear una nueva.
///
/// Es un StatelessWidget porque no gestiona estado propio,
/// solo consume y muestra el estado del notifier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/badge_notifier.dart';
import 'badge_item.dart';

class BadgesGrid extends StatelessWidget {
  const BadgesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final badgeNotifier = context.watch<BadgeNotifier>();
    final allBadges = badgeNotifier.allBadges;
    final myBadges = badgeNotifier.myBadges;

    // Estado de carga: mientras el notifier consulta Supabase
    // mostramos un indicador visual para no dejar la pantalla en blanco
    if (badgeNotifier.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    // Estado vacío: el catálogo se cargó pero no hay medallas en la BD
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

    // Cuadrícula de medallas con 3 columnas
    return GridView.builder(
      // shrinkWrap permite que el Grid ocupe solo el espacio
      // que necesitan sus hijos en lugar de expandirse infinitamente
      shrinkWrap: true,
      // NeverScrollableScrollPhysics evita conflictos de scroll
      // cuando el Grid está dentro de un ListView o SingleChildScrollView
      // en la pantalla de perfil
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 25,
        crossAxisSpacing: 10,
        // childAspectRatio menor que 1 da más altura que anchura
        // a cada celda para que el texto del nombre no se corte
        childAspectRatio: 0.75,
      ),
      itemCount: allBadges.length,
      itemBuilder: (context, index) {
        final badge = allBadges[index];

        // Comprobamos si esta medalla está en la lista de medallas
        // desbloqueadas por el usuario comparando por ID
        final bool isUnlocked =
            myBadges.any((ub) => ub.badgeId == badge.id);

        // Delegamos el diseño visual a BadgeItem para no duplicar código.
        // Si en el futuro cambia el diseño de una medalla, solo hay
        // que modificar BadgeItem y el cambio aplica a toda la cuadrícula.
        return BadgeItem(
          name: badge.name,
          imageUrl: badge.imageUrl,
          isUnlocked: isUnlocked,
        );
      },
    );
  }
}