/// wishlist_screen.dart
///
/// Pantalla que muestra los establecimientos marcados como pendientes.
///
/// Al ser pestaña del IndexedStack de MainScreen, carga los datos en
/// initState mediante addPostFrameCallback para garantizar que el árbol
/// de widgets está construido antes de la primera petición a Supabase.
///
/// Gestiona tres estados visuales:
///   - Carga: shimmer con la misma estructura que las tarjetas reales.
///   - Vacío: mensaje motivacional con botón para ir al mapa.
///   - Con datos: lista de tarjetas con acciones de ver y eliminar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/wishlist_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/bar_image.dart';
import '../widgets/shimmer_placeholder.dart';
import '../utils/app_colors.dart';
import '../models/bar_model.dart';
import 'bar_details_screen.dart';
import '../main.dart';

class WishlistScreen extends StatefulWidget {
  final VoidCallback onGoToExplore;
  const WishlistScreen({super.key, required this.onGoToExplore});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback garantiza que el árbol de widgets está construido
    // antes de solicitar datos al notifier desde el context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? userId = context.read<AuthNotifier>().currentUserId;
      if (userId != null) {
        context.read<WishlistNotifier>().fetchWishlist(userId);
      }
    });
  }

  // Recarga la wishlist desde Supabase.
  // Devuelve Future para que RefreshIndicator muestre la animación
  // mientras la operación está en curso.
  Future<void> _refreshData() async {
    final String? userId = context.read<AuthNotifier>().currentUserId;
    if (userId != null) {
      await context.read<WishlistNotifier>().fetchWishlist(userId);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _removeWithUndo
  // Elimina el bar de pendientes y muestra un SnackBar con "Deshacer".
  // Patrón de acción reversible — el usuario tiene 4 segundos para
  // recuperar el bar antes de que la eliminación sea definitiva.
  //
  // Se usa scaffoldMessengerKey.currentState en lugar de
  // ScaffoldMessenger.of(context) para evitar conflictos con el
  // IndexedStack de MainScreen que mantiene todas las pantallas en memoria.
  // ───────────────────────────────────────────────────────────────────────────

 void _removeWithUndo(
    BuildContext context,
    WishlistNotifier notifier,
    String userId,
    BarModel bar,
  ) {
    // 1. Ejecutamos la lógica de datos
    notifier.removeFromWishlist(userId, bar);

    // 2. OBTENEMOS EL MENSAJERO LOCAL (Fundamental)
    // Usar .of(context) asegura que el SnackBar se vincule al Ticker (reloj) 
    // de la pantalla actual.
    final messenger = ScaffoldMessenger.of(context); 

    // 3. LIMPIEZA PREVENTIVA
    // hideCurrentSnackBar() detiene cualquier temporizador previo de forma limpia.
    messenger.hideCurrentSnackBar(); 

    // 4. LANZAMOS EL MENSAJE
    messenger.showSnackBar(
      SnackBar(
        // UniqueKey fuerza a Flutter a crear un Timer totalmente nuevo
        key: UniqueKey(), 
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 6), 
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(Icons.bookmark_remove_rounded, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${bar.name} ha sido eliminado de Pendientes',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: AppColors.primary,
          onPressed: () => notifier.addToWishlist(userId, bar),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 5), () {
  // Verificamos que el mensajero siga existiendo para evitar errores
  messenger.hideCurrentSnackBar();
});
  }

  @override
  Widget build(BuildContext context) {
    // context.watch suscribe este widget a WishlistNotifier.
    // Cuando cambia la lista de pendientes la pantalla se reconstruye.
    final wishlistNotifier = context.watch<WishlistNotifier>();
    final String? userId = context.read<AuthNotifier>().user?.id;
    final wishlist = wishlistNotifier.wishlistBars;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshData,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Expanded(
                child: _buildBody(
                    context, wishlistNotifier, wishlist, userId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cabecera con título y subtítulo — mismo patrón que el resto de pestañas.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pendientes',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w300,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Bares que quieres visitar',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // Gestiona los tres estados posibles de la pantalla.
  Widget _buildBody(
    BuildContext context,
    WishlistNotifier wishlistNotifier,
    List wishlist,
    String? userId,
  ) {
    // Estado de carga: shimmer con la misma estructura que las tarjetas reales.
    if (wishlistNotifier.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14)),
                child: ShimmerPlaceholder.rectangular(
                    width: 90, height: 90),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerPlaceholder.rectangular(height: 13),
                      const SizedBox(height: 8),
                      ShimmerPlaceholder.rectangular(
                          width: 90, height: 10),
                      const SizedBox(height: 10),
                      ShimmerPlaceholder.rectangular(
                          width: 70, height: 10),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      );
    }

    // Estado vacío: ListView para que RefreshIndicator siga funcionando.
    if (wishlist.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          _buildEmptyState(),
        ],
      );
    }

    // Estado con datos: lista de tarjetas.
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: wishlist.length,
      itemBuilder: (context, index) {
        final bar = wishlist[index] as BarModel;
        return _buildBarCard(context, wishlistNotifier, bar, userId);
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildBarCard
  // Tarjeta horizontal con imagen, nombre, dirección, botón de detalles
  // e icono para eliminar con opción de deshacer.
  // Diseño idéntico a FavoritesScreen para garantizar consistencia visual.
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBarCard(
    BuildContext context,
    WishlistNotifier wishlistNotifier,
    BarModel bar,
    String? userId,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Imagen del bar mediante el widget reutilizable BarImage.
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14)),
            child: BarImage(url: bar.mainImageUrl, size: 90),
          ),

          // Nombre, dirección y botón de acción.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bar.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.titleOrange,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Dirección física en lugar del distrito para facilitar
                  // que el usuario localice el bar cuando quiera visitarlo.
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          bar.address,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Botón "Ver detalles" con ElevatedButton para mantener
                  // coherencia con el resto de botones de acción de la app.
                  SizedBox(
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BarDetailsScreen(bar: bar),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Ver detalles',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Icono bookmark para eliminar el bar de pendientes.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(
                Icons.bookmark_rounded,
                color: AppColors.primary,
              ),
              onPressed: userId == null
                  ? null
                  : () => _removeWithUndo(
                      context, wishlistNotifier, userId, bar),
            ),
          ),
        ],
      ),
    );
  }

  // Estado vacío con mensaje motivacional y botón para ir al mapa.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.bookmark_outline_rounded,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            '¡Nada por aquí todavía!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Guarda los bares que quieras visitar\ny tenlos siempre a mano.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[400], fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: widget.onGoToExplore,
            icon: const Icon(Icons.map_outlined,
                size: 18, color: Colors.white),
            label: const Text(
              'Explorar bares',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 28, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}