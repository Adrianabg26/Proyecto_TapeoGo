/// bar_model.dart
///
/// Modelo de datos para la entidad principal de TapeoGo.
/// Mapea la tabla 'bars' de Supabase/PostgreSQL, que actúa como el catálogo
/// de establecimientos gastronómicos disponibles en la aplicación.
///
/// Su función principal es proveer las coordenadas geográficas (latitude,
/// longitude) necesarias para renderizar los marcadores en el SDK de
/// Google Maps, además de la información descriptiva de cada local.

import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTIDAD: BarModel
// Mapea la tabla 'bars' de Supabase/PostgreSQL.
// ─────────────────────────────────────────────────────────────────────────────
@immutable
class BarModel {
  final String id; // Identificador único del establecimiento (UUID generado por Supabase)
  final String name; // Nombre del establecimiento
  final String district; // Distrito o zona donde se encuentra el bar. Permite filtar por ubicación.
  final String description; // Descripción breve del establecimiento
  final String address; // Dirección física legible para el usuario
  final String specialtyTapa; // Nombre de la tapa estrella recomendada por el bar
  final double latitude; // Latitud para la ubicación en el mapa
  final double longitude; // Longitud para la ubicación en el mapa
  final String? mainImageUrl; // Url de la imagen principal del establecimiento almacenada en Supabase Storage.

  const BarModel({
    required this.id,
    required this.name,
    required this.district,
    required this.description,
    required this.address,
    required this.specialtyTapa,
    required this.latitude,
    required this.longitude,
    this.mainImageUrl,
  });

// ───────────────────────────────────────────────────────────────────────────
  // DESERIALIZACIÓN: Supabase → Dart
  // Convierte el Map JSON recibido de la API REST de Supabase en un objeto
  // BarModel. Se aplica Null Safety mediante el operador de coalescencia
  // nula '??' para garantizar que la interfaz siempre tenga contenido que
  // mostrar, evitando errores de renderizado si algún campo llegara vacío.
  // ───────────────────────────────────────────────────────────────────────────

  factory BarModel.fromJson(Map<String, dynamic> json) {
    return BarModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Bar sin nombre',
      district: json['district'] ?? 'Sevilla',
      description: json['description'] as String? ?? 'Descripción no disponible',
      address: json['address'] as String? ?? 'Dirección no disponible',
      specialtyTapa: json['specialty_tapa'] as String? ?? 'Tapa por definir',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      mainImageUrl: json['main_image_url'] as String?, // Este campo es opcional
    );
  }

// ───────────────────────────────────────────────────────────────────────────
  // SERIALIZACIÓN: Dart → Supabase
  // El flujo principal de 'bars' es de lectura, ya que el dataset de
  // establecimientos se gestiona desde el panel de Supabase por el
  // administrador. Este método se mantiene para operaciones de actualización
  // o para futuras funcionalidades de alta de nuevos locales.
  // ───────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'district': district,
      'description': description,
      'address': address,
      'specialty_tapa': specialtyTapa,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
