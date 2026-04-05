/// favorites_screen.dart
///
/// Pantalla que muestra la lista de establecimientos marcados como
/// favoritos por el usuario. Consume FavoriteNotifier mediante
/// context.watch para actualizarse automáticamente cuando el usuario
/// añade o elimina un favorito desde cualquier otra pantalla.
///
/// Es un StatelessWidget porque no gestiona estado propio,
/// toda la lógica de persistencia reside en FavoriteNotifier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/favorite_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/bar_image.dart';
import '../utils/app_colors.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favoriteNotifier = context.watch<FavoriteNotifier>();
    // context.read es suficiente para userId porque no necesitamos
    // reconstruir la pantalla si cambia el usuario autenticado
    final String? userId = context.read<AuthNotifier>().user?.id;
    final favorites = favoriteNotifier.favoriteBars;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Sitios Top',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.titleOrange),
        ),
        centerTitle: true,
      ),
      body: _buildBody(context, favoriteNotifier, favorites, userId),
    );
  }

  Widget _buildBody(
    BuildContext context,
    FavoriteNotifier favoriteNotifier,
    List favorites,
    String? userId,
  ) {
    // Estado de carga: mientras FavoriteNotifier consulta Supabase
    if (favoriteNotifier.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    // Estado vacío: la lista cargó pero el usuario no tiene favoritos
    if (favorites.isEmpty) {
      return _buildEmptyState();
    }

    // Estado con datos: lista de bares favoritos
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final bar = favorites[index];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            // BarImage gestiona los estados de carga, error y sin imagen
            leading: BarImage(url: bar.mainImageUrl, size: 60),
            title: Text(
              bar.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.titleOrange),
            ),
            subtitle: Text(
              bar.specialtyTapa,
              style: const TextStyle(
                color: AppColors.subtitleOrange,
              ),
            ),
            // Botón para eliminar el bar de favoritos.
            // Siempre muestra corazón relleno porque todos los elementos
            // de esta lista son favoritos por definición.
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red),
              onPressed: () {
                if (userId != null) {
                  favoriteNotifier.toggleFavorite(userId, bar);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: No se detectó sesión activa'),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET AUXILIAR: _buildEmptyState
  // Muestra un mensaje amigable cuando el usuario no tiene favoritos.
  // Evita que el usuario piense que hay un error al ver la pantalla vacía,
  // proporcionando contexto y motivación para explorar la app.
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Aún no tienes favoritos',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textGrey,
            ),
          ),
          const Text(
            '¡Explora Sevilla y guarda los mejores!',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}
