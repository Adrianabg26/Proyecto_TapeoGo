/// favorite_model.dart
///
/// Modelo inmutable que mapea la tabla 'favorites' de Supabase.
/// Representa la relación entre un usuario y un bar marcado como favorito.
///
/// Es una entidad débil — solo tiene sentido en combinación con
/// un usuario (user_id) y un bar (bar_id).
///
/// barData contiene los datos del bar obtenidos mediante JOIN en Supabase.
/// Se usa en FavoriteNotifier para construir el BarModel sin una segunda
/// consulta — evitando el problema N+1.

import 'package:flutter/foundation.dart';

@immutable
class FavoriteModel {
  final String id;
  final String userId;  // FK → tabla profiles
  final String barId;   // FK → tabla bars
  final DateTime addedAt;

  // Datos del bar obtenidos del JOIN select('*, bars(*)')
  // Nullable porque en inserciones no viene el JOIN.
  final Map<String, dynamic>? barData;

  const FavoriteModel({
    required this.id,
    required this.userId,
    required this.barId,
    required this.addedAt,
    this.barData,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // fromJson — deserialización Supabase → Dart
  // El campo 'bars' viene del JOIN y contiene todos los datos del bar.
  // Se guarda en barData para que FavoriteNotifier construya el BarModel.
  // ───────────────────────────────────────────────────────────────────────────

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id:      json['id'] as String,
      userId:  json['user_id'] as String,
      barId:   json['bar_id'] as String,
      addedAt: DateTime.parse(json['created_at'] as String),
      barData: json['bars'] as Map<String, dynamic>?,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // toJson — serialización Dart → Supabase
  // Solo se envían user_id y bar_id en el INSERT.
  // id lo genera Supabase automáticamente (UUID).
  // created_at usa DEFAULT now() en PostgreSQL.
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bar_id':  barId,
    };
  }
}