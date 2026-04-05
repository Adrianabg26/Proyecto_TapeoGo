/// user_badge_model.dart
///
/// Modelo de datos para la tabla intermedia 'user_badges' de TapeoGo.
/// Resuelve la relación N:M entre 'profiles' y 'badges' (ver Diagrama E/R),
/// registrando qué usuario ha desbloqueado qué medalla y en qué momento
/// exacto.
///
/// Es una entidad de asociación pura: su existencia depende de la
/// concurrencia de un perfil válido y una medalla válida en el sistema.

import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTIDAD: UserBadgeModel
// Mapea la tabla intermedia 'user_badges' de Supabase/PostgreSQL.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class UserBadgeModel {
  final String id; // Identificador único del registro de concesión del logro.
  final String userId; // UUID del usuario beneficiario del logro. Referencia a 'profiles.id'.
  final String badgeId; // ID de la medalla obtenida. Referencia a 'badges.id'.
  final DateTime unlockedAt; // Marca temporal exacta en la que se cumplieron los requisitos de desbloqueo.

  const UserBadgeModel({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.unlockedAt,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DESERIALIZACIÓN: Supabase → Dart
  // Transforma los tipos primitivos recibidos de la API REST de Supabase
  // en objetos complejos de Dart, permitiendo realizar cálculos temporales
  // o formateo de fechas en la interfaz de usuario.
  // ───────────────────────────────────────────────────────────────────────────

  factory UserBadgeModel.fromJson(Map<String, dynamic> json) {
    return UserBadgeModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      badgeId: json['badge_id'] as String,
      // DateTime.parse interpreta el formato ISO 8601 que devuelve Supabase
      // para los campos de tipo 'timestamptz'.
      unlockedAt: DateTime.parse(json['unlocked_at'] as String),
    );
  }
  // ───────────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN: Dart → Supabase
  // Solo se envían 'user_id' y 'badge_id' en la inserción. Los campos 'id'
  // y 'unlocked_at' los genera automáticamente el motor PostgreSQL de Supabase.
  // Este método se invoca desde BadgeNotifier.checkAchievements() cuando
  // el usuario cumple los requisitos de desbloqueo de una medalla.
  // ───────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'badge_id': badgeId,
    };
  }
}