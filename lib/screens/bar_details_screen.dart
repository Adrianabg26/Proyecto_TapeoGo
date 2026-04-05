/// bar_details_screen.dart
///
/// Pantalla de detalles de un establecimiento en TapeoGo.
/// Muestra la información completa del bar y permite al usuario
/// realizar tres acciones principales:
///   - Marcar el bar como favorito (corazón)
///   - Añadir o quitar de pendientes (marcador)
///   - Navegar a CheckInScreen para registrar la visita

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bar_model.dart';
import '../notifiers/favorite_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/wishlist_notifier.dart';
import '../widgets/bar_image.dart';
import '../utils/app_colors.dart';
import 'check_in_screen.dart';

class BarDetailsScreen extends StatefulWidget {
  final BarModel bar;
  const BarDetailsScreen({super.key, required this.bar});

  @override
  State<BarDetailsScreen> createState() => _BarDetailsScreenState();
}

class _BarDetailsScreenState extends State<BarDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final favoriteNotifier = context.watch<FavoriteNotifier>();
    final wishlistNotifier = context.watch<WishlistNotifier>();
    final String? userId = context.read<AuthNotifier>().currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.bar.name,
          style: const TextStyle(color: AppColors.titleOrange),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.titleOrange),
        actions: [
          // Botón de wishlist: marcador relleno si el bar está en pendientes
          IconButton(
            icon: Icon(
              wishlistNotifier.isInWishlist(widget.bar.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: Colors.orange,
            ),
            onPressed: userId == null
                ? null
                : () => wishlistNotifier.isInWishlist(widget.bar.id)
                    ? wishlistNotifier.removeFromWishlist(userId, widget.bar)
                    : wishlistNotifier.addToWishlist(userId, widget.bar),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen principal del bar
            Center(
              child: BarImage(
                url: widget.bar.mainImageUrl,
                size: 200,
              ),
            ),
            const SizedBox(height: 20),

            // Nombre, distrito y botón de favorito
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.bar.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.titleOrange,
                        ),
                      ),
                      Text(
                        widget.bar.district,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.subtitleOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botón de favorito
                IconButton(
                  icon: Icon(
                    favoriteNotifier.isFavorite(widget.bar.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  onPressed: userId == null
                      ? null
                      : () => favoriteNotifier.toggleFavorite(
                            userId,
                            widget.bar,
                          ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Especialidad gastronómica
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '⭐ Especialidad: ${widget.bar.specialtyTapa}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Descripción del local
            const Text(
              'Sobre este lugar:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.titleOrange,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.bar.description.isNotEmpty
                  ? widget.bar.description
                  : 'Este establecimiento aún no tiene descripción.',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.subtitleOrange,
                height: 1.4,
              ),
            ),

            const Divider(height: 60),

            // Botón principal de check-in
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text(
                  'REGISTRAR VISITA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CheckInScreen(bar: widget.bar),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}