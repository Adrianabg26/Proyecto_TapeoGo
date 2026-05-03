/// auth_notifier.dart
///
/// Notifier central de autenticación y perfil de usuario en TapeoGo.
/// Extiende ChangeNotifier para integrarse con el patrón Provider.
///
/// Gestiona tres responsabilidades:
///   - Ciclo de vida de la sesión: registro, login y logout.
///   - Perfil extendido del usuario desde la tabla 'profiles' de Supabase.
///   - Limpieza del estado global al cerrar sesión, evitando que datos
///     de un usuario sean visibles si otro inicia sesión en el mismo dispositivo.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import 'badge_notifier.dart';
import 'favorite_notifier.dart';
import 'map_notifier.dart';
import 'profile_notifier.dart';
import 'visit_notifier.dart';
import 'wishlist_notifier.dart';

class AuthNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  ProfileModel? _profile;
  bool _isLoading = false;

  // Getters públicos — exponen el estado mínimo necesario a la UI.
  User? get user => _user;
  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get currentUserId => _user?.id;

  // Referencias a otros notifiers para coordinar la limpieza de estado en logout.
  // Se inyectan desde main.dart mediante registerNotifiers() para evitar
  // dependencias circulares en la construcción del árbol de Provider.
  BadgeNotifier? _badgeNotifier;
  FavoriteNotifier? _favoriteNotifier;
  MapNotifier? _mapNotifier;
  ProfileNotifier? _profileNotifier;
  VisitNotifier? _visitNotifier;
  WishlistNotifier? _wishlistNotifier;

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: registerNotifiers
  // Inyección de dependencias de los notifiers secundarios.
  // AuthNotifier necesita referencias a todos los notifiers para poder
  // invocar sus métodos clear*() al cerrar sesión y garantizar que
  // ningún dato del usuario anterior permanece en memoria.
  // ─────────────────────────────────────────────────────────────────────────
  void registerNotifiers({
    required BadgeNotifier badgeNotifier,
    required FavoriteNotifier favoriteNotifier,
    required MapNotifier mapNotifier,
    required ProfileNotifier profileNotifier,
    required VisitNotifier visitNotifier,
    required WishlistNotifier wishlistNotifier,
  }) {
    _badgeNotifier = badgeNotifier;
    _favoriteNotifier = favoriteNotifier;
    _mapNotifier = mapNotifier;
    _profileNotifier = profileNotifier;
    _visitNotifier = visitNotifier;
    _wishlistNotifier = wishlistNotifier;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONSTRUCTOR
  // Suscribe al stream de cambios de sesión de Supabase Auth.
  // onAuthStateChange emite un evento cada vez que el usuario inicia o
  // cierra sesión, permitiendo que la UI reaccione automáticamente sin
  // necesidad de polling ni comprobaciones manuales.
  // ─────────────────────────────────────────────────────────────────────────
  AuthNotifier() {
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        // Si hay sesión activa, carga el perfil extendido desde Supabase.
        fetchProfile();
      } else {
        // Si no hay sesión, limpia el perfil en memoria y notifica a la UI.
        _profile = null;
        notifyListeners();
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchProfile
  // Carga el perfil extendido del usuario desde la tabla 'profiles'.
  // Se invoca automáticamente al detectar una sesión activa y manualmente
  // después de actualizar el perfil para refrescar el estado en memoria.
  // Llama a ProfileNotifier.fetchProfile() para sincronizar el estado
  // de edición de perfil con los datos más recientes de Supabase.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchProfile() async {
    if (_user == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .single();

      _profile = ProfileModel.fromJson(data);
      notifyListeners();

      // Sincroniza ProfileNotifier con los datos recién cargados.
      await _profileNotifier?.fetchProfile(_user!.id);
    } catch (e) {
      debugPrint('Error al recuperar perfil: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateAvatar
  // Orquestador del flujo completo de actualización de foto de perfil.
  //
  // Flujo en tres pasos:
  // 1. Sube el archivo físico al bucket 'avatars' de Supabase Storage.
  //    El nombre incluye userId + timestamp para evitar conflictos de caché.
  // 2. Obtiene la URL pública del archivo subido.
  // 3. Persiste la URL en la tabla 'profiles' mediante updateProfile().
  //
  // upsert: true permite sobrescribir si ya existe un archivo con el mismo
  // nombre, aunque el timestamp lo hace prácticamente imposible.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> updateAvatar(String localPath) async {
    if (_user == null || _profile == null) return;

    try {
      _setLoading(true);

      // Construcción del nombre único del archivo en Storage.
      final file = File(localPath);
      final fileExt = localPath.split('.').last;
      final fileName =
          '${_user!.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      // Subida al bucket 'avatars' de Supabase Storage.
      await _supabase.storage.from('avatars').upload(
            filePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // Obtención de la URL pública para persistir en la tabla profiles.
      final String publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(filePath);

      // Persistencia en la tabla profiles reutilizando updateProfile().
      await updateProfile(
        fullName: _profile!.fullName,
        username: _profile!.username,
        avatarUrl: publicUrl,
      );
    } catch (e) {
      debugPrint('Error crítico en flujo de avatar: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: register
  // Registro de nuevo usuario mediante Supabase Auth.
  // Los datos adicionales (username, full_name) se pasan en el campo 'data'
  // para que el trigger de Supabase los inserte automáticamente en 'profiles'.
  // Los errores se traducen a mensajes legibles en español mediante
  // _traducirError() para mostrarlos directamente en la UI.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    _setLoading(true);
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
        },
      );
    } catch (e) {
      debugPrint('Error al registrar usuario: $e');
      throw Exception(_traducirError(e));
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: login
  // Autenticación con email y contraseña mediante Supabase Auth.
  // Al completarse con éxito, onAuthStateChange emite un evento que
  // dispara fetchProfile() automáticamente — no es necesario llamarlo aquí.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Error en la autenticación: $e');
      throw Exception(_traducirError(e));
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: logout
  // Cierre de sesión con limpieza doble de seguridad:
  // 1. Invalida el JWT en Supabase y lo elimina del almacenamiento seguro.
  // 2. Limpia el estado en memoria de todos los notifiers mediante sus
  //    métodos clear*(), garantizando que ningún dato del usuario anterior
  //    permanece accesible si otro usuario inicia sesión en el mismo dispositivo.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();

      // Limpieza coordinada del estado global de todos los notifiers.
      _badgeNotifier?.clearBadges();
      _favoriteNotifier?.clearFavorites();
      _mapNotifier?.clearBars();
      _profileNotifier?.clearProfile();
      _visitNotifier?.clearVisits();
      _wishlistNotifier?.clearWishlist();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateLocalXP
  // Actualiza el xp_total del perfil en memoria sin consultar Supabase.
  // Se invoca desde BadgeNotifier después de desbloquear una medalla para
  // que ProfileHeader refleje el nuevo XP de forma inmediata, aplicando
  // el principio de Single Source of Truth — el XP real sigue en Supabase.
  // ─────────────────────────────────────────────────────────────────────────
  void updateLocalXP(int nuevoXP) {
    if (_profile == null) return;
    _profile = ProfileModel(
      id: _profile!.id,
      username: _profile!.username,
      fullName: _profile!.fullName,
      avatarUrl: _profile!.avatarUrl,
      updatedAt: _profile!.updatedAt,
      xpTotal: nuevoXP,
    );
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateProfile
  // Actualiza nombre, username y avatar_url en la tabla 'profiles'.
  // avatar_url es opcional — solo se incluye en el UPDATE si se proporciona,
  // evitando sobreescribir la foto existente en actualizaciones de texto.
  // Llama a fetchProfile() al terminar para refrescar el estado en memoria.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> updateProfile({
    required String fullName,
    required String username,
    String? avatarUrl,
  }) async {
    if (_user == null) return;
    try {
      final Map<String, dynamic> updates = {
        'full_name': fullName,
        'username': username,
        'updated_at': DateTime.now().toIso8601String(),
        // avatar_url solo se incluye si se ha proporcionado un valor nuevo.
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      await _supabase.from('profiles').update(updates).eq('id', _user!.id);

      // Refresca el perfil en memoria con los datos actualizados de Supabase.
      await fetchProfile();
    } catch (e) {
      debugPrint('Error al actualizar perfil: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _traducirError
  // Convierte los códigos de error de Supabase Auth en mensajes legibles
  // en español para mostrar directamente al usuario en la UI.
  // Evita exponer mensajes técnicos en inglés en pantallas de login y registro.
  // ─────────────────────────────────────────────────────────────────────────
  String _traducirError(dynamic e) {
    final mensaje = e.toString();

    if (mensaje.contains('email_address_invalid')) {
      return 'El formato del email no es válido.';
    }
    if (mensaje.contains('over_email_send_rate_limit')) {
      return 'Demasiados intentos. Espera un momento.';
    }
    if (mensaje.contains('email_exists') ||
        mensaje.contains('already registered')) {
      return 'Este email ya está registrado.';
    }
    if (mensaje.contains('invalid_credentials')) {
      return 'Email o contraseña incorrectos.';
    }
    if (mensaje.contains('weak_password')) {
      return 'La contraseña es demasiado débil.';
    }
    if (mensaje.contains('network') || mensaje.contains('fetch')) {
      return 'Sin conexión. Comprueba tu internet.';
    }

    return 'Ha ocurrido un error. Inténtalo de nuevo.';
  }

  // Actualiza _isLoading y notifica a los widgets suscritos.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
