/// check_in_screen.dart
///
/// Pantalla que gestiona el proceso completo de registro de una visita.
/// Permite al usuario fotografiar su tapa, categorizar el tipo de consumo
/// para el sistema de gamificación, añadir un comentario opcional y
/// enviar el check-in a través de VisitNotifier.
///
/// Tras un check-in exitoso con GPS verificado, muestra una animación
/// de confeti y un diálogo de celebración si el usuario ha desbloqueado
/// nuevas medallas.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../models/bar_model.dart';
import '../models/badge_model.dart';
import '../notifiers/visit_notifier.dart';
import '../notifiers/profile_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/badge_notifier.dart';
import '../utils/app_colors.dart';

class CheckInScreen extends StatefulWidget {
  final BarModel bar;

  const CheckInScreen({super.key, required this.bar});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  File? _image;
  String _selectedType = 'serranito';
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Controlador de confeti para celebrar el desbloqueo de medallas
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    // Liberamos ambos controladores para evitar fugas de memoria
    _commentController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _takePhoto
  // Abre la cámara con compresión imageQuality: 70 para optimizar
  // el peso del archivo antes de subirlo a Supabase Storage.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );

    if (photo != null) {
      setState(() => _image = File(photo.path));
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _showBadgeCelebration
  // Lanza el confeti y muestra el diálogo de logro desbloqueado.
  // Se invoca una vez por cada medalla nueva obtenida tras el check-in.
  // ───────────────────────────────────────────────────────────────────────────

  void _showBadgeCelebration(BadgeModel badge) {
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¡LOGRO DESBLOQUEADO!',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 45,
              backgroundColor: Colors.orangeAccent,
              child: Icon(Icons.emoji_events, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              badge.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.titleOrange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            Text(
              '+${badge.xpBonus} XP',
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                '¡Genial!',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visitNotifier = context.watch<VisitNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Check-in en ${widget.bar.name}',
          style: const TextStyle(color: AppColors.titleOrange),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.titleOrange),
      ),
      // Stack para superponer el confeti sobre el formulario
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Área de captura de imagen
                GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.5),
                      ),
                    ),
                    child: _image == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 50, color: Colors.orange),
                              SizedBox(height: 8),
                              Text('Pulsa para hacer foto a tu tapa'),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(_image!, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Selector de tipo de consumo para gamificación
                const Text(
                  '¿Qué has tomado?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.titleOrange,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: 'serranito', child: Text('Serranito')),
                      DropdownMenuItem(
                          value: 'cerveza', child: Text('Cerveza')),
                      DropdownMenuItem(
                          value: 'croquetas', child: Text('Croquetas')),
                      DropdownMenuItem(value: 'vino', child: Text('Vino')),
                      DropdownMenuItem(
                          value: 'solomillo_whisky',
                          child: Text('Solomillo al Whisky')),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedType = value!),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo de comentario opcional
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '¿Qué te ha parecido?',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: El mejor serranito de Sevilla...',
                  ),
                ),
                const SizedBox(height: 30),

                // Botón de acción principal
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        visitNotifier.isProcessing ? null : _processCheckIn,
                    child: visitNotifier.isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'REGISTRAR VISITA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Confeti superpuesto sobre toda la pantalla
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.orange,
                Colors.red,
                Colors.yellow,
                Colors.green,
              ],
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _processCheckIn
  // Orquesta el proceso completo del check-in y gestiona las medallas
  // nuevas mostrando el diálogo de celebración por cada una.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _processCheckIn() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, haz una foto a tu tapa')),
      );
      return;
    }

    try {
      final String? userId = context.read<AuthNotifier>().currentUserId;

      if (userId == null) {
        throw 'Sesión no válida. Por favor, reinicia la app.';
      }

      // Ejecutamos el pipeline completo del check-in
      final List<BadgeModel> nuevasMedallas =
          await context.read<VisitNotifier>().performCheckIn(
                bar: widget.bar,
                userId: userId,
                profileNotifier: context.read<ProfileNotifier>(),
                badgeNotifier: context.read<BadgeNotifier>(),
                recordType: _selectedType,
                imageFile: _image!,
                comment: _commentController.text.isEmpty
                    ? null
                    : _commentController.text,
              );

      if (mounted) {
        // Si hay medallas nuevas mostramos la celebración por cada una
        if (nuevasMedallas.isNotEmpty) {
          for (final badge in nuevasMedallas) {
            _showBadgeCelebration(badge);
          }
        } else {
          // Check-in exitoso sin medallas nuevas
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visita registrada con éxito'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}