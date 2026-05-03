/// map_notifier.dart
///
/// Gestiona el estado de la capa geoespacial de TapeoGo.
///
/// Responsabilidades:
///   - Cargar el catálogo de bares desde Supabase.
///   - Transformarlos en marcadores personalizados nítidos para Google Maps.
///   - Filtrar bares en memoria sin consultas adicionales a la BD.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bar_model.dart';

class MapNotifier extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<BarModel> _allBars = [];
  List<BarModel> _filteredBars = [];
  Set<Marker> _markers = {};
  bool _isLoading = false;

  // Getters públicos — exponen el estado mínimo necesario a la UI.
  List<BarModel> get allBars => _allBars;
  List<BarModel> get filteredBars => _filteredBars;
  Set<Marker> get markers => _markers;
  bool get isLoading => _isLoading;

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchBars
  // Descarga el catálogo completo de bares desde Supabase y genera los
  // marcadores personalizados para Google Maps escalados a la densidad
  // de pantalla del dispositivo (pixelRatio).
  //
  // pixelRatio se obtiene desde HomeMapScreen mediante
  // MediaQuery.of(context).devicePixelRatio y se pasa al notifier para
  // que los marcadores sean nítidos en tablets y pantallas de alta densidad.
  //
  // Si la carga falla, relanza la excepción para que HomeMapScreen
  // la capture en su try/catch y muestre el SnackBar de error.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchBars(double pixelRatio) async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _supabase.from('bars').select();
      _allBars = data.map((json) => BarModel.fromJson(json)).toList();
      _filteredBars = List.from(_allBars);

      // Genera los marcadores con el ratio de píxeles del dispositivo.
      await _createMarkers(_allBars, pixelRatio);
    } catch (e) {
      debugPrint('Error cargando bares: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: filterBars
  // Filtra el catálogo en memoria por nombre, distrito y especialidad
  // sin realizar consultas adicionales a Supabase.
  //
  // Si la búsqueda está vacía restaura la lista completa y regenera
  // todos los marcadores. Si hay texto, filtra y regenera solo los
  // marcadores de los bares que coinciden con la búsqueda.
  //
  // El filtrado en memoria garantiza respuesta instantánea al usuario
  // sin latencia de red, independientemente del número de bares.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> filterBars(String query, double pixelRatio) async {
    if (query.isEmpty) {
      // Sin búsqueda activa — restaura el catálogo completo.
      _filteredBars = List.from(_allBars);
      await _createMarkers(_allBars, pixelRatio);
    } else {
      // Filtra por nombre, distrito y especialidad ignorando mayúsculas.
      final String q = query.toLowerCase();
      _filteredBars = _allBars.where((bar) {
        return bar.name.toLowerCase().contains(q) ||
            bar.district.toLowerCase().contains(q) ||
            bar.specialtyTapa.toLowerCase().contains(q);
      }).toList();

      // Regenera solo los marcadores de los bares filtrados.
      await _createMarkers(_filteredBars, pixelRatio);
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: getBarById
  // Busca un bar en la lista local por su ID y lo devuelve.
  // Devuelve null si no existe para evitar excepciones en HomeMapScreen
  // cuando el usuario pulsa un marcador cuyo bar no está en memoria.
  // Se usa en el onTap de cada marcador del mapa para obtener el BarModel
  // completo sin consultas adicionales a Supabase.
  // ─────────────────────────────────────────────────────────────────────────
  BarModel? getBarById(String id) {
    try {
      return _allBars.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _createMarkers
  // Genera el conjunto de marcadores para Google Maps a partir de una
  // lista de bares. El icono personalizado se construye una sola vez
  // y se reutiliza para todos los marcadores — evita renderizar el asset
  // N veces (una por bar) mejorando el rendimiento.
  //
  // anchor: (0.5, 1.0) posiciona el marcador con la punta inferior
  // exactamente sobre las coordenadas del bar en el mapa.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _createMarkers(
      List<BarModel> barsToMark, double pixelRatio) async {
    final Set<Marker> markers = {};

    // Construye el icono una sola vez escalado a la densidad de pantalla.
    final BitmapDescriptor icon = await _buildCustomMarker(pixelRatio);

    for (final bar in barsToMark) {
      markers.add(
        Marker(
          markerId: MarkerId(bar.id),
          position: LatLng(bar.latitude, bar.longitude),
          icon: icon,
          // anchor (0.5, 1.0) centra horizontalmente y ancla
          // la punta inferior del marcador sobre las coordenadas.
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }
    _markers = markers;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _buildCustomMarker
  // Genera un BitmapDescriptor nítido a partir del asset logoapp.png
  // escalado al devicePixelRatio de la pantalla mediante dart:ui.
  //
  // El proceso en 9 pasos garantiza que el marcador se renderiza sin
  // pérdida de calidad en dispositivos de alta densidad (tablets, OLED):
  //
  // 1. Carga el asset en memoria como ByteData.
  // 2. Define el tamaño lógico deseado (markerSize en puntos).
  // 3. Calcula el tamaño físico real (markerSize × pixelRatio).
  // 4. Decodifica el asset directamente al tamaño físico.
  // 5. Crea un canvas en tamaño físico con PictureRecorder.
  // 6. Configura el pincel con FilterQuality.high (interpolación bicúbica).
  // 7. Dibuja el logo ocupando todo el canvas físico.
  // 8. Convierte el canvas a PNG en tamaño físico.
  // 9. Crea el BitmapDescriptor con imagePixelRatio para que Google Maps
  //    lo renderice al tamaño lógico correcto sin estirarlo.
  // ─────────────────────────────────────────────────────────────────────────
  Future<BitmapDescriptor> _buildCustomMarker(double pixelRatio) async {
    // 1. Carga el asset del logo desde la carpeta de recursos.
    final ByteData data = await rootBundle.load('assets/images/logoapp.png');

    // 2. Tamaño lógico deseado en pantalla (puntos, no píxeles físicos).
    //    Ajusta este valor para cambiar el tamaño visual del marcador.
    const double markerSize = 50;

    // 3. Tamaño físico real = tamaño lógico × densidad de pantalla.
    //    En una tablet con pixelRatio 2.0 → 50 × 2.0 = 100px físicos.
    final double physicalSize = markerSize * pixelRatio;

    // 4. Decodifica el asset al tamaño físico necesario.
    //    Evita pérdida de calidad por escalado posterior del codec.
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: physicalSize.toInt(),
      targetHeight: physicalSize.toInt(),
    );
    final ui.Image logoImage = (await codec.getNextFrame()).image;

    // 5. Prepara el canvas para dibujar en tamaño físico.
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // 6. Configura el pincel con máxima calidad de filtrado.
    //    FilterQuality.high usa interpolación bicúbica → bordes nítidos.
    final paint = Paint()
      ..filterQuality = ui.FilterQuality.high
      ..isAntiAlias = true;

    // 7. Dibuja el logo ocupando todo el canvas físico.
    //    src: toda la imagen original decodificada.
    //    dst: canvas completo en tamaño físico (no lógico).
    canvas.drawImageRect(
      logoImage,
      Rect.fromLTWH(
          0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
      Rect.fromLTWH(0, 0, physicalSize, physicalSize),
      paint,
    );

    // 8. Convierte el canvas a imagen PNG en tamaño físico.
    //    Usar markerSize aquí produciría un marcador borroso en tablets.
    final ui.Image markerImage = await recorder
        .endRecording()
        .toImage(physicalSize.toInt(), physicalSize.toInt());

    final ByteData? byteData =
        await markerImage.toByteData(format: ui.ImageByteFormat.png);

    // 9. Crea el BitmapDescriptor indicando el pixelRatio al SDK de Maps.
    //    Sin imagePixelRatio Google Maps renderizaría la imagen al doble
    //    del tamaño visual deseado al no saber que está en alta densidad.
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      imagePixelRatio: pixelRatio,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearBars
  // Limpia el estado en memoria al cerrar sesión.
  // Se invoca desde AuthNotifier.logout() para garantizar que el catálogo
  // de bares y los marcadores del usuario anterior no permanecen en memoria
  // si otro usuario inicia sesión en el mismo dispositivo.
  // ─────────────────────────────────────────────────────────────────────────
  void clearBars() {
    _allBars = [];
    _filteredBars = [];
    _markers = {};
    notifyListeners();
  }
}