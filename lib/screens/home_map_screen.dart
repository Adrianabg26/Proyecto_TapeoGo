/// home_map_screen.dart
///
/// Pantalla principal de TapeoGo. Muestra el mapa interactivo con los
/// marcadores de los establecimientos y permite al usuario buscar bares
/// por nombre o distrito mediante el buscador flotante.
///
/// Al pulsar un marcador aparece una tarjeta inferior con información
/// del bar que permite navegar a BarDetailsScreen para ver el detalle
/// completo y realizar el check-in.
///
/// Incluye una animación de confeti que se activa cuando el usuario
/// desbloquea una nueva medalla tras registrar una visita.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../notifiers/map_notifier.dart';
import '../models/bar_model.dart';
import '../utils/app_colors.dart';
import 'bar_details_screen.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  // Bar seleccionado al pulsar un marcador en el mapa
  BarModel? _selectedBar;

  // Controlador de la animación de confeti para celebrar medallas
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // addPostFrameCallback garantiza que el árbol de widgets esté
    // completamente construido antes de solicitar datos a Supabase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapNotifier>().fetchBars();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar con logo centrado y botón de refresco.
      // Se usa el logo sin texto para maximizar el espacio vertical del mapa.
      // El fondo blanco con elevación 0 lo integra visualmente con el buscador.
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/logo.png',
          height: 36,
          fit: BoxFit.contain,
        ),
        actions: [
          // Botón de refresco para sincronizar los marcadores con Supabase
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => context.read<MapNotifier>().fetchBars(),
            tooltip: 'Actualizar mapa',
          ),
        ],
      ),
      body: Consumer<MapNotifier>(
        builder: (context, mapNotifier, child) {
          if (mapNotifier.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          // Stack permite superponer capas sobre el mapa:
          // Mapa (fondo) → Buscador (superior) → Tarjeta (inferior) → Confeti
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // Capa base: mapa de Google con marcadores
              _buildMap(mapNotifier),

              // Capa superior: buscador flotante.
              // top: 20 en lugar de 60 porque el AppBar ya ocupa espacio.
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: _buildFloatingSearch(context),
              ),

              // Capa inferior: tarjeta de previsualización del bar.
              // AnimatedPositioned anima la entrada y salida de la tarjeta
              // desplazándola verticalmente con una curva suave.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutBack,
                bottom: _selectedBar != null ? 30 : -350,
                left: 20,
                right: 20,
                child: _buildBarPreviewCard(),
              ),

              // Capa de efectos: confeti para celebrar nuevas medallas
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
      // FloatingActionButton eliminado: el botón de refresco se ha
      // integrado en el AppBar para mantener la interfaz más limpia.
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGETS DE CONSTRUCCIÓN
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildMap(MapNotifier mapNotifier) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        // Coordenadas del centro de Sevilla
        target: LatLng(37.3891, -5.9845),
        zoom: 14,
      ),
      markers: mapNotifier.markers.map((m) {
        return m.copyWith(
          onTapParam: () {
            // Al pulsar un marcador buscamos el BarModel completo en la
            // lista de MapNotifier para tener todos los datos disponibles
            final BarModel bar = mapNotifier.allBars.firstWhere(
              (b) => b.id == m.markerId.value,
              orElse: () => mapNotifier.allBars.first,
            );
            setState(() => _selectedBar = bar);
          },
        );
      }).toSet(),
      // Al pulsar el mapa fuera de un marcador se oculta la tarjeta
      onTap: (_) => setState(() => _selectedBar = null),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildFloatingSearch(BuildContext context) {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (value) =>
                  context.read<MapNotifier>().filterBars(value),
              decoration: const InputDecoration(
                hintText: 'Busca por nombre o distrito...',
                border: InputBorder.none,
              ),
            ),
          ),
          const Icon(Icons.tune, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildBarPreviewCard() {
    if (_selectedBar == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 70,
                  height: 70,
                  color: Colors.orange[50],
                  child: const Icon(Icons.restaurant, color: Colors.orange),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedBar!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.titleOrange,
                      ),
                    ),
                    Text(
                      _selectedBar!.district,
                      style: const TextStyle(
                        color: AppColors.subtitleOrange,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => setState(() => _selectedBar = null),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // El botón navega a BarDetailsScreen que gestiona el check-in
          // completo con GPS, foto y validación a través de VisitNotifier
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BarDetailsScreen(bar: _selectedBar!),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Ver detalles',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  } 
}