/// edit_profile_screen.dart
///
/// Pantalla de edición del perfil del usuario en TapeoGo.
///
/// Permite modificar nombre completo, nombre de usuario y foto de perfil.
/// La foto se sube a Supabase Storage y su URL pública se guarda en la
/// tabla 'profiles'. AuthNotifier refresca el perfil en memoria tras guardar
/// para que la UI refleje los cambios sin necesidad de reiniciar la app.
///
/// Gestión de errores: las excepciones de AuthNotifier se propagan hasta
/// el bloque catch de _saveProfile, donde se muestra el SnackBar de error.
/// No se usa ningún booleano _hasError en el notifier.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../notifiers/auth_notifier.dart';
import '../utils/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {

  // Controladores inicializados con los valores actuales del perfil.
  // Se declaran como late porque su inicialización depende del context
  // en initState — no pueden inicializarse en la declaración.
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;

  // Imagen seleccionada localmente. null indica que no hay imagen nueva
  // y se mantiene la URL existente en Supabase Storage sin modificarla.
  File? _selectedImage;

  // _isSaving bloquea el botón durante el guardado para evitar
  // envíos duplicados si el usuario pulsa varias veces seguidas.
  bool _isSaving = false;

  // GlobalKey del formulario para invocar la validación de todos
  // los campos antes de enviar los datos a Supabase.
  final _formKey = GlobalKey<FormState>();

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // context.read porque solo necesitamos el valor inicial del perfil —
    // no nos suscribimos a cambios en initState.
    final profile = context.read<AuthNotifier>().profile;
    _fullNameController = TextEditingController(text: profile?.fullName ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
  }

  @override
  void dispose() {
    // Obligatorio liberar ambos controladores en dispose()
    // para evitar fugas de memoria al salir de la pantalla.
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _pickImage
  // Abre la galería del dispositivo para seleccionar una foto de perfil.
  // imageQuality: 80 comprime la imagen antes de subirla a Storage,
  // reduciendo el tiempo de carga sin pérdida visual apreciable.
  // La imagen seleccionada se muestra como preview inmediato en el avatar
  // antes de confirmar el guardado — mejora la percepción de velocidad.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _saveProfile
  // Orquesta el guardado del perfil en tres pasos secuenciales:
  // 1. Valida el formulario con _formKey — si falla, retorna sin hacer nada.
  // 2. Sube la imagen a Storage si el usuario seleccionó una nueva.
  // 3. Actualiza la tabla 'profiles' mediante AuthNotifier.updateProfile().
  //
  // Las excepciones de AuthNotifier se capturan aquí y se muestran como
  // SnackBar de error, manteniendo al usuario en la pantalla para que
  // corrija el problema sin perder los datos del formulario.
  //
  // finally garantiza que _isSaving vuelve a false tanto si el guardado
  // fue exitoso como si falló — evita que el botón quede bloqueado.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? newAvatarUrl;

      // Solo sube la imagen si el usuario seleccionó una nueva.
      // Si no hay imagen nueva, avatarUrl será null y AuthNotifier
      // mantendrá la URL anterior en la actualización sin sobreescribirla.
      if (_selectedImage != null) {
        newAvatarUrl = await _uploadAvatar(_selectedImage!);
      }

      if (!mounted) return;

      await context.read<AuthNotifier>().updateProfile(
            fullName: _fullNameController.text.trim(),
            username: _usernameController.text.trim(),
            avatarUrl: newAvatarUrl,
          );

      if (!mounted) return;

      // SnackBar de éxito en verde suave — coherente con el sistema
      // de feedback visual del resto de pantallas de la app.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          backgroundColor: const Color(0xFFF0FFF4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF16A34A), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Perfil actualizado correctamente',
                  style: TextStyle(color: Color(0xFF166534), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      // SnackBar de error en rojo suave.
      // El usuario permanece en la pantalla para corregir el problema.
      // replaceFirst elimina el prefijo "Exception: " que Dart añade.
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
                  e.toString().replaceFirst('Exception: ', ''),
                  style: const TextStyle(
                      color: Color(0xFFC62828), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: _uploadAvatar
  // Sube la imagen al bucket 'avatars' de Supabase Storage.
  //
  // El nombre del archivo usa el userId como identificador único —
  // cada actualización sobreescribe el archivo anterior sin acumular
  // imágenes huérfanas en el bucket.
  //
  // upsert: true evita el error 409 Conflict cuando ya existe un archivo
  // con el mismo nombre, permitiendo la sobreescritura directa.
  //
  // Devuelve la URL pública del archivo para persistirla en 'profiles'.
  // ─────────────────────────────────────────────────────────────────────────
  Future<String> _uploadAvatar(File image) async {
    final userId = _supabase.auth.currentUser!.id;
    final fileName = 'avatar_$userId.jpg';

    await _supabase.storage.from('avatars').upload(
          fileName,
          image,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    return _supabase.storage.from('avatars').getPublicUrl(fileName);
  }

  @override
  Widget build(BuildContext context) {
    // context.watch para que el avatar se actualice si el perfil cambia
    // desde otra pantalla mientras esta está abierta en la pila de navegación.
    final profile = context.watch<AuthNotifier>().profile;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: Colors.grey[700], size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Editar Perfil',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // ── Selector de avatar ──
              // Muestra preview local, imagen de Supabase o inicial del nombre.
              _buildAvatarPicker(profile?.avatarUrl),

              const SizedBox(height: 32),

              // ── Campo nombre completo ──
              // Validación: no vacío y mínimo 2 caracteres.
              _buildField(
                controller: _fullNameController,
                label: 'Nombre completo',
                hint: 'Tu nombre y apellidos',
                icon: Icons.person_outline_rounded,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre no puede estar vacío';
                  }
                  if (v.trim().length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ── Campo nombre de usuario ──
              // Validación: mínimo 3 caracteres y solo letras, números y _.
              // La expresión regular previene caracteres especiales que
              // podrían causar problemas en búsquedas o menciones futuras.
              _buildField(
                controller: _usernameController,
                label: 'Nombre de usuario',
                hint: 'Tu alias en TapeoGo',
                icon: Icons.alternate_email_rounded,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre de usuario no puede estar vacío';
                  }
                  if (v.trim().length < 3) {
                    return 'El nombre de usuario debe tener al menos 3 caracteres';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                    return 'Solo se permiten letras, números y _';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // ── Botón de guardado ──
              // Se deshabilita durante _isSaving mostrando un spinner
              // en lugar del texto para indicar actividad en curso.
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[200],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Guardar cambios',
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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildAvatarPicker
  // Muestra la foto de perfil con un icono de cámara superpuesto.
  //
  // Prioridad de imagen:
  // 1. Imagen local recién seleccionada (_selectedImage) — preview inmediato
  //    sin esperar a la subida, mejora la percepción de velocidad.
  // 2. Imagen de Supabase Storage (currentAvatarUrl) — foto guardada.
  // 3. Inicial del nombre en blanco sobre naranja — fallback sin foto.
  //
  // El icono de cámara superpuesto indica visualmente que el avatar
  // es pulsable para cambiar la foto de perfil.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAvatarPicker(String? currentAvatarUrl) {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              image: _selectedImage != null
                  ? DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover)
                  : currentAvatarUrl != null && currentAvatarUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(currentAvatarUrl),
                          fit: BoxFit.cover)
                      : null,
            ),
            // Muestra la inicial solo cuando no hay imagen disponible.
            child: _selectedImage == null &&
                    (currentAvatarUrl == null || currentAvatarUrl.isEmpty)
                ? Center(
                    child: Text(
                      _fullNameController.text.isNotEmpty
                          ? _fullNameController.text[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  )
                : null,
          ),

          // Icono de cámara que indica que el avatar es pulsable.
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
            child: const Icon(Icons.camera_alt_rounded,
                color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildField
  // Campo de texto reutilizable con validación integrada.
  //
  // Usa TextFormField en lugar de TextField para que el Form gestione
  // automáticamente la validación de todos los campos al pulsar guardar.
  // Los cuatro bordes (normal, activo, error, error activo) garantizan
  // coherencia visual en todos los estados del campo.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        filled: true,
        fillColor: Colors.grey[50],
        // Borde en estado normal — gris suave.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        // Borde en estado enfocado — naranja corporativo.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        // Borde en estado de error — rojo para indicar campo inválido.
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        // Borde en estado de error enfocado.
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}