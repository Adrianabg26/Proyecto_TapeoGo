/// map_notifier.dart
///
/// Gestiona el estado de la capa geoespacial de TapeoGo.
/// Se encarga de cargar el catálogo de bares desde Supabase,
/// transformarlos en marcadores para Google Maps y aplicar
/// filtros de búsqueda en memoria sin consultas adicionales a la BD.

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bar_model.dart';

class MapNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // _allBars guarda el catálogo completo descargado de Supabase.
  // _filteredBars contiene los bares visibles según el filtro activo.
  // Esta separación permite filtrar en memoria sin volver a consultar la BD.
  List<BarModel> _allBars = [];
  List<BarModel> _filteredBars = [];
  Set<Marker> _markers = {};

  List<BarModel> get allBars => _allBars;
  List<BarModel> get filteredBars => _filteredBars;
  Set<Marker> get markers => _markers;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchBars
  // Descarga el catálogo completo de bares desde la tabla 'bars' de Supabase.
  // Al usar ChangeNotifier, la pantalla del mapa se actualiza automáticamente
  // cuando los datos llegan, pasando del estado de carga al estado con datos.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> fetchBars() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase.from('bars').select();

      _allBars = data.map((json) => BarModel.fromJson(json)).toList();

      // Inicialmente los bares filtrados son todos los bares
      _filteredBars = List.from(_allBars);

      // Transformamos los BarModel en Markers para Google Maps
      _createMarkers(_allBars);
    } catch (e) {
      debugPrint('Error cargando bares: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: filterBars
  // Filtra los bares en memoria por nombre o distrito con complejidad O(n),
  // lo que permite una respuesta instantánea en el buscador sin coste de red.
  // Si la búsqueda está vacía, restaura todos los marcadores del mapa.
  // ───────────────────────────────────────────────────────────────────────────

  void filterBars(String query) {
    if (query.isEmpty) {
      _filteredBars = List.from(_allBars);
      _createMarkers(_allBars);
    } else {
      _filteredBars = _allBars.where((bar) {
        return bar.name.toLowerCase().contains(query.toLowerCase()) ||
            bar.district.toLowerCase().contains(query.toLowerCase());
      }).toList();
      _createMarkers(_filteredBars);
    }
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _createMarkers
  // Convierte cada BarModel en un objeto Marker de Google Maps.
  // Se usa el color naranja corporativo de TapeoGo para los marcadores.
  // El InfoWindow muestra el nombre y el distrito del bar al pulsar
  // sobre el marcador en el mapa.
  // ───────────────────────────────────────────────────────────────────────────

  void _createMarkers(List<BarModel> barsToMark) {
    _markers = barsToMark.map((bar) {
      return Marker(
        markerId: MarkerId(bar.id),
        position: LatLng(bar.latitude, bar.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(
          title: bar.name,
          snippet: bar.district,
        ),
      );
    }).toSet();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearBars
  // Limpia el estado del mapa al cerrar sesión para evitar que los datos
  // queden visibles si otro usuario inicia sesión en el mismo dispositivo.
  // Se invoca desde AuthNotifier.logout().
  // ───────────────────────────────────────────────────────────────────────────

  void clearBars() {
    _allBars = [];
    _filteredBars = [];
    _markers = {};
    notifyListeners();
  }
}
