/// wishlist_notifier.dart
///
/// Gestiona el estado y la persistencia de la lista de bares pendientes
/// del usuario en TapeoGo.
///
/// Trabaja con una lista de [BarModel] en lugar de [WishlistModel]
/// para evitar consultas N+1, obteniendo todos los datos del bar
/// en una única consulta relacional JOIN igual que [FavoriteNotifier].
///
/// A diferencia de [FavoriteNotifier] que usa un método toggle,
/// este notifier tiene métodos explícitos separados para añadir
/// y eliminar, porque los flujos de gestión de pendientes están
/// más separados en la navegación de la app.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bar_model.dart';

class WishlistNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Lista de bares completos marcados como pendientes por el usuario.
  // Se usa BarModel y no WishlistModel para que la UI tenga acceso
  // directo a todos los datos del bar sin consultas adicionales.
  List<BarModel> _wishlistBars = [];
  List<BarModel> get wishlistBars => _wishlistBars;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchWishlist
  // Carga los bares pendientes del usuario mediante una consulta JOIN.
  // 'select('bars (*)')' hace que Supabase devuelva el registro de
  // wishlist junto con todos los datos del bar en una sola petición,
  // evitando múltiples consultas a la base de datos.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> fetchWishlist(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('wishlist')
          .select('bars (*)')
          .eq('user_id', userId);

      // Extraemos el objeto 'bars' de cada registro de wishlist
      // y lo convertimos directamente a BarModel.
      _wishlistBars = data
          .map((item) => BarModel.fromJson(item['bars'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error al cargar lista de pendientes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: addToWishlist
  // Añade un bar a la lista de pendientes en Supabase y en memoria.
  // Se pasa el objeto BarModel completo para actualizar la lista local
  // de forma inmediata sin necesidad de recargar desde la BD.
  // La restricción UNIQUE(user_id, bar_id) en PostgreSQL impide
  // duplicados aunque el método se llame varias veces seguidas.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> addToWishlist(String userId, BarModel bar) async {
    try {
      await _supabase.from('wishlist').insert({
        'user_id': userId,
        'bar_id': bar.id,
      });

      _wishlistBars.add(bar);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al añadir a pendientes: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: removeFromWishlist
  // Elimina un bar de la lista de pendientes en Supabase y en memoria.
  // La eliminación en memoria usa removeWhere con complejidad O(n),
  // lo que permite una respuesta inmediata en la UI sin recargar la lista.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> removeFromWishlist(String userId, BarModel bar) async {
    try {
      await _supabase
          .from('wishlist')
          .delete()
          .eq('user_id', userId)
          .eq('bar_id', bar.id);

      _wishlistBars.removeWhere((item) => item.id == bar.id);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al eliminar de pendientes: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: isInWishlist
  // Comprueba si un bar está en la lista local de pendientes.
  // Se usa en BarDetailsScreen para mostrar el botón de pendiente
  // activo o inactivo según el estado actual del bar.
  // ───────────────────────────────────────────────────────────────────────────

  bool isInWishlist(String barId) {
    return _wishlistBars.any((item) => item.id == barId);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearWishlist
  // Limpia la lista local al cerrar sesión para evitar que los datos
  // del usuario anterior sean visibles si otro usuario inicia sesión
  // en el mismo dispositivo.
  // Se invoca desde AuthNotifier.logout().
  // ───────────────────────────────────────────────────────────────────────────

  void clearWishlist() {
    _wishlistBars = [];
    notifyListeners();
  }
}