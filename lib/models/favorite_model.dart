/// favorite_model.dart
///
/// Modelo de datos para la entidad de fidelización de TapeoGo.
/// Mapea la tabla 'favorites' de Supabase/PostgreSQL, que actúa como
/// entidad débil para gestionar los establecimientos destacados por el
/// usuario como preferidos.
///
/// Su existencia depende de la concurrencia de un perfil y un bar,
/// por lo que no tiene sentido sin ambas entidades referenciadas

import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTIDAD: FavoriteModel
// Mapea la tabla 'favorites' de Supabase/PostgreSQL.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class FavoriteModel {
  final String id; // Identificador único de la relación (UUID generado por Supabase)
  final String userId; // Clave Foránea (FK) que referencia al usuario que marca el favorito
  final String barId; // Clave Foránea (FK) que referencia al bar marcado como favorito
  final DateTime addedAt; // Fecha de creación del registro, usada para ordenación cronológica descendente en la lista 'Mis Favoritos' del perfil de usuario.

  const FavoriteModel({
    required this.id,
    required this.userId,
    required this.barId,
    required this.addedAt,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DESERIALIZACIÓN: Supabase → Dart
  // Convierte el Map JSON recibido de la API REST de Supabase en un objeto
  // FavoriteModel. Las claves foráneas 'user_id' y 'bar_id' conectan esta
  // tabla con 'profiles' y 'bars' respectivamente, resolviendo la relación
  // de personalización del usuario (ver Diagrama E/R).
  // ───────────────────────────────────────────────────────────────────────────

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      barId: json['bar_id'] as String,
      addedAt: DateTime.parse(json['created_at'] as String),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN: Dart → Supabase
  // Solo se envían user_id y bar_id en la inserción. El campo 'id' lo genera
  // Supabase automáticamente (UUID) y 'added_at' se establece con
  // DEFAULT now() en PostgreSQL, por lo que incluirlos provocaría un error
  // de constraint o sobreescritura no deseada.
  // Este método se invoca cuando el usuario pulsa el botón de favorito en
  // la pantalla de detalles del bar.
  // ───────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bar_id': barId,
    };
  }
}