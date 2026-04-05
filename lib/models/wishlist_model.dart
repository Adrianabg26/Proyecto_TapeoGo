/// wishlist_model.dart
///
/// Modelo de datos para la entidad de planificación de TapeoGo.
/// Mapea la tabla 'wishlist' de Supabase/PostgreSQL, que actúa como
/// entidad débil para gestionar los establecimientos marcados como
/// "Pendientes" para futuras visitas.
///
/// Representa la relación denominada "Guarda" en el diagrama E/R de
/// la memoria. Su existencia depende de la concurrencia de un perfil
/// válido y un bar válido en el sistema, por lo que no tiene sentido
/// como entidad autónoma.

import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTIDAD: WishlistModel
// Mapea la tabla 'wishlist' de Supabase/PostgreSQL.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class WishlistModel {
  final String id; // Identificador único del registro de pendiente (UUID generado por Supabase).
  final String userId; // UUID del usuario propietario de la lista de pendientes. Referencia a 'profiles.id'.
  final String barId; // UUID del establecimiento guardado para futura visita. Referencia a 'bars.id'.
  final DateTime createdAt; // Fecha de inclusión del bar en la lista de pendientes.
  // Permite ordenar la lista cronológicamente, mostrando al usuario
  /// sus planes más recientes primero.

  const WishlistModel({
    required this.id,
    required this.userId,
    required this.barId,
    required this.createdAt,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DESERIALIZACIÓN: Supabase → Dart
  // Convierte el Map JSON recibido de la API REST de Supabase en un objeto
  // WishlistModel.
  // ───────────────────────────────────────────────────────────────────────────

  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    return WishlistModel(
      // Todos los ids de esta tabla son UUID, cast directo seguro.
      id: json['id'] as String,
      userId: json['user_id'] as String,
      barId: json['bar_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String), // DateTime.parse interpreta el formato ISO 8601 que devuelve Supabase
      // para los campos de tipo 'timestamptz'.
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN: Dart → Supabase
  // Solo se envían 'user_id' y 'bar_id' en la inserción. El campo 'id'
  // lo genera Supabase automáticamente (UUID) y 'created_at' se establece
  // con DEFAULT now() en PostgreSQL.
  // Este método se invoca desde WishlistNotifier.addToWishlist(barId)
  // cuando el usuario pulsa el botón "Añadir a Pendientes" en la
  // pantalla de detalles del bar (BarDetailsScreen).
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bar_id': barId,
    };
  }
}