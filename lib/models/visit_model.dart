/// visit_model.dart
///
/// Modelo de datos para la entidad transaccional principal de TapeoGo.
/// Mapea la tabla 'visits' de Supabase/PostgreSQL, que registra cada
/// check-in realizado por un usuario en un establecimiento.
///
/// Es la entidad más importante del flujo operativo de la aplicación:
/// cada visita registrada alimenta el sistema de gamificación mediante
/// BadgeNotifier.checkAchievements(), que verifica si el nuevo total
/// de visitas desbloquea alguna medalla pendiente.


import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTIDAD: VisitModel
// Mapea la tabla 'visits' de Supabase/PostgreSQL.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class VisitModel {
  final String id; // Identificador único de la visita (UUID generado por Supabase).
  final String userId; // UUID del usuario que realiza el check-in. Referencia a 'profiles.id'.
  final String barId; // UUID del establecimiento visitado. Referencia a 'bars.id'.
  final String barName; // Nombre del establecimiento,
  final String? photoUrl; // URL de la imagen capturada como evidencia visual de la tapa consumida.
  // Almacenada en Supabase Storage y optimizada antes de la subida mediante Flutter Image Compress.
  // Campo opcional: puede ser null si la subida de imagen falla por red.
  final String? comment; // Comentario o reseña breve del usuario sobre la visita.
  // Campo opcional: el usuario puede hacer check-in sin comentario.
  final DateTime createdAt;  // Marca temporal de la visita para ordenación cronológica del historial.
  final bool gpsVerified;
  // Flag de control que confirma que el usuario se encontraba en un
  // radio de proximidad válido respecto al establecimiento en el momento del registro.
  final String recordType; // Tipo de registro del check-in, permite categorizar visitas.
  

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
  });

  // ───────────────────────────────────────────────────────────────────────────
  // DESERIALIZACIÓN: Supabase → Dart
  // Implementa extracción de datos relacionales anidados. 
  // El operador '?.' accede de forma segura al objeto anidado 'bars',
  // devolviendo 'Bar desconocido' si la relación no resuelve correctamente.
  // ───────────────────────────────────────────────────────────────────────────

  factory VisitModel.fromJson(Map<String, dynamic> json) {
    return VisitModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      barId: json['bar_id'] as String,

      // Acceso seguro al objeto relacional anidado 'bars'.
      // Si la relación falla o el bar ha sido eliminado del dataset,
      // se devuelve un valor genérico para no romper la interfaz.
      barName: json['bars']?['name'] as String? ?? 'Bar desconocido',

      // photoUrl es opcional: puede ser null si la subida falló por red.
      photoUrl: json['photo_url'] as String?,
      comment: json['comment'] as String?,

      // DateTime.parse interpreta el formato ISO 8601 de Supabase.
      createdAt: DateTime.parse(json['created_at'] as String),

      // Protección contra nulos: si falta el flag de validación GPS,
      // se asume false por seguridad para no validar visitas dudosas.
      gpsVerified: json['gps_verified'] as bool? ?? false,
      recordType: json['record_type'] as String? ?? 'generic',
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN: Dart → Supabase
  // Se omiten 'id' y 'created_at' porque los genera automáticamente
  // PostgreSQL (UUID y DEFAULT now() respectivamente).
  // Se omite 'barName' porque no es un campo de la tabla 'visits' sino
  // un dato derivado de la relación con 'bars'. Incluirlo causaría
  // un error de columna inexistente en Supabase.
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'bar_id': barId,
      'photo_url': photoUrl,
      'comment': comment,
      'gps_verified': gpsVerified,
      'record_type': recordType,
    };
  }
}