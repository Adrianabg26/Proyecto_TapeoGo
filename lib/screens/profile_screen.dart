/// profile_screen.dart
///
/// Pantalla de perfil del usuario en TapeoGo. Muestra la cabecera con
/// el avatar, nombre, rango, nivel y barra de XP, y dos pestañas internas:
///   - Medallas: cuadrícula de logros desbloqueados y pendientes.
///   - Historial: registro cronológico de visitas realizadas.
///
/// Es un StatefulWidget porque necesita initState para cargar medallas
/// e historial, y un TickerProviderStateMixin para el TabController.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/badge_notifier.dart';
import '../notifiers/visit_notifier.dart';
import '../models/visit_model.dart';
import '../widgets/profile_header.dart';
import '../widgets/badges_header.dart';
import '../widgets/badges_grid.dart';
import '../utils/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

// TickerProviderStateMixin (sin "Single") porque TabController también
// necesita un ticker además del propio widget. Con SingleTickerProviderStateMixin
// solo se puede gestionar un ticker a la vez, lo que provocaría un error.
class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // length: 2 porque hay dos pestañas: Medallas e Historial.
    // vsync: this conecta el controlador con el ticker del mixin.
    _tabController = TabController(length: 2, vsync: this);

    // addPostFrameCallback garantiza que el BuildContext está listo
    // antes de acceder a los Providers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? userId = context.read<AuthNotifier>().currentUserId;
      if (userId != null) {
        // Cargamos medallas e historial al inicializarse la pantalla.
        // Las dos llamadas son independientes: si una falla la otra
        // sigue ejecutándose.
        context.read<BadgeNotifier>().fetchBadges(userId);
        context.read<VisitNotifier>().fetchHistory(userId);
      }
    });
  }

  @override
  void dispose() {
    // TabController mantiene listeners internos sobre el estado de la pestaña
    // activa. Sin dispose() se producen fugas de memoria.
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Guardamos las referencias a los notifiers antes del await para
    // evitar async gaps con BuildContext tras la operación asíncrona.
    final authNotifier  = context.read<AuthNotifier>();
    final badgeNotifier = context.read<BadgeNotifier>();
    final visitNotifier = context.read<VisitNotifier>();

    final String? userId = context.read<AuthNotifier>().currentUserId;
    if (userId != null) {
      // Las tres llamadas son secuenciales (await): primero el perfil,
      // luego las medallas y finalmente el historial.
      await authNotifier.fetchProfile();
      await badgeNotifier.fetchBadges(userId);
      await visitNotifier.fetchHistory(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.watch suscribe el widget a cambios en AuthNotifier,
    // BadgeNotifier y VisitNotifier. Cualquier notifyListeners() en
    // cualquiera de los tres provoca el rebuild de este build().
    final auth         = context.watch<AuthNotifier>();
    final profile      = auth.profile;
    final badgeNotifier = context.watch<BadgeNotifier>();
    final visitNotifier = context.watch<VisitNotifier>();

    // Los getters de ProfileModel calculan rango, nivel y progreso
    // directamente desde xp_total sin consultas adicionales a Supabase.
    // El operador ?? proporciona valores por defecto si profile es null.
    final int xpTotal         = profile?.xpTotal ?? 0;
    final int nivel           = profile?.userLevel ?? 1;
    final double progresoNivel = profile?.xpProgress ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.titleOrange),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.titleOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Cerrar sesión',
            // auth.logout() limpia todos los notifiers mediante
            // registerNotifiers() y llama a supabase.auth.signOut().
            // El StreamBuilder de main.dart detecta el cambio de sesión
            // y navega automáticamente a LoginScreen.
            onPressed: () => auth.logout(),
          ),
        ],
        // TabBar en el bottom del AppBar para que quede fijo en pantalla
        // mientras el contenido de las pestañas hace scroll.
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Medallas'),
            Tab(icon: Icon(Icons.history),                text: 'Historial'),
          ],
        ),
      ),
      // Mientras profile es null (primera carga) mostramos el spinner.
      // En cuanto AuthNotifier llama a notifyListeners() con el perfil
      // cargado, este build() se re-ejecuta y muestra el contenido real.
      body: profile == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            )
          : RefreshIndicator(
              color: Colors.orange,
              onRefresh: _refreshData,
              // NestedScrollView coordina el scroll de la cabecera con
              // el scroll interno de cada pestaña (ListView o SingleChildScrollView).
              // Sin él, la cabecera y el contenido harían scroll de forma
              // independiente y la cabecera quedaría siempre visible.
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // ProfileHeader consume los getters de ProfileModel
                        // ya calculados arriba, sin lógica de negocio en la UI.
                        ProfileHeader(
                          fullName:   profile.fullName,
                          username:   profile.username,
                          level:      nivel,
                          rankTitle:  profile.userRank,
                          xpProgress: progresoNivel,
                          xpTotal:    xpTotal,
                          avatarUrl:  profile.avatarUrl,
                        ),
                        const Divider(height: 1, thickness: 1),
                      ],
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── PESTAÑA 1: MEDALLAS ──────────────────────────────
                    _buildMedallasTab(badgeNotifier),

                    // ── PESTAÑA 2: HISTORIAL ─────────────────────────────
                    _buildHistorialTab(visitNotifier),
                  ],
                ),
              ),
            ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PESTAÑA MEDALLAS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMedallasTab(BadgeNotifier badgeNotifier) {
    return SingleChildScrollView(
      // AlwaysScrollableScrollPhysics permite el gesto de pull-to-refresh
      // aunque el contenido no sea suficiente para hacer scroll.
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // BadgesHeader muestra el contador de medallas desbloqueadas
          // sobre el total del catálogo.
          const BadgesHeader(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            // BadgesGrid renderiza la cuadrícula de 9 medallas.
            // Consume BadgeNotifier internamente mediante context.watch.
            child: BadgesGrid(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // PESTAÑA HISTORIAL
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHistorialTab(VisitNotifier visitNotifier) {
    // isProcessing true con lista vacía indica primera carga.
    // Si la lista ya tiene datos y se está recargando, no mostramos
    // el spinner para no ocultar el contenido existente.
    if (visitNotifier.isProcessing && visitNotifier.visits.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (visitNotifier.visits.isEmpty) {
      // ListView en lugar de Column para que RefreshIndicator detecte
      // el gesto de pull-to-refresh también en el estado vacío.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          _buildHistorialEmptyState(),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(15),
      itemCount: visitNotifier.visits.length,
      // builder construye cada tarjeta bajo demanda, solo cuando
      // el ítem es visible en pantalla. Más eficiente que un Column
      // con todos los ítems construidos de una vez.
      itemBuilder: (context, index) {
        return _buildVisitCard(visitNotifier.visits[index]);
      },
    );
  }

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

  Widget _buildVisitCard(VisitModel visit) {
    return Card(
      // Clip.antiAlias recorta la imagen de la tarjeta con el mismo
      // borderRadius de la Card, evitando esquinas cuadradas en la imagen.
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardImage(visit),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                visit.barName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.titleOrange,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // El icono de verificado solo aparece si
                              // gpsVerified es true, es decir si el check-in
                              // se realizó dentro del radio de 100 metros.
                              if (visit.gpsVerified)
                                const Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                  size: 18,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 14,
                                color: AppColors.textGrey,
                              ),
                              const SizedBox(width: 5),
                              // DateFormat del paquete intl formatea DateTime
                              // al patrón legible dd/MM/yyyy - HH:mm.
                              Text(
                                DateFormat('dd/MM/yyyy - HH:mm')
                                    .format(visit.createdAt),
                                style: const TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Badge con el tipo de consumo registrado (serranito,
                    // cerveza, etc.) en mayúsculas para destacarlo visualmente.
                    _buildTypeBadge(visit.recordType),
                  ],
                ),
                // El comentario solo se renderiza si existe y no está vacío.
                // El operador spread ... inserta los widgets de la lista
                // directamente dentro del Column padre.
                if (visit.comment != null && visit.comment!.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          visit.comment!,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: AppColors.subtitleOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardImage(VisitModel visit) {
    if (visit.photoUrl != null && visit.photoUrl!.isNotEmpty) {
      return Image.network(
        visit.photoUrl!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        // loadingBuilder muestra un placeholder mientras la imagen
        // se descarga. progress == null indica que la carga terminó.
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 160,
            color: Colors.orange[50],
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.orange,
                strokeWidth: 2,
              ),
            ),
          );
        },
        // errorBuilder se activa si la URL es inválida o la descarga falla.
        // Muestra el icono del tipo de tapa como fallback visual.
        errorBuilder: (context, error, stackTrace) => Container(
          height: 100,
          width: double.infinity,
          color: Colors.orange[50],
          child: Icon(
            _getIconForType(visit.recordType),
            size: 40,
            color: Colors.orange,
          ),
        ),
      );
    }
    // Si photoUrl es null muestra directamente el icono del tipo de tapa.
    return Container(
      height: 100,
      width: double.infinity,
      color: Colors.orange[50],
      child: Icon(
        _getIconForType(visit.recordType),
        size: 40,
        color: Colors.orange,
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: Colors.orange[900],
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Switch que mapea cada valor de record_type al icono más representativo.
  // El caso default cubre 'generic' y cualquier valor no contemplado.
  IconData _getIconForType(String type) {
    switch (type) {
      case 'serranito':
        return Icons.bakery_dining;
      case 'cerveza':
        return Icons.local_bar;
      case 'vino':
        return Icons.wine_bar;
      case 'croquetas':
        return Icons.circle;
      case 'solomillo_whisky':
        return Icons.restaurant;
      default:
        return Icons.restaurant_menu;
    }
  }
}