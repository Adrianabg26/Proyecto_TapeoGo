/// profile_notifier.dart
///
/// Gestiona el estado del perfil extendido del usuario en TapeoGo.
///
/// Se diferencia de AuthNotifier en responsabilidad:
///   - AuthNotifier gestiona el ciclo de vida de la sesión (login/logout).
///   - ProfileNotifier gestiona la edición y actualización del perfil
///     (nombre, avatar, XP) y es consumido por pantallas que necesitan
///     estos datos sin depender directamente de AuthNotifier.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class ProfileNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  ProfileModel? _currentProfile;
  bool _isLoading = false;

  // Getters públicos — exponen el estado mínimo necesario a la UI.
  ProfileModel? get currentProfile => _currentProfile;
  bool get isLoading => _isLoading;

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchProfile
  // Recupera el perfil completo desde la tabla 'profiles' por UUID.
  //
  // Se invoca automáticamente desde AuthNotifier.fetchProfile() tras
  // el login para sincronizar ProfileNotifier con los datos actuales.
  // También se llama manualmente tras editar el perfil para refrescar
  // el estado en memoria con los datos más recientes de Supabase.
  //
  // Los errores se capturan con debugPrint sin relanzarlos porque es
  // una carga automática en segundo plano — no una acción directa del usuario.
  // ─────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateProfile
  // Actualiza nombre y/o avatar del usuario en Supabase y en memoria local.
  //
  // Solo incluye en el UPDATE los campos que realmente han cambiado —
  // evita sobreescribir datos no modificados con valores nulos.
  // Si el mapa de cambios está vacío retorna sin hacer ninguna petición.
  //
  // ProfileModel es inmutable — al actualizar se crea una instancia nueva
  // preservando los campos no modificados en lugar de mutar la existente.
  //
  // Los errores se propagan con rethrow para que EditProfileScreen los
  // capture y muestre el mensaje de error al usuario.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> updateProfile({
    required String userId,
    String? newFullName,
    String? newAvatarUrl,
  }) async {
    if (_currentProfile == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      // Construye el mapa solo con los campos que han cambiado.
      final Map<String, dynamic> updates = {};
      if (newFullName != null) updates['full_name'] = newFullName;
      if (newAvatarUrl != null) updates['avatar_url'] = newAvatarUrl;

      // Si no hay cambios no realiza ninguna petición a Supabase.
      if (updates.isEmpty) return;

      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      // Reconstruye el ProfileModel con los campos actualizados
      // preservando los no modificados — patrón de inmutabilidad.
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

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: addXP
  // Suma puntos de experiencia al perfil del usuario.
  //
  // Persiste el nuevo xp_total en la tabla 'profiles' de Supabase y
  // actualiza el estado local inmediatamente para que ProfileHeader
  // muestre el nuevo valor sin necesidad de recargar el perfil completo.
  //
  // Se invoca desde VisitNotifier.performCheckIn() tras registrar la visita:
  // +20 XP si GPS verificado en radio de 100 metros, +5 XP sin verificar.
  //
  // Los errores se propagan con rethrow para que VisitNotifier los gestione
  // y pueda mostrar el feedback adecuado al usuario en CheckInScreen.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> addXP(int points) async {
    if (_currentProfile == null) return;

    final int newXP = _currentProfile!.xpTotal + points;

    try {
      // Persiste el nuevo XP en Supabase.
      await _supabase
          .from('profiles')
          .update({'xp_total': newXP})
          .eq('id', _currentProfile!.id);

      // Reconstruye el ProfileModel con el nuevo XP preservando el resto
      // de campos — patrón de inmutabilidad de ProfileModel.
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

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearProfile
  // Limpia el perfil en memoria al cerrar sesión.
  // Se invoca desde AuthNotifier.logout() para garantizar que los datos
  // del usuario anterior no son accesibles si otro usuario inicia sesión
  // en el mismo dispositivo.
  // ─────────────────────────────────────────────────────────────────────────
  void clearProfile() {
    _currentProfile = null;
    notifyListeners();
  }
}