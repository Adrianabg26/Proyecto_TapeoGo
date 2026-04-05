/// history_screen.dart
///
/// Pantalla que muestra el historial de visitas del usuario ordenadas
/// de más reciente a más antigua. Usa RefreshIndicator para permitir
/// al usuario sincronizar manualmente con Supabase mediante el gesto
/// pull-to-refresh estándar en aplicaciones móviles.
///
/// Es un StatefulWidget porque necesita cargar los datos al inicializarse
/// mediante initState, lo que no es posible en un StatelessWidget.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/visit_model.dart';
import '../notifiers/visit_notifier.dart';
import '../notifiers/auth_notifier.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {

  @override
  void initState() {
    super.initState();
    // Future.microtask garantiza que el frame de Flutter esté completamente
    // construido antes de solicitar datos, evitando errores de setState
    // durante la fase de build inicial
    Future.microtask(() => _refreshData());
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _refreshData
  // Carga o actualiza el historial desde Supabase. Devuelve un Future
  // para que RefreshIndicator pueda mostrar la animación de carga
  // mientras la operación está en curso.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _refreshData() async {
    final String? userId = context.read<AuthNotifier>().currentUserId;
    if (userId != null) {
      await context.read<VisitNotifier>().fetchHistory(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visitNotifier = context.watch<VisitNotifier>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Mi Historial de Tapeo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      // RefreshIndicator implementa el patrón pull-to-refresh estándar.
      // El hijo debe ser un ScrollView para que el gesto funcione correctamente.
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: Colors.orange,
        backgroundColor: Colors.white,
        child: _buildBody(visitNotifier),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _buildBody
  // Gestiona los tres estados posibles de la pantalla: cargando, vacío
  // y con datos. El estado vacío usa ListView para que RefreshIndicator
  // siga funcionando aunque no haya elementos que mostrar.
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildBody(VisitNotifier notifier) {
    // Estado de carga inicial
    if (notifier.isProcessing && notifier.visits.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    // Estado vacío: debe ser scrolleable para que pull-to-refresh funcione
    if (notifier.visits.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          _buildEmptyState(),
        ],
      );
    }

    // Estado con datos
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      // AlwaysScrollableScrollPhysics garantiza que pull-to-refresh funcione
      // aunque la lista sea corta y no llene toda la pantalla
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: notifier.visits.length,
      itemBuilder: (context, index) {
        return _buildVisitCard(notifier.visits[index]);
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text(
            '¡Tu historial está vacío!\nSal a tapear para estrenar tu perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
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
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Icono de verificación GPS visible solo
                              // si el check-in fue validado por proximidad
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
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                DateFormat('dd/MM/yyyy - HH:mm')
                                    .format(visit.createdAt),
                                style: const TextStyle(
                                  color: Colors.grey,
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
                // El comentario solo se muestra si el usuario lo escribió
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
                            color: Colors.grey[800],
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
    // photoUrl es nullable tras la corrección del modelo
    if (visit.photoUrl != null && visit.photoUrl!.isNotEmpty) {
      return Image.network(
        visit.photoUrl!,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        // Spinner mientras carga la imagen de Supabase Storage
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
        // Placeholder si la imagen falla por red
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
          // Naranja oscuro sobre fondo naranja claro para mejor contraste
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