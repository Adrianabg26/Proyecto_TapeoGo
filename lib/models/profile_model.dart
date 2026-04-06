/// profile_model.dart
///
/// Modelo de datos para la entidad central de identidad de TapeoGo.
/// Mapea la tabla 'profiles' de Supabase/PostgreSQL, que extiende la
/// información del usuario autenticado más allá de las credenciales
/// gestionadas por Supabase Auth.
///
/// El email del usuario no forma parte de este modelo ya que es gestionado
/// exclusivamente por Supabase Auth y es accesible en cualquier momento
/// a través de AuthNotifier mediante '_user?.email', evitando así
/// duplicidad de datos entre la tabla 'profiles' y el sistema de Auth.
///
/// Sigue el principio de Single Source of Truth: la lógica de gamificación
/// (cálculo de rango, nivel y progreso) reside en el propio modelo,
/// evitando duplicidad de código en la capa de presentación (UI).

import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTIDAD: ProfileModel
// Mapea la tabla 'profiles' de Supabase/PostgreSQL.
// Campos en BD: id (uuid FK → auth.users), username, full_name,
// avatar_url, updated_at, xp_total.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class ProfileModel {
  
  final String id;// UUID del usuario, vinculado directamente a 'auth.users' de Supabase.
  final String username; // Nombre de usuario público dentro de la comunidad TapeoGo.
  final String fullName; // Nombre y apellidos del usuario para personalización de la interfaz.
  final String? avatarUrl; // URL de la imagen de perfil almacenada en Supabase Storage.
  // Campo opcional: puede ser null si el usuario no ha subido foto.
  final DateTime? updatedAt;  // Fecha de la última modificación del perfil.

  // Puntos de experiencia acumulados por el usuario.
  /// Se incrementa al desbloquear medallas, sumando el 'xp_bonus'
  /// de cada [BadgeModel] obtenido. Determina el rango del usuario
  /// mediante el getter [userRank].
  final int xpTotal;

  const ProfileModel({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.updatedAt,
    this.xpTotal = 0,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // GETTER: userRank
  // Calcula el rango del usuario en tiempo real a partir de su xpTotal.
  // Al residir en el modelo y no en la UI, cualquier pantalla que tenga
  // acceso al perfil puede mostrar el rango sin duplicar esta lógica.
  // ───────────────────────────────────────────────────────────────────────────

  String get userRank {
    if (xpTotal >= 5000) return 'Leyenda del Tapeo';
    if (xpTotal >= 2000) return 'Rey de la Barra';
    if (xpTotal >= 1000) return 'Experto Gourmet';
    if (xpTotal >= 500)  return 'Tapeador Experto';
    if (xpTotal >= 100)  return 'Aprendiz de Tapa';
    return 'Tapeador Amateur';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // GETTER: userLevel
  // Calcula el nivel numérico del usuario a partir de su xpTotal.
  // Cada 500 XP equivale a un nivel, empezando desde el nivel 1.
  // Al residir en el modelo, cualquier pantalla puede mostrar el nivel
  // sin duplicar la fórmula de cálculo.
  // Ejemplo: 0 XP = nivel 1, 500 XP = nivel 2, 1000 XP = nivel 3.
  // ───────────────────────────────────────────────────────────────────────────

  int get userLevel => (xpTotal / 500).floor() + 1;

  // ───────────────────────────────────────────────────────────────────────────
  // GETTER: xpProgress
  // Calcula el progreso del usuario dentro de su nivel actual,
  // devolviendo un valor entre 0.0 y 1.0 para alimentar directamente
  // el LinearProgressIndicator de ProfileHeader.
  // Ejemplo: con 750 XP, el usuario está en nivel 2 (500-1000 XP).
  // El progreso dentro del nivel es (750 % 500) / 500 = 0.5 (50%).
  // ───────────────────────────────────────────────────────────────────────────

  double get xpProgress => (xpTotal % 500) / 500;

  // ───────────────────────────────────────────────────────────────────────────
  // DESERIALIZACIÓN: Supabase → Dart
  // ───────────────────────────────────────────────────────────────────────────

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'Usuario',
      fullName: json['full_name'] as String? ?? 'Nombre no disponible',
      avatarUrl: json['avatar_url'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      xpTotal: (json['xp_total'] as num?)?.toInt() ?? 0,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN: Dart → Supabase
  // Se omite 'id' ya que nunca debe modificarse desde la aplicación.
  // 'updated_at' lo gestiona automáticamente PostgreSQL con DEFAULT now().
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'xp_total': xpTotal,
    };
  }
}