/// map_helper.dart
///
/// Utilidad estática para generar assets escalados a la densidad real
/// de pantalla del dispositivo.
///
/// Se usa en MapNotifier para garantizar que los marcadores personalizados
/// de Google Maps son nítidos en tablets y pantallas de alta densidad,
/// evitando el efecto borroso que produce escalar imágenes en baja resolución.

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class MapHelper {

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO ESTÁTICO: getBytesFromAsset
  // Carga un asset desde la carpeta de recursos y lo escala al tamaño
  // físico real de la pantalla para garantizar nitidez en cualquier
  // densidad de píxeles.
  //
  // El problema que resuelve: si se carga un asset a 50px lógicos en una
  // tablet con pixelRatio 2.0, el sistema necesita 100px físicos. Sin este
  // escalado el asset se estira y aparece borroso en pantallas de alta densidad.
  //
  // Parámetros:
  // - [path]: ruta del asset relativa a la carpeta assets/ del proyecto.
  // - [logicalSize]: tamaño visual deseado en puntos lógicos (dp).
  // - [pixelRatio]: ratio de píxeles del dispositivo, obtenido mediante
  //   MediaQuery.of(context).devicePixelRatio desde la UI.
  //
  // Devuelve los bytes PNG del asset escalado, listos para usarse con
  // BitmapDescriptor.bytes() en Google Maps.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> getBytesFromAsset(
    String path, {
    required double logicalSize,
    required double pixelRatio,
  }) async {
    // Calcula el tamaño físico real multiplicando el tamaño lógico
    // por el ratio de píxeles del dispositivo.
    // Ejemplo: logicalSize=50, pixelRatio=2.0 → physicalSize=100px
    final int physicalSize = (logicalSize * pixelRatio).toInt();

    // Carga el asset desde el bundle de la aplicación.
    final ByteData data = await rootBundle.load(path);

    // Decodifica el asset directamente al tamaño físico necesario.
    // Hacerlo en este paso evita pérdida de calidad por escalado posterior.
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: physicalSize,
      targetHeight: physicalSize,
    );

    // Obtiene el primer fotograma de la imagen decodificada.
    final ui.FrameInfo fi = await codec.getNextFrame();

    // Convierte la imagen a bytes PNG y los devuelve como Uint8List.
    // El formato PNG preserva la transparencia del logo.
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }
}