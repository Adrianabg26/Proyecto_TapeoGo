/// visit_notifier.dart
///
/// Gestiona el flujo completo del check-in en TapeoGo.
///
/// Coordina tres servicios externos en un pipeline de cinco pasos:
///   - GPS (Geolocator) para validar la presencia física del usuario.
///   - Supabase Storage para guardar la foto de la tapa (opcional).
///   - Supabase PostgreSQL para registrar la visita en la BD.
///
/// Tras cada check-in verificado por GPS activa el motor de gamificación
/// para comprobar si el usuario ha desbloqueado nuevas medallas.
///
/// La foto es opcional — enriquece el registro pero no lo condiciona.
/// El único requisito obligatorio es la verificación GPS.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bar_model.dart';
import '../models/visit_model.dart';
import '../models/badge_model.dart';
import 'profile_notifier.dart';
import 'badge_notifier.dart';
import 'auth_notifier.dart';

class VisitNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // _isProcessing en lugar de _isLoading porque el check-in es un pipeline
  // de cinco pasos secuenciales, no una simple carga de datos.
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  List<VisitModel> _visits = [];
  List<VisitModel> get visits => _visits;

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchHistory
  // Carga el historial de visitas del usuario con un JOIN a bars(name, address)
  // para obtener nombre y dirección de cada bar en una única petición —
  // evita el problema N+1 que ocurriría al consultar cada bar por separado.
  //
  // Las visitas se ordenan de más reciente a más antigua para que el
  // historial muestre siempre la última visita en la primera posición.
  //
  // Los errores se propagan con rethrow para que ProfileScreen los capture
  // y muestre el estado de error adecuado al usuario.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchHistory(String userId) async {
    _setLoading(true);

    try {
      final response = await _supabase
          .from('visits')
          .select('*, bars(name, address)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _visits = response.map((json) => VisitModel.fromJson(json)).toList();
      debugPrint('Historial cargado: ${_visits.length} visitas.');
    } catch (e) {
      debugPrint('Error al cargar historial: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: performCheckIn
  // Pipeline de cinco pasos secuenciales para registrar una visita.
  //
  // Paso 0 — Validación de duplicados: comprueba que el usuario no ha
  //   registrado ya la misma tapa en el mismo bar mediante maybeSingle().
  // Paso 1 — Verificación GPS: obtiene la posición actual y comprueba
  //   la proximidad al bar en un radio de 100 metros.
  // Paso 2 — Subida de foto (opcional): sube la imagen a Supabase Storage
  //   y obtiene la URL pública. Solo si el usuario seleccionó una imagen.
  // Paso 3 — Registro en BD: inserta la visita en la tabla 'visits' con
  //   todos los datos recopilados en los pasos anteriores.
  // Paso 4 — Gamificación: si el GPS está verificado, evalúa las condiciones
  //   de desbloqueo de medallas y actualiza el XP del perfil.
  // Paso 5 — Actualización optimista: inserta la visita al inicio del
  //   historial local para que aparezca sin recargar desde Supabase.
  //
  // Si cualquier paso falla se lanza excepción y el proceso se detiene,
  // evitando estados inconsistentes (foto subida sin visita registrada).
  //
  // Devuelve la lista de medallas nuevas para que CheckInScreen muestre
  // el AlertDialog y el ConfettiWidget de celebración.
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<BadgeModel>> performCheckIn({
    required BarModel bar,
    required String userId,
    required ProfileNotifier profileNotifier,
    required BadgeNotifier badgeNotifier,
    required AuthNotifier authNotifier,
    required String recordType,
    String? comment,
    File? imageFile,
  }) async {
    _setLoading(true);

    try {
      // ── PASO 0: Validación de duplicados ──
      // maybeSingle() devuelve null si no existe el registro, evitando
      // la excepción que lanzaría single() con cero resultados.
      // La restricción UNIQUE(user_id, bar_id, record_type) en PostgreSQL
      // actúa como segunda capa de seguridad ante condiciones de carrera.
      final existing = await _supabase
          .from('visits')
          .select('id')
          .eq('user_id', userId)
          .eq('bar_id', bar.id)
          .eq('record_type', recordType)
          .maybeSingle();

      if (existing != null) {
        throw 'Ya has registrado esta tapa en este bar. ¡Prueba otra!';
      }

      // ── PASO 1: Verificación GPS ──
      // Obtiene la posición actual y comprueba la proximidad al bar.
      // Si el GPS está desactivado o los permisos denegados se lanza
      // una excepción con mensaje descriptivo en español para la UI.
      final Position userPos = await _getCurrentLocation();
      final bool isGpsVerified = _checkProximity(userPos, bar);

      // ── PASO 2: Subida de foto a Supabase Storage (opcional) ──
      // Solo se ejecuta si el usuario seleccionó una imagen desde la
      // cámara o galería. La URL pública se guarda en la visita.
      final String? publicUrl =
          imageFile != null ? await _uploadTapaPhoto(userId, imageFile) : null;

      // ── PASO 3: Registro de la visita en la BD ──
      // Incluye gps_verified para que el motor de gamificación pueda
      // filtrar solo las visitas físicas reales.
      final VisitModel newVisit = await _saveVisitToDatabase(
        userId: userId,
        barId: bar.id,
        recordType: recordType,
        url: publicUrl,
        verified: isGpsVerified,
        comment: comment,
      );

      // ── PASO 4: Gamificación ──
      // Check-in con GPS verificado → +20 XP + evaluación de medallas.
      // Check-in sin GPS → +5 XP sin evaluación de medallas.
      // La distinción garantiza que los logros corresponden a visitas reales.
      // El XP lo suma el trigger de Supabase — no se gestiona en cliente.
      List<BadgeModel> nuevasMedallas = [];
      if (isGpsVerified) {
        nuevasMedallas = await badgeNotifier.updateAndCheckBadges(userId);
      } else {
        debugPrint('Visita sin GPS: el trigger de BD asignará 5 XP.');
      }

      // Refresca el perfil para mostrar el nuevo XP sumado por la BD.
      await authNotifier.fetchProfile();

      // ── PASO 5: Actualización optimista del historial local ──
      // Inserta al inicio de _visits para que aparezca en ProfileScreen
      // sin necesidad de recargar el historial completo desde Supabase.
      _visits.insert(0, newVisit);

      return nuevasMedallas;
    } catch (e) {
      debugPrint('Error en el check-in: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _getCurrentLocation
  // Gestiona el ciclo completo de permisos de ubicación y obtiene la
  // posición actual del dispositivo con precisión alta.
  //
  // Lanza excepciones con mensajes descriptivos en español para que
  // CheckInScreen las muestre directamente al usuario sin traducción.
  //
  // timeLimit: 15 segundos evita que el pipeline se bloquee indefinidamente
  // en dispositivos con señal GPS débil o en interiores.
  // ─────────────────────────────────────────────────────────────────────────
  Future<Position> _getCurrentLocation() async {
    // Comprueba si el servicio de localización está activo en el dispositivo.
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'El GPS está desactivado. Por favor, actívalo en los ajustes.';
    }

    // Comprueba y solicita permisos de ubicación si no están concedidos.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Permisos de ubicación denegados.';
      }
    }

    // deniedForever requiere que el usuario vaya a los ajustes del sistema.
    if (permission == LocationPermission.deniedForever) {
      throw 'Los permisos de ubicación están bloqueados en los ajustes del dispositivo.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _checkProximity
  // Calcula la distancia entre el usuario y el bar usando la fórmula
  // de Haversine, implementada internamente por el paquete Geolocator.
  //
  // El radio de 100 metros proporciona tolerancia suficiente para usuarios
  // en el interior o en la puerta del establecimiento, sin ser tan amplio
  // como para permitir check-ins fraudulentos desde lugares cercanos.
  // ─────────────────────────────────────────────────────────────────────────
  bool _checkProximity(Position userPos, BarModel bar) {
    final double distance = Geolocator.distanceBetween(
      userPos.latitude,
      userPos.longitude,
      bar.latitude,
      bar.longitude,
    );

    debugPrint('Distancia al bar: ${distance.toStringAsFixed(2)} metros.');
    return distance < 100; // Radio de validación: 100 metros
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _uploadTapaPhoto
  // Sube la foto de la tapa al bucket 'tapas_photos' de Supabase Storage.
  //
  // La ruta visits/{userId}/{timestamp}.jpg organiza las fotos por usuario
  // y garantiza unicidad del nombre mediante el timestamp en milisegundos,
  // evitando colisiones entre fotos del mismo usuario.
  //
  // Las Storage Policies de Supabase garantizan que cada usuario solo puede
  // acceder a su propia carpeta — coherente con las políticas RLS de la BD.
  //
  // Devuelve la URL pública para persistirla en la columna photo_url de 'visits'.
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> _uploadTapaPhoto(String userId, File file) async {
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String storagePath = 'visits/$userId/$fileName';

    await _supabase.storage.from('tapas_photos').upload(storagePath, file);
    return _supabase.storage.from('tapas_photos').getPublicUrl(storagePath);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _saveVisitToDatabase
  // Inserta la visita en la tabla 'visits' y devuelve el registro completo
  // con un JOIN a bars(name, address) para construir el VisitModel sin
  // una segunda consulta a Supabase.
  //
  // photo_url y comment son opcionales — se incluyen en el INSERT solo si
  // no son null, respetando el esquema nullable de la BD y evitando
  // insertar valores nulos explícitos que ocupan espacio innecesario.
  // ─────────────────────────────────────────────────────────────────────────
  Future<VisitModel> _saveVisitToDatabase({
    required String userId,
    required String barId,
    required String recordType,
    String? url,
    required bool verified,
    String? comment,
  }) async {
    final Map<String, dynamic> data = {
      'user_id': userId,
      'bar_id': barId,
      'record_type': recordType,
      'gps_verified': verified,
      // Campos opcionales — solo se incluyen si tienen valor.
      if (url != null) 'photo_url': url,
      if (comment != null) 'comment': comment,
    };

    final response = await _supabase
        .from('visits')
        .insert(data)
        .select('*, bars(name, address)')
        .single();

    return VisitModel.fromJson(response);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearVisits
  // Limpia el historial en memoria al cerrar sesión.
  // Se invoca desde AuthNotifier.logout() para garantizar que el historial
  // del usuario anterior no es visible si otro usuario inicia sesión
  // en el mismo dispositivo.
  // ─────────────────────────────────────────────────────────────────────────
  void clearVisits() {
    _visits = [];
    notifyListeners();
  }

  // Actualiza _isProcessing y notifica a los widgets suscritos.
  void _setLoading(bool value) {
    _isProcessing = value;
    notifyListeners();
  }
}