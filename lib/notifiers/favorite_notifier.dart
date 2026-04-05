/// favorite_notifier.dart
///
/// Gestiona el estado y la persistencia de los establecimientos
/// marcados como favoritos por el usuario en TapeoGo.
///
/// Trabaja con una lista de [BarModel] en lugar de [FavoriteModel]
/// para evitar el problema de las consultas N+1: en lugar de cargar
/// primero los IDs de favoritos y luego consultar cada bar por separado,
/// se obtiene toda la información en una única consulta relacional JOIN.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bar_model.dart';

class FavoriteNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lista de bares completos marcados como favoritos por el usuario.
  // Se usa BarModel y no FavoriteModel para que la UI tenga acceso
  // directo a todos los datos del bar sin consultas adicionales.
  List<BarModel> _favoriteBars = [];
  List<BarModel> get favoriteBars => _favoriteBars;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchFavorites
  // Carga los bares favoritos del usuario mediante una consulta JOIN.
  // 'select('bars (*)')' hace que Supabase devuelva el registro de
  // favorito junto con todos los datos del bar en una sola petición,
  // evitando múltiples consultas a la base de datos.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> fetchFavorites(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('favorites')
          .select('bars (*)')
          .eq('user_id', userId);

      // Extraemos el objeto 'bars' de cada registro de favorito
      // y lo convertimos directamente a BarModel.
      _favoriteBars = data
          .map((item) => BarModel.fromJson(item['bars'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error al cargar favoritos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: toggleFavorite
  // Añade o elimina un bar de favoritos según su estado actual.
  // Implementa actualización optimista: modifica la lista local
  // inmediatamente para que la UI responda al instante, mientras
  // la operación se procesa en Supabase en segundo plano.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> toggleFavorite(String userId, BarModel bar) async {
    final int existingIndex = _favoriteBars.indexWhere((b) => b.id == bar.id);

    try {
      if (existingIndex >= 0) {
        // El bar ya es favorito: eliminamos el registro de la BD
        // y lo quitamos de la lista local.
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('bar_id', bar.id);

        _favoriteBars.removeAt(existingIndex);
      } else {
        // El bar no es favorito: insertamos el registro en la BD
        // y añadimos el BarModel completo a la lista local.
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'bar_id': bar.id,
        });

        _favoriteBars.add(bar);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error al modificar favorito: $e');
      // En caso de error, se podría revertir el cambio local
      // llamando a fetchFavorites(userId) para resincronizar
      // el estado local con el estado real de la base de datos.
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: isFavorite
  // Comprueba si un bar está en la lista local de favoritos.
  // Se usa en BarDetailsScreen para mostrar el icono de corazón
  // relleno o vacío según el estado actual del bar.
  // ───────────────────────────────────────────────────────────────────────────

  bool isFavorite(String barId) {
    return _favoriteBars.any((b) => b.id == barId);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearFavorites
  // Limpia la lista local al cerrar sesión para evitar que los datos
  // del usuario anterior sean visibles si otro usuario inicia sesión
  // en el mismo dispositivo.
  // Se invoca desde AuthNotifier.logout().
  // ───────────────────────────────────────────────────────────────────────────

  void clearFavorites() {
    _favoriteBars = [];
    notifyListeners();
  }
}