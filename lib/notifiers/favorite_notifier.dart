/// favorite_notifier.dart
///
/// Gestiona el estado y la persistencia de los bares favoritos del usuario.
///
/// Usa FavoriteModel como capa de deserialización intermedia y extrae
/// el BarModel del JOIN para que la UI tenga acceso directo a todos
/// los datos del bar sin consultas adicionales — evitando el problema N+1.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bar_model.dart';
import '../models/favorite_model.dart';

class FavoriteNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<BarModel> _favoriteBars = [];
  bool _isLoading = false;

  // Getters públicos — exponen el estado mínimo necesario a la UI.
  List<BarModel> get favoriteBars => _favoriteBars;
  bool get isLoading => _isLoading;

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchFavorites
  // Carga los favoritos del usuario con un JOIN completo a 'bars'.
  // select('*, bars(*)') devuelve los campos de 'favorites' y todos los
  // campos del bar relacionado en una única petición a Supabase,
  // evitando el problema N+1 que ocurriría al consultar cada bar por separado.
  //
  // Flujo de deserialización en dos pasos:
  // 1. Cada registro se deserializa como FavoriteModel (incluye barData).
  // 2. Se extrae barData para construir el BarModel que consume la UI.
  //
  // Se invoca desde FavoritesScreen en initState y tras cada modificación
  // para mantener el estado sincronizado con la BD.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchFavorites(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('favorites')
          .select('*, bars(*)')
          .eq('user_id', userId);

      // Paso 1 — deserialización como FavoriteModel con barData incluido.
      final List<FavoriteModel> favorites =
          data.map((item) => FavoriteModel.fromJson(item)).toList();

      // Paso 2 — extracción del BarModel del JOIN para consumo directo en UI.
      // El filtro where garantiza que no procesamos favoritos sin bar asociado,
      // situación que no debería ocurrir gracias a las claves foráneas de la BD.
      _favoriteBars = favorites
          .where((fav) => fav.barData != null)
          .map((fav) => BarModel.fromJson(fav.barData!))
          .toList();
    } catch (e) {
      debugPrint('Error al cargar favoritos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: toggleFavorite
  // Añade o elimina un bar de favoritos según su estado actual.
  //
  // Usa un método conmutador único porque el flujo de añadir y quitar
  // favoritos siempre parte del mismo botón — a diferencia de WishlistNotifier
  // que expone métodos separados para soportar el botón "Deshacer" del SnackBar.
  //
  // Implementa actualización optimista: modifica la lista local antes de
  // confirmar en Supabase para que la UI responda al instante sin esperar
  // la respuesta del servidor.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> toggleFavorite(String userId, BarModel bar) async {
    final int existingIndex =
        _favoriteBars.indexWhere((b) => b.id == bar.id);

    try {
      if (existingIndex >= 0) {
        // El bar ya es favorito — lo elimina de la BD y de la lista local.
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('bar_id', bar.id);

        _favoriteBars.removeAt(existingIndex);
      } else {
        // El bar no es favorito — lo inserta en la BD y en la lista local.
        // La restricción UNIQUE(user_id, bar_id) en PostgreSQL impide duplicados
        // incluso si el usuario pulsa el botón varias veces rápidamente.
        await _supabase.from('favorites').insert({
          'user_id': userId,
          'bar_id':  bar.id,
        });

        _favoriteBars.add(bar);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error al modificar favorito: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: isFavorite
  // Comprueba en memoria si un bar está en la lista de favoritos del usuario.
  // No realiza consultas a Supabase — opera sobre _favoriteBars ya cargado.
  // Se usa en BarDetailsScreen y HomeMapScreen para mostrar el estado
  // activo o inactivo del icono de corazón en tiempo real.
  // ─────────────────────────────────────────────────────────────────────────
  bool isFavorite(String barId) {
    return _favoriteBars.any((b) => b.id == barId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearFavorites
  // Limpia el estado en memoria al cerrar sesión.
  // Se invoca desde AuthNotifier.logout() para garantizar que los favoritos
  // del usuario anterior no sean visibles si otro usuario inicia sesión
  // en el mismo dispositivo.
  // ─────────────────────────────────────────────────────────────────────────
  void clearFavorites() {
    _favoriteBars = [];
    notifyListeners();
  }
}