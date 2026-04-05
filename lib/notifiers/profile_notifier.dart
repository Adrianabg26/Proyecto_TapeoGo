/// profile_notifier.dart
///
/// Gestiona el estado y la edición del perfil del usuario en TapeoGo.
/// Se diferencia de AuthNotifier en que su responsabilidad es la edición
/// de los datos del perfil como nombre, avatar y XP, mientras que
/// AuthNotifier gestiona el ciclo de vida de la sesión.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  ProfileModel? _currentProfile;
  ProfileModel? get currentProfile => _currentProfile;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchProfile
  // Recupera los datos del perfil desde la tabla 'profiles' usando el UUID
  // del usuario autenticado. Se invoca tras el login para cargar el perfil
  // completo con XP, rango y avatar en la pantalla de perfil.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> fetchProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      _currentProfile = ProfileModel.fromJson(data);
    } catch (e) {
      debugPrint('Error al recuperar datos del perfil: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateProfile
  // Actualiza el nombre y el avatar del usuario en Supabase y en memoria.
  // Es la razón principal de existencia de este notifier, diferenciándolo
  // de AuthNotifier que solo gestiona la sesión.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> updateProfile({
    required String userId,
    String? newFullName,
    String? newAvatarUrl,
  }) async {
    if (_currentProfile == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      // Actualizamos solo los campos que han cambiado
      final Map<String, dynamic> updates = {};
      if (newFullName != null) updates['full_name'] = newFullName;
      if (newAvatarUrl != null) updates['avatar_url'] = newAvatarUrl;

      if (updates.isEmpty) return;

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      // Actualizamos el estado local preservando todos los campos
      _currentProfile = ProfileModel(
        id: _currentProfile!.id,
        username: _currentProfile!.username,
        fullName: newFullName ?? _currentProfile!.fullName,
        avatarUrl: newAvatarUrl ?? _currentProfile!.avatarUrl,
        updatedAt: _currentProfile!.updatedAt,
        xpTotal: _currentProfile!.xpTotal,
      );
    } catch (e) {
      debugPrint('Error al actualizar perfil: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: addXP
  // Suma puntos de experiencia al perfil del usuario.
  // Sigue una lógica de dos pasos: primero persiste el nuevo valor en
  // Supabase y después actualiza el estado local para que la UI
  // muestre el nuevo XP y rango sin necesidad de recargar el perfil.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> addXP(int points) async {
    if (_currentProfile == null) return;

    final int newXP = _currentProfile!.xpTotal + points;

    try {
      // Persistencia en Supabase
      await _supabase
          .from('profiles')
          .update({'xp_total': newXP}).eq('id', _currentProfile!.id);

      // Actualización local preservando todos los campos del perfil
      _currentProfile = ProfileModel(
        id: _currentProfile!.id,
        username: _currentProfile!.username,
        fullName: _currentProfile!.fullName,
        avatarUrl: _currentProfile!.avatarUrl,
        updatedAt: _currentProfile!.updatedAt,
        xpTotal: newXP,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Fallo al actualizar XP: $e');
      rethrow;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearProfile
  // Limpia el perfil local al cerrar sesión para evitar que los datos
  // del usuario anterior sean visibles si otro usuario inicia sesión
  // en el mismo dispositivo.
  // Se invoca desde AuthNotifier.logout().
  // ───────────────────────────────────────────────────────────────────────────

  void clearProfile() {
    _currentProfile = null;
    notifyListeners();
  }
}