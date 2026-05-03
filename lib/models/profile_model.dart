/// profile_model.dart
///
/// Modelo inmutable que mapea la tabla 'profiles' de Supabase.
/// Extiende la información del usuario más allá de las credenciales
/// gestionadas por Supabase Auth.
///
/// El email no forma parte de este modelo — lo gestiona Supabase Auth
/// y se accede mediante AuthNotifier._user?.email, evitando duplicidad.
///
/// Sigue el principio Single Source of Truth: la lógica de gamificación
/// (rango, nivel, progreso) reside en el modelo mediante getters calculados.
/// Cualquier pantalla que tenga el perfil puede mostrar estos valores
/// sin duplicar la lógica de cálculo.

import 'package:flutter/foundation.dart';

@immutable
class ProfileModel {
  final String id;          // UUID — FK → auth.users de Supabase
  final String username;    // Nombre público en TapeoGo
  final String fullName;    // Nombre completo para personalización de la UI
  final String? avatarUrl;  // URL en Supabase Storage — null si no hay foto
  final DateTime? updatedAt;
  final int xpTotal;        // XP acumulado — determina rango y nivel

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
  // Calcula el rango del usuario a partir de su xpTotal.
  // Los umbrales deben estar sincronizados con _xpToNextLabel
  // de ProfileHeader y _showRankInfo de ProfileHeader.
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
  // Calcula el nivel numérico a partir del XP total.
  // Cada 500 XP equivale a un nivel, empezando desde el nivel 1.
  // Ejemplo: 0 XP = nivel 1 · 500 XP = nivel 2 · 1000 XP = nivel 3
  // ───────────────────────────────────────────────────────────────────────────

  int get userLevel => (xpTotal / 500).floor() + 1;

  // ───────────────────────────────────────────────────────────────────────────
  // GETTER: xpProgress
  // Progreso dentro del nivel actual — valor entre 0.0 y 1.0.
  // Alimenta directamente el LinearProgressIndicator de ProfileHeader.
  // Ejemplo: 750 XP → nivel 2 (rango 500-1000) → progreso = 250/500 = 0.5
  // ───────────────────────────────────────────────────────────────────────────

  double get xpProgress => (xpTotal % 500) / 500;

  // ───────────────────────────────────────────────────────────────────────────
  // fromJson — deserialización Supabase → Dart
  // xpTotal usa toInt() porque Supabase puede devolverlo como num.
  // updatedAt es nullable — puede no existir en perfiles recién creados.
  // ───────────────────────────────────────────────────────────────────────────

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id:        json['id'] as String,
      username:  json['username'] as String? ?? 'Usuario',
      fullName:  json['full_name'] as String? ?? 'Nombre no disponible',
      avatarUrl: json['avatar_url'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      xpTotal: (json['xp_total'] as num?)?.toInt() ?? 0,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // toJson — serialización Dart → Supabase
  // id se omite — nunca debe modificarse desde la app.
  // updated_at lo gestiona PostgreSQL con DEFAULT now() automáticamente.
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'username':   username,
      'full_name':  fullName,
      'avatar_url': avatarUrl,
      'xp_total':   xpTotal,
    };
  }
}