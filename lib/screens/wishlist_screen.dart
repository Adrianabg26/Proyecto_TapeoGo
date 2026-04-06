/// wishlist_screen.dart
///
/// Pantalla que muestra la lista de establecimientos marcados como
/// pendientes por el usuario. Al ser pestaña del IndexedStack de MainScreen,
/// usa initState para cargar los datos al inicializarse.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/wishlist_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/bar_image.dart';
import '../utils/app_colors.dart';

// StatefulWidget porque necesita initState para lanzar la carga de datos
// al montarse como pestaña dentro del IndexedStack de MainScreen.
// Si fuera StatelessWidget no tendría ciclo de vida para hacer esto.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  @override
  void initState() {
    super.initState();
    // addPostFrameCallback garantiza que el árbol de widgets está completamente
    // construido antes de ejecutar el código asíncrono. Sin esto, llamar a
    // context.read dentro de initState podría lanzar un error porque el
    // BuildContext aún no está listo para acceder a los Providers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // context.read se usa aquí (no context.watch) porque solo necesitamos
      // leer el valor una vez, no suscribirnos a cambios.
      final String? userId = context.read<AuthNotifier>().currentUserId;
      if (userId != null) {
        // Dispara la carga de la lista de pendientes desde Supabase.
        // WishlistNotifier llama a notifyListeners() al terminar,
        // lo que provoca el rebuild del widget que sí usa context.watch.
        context.read<WishlistNotifier>().fetchWishlist(userId);
      }
    });
  }

  // Método llamado por RefreshIndicator cuando el usuario arrastra hacia abajo.
  // Es async porque espera a que fetchWishlist complete antes de ocultar
  // el indicador de recarga.
  Future<void> _refreshData() async {
    final String? userId = context.read<AuthNotifier>().currentUserId;
    if (userId != null) {
      await context.read<WishlistNotifier>().fetchWishlist(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch suscribe este widget a los cambios de WishlistNotifier.
    // Cada vez que WishlistNotifier llama a notifyListeners(), este build
    // se re-ejecuta automáticamente con los datos actualizados.
    final wishlistNotifier = context.watch<WishlistNotifier>();

    // context.read aquí (sin watch) porque el userId no cambia durante
    // el uso normal de la pantalla y no necesitamos reaccionar a cambios de Auth.
    final String? userId = context.read<AuthNotifier>().user?.id;

    // wishlistBars es la lista de BarModel que devuelve el notifier.
    // Se actualiza cada vez que fetchWishlist o removeFromWishlist terminan.
    final wishlist = wishlistNotifier.wishlistBars;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Pendientes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.titleOrange,  // Color del sistema de diseño AppColors
          ),
        ),
        backgroundColor: Colors.orange[50],
        elevation: 0,        // Sin sombra para estilo flat
        centerTitle: true,
      ),
      // RefreshIndicator envuelve el body completo para que el gesto de
      // arrastrar hacia abajo (pull-to-refresh) funcione en cualquier
      // punto de la pantalla, incluyendo el estado vacío.
      body: RefreshIndicator(
        color: Colors.orange,
        onRefresh: _refreshData,
        child: _buildBody(context, wishlistNotifier, wishlist, userId),
      ),
    );
  }

  // Separamos la lógica de construcción del body en un método privado
  // para mantener el método build limpio y legible.
  // Recibe los datos ya extraídos para no repetir context.watch/read aquí.
  Widget _buildBody(
    BuildContext context,
    WishlistNotifier wishlistNotifier,
    List wishlist,
    String? userId,
  ) {
    // Estado de carga: WishlistNotifier expone isLoading = true mientras
    // fetchWishlist está ejecutándose. Muestra spinner mientras espera.
    if (wishlistNotifier.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    // Estado vacío: la lista existe pero no tiene elementos.
    // Se usa ListView (no Column) para que RefreshIndicator funcione
    // también en el estado vacío. Sin ListView, el gesto de pull-to-refresh
    // no tiene superficie de scroll donde detectarse.
    if (wishlist.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(), // Permite scroll aunque no haya contenido
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2), // Centra visualmente el mensaje
          _buildEmptyState(),
        ],
      );
    }

    // Estado con datos: lista de bares pendientes.
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(), // Necesario para que RefreshIndicator funcione
      padding: const EdgeInsets.all(16),
      itemCount: wishlist.length,
      // separatorBuilder añade un Divider entre ítems, no después del último.
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final bar = wishlist[index]; // BarModel con los datos del establecimiento

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              // Widget reutilizable que gestiona la carga de la imagen
              // con estado de loading, error y placeholder naranja.
              BarImage(url: bar.mainImageUrl, size: 70),
              const SizedBox(width: 15),
              // Expanded para que el texto ocupe el espacio disponible
              // sin desplazar el IconButton a la derecha.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bar.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleOrange,
                      ),
                    ),
                    Text(
                      bar.district, // Barrio del establecimiento
                      style: const TextStyle(
                        color: AppColors.subtitleOrange,
                      ),
                    ),
                  ],
                ),
              ),
              // Botón para eliminar el bar de la lista de pendientes.
              // Si userId es null (no debería ocurrir, la pantalla requiere sesión)
              // se deshabilita el botón con onPressed: null.
              // removeFromWishlist llama a notifyListeners() al terminar,
              // lo que provoca el rebuild y el bar desaparece de la lista.
              IconButton(
                icon: const Icon(Icons.bookmark_remove, color: Colors.grey),
                onPressed: userId == null
                    ? null
                    : () => wishlistNotifier.removeFromWishlist(userId, bar),
              ),
            ],
          ),
        );
      },
    );
  }

  // Estado vacío con mensaje motivacional.
  // Separado en método privado para mantener _buildBody legible.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          // Icono decorativo con color muy suave para no distraer
          Icon(Icons.restaurant_menu, size: 80, color: Colors.orange[100]),
          const SizedBox(height: 16),
          const Text(
            '¿No tienes hambre?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.titleOrange,
            ),
          ),
          const Text(
            'Añade bares a tu lista de pendientes.',
            style: TextStyle(color: AppColors.textGrey),
          ),
        ],
      ),
    );
  }
}