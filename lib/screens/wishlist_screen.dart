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

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? userId = context.read<AuthNotifier>().currentUserId;
      if (userId != null) {
        context.read<WishlistNotifier>().fetchWishlist(userId);
      }
    });
  }

  Future<void> _refreshData() async {
    final String? userId = context.read<AuthNotifier>().currentUserId;
    if (userId != null) {
      await context.read<WishlistNotifier>().fetchWishlist(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlistNotifier = context.watch<WishlistNotifier>();
    final String? userId = context.read<AuthNotifier>().user?.id;
    final wishlist = wishlistNotifier.wishlistBars;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Pendientes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.titleOrange,
          ),
        ),
        backgroundColor: Colors.orange[50],
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: Colors.orange,
        onRefresh: _refreshData,
        child: _buildBody(context, wishlistNotifier, wishlist, userId),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WishlistNotifier wishlistNotifier,
    List wishlist,
    String? userId,
  ) {
    if (wishlistNotifier.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (wishlist.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          _buildEmptyState(),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: wishlist.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final bar = wishlist[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              BarImage(url: bar.mainImageUrl, size: 70),
              const SizedBox(width: 15),
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
                      bar.district,
                      style: const TextStyle(
                        color: AppColors.subtitleOrange,
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
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