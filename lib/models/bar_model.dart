/// bar_model.dart
///
/// Modelo inmutable que mapea la tabla 'bars' de Supabase.
/// Es la entidad principal de TapeoGo — representa un establecimiento
/// gastronómico con su información descriptiva y coordenadas geográficas.
///
/// Las coordenadas (latitude, longitude) son el campo clave para
/// renderizar los marcadores en Google Maps mediante MapNotifier.
/// mainImageUrl, phone y openingHours son nullable porque no todos
/// los bares tienen imagen, teléfono u horario registrado.

import 'package:flutter/foundation.dart';

@immutable
class BarModel {
  final String id;              // UUID generado por Supabase
  final String name;
  final String district;        // Distrito — usado en filtros y medallas geográficas
  final String description;
  final String address;         // Dirección física para mostrar al usuario
  final String specialtyTapa;   // Tapa estrella — clave en el sistema de gamificación
  final double latitude;
  final double longitude;
  final String? mainImageUrl;   // Nullable — no todos los bares tienen imagen
  final String? phone;          // Nullable — teléfono de contacto del establecimiento
  final Map<String, String?>? openingHours; // Nullable — horario semanal en formato {lun: "11:00-23:30"}

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
    this.phone,
    this.openingHours,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // fromJson — deserialización Supabase → Dart
  // Convierte el Map JSON de la API REST en un objeto BarModel.
  // latitude y longitude se reciben como num (int o double según la BD)
  // y se convierten a double con toDouble() para compatibilidad con Google Maps.
  // openingHours llega como Map<String, dynamic> desde jsonb — se castea
  // a Map<String, String?> para tipar correctamente los valores de horario.
  // ───────────────────────────────────────────────────────────────────────────
  factory BarModel.fromJson(Map<String, dynamic> json) {
    // Parseo seguro del campo jsonb opening_hours.
    // Si el campo es null o no es un Map, openingHours queda null.
    Map<String, String?>? parsedHours;
    final hoursRaw = json['opening_hours'];
    if (hoursRaw is Map) {
      parsedHours = hoursRaw.map(
        (key, value) => MapEntry(key as String, value as String?),
      );
    }

    return BarModel(
      id:            json['id'] as String,
      name:          json['name'] as String? ?? 'Bar sin nombre',
      district:      json['district'] as String? ?? 'Sevilla',
      description:   json['description'] as String? ?? 'Descripción no disponible',
      address:       json['address'] as String? ?? 'Dirección no disponible',
      specialtyTapa: json['specialty_tapa'] as String? ?? 'Tapa por definir',
      latitude:      (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude:     (json['longitude'] as num?)?.toDouble() ?? 0.0,
      mainImageUrl:  json['main_image_url'] as String?,
      phone:         json['phone'] as String?,
      openingHours:  parsedHours,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // toJson — serialización Dart → Supabase
  // La tabla 'bars' es de solo lectura desde la app — el catálogo de bares
  // se gestiona desde el panel de administración de Supabase.
  // Este método se mantiene por completitud del modelo.
  // ───────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id':             id,
      'name':           name,
      'district':       district,
      'description':    description,
      'address':        address,
      'specialty_tapa': specialtyTapa,
      'latitude':       latitude,
      'longitude':      longitude,
      'phone':          phone,
      'opening_hours':  openingHours,
    };
  }
}