/// badge_model.dart
///
/// Modelo inmutable que mapea la tabla 'badges' de Supabase.
/// Representa una medalla del catálogo de logros de TapeoGo.
///
/// @immutable garantiza que ningún campo se modifique después
/// de la construcción — si cambia algún dato se crea una instancia nueva.

import 'package:flutter/foundation.dart';

@immutable
class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int requirementCount;
  final int xpBonus;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.requirementCount,
    required this.xpBonus,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // fromJson — deserialización Supabase → Dart
  // Convierte el Map JSON de la API REST en un objeto BadgeModel.
  // El operador ?? proporciona valores por defecto para campos opcionales,
  // evitando excepciones si Supabase devuelve null en algún campo.
  // ───────────────────────────────────────────────────────────────────────────

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id:               json['id'] as String,
      name:             json['name'] as String? ?? 'Sin nombre',
      description:      json['description'] as String? ?? '',
      imageUrl:         json['image_url'] as String? ?? '',
      requirementCount: json['requirement_count'] as int? ?? 0,
      xpBonus:          json['xp_bonus'] as int? ?? 0,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // toJson — serialización Dart → Supabase
  // Convierte el objeto a Map para operaciones de escritura en la BD.
  // El id se omite porque Supabase lo genera automáticamente en los INSERT.
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'name':              name,
      'description':       description,
      'image_url':         imageUrl,
      'requirement_count': requirementCount,
      'xp_bonus':          xpBonus,
    };
  }
}