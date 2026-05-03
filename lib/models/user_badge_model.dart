/// user_badge_model.dart
///
/// Modelo inmutable que mapea la tabla intermedia 'user_badges' de Supabase.
/// Resuelve la relación N:M entre 'profiles' y 'badges' del diagrama E/R:
/// un usuario puede tener muchas medallas y una medalla puede ser obtenida
/// por muchos usuarios.
///
/// Registra qué usuario ha desbloqueado qué medalla y en qué momento.
/// Es una entidad de asociación pura — solo tiene sentido con un
/// usuario válido y una medalla válida referenciados.

import 'package:flutter/foundation.dart';

@immutable
class UserBadgeModel {
  final String id;           // UUID generado por Supabase
  final String userId;       // FK → tabla profiles
  final String badgeId;      // FK → tabla badges
  final DateTime unlockedAt; // Marca temporal del desbloqueo — formato ISO 8601

  const UserBadgeModel({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.unlockedAt,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // fromJson — deserialización Supabase → Dart
  // DateTime.parse interpreta el formato ISO 8601 (timestamptz) que
  // devuelve Supabase para campos de tipo timestamp with time zone.
  // unlockedAt se usa en BadgeItem para mostrar la fecha de desbloqueo
  // en el modal de detalle de la medalla.
  // ───────────────────────────────────────────────────────────────────────────

  factory UserBadgeModel.fromJson(Map<String, dynamic> json) {
    return UserBadgeModel(
      id:         json['id'] as String,
      userId:     json['user_id'] as String,
      badgeId:    json['badge_id'] as String,
      unlockedAt: DateTime.parse(json['unlocked_at'] as String),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // toJson — serialización Dart → Supabase
  // Solo se envían user_id y badge_id en el INSERT.
  // id lo genera Supabase automáticamente (UUID).
  // unlocked_at usa DEFAULT now() en PostgreSQL.
  // Se invoca desde BadgeNotifier._checkAchievements() cuando el usuario
  // cumple los requisitos de desbloqueo de una medalla.
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'user_id':  userId,
      'badge_id': badgeId,
    };
  }
}