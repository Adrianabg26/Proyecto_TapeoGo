/// profile_screen.dart
///
/// Pantalla de perfil del usuario en TapeoGo.
///
/// Muestra el header con avatar, nombre, rango y barra de XP,
/// las estadísticas de medallas y XP total, y un TabController
/// con dos pestañas: grid de medallas e historial de visitas.
///
/// El avatar es interactivo — al pulsarlo abre la galería para
/// cambiar la foto de perfil mediante ImagePicker y AuthNotifier.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/badge_notifier.dart';
import '../notifiers/visit_notifier.dart';
import '../models/visit_model.dart';
import '../widgets/profile_header.dart';
import '../widgets/badges_grid.dart';
import '../utils/app_colors.dart';
import 'edit_profile_screen.dart';
import '../utils/string_extensions.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onGoToExplore;
  const ProfileScreen({super.key, required this.onGoToExplore});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {

  // TabController para las pestañas Medallas e Historial.
  // TickerProviderStateMixin proporciona el vsync necesario para
  // sincronizar la animación del tab con el refresco de pantalla.
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // addPostFrameCallback garantiza que el árbol de widgets está construido
    // antes de solicitar datos a Supabase desde los notifiers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? userId = context.read<AuthNotifier>().currentUserId;
      if (userId != null) {
        context.read<BadgeNotifier>().fetchBadges(userId);
        context.read<VisitNotifier>().fetchHistory(userId);
      }
    });
  }

  @override
  void dispose() {
    // Obligatorio liberar el TabController en dispose()
    // para evitar fugas de memoria al salir de la pantalla.
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _pickAndUploadAvatar
  // Flujo completo de actualización de foto de perfil desde la galería.
  //
  // 1. Abre la galería con imageQuality: 50 para optimizar el tamaño
  //    del archivo antes de subirlo a Supabase Storage.
  // 2. Muestra un SnackBar de feedback inmediato mientras se procesa.
  // 3. Delega la subida a AuthNotifier.updateAvatar() que gestiona
  //    el upload al bucket 'avatars' y la actualización de la URL en BD.
  // 4. Refresca todos los datos para que la UI refleje el cambio.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null && mounted) {
      // Feedback visual inmediato mientras se procesa la subida.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actualizando foto de perfil...')),
      );

      // Delega la subida y actualización de URL a AuthNotifier.
      await context.read<AuthNotifier>().updateAvatar(image.path);

      // Refresca todos los datos para sincronizar la UI con Supabase.
      await _refreshData();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _refreshData
  // Recarga el perfil, medallas e historial desde Supabase.
  // Se invoca desde el RefreshIndicator (pull-to-refresh) y tras
  // actualizar el avatar para mantener la UI sincronizada con la BD.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _refreshData() async {
    final authNotifier = context.read<AuthNotifier>();
    final badgeNotifier = context.read<BadgeNotifier>();
    final visitNotifier = context.read<VisitNotifier>();
    final String? userId = authNotifier.currentUserId;

    if (userId != null) {
      await authNotifier.fetchProfile();
      await badgeNotifier.fetchBadges(userId);
      await visitNotifier.fetchHistory(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch suscribe la pantalla a cambios en los tres notifiers.
    final auth = context.watch<AuthNotifier>();
    final profile = auth.profile;
    final badgeNotifier = context.watch<BadgeNotifier>();
    final visitNotifier = context.watch<VisitNotifier>();

    // Datos derivados del perfil con valores por defecto seguros.
    final int xpTotal = profile?.xpTotal ?? 0;
    final int nivel = profile?.userLevel ?? 1;
    final double progresoNivel = profile?.xpProgress ?? 0.0;
    final int medallasDesbloqueadas = badgeNotifier.myBadges.length;
    final int totalMedallas = badgeNotifier.allBadges.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: profile == null
          // Muestra spinner mientras el perfil se carga por primera vez.
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refreshData,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Column(
                      children: [

                        // ── Cabecera: título y acceso a ajustes ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mi Perfil',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w300,
                                      color: AppColors.primary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tu pasaporte gastronómico',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              // Botón de ajustes que navega a EditProfileScreen.
                              IconButton(
                                icon: Icon(
                                  Icons.settings_outlined,
                                  color: Colors.grey[400],
                                  size: 22,
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const EditProfileScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── ProfileHeader ──
                        // Avatar interactivo, nombre, rango, barra de XP y píldora
                        // de rango. onAvatarTap conecta con _pickAndUploadAvatar.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ProfileHeader(
                            fullName: profile.fullName,
                            username: profile.username,
                            level: nivel,
                            rankTitle: profile.userRank,
                            xpProgress: progresoNivel,
                            xpTotal: xpTotal,
                            avatarUrl: profile.avatarUrl,
                            onAvatarTap: _pickAndUploadAvatar,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Estadísticas: medallas y XP total ──
                        // Separador superior e inferior en gris suave para
                        // delimitar visualmente el bloque de estadísticas.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                    color: Colors.grey[200]!, width: 1),
                                bottom: BorderSide(
                                    color: Colors.grey[200]!, width: 1),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildStat(
                                    value: '$medallasDesbloqueadas/$totalMedallas',
                                    label: 'Medallas',
                                  ),
                                ),
                                // Separador vertical entre las dos estadísticas.
                                Container(
                                    height: 28,
                                    width: 1,
                                    color: Colors.grey[200]),
                                Expanded(
                                  child: _buildStat(
                                    value: '$xpTotal',
                                    label: 'XP Total',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── TabBar — Medallas e Historial ──
                        // Indicador naranja con bordes redondeados sobre fondo
                        // gris suave — coherente con la identidad visual de la app.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.grey[500],
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              indicator: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelPadding: EdgeInsets.zero,
                              tabs: const [
                                Tab(text: 'Medallas', height: 38),
                                Tab(text: 'Historial', height: 38),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Vistas de las pestañas ──
                        // Expanded necesario para que TabBarView ocupe
                        // el espacio restante sin desbordar la pantalla.
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildMedallasTab(),
                              _buildHistorialTab(visitNotifier),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildStat
  // Bloque de estadística con valor numérico destacado y etiqueta.
  // Se usa para mostrar medallas desbloqueadas y XP total en el header.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStat({required String value, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildMedallasTab
  // Pestaña de medallas con el grid de BadgesGrid.
  // AlwaysScrollableScrollPhysics permite el pull-to-refresh incluso
  // cuando el contenido no llena la pantalla completa.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMedallasTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BadgesGrid(onGoToExplore: widget.onGoToExplore),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildHistorialTab
  // Pestaña de historial con tres estados posibles:
  // 1. Cargando — CircularProgressIndicator mientras se obtienen las visitas.
  // 2. Vacío — estado motivacional que anima al usuario a hacer su primer check-in.
  // 3. Con datos — ListView de tarjetas de visita ordenadas de más reciente a más antigua.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHistorialTab(VisitNotifier visitNotifier) {
    // Estado de carga — solo se muestra si la lista está vacía
    // para no interrumpir la visualización de visitas ya cargadas.
    if (visitNotifier.isProcessing && visitNotifier.visits.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    // Estado vacío — lista motivacional con icono y texto de llamada a la acción.
    if (visitNotifier.visits.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          _buildHistorialEmptyState(),
        ],
      );
    }

    // Estado con datos — lista de tarjetas de visita.
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(15),
      itemCount: visitNotifier.visits.length,
      itemBuilder: (context, index) =>
          _buildVisitCard(visitNotifier.visits[index]),
    );
  }

  // Estado vacío del historial — anima al usuario a hacer su primer check-in.
  Widget _buildHistorialEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text(
            '¡Tu historial está vacío!\nSal a tapear para estrenar tu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildVisitCard
  // Tarjeta de visita individual en el historial.
  //
  // Muestra foto de la tapa (o placeholder con icono), nombre del bar,
  // dirección, fecha y comentario opcional. El chip de tipo de tapa usa
  // toFriendlyName() de StringExtensions para mostrar el valor legible
  // en lugar del record_type crudo almacenado en la BD.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVisitCard(VisitModel visit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // Foto de la tapa o placeholder con icono según el tipo de consumo.
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: visit.photoUrl != null && visit.photoUrl!.isNotEmpty
                ? Image.network(
                    visit.photoUrl!,
                    width: 42,
                    height: 42,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _visitIconPlaceholder(visit.recordType),
                  )
                : _visitIconPlaceholder(visit.recordType),
          ),
          const SizedBox(width: 12),

          // Datos de la visita: bar, dirección, fecha y comentario.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.barName,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.titleOrange),
                ),
                const SizedBox(height: 2),
                // Dirección con fallback si no está disponible en la BD.
                Text(
                  (visit.barAddress != null && visit.barAddress!.isNotEmpty)
                      ? visit.barAddress!
                      : 'Ubicación no disponible',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Fecha formateada con Intl en formato español.
                Text(
                  DateFormat('dd/MM/yyyy · HH:mm').format(visit.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
                // Comentario opcional — solo visible si el usuario lo escribió.
                if (visit.comment != null && visit.comment!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    visit.comment!,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.subtitleOrange,
                        fontStyle: FontStyle.italic),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Chip de tipo de tapa — toFriendlyName() convierte el
          // record_type de la BD en un nombre legible para el usuario.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange[200]!, width: 1),
            ),
            child: Text(
              visit.recordType.toFriendlyName(),
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _visitIconPlaceholder
  // Placeholder cuadrado con icono representativo del tipo de consumo.
  // Se muestra cuando la visita no tiene foto o la carga falla.
  // El icono se obtiene mediante _getIconForType() según el record_type.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _visitIconPlaceholder(String recordType) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
          color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
      child: Icon(
        _getIconForType(recordType),
        color: AppColors.primary,
        size: 20,
      ),
    );
  }

  // Devuelve el icono de Material Design correspondiente a cada tipo de consumo.
  // El switch cubre los cinco tipos definidos en el catálogo de medallas.
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'serranito':
        return Icons.lunch_dining;
      case 'cerveza':
        return Icons.local_bar;
      case 'vino':
        return Icons.wine_bar;
      case 'croquetas':
        return Icons.tapas;
      case 'solomillo_whisky':
        return Icons.kebab_dining;
      default:
        return Icons.restaurant_menu;
    }
  }
}