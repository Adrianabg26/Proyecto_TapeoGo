/// badge_model.dart
///
/// Modelo de datos para la definición de medallas del sistema de
/// gamificación de TapeoGo.
/// Mapea la tabla 'badges' de Supabase/PostgreSQL, que actúa como
/// catálogo global de logros disponibles en la aplicación.

import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTIDAD: BadgeModel
// Mapea la tabla 'badges' de Supabase/PostgreSQL.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class BadgeModel {
  final String id; // Identificador único de la medalla.
  final String name; // Nombre de la medalla.
  final String description; // Descripción detallada de cómo se obtiene la medalla.
  final String imageUrl; // URL de la imagen de la medalla almacenada en Supabase Storage.
  final int requirementCount; // El número de hitos necesarios para desbloquearla.
  final int xpBonus; // Puntos de experiencia (XP) que se otorgan al usuario al desbloquear esta medalla.

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.requirementCount,
    required this.xpBonus,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DESERIALIZACIÓN: Supabase → Dart
  // Convierte el Map JSON recibido de la API REST de Supabase en un objeto
  // BadgeModel. Se aplican valores por defecto con '??' para evitar
  // excepciones de tipo nulo si algún campo opcional llega vacío.
  // ───────────────────────────────────────────────────────────────────────────

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sin nombre',
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      requirementCount: json['requirement_count'] as int? ?? 0,
      xpBonus: json['xp_bonus'] as int? ?? 0,
    );
  }
  // ───────────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN: Dart → Supabase
  // Convierte el objeto a un Map para operaciones de escritura en la BD.
  // Nota: el 'id' se omite en inserciones ya que Supabase lo genera
  // automáticamente (SERIAL/autoincrement).
  // ───────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'requirement_count': requirementCount,
      'xp_bonus': xpBonus,
    };
  }
}
