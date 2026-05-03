/// favorites_screen.dart
///
/// Pantalla que muestra los establecimientos marcados como favoritos.
/// Consume FavoriteNotifier mediante context.watch para actualizarse
/// automáticamente cuando el usuario añade o elimina un favorito
/// desde cualquier otra pantalla de la app.
///
/// Gestiona tres estados visuales:
///   - Carga: shimmer con la forma exacta de las tarjetas reales.
///   - Vacío: mensaje motivacional con botón para ir al mapa.
///   - Con datos: lista de tarjetas con acciones de ver y eliminar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/favorite_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/bar_image.dart';
import '../widgets/shimmer_placeholder.dart';
import '../utils/app_colors.dart';
import '../models/bar_model.dart';
import 'bar_details_screen.dart';
import '../main.dart';

class FavoritesScreen extends StatelessWidget {
  final VoidCallback onGoToExplore;
  const FavoritesScreen({super.key, required this.onGoToExplore});

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _removeWithUndo
  // Elimina el bar de favoritos y muestra un SnackBar con opción "Deshacer".
  // Patrón de acción reversible — el usuario puede recuperar el bar
  // durante los 4 segundos que el SnackBar está visible.
  //
  // Se usa scaffoldMessengerKey.currentState en lugar de
  // ScaffoldMessenger.of(context) para evitar conflictos con el
  // IndexedStack de MainScreen, que mantiene todas las pantallas
  // en memoria simultáneamente.
  // ───────────────────────────────────────────────────────────────────────────

 void _removeWithUndo(
    BuildContext context,
    FavoriteNotifier notifier,
    String userId,
    BarModel bar,
  ) {
    // 1. Ejecutamos la lógica (esto quitará el bar de la vista)
    notifier.toggleFavorite(userId, bar);

    // 2. CAPTURAMOS EL MENSAJERO INMEDIATAMENTE
    // Al guardarlo en una variable local, ya no dependemos de si el widget se borra
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        key: UniqueKey(),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 6), // Margen de seguridad
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text('${bar.name} ha sido eliminado de Favoritos'),
        action: SnackBarAction(
          label: 'Deshacer',
          textColor: const Color(0xFFFF6D00),
          onPressed: () {
            messenger.hideCurrentSnackBar();
            notifier.toggleFavorite(userId, bar);
          },
        ),
      ),
    );

    // 3. EL "MARTILLO" (Cierre manual)
    // Esto es lo que garantiza que se vaya a los 4 segundos sí o sí
    Future.delayed(const Duration(seconds: 5), () {
      messenger.hideCurrentSnackBar();
    });
}

  @override
  Widget build(BuildContext context) {
    // context.watch suscribe este widget a FavoriteNotifier.
    // Cada vez que cambia la lista de favoritos, la pantalla se reconstruye.
    final favoriteNotifier = context.watch<FavoriteNotifier>();
    final String? userId = context.read<AuthNotifier>().user?.id;
    final favorites = favoriteNotifier.favoriteBars;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(context, favoriteNotifier, favorites, userId),
            ),
          ],
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
            'Favoritos',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w300,
              color: AppColors.primary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tus bares destacados',
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

  // Gestiona los tres estados posibles de la pantalla:
  // carga con shimmer, lista vacía y lista con datos.
  Widget _buildBody(
    BuildContext context,
    FavoriteNotifier favoriteNotifier,
    List favorites,
    String? userId,
  ) {
    // Estado de carga: shimmer con la misma estructura que las tarjetas reales.
    // ShimmerPlaceholder es un widget reutilizable definido en lib/widgets.
    if (favoriteNotifier.isLoading) {
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
                      const SizedBox(height: 8),
                      ShimmerPlaceholder.rectangular(
                          width: 55, height: 10),
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

    // Estado vacío: mensaje motivacional con botón para ir al mapa.
    if (favorites.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.12),
          _buildEmptyState(),
        ],
      );
    }

    // Estado con datos: lista de tarjetas con imagen, info y acciones.
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final bar = favorites[index] as BarModel;
        return _buildBarCard(context, favoriteNotifier, bar, userId);
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildBarCard
  // Tarjeta horizontal con imagen, nombre, dirección, botón de detalles
  // e icono para eliminar con opción de deshacer.
  // El diseño es idéntico a WishlistScreen para garantizar consistencia
  // visual entre ambas pantallas de listas.
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBarCard(
    BuildContext context,
    FavoriteNotifier favoriteNotifier,
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
                  // Se muestra la dirección física en lugar del distrito
                  // para que el usuario pueda localizar el bar fácilmente.
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          bar.address,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
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

          // Icono de corazón para eliminar el bar de favoritos.
          // El color naranja es coherente con el resto de iconos activos
          // de favorito en la app (bar_details_screen).
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(
                Icons.favorite_rounded,
                color: AppColors.primary,
              ),
              onPressed: userId == null
                  ? null
                  : () => _removeWithUndo(
                      context, favoriteNotifier, userId, bar),
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
          Icon(Icons.favorite_border_rounded,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes favoritos',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Marca con el corazón los bares\nque más te gusten.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.grey[400], fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onGoToExplore,
            icon: const Icon(Icons.map_outlined,
                size: 18, color: Colors.white),
            label: const Text(
              'Descubrir bares',
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