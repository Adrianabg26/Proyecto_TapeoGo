/// wishlist_notifier.dart
///
/// Gestiona el estado y la persistencia de los bares pendientes del usuario.
///
/// Usa WishlistModel como capa de deserialización intermedia y extrae
/// el BarModel del JOIN para que la UI tenga acceso directo a todos
/// los datos del bar sin consultas adicionales — evitando el problema N+1.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bar_model.dart';
import '../models/wishlist_model.dart';

class WishlistNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<BarModel> _wishlistBars = [];
  bool _isLoading = false;

  // Getters públicos — exponen el estado mínimo necesario a la UI.
  List<BarModel> get wishlistBars => _wishlistBars;
  bool get isLoading => _isLoading;

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchWishlist
  // Carga los bares pendientes del usuario con un JOIN completo a 'bars'.
  // select('*, bars(*)') devuelve los campos de 'wishlist' y todos los
  // campos del bar relacionado en una única petición a Supabase,
  // evitando el problema N+1 que ocurriría al consultar cada bar por separado.
  //
  // Flujo de deserialización en dos pasos:
  // 1. Cada registro se deserializa como WishlistModel (incluye barData).
  // 2. Se extrae barData para construir el BarModel que consume la UI.
  //
  // Se invoca desde WishlistScreen en initState y tras cada modificación
  // para mantener el estado sincronizado con la BD.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchWishlist(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('wishlist')
          .select('*, bars(*)')
          .eq('user_id', userId);

      // Paso 1 — deserialización como WishlistModel con barData incluido.
      final List<WishlistModel> wishlist =
          data.map((item) => WishlistModel.fromJson(item)).toList();

      // Paso 2 — extracción del BarModel del JOIN para consumo directo en UI.
      // El filtro where garantiza que no procesamos pendientes sin bar asociado,
      // situación que no debería ocurrir gracias a las claves foráneas de la BD.
      _wishlistBars = wishlist
          .where((w) => w.barData != null)
          .map((w) => BarModel.fromJson(w.barData!))
          .toList();
    } catch (e) {
      debugPrint('Error al cargar lista de pendientes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: addToWishlist
  // Añade un bar a la lista de pendientes en Supabase y en memoria local.
  //
  // Se expone como método independiente (no como toggle) porque WishlistScreen
  // necesita llamarlo directamente desde el botón "Deshacer" del SnackBar
  // sin pasar por la lógica conmutadora — a diferencia de FavoriteNotifier
  // que usa toggleFavorite porque su flujo siempre parte del mismo botón.
  //
  // La restricción UNIQUE(user_id, bar_id) en PostgreSQL impide duplicados
  // incluso si el método se invoca varias veces consecutivas.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> addToWishlist(String userId, BarModel bar) async {
    try {
      await _supabase.from('wishlist').insert({
        'user_id': userId,
        'bar_id':  bar.id,
      });

      // Actualización optimista — añade a la lista local antes de confirmar.
      _wishlistBars.add(bar);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al añadir a pendientes: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: removeFromWishlist
  // Elimina un bar de la lista de pendientes en Supabase y en memoria local.
  //
  // Se expone como método independiente para que WishlistScreen pueda
  // implementar el patrón de acción reversible: elimina inmediatamente
  // de la lista local y programa el borrado en Supabase con Future.delayed
  // de 5 segundos, permitiendo al usuario pulsar "Deshacer" para cancelar
  // la operación antes de que se confirme en la BD.
  //
  // removeWhere recorre la lista hasta encontrar el bar por id — O(n)
  // pero eficiente para listas de tamaño pequeño como la wishlist.
  // ─────────────────────────────────────────────────────────────────────────
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

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: isInWishlist
  // Comprueba en memoria si un bar está en la lista de pendientes.
  // No realiza consultas a Supabase — opera sobre _wishlistBars ya cargado.
  // Se usa en BarDetailsScreen y HomeMapScreen para mostrar el estado
  // activo o inactivo del icono de marcador en tiempo real.
  // ─────────────────────────────────────────────────────────────────────────
  bool isInWishlist(String barId) {
    return _wishlistBars.any((item) => item.id == barId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearWishlist
  // Limpia el estado en memoria al cerrar sesión.
  // Se invoca desde AuthNotifier.logout() para garantizar que los pendientes
  // del usuario anterior no son visibles si otro usuario inicia sesión
  // en el mismo dispositivo.
  // ─────────────────────────────────────────────────────────────────────────
  void clearWishlist() {
    _wishlistBars = [];
    notifyListeners();
  }
}