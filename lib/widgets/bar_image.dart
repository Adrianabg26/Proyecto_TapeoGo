/// bar_image.dart
///
/// Widget reutilizable que muestra la imagen de un establecimiento
/// cargada desde Supabase Storage mediante su URL pública.
///
/// Gestiona tres estados posibles:
///   - URL válida: muestra la imagen con animación de carga.
///   - URL nula o vacía: muestra un icono de restaurante por defecto.
///   - Error de red: muestra un icono de imagen rota.
///
/// Es configurable en tamaño para reutilizarse tanto en listas
/// compactas como en la pantalla de detalles del bar.
///
/// Es un StatelessWidget porque no gestiona estado propio,
/// solo renderiza la imagen según la URL que recibe.

import 'package:flutter/material.dart';

class BarImage extends StatelessWidget {
  /// URL pública de la imagen almacenada en Supabase Storage.
  /// Opcional: si es null o vacía se muestra el icono por defecto.
  final String? url;

  /// Tamaño del widget en píxeles lógicos, aplicado a ancho y alto.
  /// Valor por defecto 80.0 para uso en listas. Se puede aumentar
  /// para la pantalla de detalles del bar.
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
        // Fondo naranja suave visible mientras carga la imagen
        // o cuando no hay URL disponible
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: (url != null && url!.isNotEmpty)
          ? ClipRRect(
              // ClipRRect recorta la imagen respetando el borderRadius
              // del Container para que las esquinas queden redondeadas
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url!,
                fit: BoxFit.cover,
                // Muestra un spinner mientras la imagen se descarga
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                // Si la imagen falla por red muestra un icono informativo
                // en lugar de dejar el espacio en blanco o romper el layout
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, color: Colors.orange),
              ),
            )
          // Si no hay URL muestra el icono de restaurante por defecto
          : const Icon(Icons.restaurant, color: Colors.orange),
    );
  }
}