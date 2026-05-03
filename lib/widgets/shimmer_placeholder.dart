/// shimmer_placeholder.dart
///
/// Widget reutilizable que muestra un esqueleto animado mientras
/// se cargan los datos desde Supabase.
///
/// Tiene dos constructores nombrados para los dos casos de uso:
///   - ShimmerPlaceholder.rectangular() — para textos y cajas.
///   - ShimmerPlaceholder.circular() — para avatares y medallas.
///
/// Siguiendo el principio DRY, este único componente se reutiliza
/// en FavoritesScreen, WishlistScreen y BadgesGrid sin duplicar
/// la lógica de animación en cada pantalla.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerPlaceholder extends StatelessWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  // Constructor para rectángulos — texto, cajas, imágenes de bar.
  // width por defecto double.infinity para ocupar todo el ancho disponible.
  const ShimmerPlaceholder.rectangular({
    super.key,
    this.width = double.infinity,
    required this.height,
  }) : shapeBorder = const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)));

  // Constructor para círculos — avatares y medallas.
  const ShimmerPlaceholder.circular({
    super.key,
    required this.width,
    required this.height,
  }) : shapeBorder = const CircleBorder();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      // baseColor es el fondo gris del esqueleto.
      // highlightColor es el destello que recorre el widget simulando carga.
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: Colors.grey[400]!,
          // shapeBorder determina si el esqueleto es rectangular o circular
          // según el constructor que se haya usado al instanciar el widget.
          shape: shapeBorder,
        ),
      ),
    );
  }
}