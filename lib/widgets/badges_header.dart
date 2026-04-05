/// badges_header.dart
///
/// Widget que muestra el título de la sección de logros y el contador
/// de medallas desbloqueadas sobre el total disponible en el catálogo.
///
/// Consume [BadgeNotifier] mediante context.watch para actualizarse
/// automáticamente cuando el usuario desbloquea una nueva medalla,
/// sin necesidad de recargar la pantalla manualmente.
///
/// Es un StatelessWidget porque no gestiona estado propio,
/// solo muestra los datos que recibe del notifier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/badge_notifier.dart';
import '../utils/app_colors.dart';

class BadgesHeader extends StatelessWidget {
  const BadgesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // context.watch establece un vínculo activo con BadgeNotifier.
    // Cada vez que el notifier llama a notifyListeners(), este widget
    // se reconstruye automáticamente con los datos actualizados.
    final badgeNotifier = context.watch<BadgeNotifier>();

    final int ganadas = badgeNotifier.myBadges.length;
    final int totales = badgeNotifier.allBadges.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        // spaceBetween empuja el título a la izquierda y el contador
        // a la derecha aprovechando todo el ancho disponible
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Mis Logros de Tapeo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.titleOrange,
            ),
          ),

          // Burbuja de progreso con el contador ganadas/totales.
          // Usamos Container con BoxDecoration para crear este elemento
          // personalizado ya que no existe como widget nativo en Flutter.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Text(
              '$ganadas / $totales',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}