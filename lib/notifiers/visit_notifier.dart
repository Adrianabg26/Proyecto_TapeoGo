/// visit_notifier.dart
///
/// Gestiona el flujo completo del check-in en TapeoGo.
/// Coordina tres servicios: GPS para validar la ubicación,
/// Supabase Storage para guardar la foto de la tapa, y
/// PostgreSQL para registrar la visita en la base de datos.
/// Tras cada check-in verificado, activa el motor de gamificación
/// para comprobar si el usuario ha desbloqueado nuevas medallas.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bar_model.dart';
import '../models/visit_model.dart';
import '../models/badge_model.dart';
import 'profile_notifier.dart';
import 'badge_notifier.dart';

class VisitNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  List<VisitModel> _visits = [];
  List<VisitModel> get visits => _visits;

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchHistory
  // Carga el historial de visitas del usuario desde Supabase.
  // Usa una consulta JOIN con 'bars(name)' para obtener el nombre del
  // bar en una sola petición, evitando consultas adicionales.
  // Las visitas se ordenan de más reciente a más antigua.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> fetchHistory(String userId) async {
    _setProcessing(true);

    try {
      final response = await _supabase
          .from('visits')
          .select('*, bars(name)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _visits = response.map((json) => VisitModel.fromJson(json)).toList();

      debugPrint('Historial cargado: ${_visits.length} visitas.');
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: performCheckIn
  // Coordina el proceso completo del check-in en cinco pasos secuenciales.
  // Si cualquier paso falla, el proceso se detiene para evitar
  // inconsistencias, por ejemplo subir una foto sin guardar la visita.
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<BadgeModel>> performCheckIn({
    required BarModel bar,
    required String userId,
    required ProfileNotifier profileNotifier,
    required BadgeNotifier badgeNotifier,
    required String recordType,
    String? comment,
    required File imageFile,
  }) async {
    _setProcessing(true);

    try {
      // PASO 0 — Validación previa
      // Comprobamos que la imagen existe antes de iniciar el proceso.
      if (!await imageFile.exists()) {
        throw 'La imagen seleccionada ya no existe en el dispositivo.';
      }

      // PASO 1 — Verificación de ubicación
      // El GPS es el primer filtro. Si el servicio está desactivado
      // o los permisos denegados, el proceso se detiene aquí.
      final Position userPos = await _getCurrentLocation();
      final bool isGpsVerified = _checkProximity(userPos, bar);

      // PASO 2 — Subida de la foto a Supabase Storage
      // La foto se sube antes de guardar la visita en la BD porque
      // necesitamos la URL pública para incluirla en el registro SQL.
      final String publicUrl = await _uploadTapaPhoto(userId, imageFile);

      // PASO 3 — Registro de la visita en la base de datos
      // Guardamos la visita con todos sus datos incluyendo la URL
      // de la foto y el resultado de la validación GPS.
      final VisitModel newVisit = await _saveVisitToDatabase(
        userId: userId,
        barId: bar.id,
        recordType: recordType,
        url: publicUrl,
        verified: isGpsVerified,
        comment: comment,
      );

      // PASO 4 — Gamificación: XP y medallas
      // Solo se otorga XP completo y se comprueban medallas si el
      // check-in está verificado por GPS, garantizando que los logros
      // corresponden a visitas físicas reales.
      // Los check-ins manuales reciben XP reducido como incentivo
      // pero no desbloquean medallas.
      List<BadgeModel> nuevasMedallas = [];
      if (isGpsVerified) {
        await profileNotifier.addXP(20);
        nuevasMedallas =await badgeNotifier.updateAndCheckBadges(userId);
      } else {
        await profileNotifier.addXP(5);
        debugPrint('Check-in manual: XP reducido, sin evaluación de medallas.');
      }

      // PASO 5 — Actualización local optimista
      // Insertamos la nueva visita al inicio de la lista local para
      // que aparezca en el historial sin necesidad de recargar todo.
      _visits.insert(0, newVisit);

      return nuevasMedallas;
    } catch (e) {
      debugPrint('Error en el check-in: $e');
      rethrow;
    } finally {
      _setProcessing(false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _getCurrentLocation
  // Gestiona los permisos de ubicación y obtiene la posición actual
  // del dispositivo con alta precisión. Lanza excepciones descriptivas
  // si el GPS está desactivado o los permisos están denegados para
  // que la UI pueda mostrar mensajes informativos al usuario.
  // ───────────────────────────────────────────────────────────────────────────

  Future<Position> _getCurrentLocation() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'El GPS está desactivado. Por favor, actívalo en los ajustes.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Permisos de ubicación denegados.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Los permisos de ubicación están bloqueados en los ajustes del dispositivo.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _checkProximity
  // Calcula la distancia entre el usuario y el bar usando la fórmula
  // de Haversine implementada por el paquete Geolocator.
  // El radio de validación es de 100 metros, que permite cierta
  // tolerancia para usuarios dentro o en la puerta del local.
  // ───────────────────────────────────────────────────────────────────────────

  bool _checkProximity(Position userPos, BarModel bar) {
    final double distance = Geolocator.distanceBetween(
      userPos.latitude,
      userPos.longitude,
      bar.latitude,
      bar.longitude,
    );

    debugPrint('Distancia al bar: ${distance.toStringAsFixed(2)} metros.');
    return distance < 100;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _uploadTapaPhoto
  // Sube la foto de la tapa al bucket 'tapas_photos' de Supabase Storage.
  // El nombre del archivo incluye el timestamp para garantizar unicidad
  // y evitar sobreescrituras entre fotos del mismo usuario.
  // Devuelve la URL pública necesaria para guardarla en la tabla 'visits'.
  // ───────────────────────────────────────────────────────────────────────────

  Future<String> _uploadTapaPhoto(String userId, File file) async {
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String storagePath = 'visits/$userId/$fileName';

    await _supabase.storage.from('tapas_photos').upload(storagePath, file);
    return _supabase.storage.from('tapas_photos').getPublicUrl(storagePath);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _saveVisitToDatabase
  // Inserta el registro de la visita en la tabla 'visits' y devuelve
  // el objeto completo con el JOIN de bars(name) para construir
  // el VisitModel sin necesidad de una segunda consulta.
  // ───────────────────────────────────────────────────────────────────────────

  Future<VisitModel> _saveVisitToDatabase({
    required String userId,
    required String barId,
    required String recordType,
    required String url,
    required bool verified,
    String? comment,
  }) async {
    final response = await _supabase.from('visits').insert({
      'user_id': userId,
      'bar_id': barId,
      'record_type': recordType,
      'photo_url': url,
      'gps_verified': verified,
      'comment': comment,
    }).select('*, bars(name)').single();

    return VisitModel.fromJson(response);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearVisits
  // Limpia el historial local al cerrar sesión para evitar que las
  // visitas del usuario anterior sean visibles en el mismo dispositivo.
  // Se invoca desde AuthNotifier.logout().
  // ───────────────────────────────────────────────────────────────────────────

  void clearVisits() {
    _visits = [];
    notifyListeners();
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }
}