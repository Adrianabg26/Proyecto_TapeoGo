/// auth_notifier.dart
///
/// Gestor de Estado Global para la autenticación y el perfil de usuario
/// en TapeoGo. Extiende [ChangeNotifier] para integrarse con el sistema
/// de gestión de estado de la aplicación mediante el patrón Observer.
///
/// Centraliza tres responsabilidades principales:
///   - Gestión del ciclo de vida de la sesión (registro, login, logout).
///   - Recuperación y mantenimiento del perfil extendido del usuario
///     desde la tabla 'profiles' de Supabase.
///   - Limpieza del estado global de todos los notifiers al cerrar sesión,
///     garantizando que ningún dato del usuario anterior sea visible
///     si otro usuario inicia sesión en el mismo dispositivo.

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

  // ───────────────────────────────────────────────────────────────────────────
  // GETTERS PÚBLICOS
  // ───────────────────────────────────────────────────────────────────────────

  User? get user => _user;
  ProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get currentUserId => _user?.id;

  // ───────────────────────────────────────────────────────────────────────────
  // REFERENCIAS A OTROS NOTIFIERS para limpiar su estado en logout.
  // Se inyectan desde fuera para evitar dependencias circulares.
  // ───────────────────────────────────────────────────────────────────────────

  BadgeNotifier? _badgeNotifier;
  FavoriteNotifier? _favoriteNotifier;
  MapNotifier? _mapNotifier;
  ProfileNotifier? _profileNotifier;
  VisitNotifier? _visitNotifier;
  WishlistNotifier? _wishlistNotifier;

  /// Registra las referencias a los notifiers que deben limpiarse
  /// al cerrar sesión. Se llama una vez al inicializar la app.
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

  // ───────────────────────────────────────────────────────────────────────────
  // CONSTRUCTOR
  // ───────────────────────────────────────────────────────────────────────────

  AuthNotifier() {
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;

      if (_user != null) {
        fetchProfile();
      } else {
        _profile = null;
        notifyListeners();
      }
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchProfile
  // ───────────────────────────────────────────────────────────────────────────

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
    } catch (e) {
      debugPrint('Error al recuperar perfil: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: register (CU-01)
  // ───────────────────────────────────────────────────────────────────────────

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
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: login (CU-03)
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint('Error en la autenticación: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: logout (CU-02)
  // Cierra la sesión y limpia el estado de todos los notifiers para
  // evitar que los datos del usuario sean visibles tras el logout.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();

      // Limpiamos el estado de todos los notifiers.
      // onAuthStateChange limpia _user y _profile automáticamente,
      // pero los otros notifiers necesitan limpiarse explícitamente.
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

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateLocalXP
  // Actualiza el XP del perfil en memoria preservando todos los campos.
  // Se invoca desde BadgeNotifier tras desbloquear una medalla para
  // reflejar el nuevo rango en la UI de forma inmediata.
  // ───────────────────────────────────────────────────────────────────────────

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

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _setLoading
  // ───────────────────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}