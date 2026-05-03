/// bar_image.dart
///
/// Widget reutilizable que muestra la imagen de un establecimiento
/// cargada desde Supabase Storage mediante su URL pública.
///
/// Gestiona tres estados:
///   - URL válida: imagen con spinner de carga mientras descarga.
///   - URL nula o vacía: icono de restaurante por defecto sin descarga.
///   - Error de red: icono de imagen rota en lugar de espacio en blanco.
///
/// El parámetro size permite reutilizarlo en listas compactas
/// (FavoritesScreen, WishlistScreen) con el mismo componente visual.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class BarImage extends StatelessWidget {

  /// URL pública desde Supabase Storage.
  /// Nullable — si es null o vacía se muestra el icono por defecto
  /// sin intentar ninguna petición de red.
  final String? url;

  /// Tamaño en puntos lógicos aplicado a ancho y alto.
  /// Por defecto 80.0 para uso en tarjetas de lista.
  /// Permite reutilizar el widget en contextos de distintos tamaños.
  final double size;

  const BarImage({
    super.key,
    this.url,
    this.size = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Fondo naranja suave visible durante la carga o cuando no hay URL.
        // Mantiene la coherencia visual con la paleta corporativa de la app.
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: (url != null && url!.isNotEmpty)
          // ── URL válida: imagen con estados de carga y error ──
          ? ClipRRect(
              // ClipRRect recorta la imagen respetando el borderRadius
              // del Container para mantener las esquinas redondeadas.
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url!,
                fit: BoxFit.cover,
                // Spinner mientras la imagen se descarga desde Supabase Storage.
                // progress == null indica que la descarga ha completado.
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  );
                },
                // Si la imagen falla por error de red muestra un icono
                // informativo en lugar de dejar el espacio en blanco.
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  color: AppColors.primary,
                ),
              ),
            )
          // ── Sin URL: icono de restaurante por defecto ──
          // No realiza ninguna petición de red — evita errores innecesarios.
          : const Icon(
              Icons.restaurant,
              color: AppColors.primary,
            ),
    );
  }
}