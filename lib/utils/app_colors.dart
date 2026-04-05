/// app_colors.dart
///
/// Paleta de colores corporativa de TapeoGo.
/// Centraliza todos los colores del sistema de diseño en un único archivo
/// para garantizar consistencia visual en toda la app y facilitar
/// cambios futuros: modificar un color aquí lo aplica en todas las pantallas.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Naranja principal de marca. Color corporativo de TapeoGo.
  /// Usado en botones principales, iconos activos y elementos destacados.
  static const Color primary = Color(0xFFF97316);

  /// Naranja oscuro para títulos y nombres sobre fondo blanco.
  /// Cumple los estándares de contraste WCAG AA (ratio > 4.5:1).
  /// Usado en nombres de bares, títulos de sección y nombres de usuario.
  static const Color titleOrange = Color(0xFF92400E);

  /// Naranja medio para subtítulos y textos secundarios sobre fondo blanco.
  /// Usado en distritos, rangos y etiquetas secundarias.
  static const Color subtitleOrange = Color(0xFFC2410C);

  /// Naranja suave para fondos de cards, badges y contenedores.
  static const Color softOrange = Color(0xFFFFF7ED);

  /// Naranja de borde para contenedores y separadores.
  static const Color borderOrange = Color(0xFFFED7AA);

  /// Gris para textos secundarios como fechas, usernames y hints.
  static const Color textGrey = Color(0xFF9CA3AF);
}