/// camera_view.dart
///
/// Pantalla de captura de imagen que actúa como interfaz entre
/// la app y la cámara del dispositivo.
///
/// Inicializa el controlador de cámara de forma asíncrona y muestra
/// un preview en tiempo real. Al pulsar el botón de captura, toma
/// la foto y la devuelve como objeto File a la pantalla anterior
/// mediante Navigator.pop, para que el notifier gestione la subida
/// a Supabase Storage.
///
/// Es un StatefulWidget porque necesita gestionar el ciclo de vida
/// del CameraController, un recurso de hardware que debe inicializarse
/// y liberarse correctamente para no consumir batería innecesariamente.

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _setupCamera
  // Localiza las cámaras disponibles del dispositivo y configura
  // el controlador con la cámara trasera por defecto.
  // Se usa ResolutionPreset.medium para optimizar el tamaño del archivo
  // resultante y acelerar la subida a Supabase Storage.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller!.initialize();

    // mounted comprueba que el widget sigue en el árbol antes de llamar
    // a setState, evitando errores si el usuario sale antes de que
    // la cámara termine de inicializarse
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // La cámara es un recurso de hardware costoso en batería y RAM.
    // dispose() libera el hardware inmediatamente al salir de la pantalla.
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Captura tu tapa'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          // Mientras la cámara inicializa mostramos un spinner.
          // Cuando el Future completa mostramos el preview en tiempo real.
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null) {
            return Center(child: CameraPreview(_controller!));
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.orange),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
        onPressed: () async {
          try {
            await _initializeControllerFuture;

            final XFile image = await _controller!.takePicture();

            if (!mounted) return;

            // Devolvemos el File a CheckInScreen mediante Navigator.pop.
            // La pantalla anterior recibe la foto y la pasa a VisitNotifier
            // para que gestione la subida a Supabase Storage.
            Navigator.pop(context, File(image.path));
          } catch (e) {
            debugPrint('Error al realizar la captura: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Error al capturar la imagen. Inténtalo de nuevo.',
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }
}