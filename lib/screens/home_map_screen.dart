/// home_map_screen.dart
///
/// Pantalla principal de TapeoGo. Muestra el mapa interactivo con los
/// marcadores de los establecimientos y permite buscar bares por nombre,
/// distrito o especialidad mediante el buscador integrado en la cabecera.
///
/// Al pulsar un marcador aparece una tarjeta inferior con la información
/// del bar que permite navegar a BarDetailsScreen.
///
/// Gestión de errores: _loadBars usa try/catch directamente en la UI
/// siguiendo el patrón recomendado — sin booleanos _hasError en el notifier.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../notifiers/map_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../models/bar_model.dart';
import '../utils/app_colors.dart';
import 'bar_details_screen.dart';
import 'edit_profile_screen.dart';
import 'package:tapeo_go/utils/ui_helpers.dart';
import 'package:tapeo_go/notifiers/favorite_notifier.dart';
import 'package:tapeo_go/notifiers/wishlist_notifier.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  // Bar seleccionado al pulsar un marcador.
  // null = no hay marcador activo y la tarjeta inferior está oculta.
  BarModel? _selectedBar;

  late ConfettiController _confettiController;

  // Controlador del mapa para animar la cámara programáticamente.
  GoogleMapController? _mapController;

  final TextEditingController _searchController = TextEditingController();

  // Controla el color del borde del buscador al enfocar.
  bool _searchFocused = false;

  // Número de bares que coinciden con la búsqueda activa.
  int _filteredCount = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    // addPostFrameCallback garantiza que el árbol de widgets está construido
    // antes de solicitar datos a Supabase desde el notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBars();
    });
  }

  @override
  void dispose() {
    // Obligatorio liberar los tres controladores para evitar fugas de memoria.
    _confettiController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _loadBars
  // Carga el catálogo de bares desde Supabase mediante MapNotifier.
  // Si falla, muestra un SnackBar con botón "Reintentar".
  // ───────────────────────────────────────────────────────────────────────────
  Future<void> _loadBars() async {
    try {
      final double dpr = MediaQuery.of(context).devicePixelRatio;
      await context.read<MapNotifier>().fetchBars(dpr);
      if (!mounted) return;
      setState(
          () => _filteredCount = context.read<MapNotifier>().allBars.length);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: const Color(0xFFFFF0F0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    color: Color(0xFFFFE0E0), shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    color: Color(0xFFE53935), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No se pudieron cargar los bares. Comprueba tu conexión.',
                  style: TextStyle(color: Color(0xFFC62828), fontSize: 13),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Reintentar',
            textColor: AppColors.primary,
            onPressed: _loadBars,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.watch<AuthNotifier>();
    final userId = authNotifier.user?.id;
    final profile = authNotifier.profile;

    // Escuchamos cambios en favoritos y wishlist para actualizar la UI reactivamente.
    context.watch<FavoriteNotifier>();
    context.watch<WishlistNotifier>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildExploreHeader(profile?.username ?? ''),
            Expanded(
              child: Consumer<MapNotifier>(
                builder: (context, mapNotifier, child) {
                  if (mapNotifier.isLoading) {
                    return _buildLoadingState();
                  }

                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      _buildMap(mapNotifier),

                      // Capa de atenuación al seleccionar un marcador.
                      // IgnorePointer evita que bloquee el mapa cuando es invisible.
                      IgnorePointer(
                        ignoring: _selectedBar == null,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedBar = null),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _selectedBar != null ? 0.15 : 0.0,
                            child: Container(color: Colors.black),
                          ),
                        ),
                      ),

                      // Chip de resultados — solo visible durante una búsqueda activa.
                      if (_searchController.text.isNotEmpty)
                        Positioned(
                          top: 12,
                          child: _buildResultsChip(_filteredCount),
                        ),

                      // FAB de ubicación — sube cuando la tarjeta está visible.
                      Positioned(
                        right: 14,
                        bottom: _selectedBar != null ? 260 : 30,
                        child: _buildMyLocationButton(),
                      ),

                      // Tarjeta inferior con animación de entrada y salida.
                      // AnimatedPositioned mueve la tarjeta verticalmente.
                      // AnimatedSwitcher anima la transición entre bares distintos.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutBack,
                        bottom: _selectedBar != null ? 60 : -400,
                        left: 16,
                        right: 16,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: _selectedBar != null
                              ? _buildBarPreviewCard(
                                  _selectedBar!,
                                  userId: userId,
                                  key: ValueKey(_selectedBar!.id),
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),
                      ),

                      // Confeti — se activa desde CheckInScreen al desbloquear medalla.
                      ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                        colors: const [
                          Colors.orange,
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                        ],
                        numberOfParticles: 15,
                        gravity: 0.1,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildExploreHeader
  // Cabecera con título, saludo, avatar y buscador.
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildExploreHeader(String username) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Explora Sevilla',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Hola $username',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 139, 139, 139),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _RefreshButton(
                    onPressed: () {
                      _searchController.clear();
                      _loadBars();
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildTopAvatar(username),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildTopAvatar
  // Avatar circular con menú desplegable (Editar Perfil / Cerrar Sesión).
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTopAvatar(String name) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      onSelected: (value) {
        if (value == 'logout') {
          context.read<AuthNotifier>().logout();
        } else if (value == 'edit_profile') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          );
        }
      },
      // Pasamos directamente el CircleAvatar como hijo del PopupMenuButton
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'edit_profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              const Text('Editar Perfil',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text('Cerrar Sesión',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildSearchBar
  // Buscador con borde animado al enfocar. Filtra en memoria sobre la lista
  // ya cargada sin consultas adicionales a Supabase.
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Focus(
      onFocusChange: (focused) => setState(() => _searchFocused = focused),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _searchFocused
                ? AppColors.primary.withValues(alpha: 0.6)
                : const Color(0xFFFFD4A0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) async {
                  final double dpr = MediaQuery.of(context).devicePixelRatio;
                  await context.read<MapNotifier>().filterBars(value, dpr);
                  setState(() {
                    _filteredCount =
                        context.read<MapNotifier>().filteredBars.length;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Busca tu próximo bar, zona o tapa...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                onPressed: () async {
                  _searchController.clear();
                  final double dpr = MediaQuery.of(context).devicePixelRatio;
                  await context.read<MapNotifier>().filterBars('', dpr);
                  setState(() => _filteredCount =
                      context.read<MapNotifier>().allBars.length);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Chip flotante con el número de bares encontrados.
  // Cambia a rojo cuando no hay resultados.
  Widget _buildResultsChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_rounded,
              size: 14,
              color: count == 0 ? Colors.red[700] : AppColors.primary),
          const SizedBox(width: 4),
          Text(
            count == 0
                ? 'Sin resultados'
                : '$count ${count == 1 ? 'bar encontrado' : 'bares encontrados'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: count == 0 ? Colors.red[700] : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Estado de carga mientras MapNotifier descarga los bares de Supabase.
  Widget _buildLoadingState() {
    return Stack(
      children: [
        Container(color: const Color(0xFFF8F8F8)),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text('Cargando bares...',
                    style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text('Buscando el mejor tapeo cerca de ti',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // FAB para centrar la cámara en Sevilla.
  // heroTag evita conflictos si hay más de un FAB en la pantalla.
  Widget _buildMyLocationButton() {
    return FloatingActionButton.small(
      heroTag: 'myLocation',
      backgroundColor: Colors.white,
      elevation: 4,
      onPressed: () {
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(
              target: LatLng(37.3891, -5.9845),
              zoom: 15,
            ),
          ),
        );
      },
      child: const Icon(Icons.my_location_rounded,
          color: AppColors.primary, size: 20),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildMap
  // GoogleMap con marcadores generados por MapNotifier.
  // mapToolbarEnabled: false elimina los accesos directos de Google.
  // myLocationButtonEnabled: false oculta el botón nativo — usamos FAB propio.
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMap(MapNotifier mapNotifier) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.3891, -5.9845),
        zoom: 14,
      ),
      onMapCreated: (controller) => _mapController = controller,
      markers: mapNotifier.markers.map((m) {
        return m.copyWith(
          onTapParam: () {
            final BarModel? bar = mapNotifier.getBarById(m.markerId.value);
            if (bar == null) return;
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                  LatLng(bar.latitude, bar.longitude), 16),
            );
            setState(() => _selectedBar = bar);
          },
        );
      }).toSet(),
      onTap: (_) => setState(() => _selectedBar = null),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildBarPreviewCard
  // Tarjeta inferior del bar seleccionado.
  // userId se recibe como parámetro para evitar context.read dentro de build.
  // ValueKey garantiza que AnimatedSwitcher anima correctamente entre bares.
  // onVerticalDragUpdate: deslizar abajo cierra, deslizar arriba va a detalles.
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBarPreviewCard(BarModel bar, {Key? key, required String? userId}) {
  final favoriteNotifier = context.watch<FavoriteNotifier>();
  final wishlistNotifier = context.watch<WishlistNotifier>();
  final bool isFavorite = favoriteNotifier.isFavorite(bar.id);
  final bool isInWishlist = wishlistNotifier.isInWishlist(bar.id);

  return GestureDetector(
    onVerticalDragUpdate: (details) {
      if (details.delta.dy > 10) {
        setState(() => _selectedBar = null);
      } else if (details.delta.dy < -10) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BarDetailsScreen(bar: bar)),
        );
      }
    },
    child: Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              _buildBarImage(bar),
              
             
              Positioned(
                top: 8, // Separación desde el borde superior de la imagen
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9), // Blanco casi opaco
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        // Sombra suave para garantizar contraste sobre fondos claros
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ---------------------------------

              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  children: [
                    _buildQuickActionButton(
                      icon: isInWishlist
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isInWishlist
                          ? AppColors.primary
                          : Colors.grey[600]!,
                      onPressed: userId == null
                          ? null
                          : () => isInWishlist
                              ? wishlistNotifier.removeFromWishlist(userId, bar)
                              : wishlistNotifier.addToWishlist(userId, bar),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionButton(
                      icon: isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFavorite ? AppColors.primary : Colors.grey[600]!,
                      onPressed: userId == null
                          ? null
                          : () => favoriteNotifier.toggleFavorite(userId, bar),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bar.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.titleOrange,
                              )),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.place_rounded,
                                  size: 13, color: Colors.grey),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(bar.address,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500]),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _selectedBar = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.grey[100], shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                BarDetailsScreen(bar: bar))),
                    icon: const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 18),
                    label: const Text('Ver detalles',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  // Botón de acción rápida circular sobre la imagen del bar.
  // onPressed null → botón deshabilitado visualmente (usuario no autenticado).
  Widget _buildQuickActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: onPressed == null ? 0.4 : 1.0,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // Imagen del bar desde Supabase Storage.
  // Si no hay URL o falla la descarga muestra el placeholder de marca.
  Widget _buildBarImage(BarModel bar) {
    const double imageHeight = 200.0;

    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: (bar.mainImageUrl != null && bar.mainImageUrl!.isNotEmpty)
            ? Image.network(
                bar.mainImageUrl!,
                fit: BoxFit.cover,
                alignment: const Alignment(0.0, -0.8),
                cacheHeight: 800,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => _barImagePlaceholder(imageHeight),
              )
            : _barImagePlaceholder(imageHeight),
      ),
    );
  }

  // Placeholder para locales sin imagen — mantiene la identidad visual.
  Widget _barImagePlaceholder(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.02),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.05), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        children: [
          UIHelpers.buildDecorativeIcon(
              icon: Icons.local_pizza_rounded,
              top: -10,
              left: -10,
              size: 80,
              angle: 0.5),
          UIHelpers.buildDecorativeIcon(
              icon: Icons.wine_bar_rounded,
              bottom: -5,
              right: -10,
              size: 90,
              angle: -0.3),
          UIHelpers.buildDecorativeIcon(
              icon: Icons.restaurant_menu_rounded,
              top: 40,
              right: 30,
              size: 50,
              angle: 0.2),
          UIHelpers.buildDecorativeIcon(
              icon: Icons.bakery_dining_rounded,
              bottom: 20,
              left: 20,
              size: 60,
              angle: -0.4),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.camera_enhance_rounded,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 2),
              Text(
                'IMAGEN EN CONSTRUCCIÓN',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.primary.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET AUXILIAR: _RefreshButton
// Botón de actualización con animación de rotación independiente.
// Se extrae como widget propio para que su AnimationController no provoque
// reconstrucciones innecesarias en HomeMapScreen.
// ─────────────────────────────────────────────────────────────────────────────
class _RefreshButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _RefreshButton({required this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: IconButton(
        icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
        onPressed: () {
          _controller.forward(from: 0);
          widget.onPressed();
        },
        tooltip: 'Actualizar mapa',
      ),
    );
  }
}
