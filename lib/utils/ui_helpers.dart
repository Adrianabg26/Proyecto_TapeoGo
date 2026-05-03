/// ui_helpers.dart
///
/// Utilidades estáticas de UI reutilizables en toda la aplicación.
///
/// Centraliza elementos visuales comunes que se repiten en múltiples
/// pantallas, evitando duplicar código y garantizando coherencia visual.
/// Actualmente utilizado en los placeholders de imagen de HomeMapScreen
/// y BarDetailsScreen para mantener la identidad de marca cuando un
/// establecimiento no tiene foto disponible.

import 'package:flutter/material.dart';
import 'app_colors.dart';

class UIHelpers {

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO ESTÁTICO: buildDecorativeIcon
  // Genera un icono decorativo rotado y posicionado para usar como
  // elemento de fondo en los placeholders de imagen.
  //
  // Debe usarse dentro de un Stack con clipBehavior: Clip.hardEdge para
  // que los iconos que sobresalen por los bordes queden recortados
  // correctamente sin desbordarse fuera del contenedor.
  //
  // Parámetros:
  // - [icon]: icono de Material Design a renderizar.
  // - [size]: tamaño del icono en puntos lógicos.
  // - [angle]: ángulo de rotación en radianes (positivo = horario).
  // - [top], [left], [right], [bottom]: posición dentro del Stack padre.
  // - [color]: color del icono. Por defecto naranja corporativo con
  //   opacidad muy baja (0.06) para que sea sutil y no distraiga.
  //
  // Ejemplo de uso en _barImagePlaceholder:
  //   UIHelpers.buildDecorativeIcon(
  //     icon: Icons.wine_bar_rounded,
  //     size: 90, angle: -0.3,
  //     bottom: -5, right: -10,
  //   )
  // ─────────────────────────────────────────────────────────────────────────
  static Widget buildDecorativeIcon({
    required IconData icon,
    required double size,
    required double angle,
    double? top,
    double? left,
    double? right,
    double? bottom,
    Color? color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.rotate(
        angle: angle,
        child: Icon(
          icon,
          size: size,
          // Naranja corporativo con opacidad muy baja por defecto —
          // sutil para no competir visualmente con el contenido central.
          color: color ?? AppColors.primary.withValues(alpha: 0.06),
        ),
      ),
    );
  }
}