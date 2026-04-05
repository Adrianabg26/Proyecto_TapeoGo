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

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? userId = context.read<AuthNotifier>().currentUserId;
      if (userId != null) {
        // Cargamos medallas e historial al inicializarse la pantalla
        context.read<BadgeNotifier>().fetchBadges(userId);
        context.read<VisitNotifier>().fetchHistory(userId);
      }
    });
  }

  @override
  void dispose() {
    // Liberamos el TabController para evitar fugas de memoria
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final authNotifier = context.read<AuthNotifier>();
    final badgeNotifier = context.read<BadgeNotifier>();
    final visitNotifier = context.read<VisitNotifier>();

    final String? userId = context.read<AuthNotifier>().currentUserId;
    if (userId != null) {
      await authNotifier.fetchProfile();
      await badgeNotifier.fetchBadges(userId);
      await visitNotifier.fetchHistory(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final profile = auth.profile;
    final badgeNotifier = context.watch<BadgeNotifier>();
    final visitNotifier = context.watch<VisitNotifier>();

    final int xpTotal = profile?.xpTotal ?? 0;
    final int nivel = profile?.userLevel ?? 1;
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
            onPressed: () => auth.logout(),
          ),
        ],
        // TabBar integrado en el AppBar para que quede fijo
        // mientras el contenido hace scroll
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events_outlined), text: 'Medallas'),
            Tab(icon: Icon(Icons.history), text: 'Historial'),
          ],
        ),
      ),
      body: profile == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            )
          : RefreshIndicator(
              color: Colors.orange,
              onRefresh: _refreshData,
              child: NestedScrollView(
                // NestedScrollView permite que la cabecera haga scroll
                // junto con el contenido de cada pestaña
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        ProfileHeader(
                          fullName: profile.fullName,
                          username: profile.username,
                          level: nivel,
                          rankTitle: profile.userRank,
                          xpProgress: progresoNivel,
                          xpTotal: xpTotal,
                          avatarUrl: profile.avatarUrl,
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
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          const BadgesHeader(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
    if (visitNotifier.isProcessing && visitNotifier.visits.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    if (visitNotifier.visits.isEmpty) {
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
                    _buildTypeBadge(visit.recordType),
                  ],
                ),
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
                            color:AppColors.subtitleOrange,
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
