/// visit_model.dart
///
/// Modelo inmutable que mapea la tabla 'visits' de Supabase.
/// Representa cada check-in realizado por un usuario en un establecimiento.
///
/// Es la entidad transaccional principal de TapeoGo — cada visita
/// registrada alimenta el sistema de gamificación mediante
/// BadgeNotifier.updateAndCheckBadges(), que evalúa si el nuevo total
/// de visitas desbloquea alguna medalla pendiente.
///
/// barName y barAddress no son campos de 'visits' — se obtienen del
/// JOIN con 'bars' en fetchHistory y se usan solo para mostrar
/// información en el historial del perfil.

import 'package:flutter/foundation.dart';

@immutable
class VisitModel {
  final String id;          // UUID generado por Supabase
  final String userId;      // FK → tabla profiles
  final String barId;       // FK → tabla bars
  final String barName;     // Del JOIN bars(name) — no es columna de 'visits'
  final String? photoUrl;   // URL en Supabase Storage — null si no hay foto
  final String? comment;    // Comentario opcional del usuario
  final DateTime createdAt; // Marca temporal — formato ISO 8601
  final bool gpsVerified;   // true si el usuario estaba a menos de 100m del bar
  final String recordType;  // Tipo de tapa — clave del sistema de gamificación
  final String? barAddress; // Del JOIN bars(address) — para el historial

  const VisitModel({
    required this.id,
    required this.userId,
    required this.barId,
    required this.barName,
    this.photoUrl,
    this.comment,
    required this.createdAt,
    required this.gpsVerified,
    this.recordType = 'generic',
    this.barAddress,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // fromJson — deserialización Supabase → Dart
  // barName y barAddress se extraen del objeto anidado 'bars' del JOIN.
  // El operador ?. accede de forma segura — si la relación no resuelve
  // (bar eliminado de la BD) devuelve el valor por defecto sin lanzar excepción.
  // gpsVerified usa ?? false por seguridad — si falta el flag se asume
  // que la visita no está verificada para no validar check-ins dudosos.
  // ───────────────────────────────────────────────────────────────────────────

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id:          json['id'] as String,
      userId:      json['user_id'] as String,
      barId:       json['bar_id'] as String,
      barName:     json['bars']?['name'] as String? ?? 'Bar desconocido',
      photoUrl:    json['photo_url'] as String?,
      comment:     json['comment'] as String?,
      createdAt:   DateTime.parse(json['created_at'] as String),
      gpsVerified: json['gps_verified'] as bool? ?? false,
      recordType:  json['record_type'] as String? ?? 'generic',
      barAddress:  json['bars']?['address'] as String? ?? 'Ubicación no disponible',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // toJson — serialización Dart → Supabase
  // id y created_at se omiten — los genera PostgreSQL automáticamente.
  // barName y barAddress se omiten — no son columnas de 'visits',
  // son datos derivados del JOIN. Incluirlos causaría error en Supabase.
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'user_id':     userId,
      'bar_id':      barId,
      'photo_url':   photoUrl,
      'comment':     comment,
      'gps_verified': gpsVerified,
      'record_type': recordType,
    };
  }
}