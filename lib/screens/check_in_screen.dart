/// check_in_screen.dart
///
/// Pantalla de registro de visita (check-in) en TapeoGo.
///
/// Coordina cuatro elementos principales:
///   - Captura de foto opcional mediante ImagePicker
///   - Selección del tipo de tapa mediante chips interactivos
///   - Comentario opcional con límite de 200 caracteres
///   - Envío del check-in a VisitNotifier, que gestiona GPS, foto y gamificación
///
/// La gestión de errores sigue el patrón recomendado: VisitNotifier
/// propaga las excepciones con rethrow y esta pantalla las captura
/// en el bloque catch de _processCheckIn para mostrar el SnackBar de error.

import 'dart:io';
import 'package:flutter/foundation.dart';
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

  // _image es nullable porque la foto es opcional.
  // El check-in se completa sin foto si el usuario no selecciona ninguna.
  File? _image;
  String _selectedType = 'serranito';
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // ConfettiController gestiona la animación de celebración al desbloquear
  // una medalla nueva. Se inicializa en initState y libera en dispose.
  late ConfettiController _confettiController;

  // Catálogo de tipos de tapa para los chips de selección.
  // Cada entrada contiene el valor guardado en BD (record_type),
  // la etiqueta visible y el icono representativo del consumo.
  final List<Map<String, dynamic>> _tapaTypes = [
    {'value': 'serranito',       'label': 'Serranito', 'icon': Icons.lunch_dining},
    {'value': 'solomillo_whisky','label': 'Solomillo',  'icon': Icons.kebab_dining},
    {'value': 'croquetas',       'label': 'Croqueta',   'icon': Icons.tapas},
    {'value': 'cerveza',         'label': 'Cerveza',    'icon': Icons.local_bar},
    {'value': 'vino',            'label': 'Vino',       'icon': Icons.wine_bar},
  ];

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    // Obligatorio liberar ambos controladores en dispose()
    // para evitar fugas de memoria al salir de la pantalla.
    _commentController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _pickImage
  // Gestiona la selección de imagen de forma multiplataforma.
  //
  // En web: Image.file no está soportado por Flutter Web, por lo que
  // se muestra un diálogo informativo en lugar de abrir la cámara.
  // kIsWeb es una constante de compilación evaluada en tiempo de compilación,
  // no en ejecución — sin coste de rendimiento en builds de producción.
  //
  // En Android/iOS: imageQuality: 70 comprime la imagen antes de subirla
  // a Supabase Storage, reduciendo el tiempo de carga sin pérdida visual
  // apreciable para el usuario final.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (kIsWeb) {
      // En web mostramos un diálogo informativo en lugar de la cámara.
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: Colors.orange[50], shape: BoxShape.circle),
                child: const Icon(Icons.smartphone_rounded,
                    color: AppColors.primary, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Función disponible en móvil',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'La cámara solo está disponible en la app de Android. Puedes registrar la visita sin foto.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[500], height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // En Android/iOS abre la cámara o galería con compresión imageQuality: 70.
    final XFile? photo =
        await _picker.pickImage(source: source, imageQuality: 70);
    if (photo != null) setState(() => _image = File(photo.path));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _showCheckInSummary
  // BottomSheet de resumen que aparece tras un check-in exitoso sin medallas.
  //
  // isDismissible: false obliga al usuario a pulsar el botón explícitamente,
  // evitando cierres accidentales antes de leer el XP ganado en esta visita.
  //
  // El XP total se lee directamente del perfil ya actualizado en AuthNotifier,
  // que fue sincronizado por VisitNotifier.performCheckIn() antes de aquí.
  // ─────────────────────────────────────────────────────────────────────────
  void _showCheckInSummary(bool gpsVerified) {
    final int xpGanado = gpsVerified ? 20 : 5;
    final int xpTotal = context.read<AuthNotifier>().profile?.xpTotal ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pastilla indicadora del BottomSheet.
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 20),

            // Icono de confirmación verde.
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF16A34A), size: 32),
            ),
            const SizedBox(height: 14),

            const Text(
              '¡Visita registrada!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              widget.bar.name,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            // Resumen del XP ganado en esta visita y el total acumulado.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+$xpGanado XP  →  $xpTotal XP totales',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),

            // Aviso informativo si el check-in no pudo verificarse por GPS.
            // Sin GPS se otorgan solo 5 XP y no se evalúan medallas.
            if (!gpsVerified) ...[
              const SizedBox(height: 8),
              Text(
                'Check-in sin GPS verificado · +5 XP',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cierra el BottomSheet.
                  Navigator.pop(context); // Cierra CheckInScreen.
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  '¡Genial!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _showBadgeCelebration
  // Muestra el AlertDialog de logro desbloqueado y lanza el confeti.
  //
  // barrierDismissible: false evita cerrar el diálogo accidentalmente
  // antes de que el usuario lea el nombre y el XP de la medalla ganada.
  //
  // Si el check-in desbloquea varias medallas a la vez, este método
  // se llama una vez por medalla — un diálogo por logro.
  // ─────────────────────────────────────────────────────────────────────────
  void _showBadgeCelebration(BadgeModel badge) {
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¡LOGRO DESBLOQUEADO!',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 20),

            // Icono de medalla — en producción podría mostrar badge.imageUrl.
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.orange[50],
              child: const Icon(Icons.emoji_events,
                  size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 20),

            Text(
              badge.name,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.titleOrange),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),

            // XP bonus obtenido al desbloquear esta medalla.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(15),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '+${badge.xpBonus} XP',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  '¡Genial!',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.watch para que el botón reaccione a isProcessing y se
    // deshabilite automáticamente mientras el check-in está en curso.
    final visitNotifier = context.watch<VisitNotifier>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: Column(
          children: [
            const Text(
              'Check-in',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16),
            ),
            // Nombre del bar como subtítulo — el usuario sabe siempre
            // en qué establecimiento está registrando la visita.
            Text(
              widget.bar.name,
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      // Sticky footer con el botón de registro — mismo patrón que BarDetailsScreen.
      bottomNavigationBar: _buildStickyButton(visitNotifier),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Sección de foto ──
                // Dos botones para cámara y galería. La foto es opcional:
                // si no se selecciona el check-in se registra sin photo_url.
                _buildSectionLabel('FOTO DE TU TAPA'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildPhotoButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Cámara',
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPhotoButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Galería',
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),

                // Preview de la foto seleccionada.
                // ValueKey garantiza que Flutter identifique la imagen como
                // un elemento nuevo, evitando saltos de scroll inesperados.
                if (_image != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[100]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: kIsWeb
                          ? Image.network(
                              _image!.path,
                              key: ValueKey(_image!.path),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              _image!,
                              key: ValueKey(_image!.path),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Selector de tipo de tapa ──
                // AnimatedContainer anima el cambio de color al seleccionar
                // un chip, proporcionando feedback visual inmediato.
                // El valor seleccionado se guarda en BD como record_type
                // y es la clave del motor de gamificación de medallas.
                _buildSectionLabel('TIPO DE TAPA'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tapaTypes.map((tapa) {
                    final bool isSelected = _selectedType == tapa['value'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedType = tapa['value']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              isSelected ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tapa['icon'] as IconData,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tapa['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // ── Campo de comentario opcional ──
                // maxLength muestra el contador automáticamente debajo del
                // campo. El comentario se guarda como null en BD si está vacío.
                _buildSectionLabel('COMENTARIO (OPCIONAL)'),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'Ej: El mejor serranito de Sevilla...',
                    hintStyle:
                        TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ConfettiWidget superpuesto sobre toda la pantalla.
          // Se activa desde _showBadgeCelebration al desbloquear una medalla.
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

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildSectionLabel
  // Etiqueta de sección en mayúsculas para separar visualmente las tres
  // secciones del formulario: foto, tapa y comentario.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 0.8),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildPhotoButton
  // Botón de selección de foto con fondo naranja suave y borde corporativo.
  // Se usa para los botones de Cámara y Galería con el mismo estilo visual.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPhotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildStickyButton
  // Sticky footer con el botón de registro del check-in.
  // Se deshabilita mientras visitNotifier.isProcessing es true, mostrando
  // un CircularProgressIndicator en lugar del icono para indicar actividad.
  // El color gris del estado deshabilitado evita confundir al usuario.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStickyButton(VisitNotifier visitNotifier) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: visitNotifier.isProcessing ? null : _processCheckIn,
          icon: visitNotifier.isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: Text(
            visitNotifier.isProcessing ? 'Registrando...' : 'Registrar visita',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[200],
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _processCheckIn
  // Punto de entrada de la acción de registro desde la UI.
  //
  // Sigue el patrón recomendado para acciones puntuales del usuario:
  // VisitNotifier propaga las excepciones con rethrow y este método las
  // captura en el bloque catch para mostrar el SnackBar de error.
  // Esto evita usar booleanos _hasError en el notifier y permite mostrar
  // el mensaje exactamente donde ocurre la acción.
  //
  // Flujo de éxito:
  // - Si hay medallas nuevas → _showBadgeCelebration por cada medalla.
  // - Si no hay medallas → _showCheckInSummary con el resumen de XP.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _processCheckIn() async {
    try {
      final String? userId = context.read<AuthNotifier>().currentUserId;
      if (userId == null) {
        throw 'Sesión no válida. Por favor, reinicia la app.';
      }

      final List<BadgeModel> nuevasMedallas =
          await context.read<VisitNotifier>().performCheckIn(
                bar: widget.bar,
                userId: userId,
                profileNotifier: context.read<ProfileNotifier>(),
                badgeNotifier: context.read<BadgeNotifier>(),
                authNotifier: context.read<AuthNotifier>(),
                recordType: _selectedType,
                imageFile: _image,
                // El comentario se pasa como null si el campo está vacío
                // para respetar el esquema nullable de la columna en la BD.
                comment: _commentController.text.isEmpty
                    ? null
                    : _commentController.text,
              );

      if (mounted) {
        if (nuevasMedallas.isNotEmpty) {
          // Muestra un diálogo de celebración por cada medalla desbloqueada.
          for (final badge in nuevasMedallas) {
            _showBadgeCelebration(badge);
          }
        } else {
          // Sin medallas nuevas — muestra el resumen de XP ganado.
          final visits = context.read<VisitNotifier>().visits;
          final bool gpsVerified =
              visits.isNotEmpty ? visits.first.gpsVerified : false;
          _showCheckInSummary(gpsVerified);
        }
      }
    } catch (e) {
      // Las excepciones de VisitNotifier llegan aquí directamente.
      // replaceFirst elimina el prefijo "Exception: " que Dart añade
      // al convertir una excepción a String, mostrando solo el mensaje útil.
      if (mounted) {
        final String mensaje = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            backgroundColor: const Color(0xFFFFF0F0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      color: Color(0xFFFFE0E0), shape: BoxShape.circle),
                  child: const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFE53935), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    mensaje,
                    style: const TextStyle(
                        color: Color(0xFFC62828), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }
}