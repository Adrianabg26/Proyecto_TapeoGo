/// register_screen.dart
///
/// Pantalla de registro de nuevos usuarios en TapeoGo.
///
/// Recoge email, contraseña, nombre de usuario y nombre completo,
/// valida los campos localmente y delega el registro a AuthNotifier,
/// que internamente usa Supabase Auth.
///
/// La navegación post-registro no se gestiona manualmente aquí.
/// Cuando Supabase confirma la sesión, el StreamBuilder de main.dart
/// redirige automáticamente a MainScreen — patrón "Portero Automatizado".
///
/// Gestión de errores: AuthNotifier propaga las excepciones con rethrow
/// y _handleRegister las captura en el bloque catch para mostrar el SnackBar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/auth_notifier.dart';
import '../utils/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Un TextEditingController por campo. Se declaran como atributos del State
  // (no dentro de build) para que persistan entre reconstrucciones del widget.
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();

  // _isLoading bloquea el botón durante el registro para evitar
  // envíos duplicados si el usuario pulsa varias veces.
  bool _isLoading = false;

  @override
  void dispose() {
    // Obligatorio liberar todos los controladores en dispose() para evitar
    // fugas de memoria — cada uno mantiene listeners internos activos.
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _handleRegister
  // Valida los campos localmente antes de llamar a Supabase para evitar
  // peticiones de red innecesarias con datos incompletos o inválidos.
  // Las excepciones de AuthNotifier se capturan aquí y se muestran
  // como SnackBar de error al usuario.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    // Validación 1 — campos vacíos.
    // trim() elimina espacios en blanco accidentales al inicio y al final.
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _fullNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Por favor, rellena todos los campos');
      return;
    }

    // Validación 2 — longitud mínima de contraseña.
    // Supabase Auth requiere mínimo 6 caracteres. Se valida aquí para
    // dar feedback inmediato sin esperar la respuesta del servidor.
    if (_passwordController.text.length < 6) {
      _showErrorSnackBar(
          'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // context.read en lugar de watch porque solo necesitamos llamar
      // al método, no suscribirnos a cambios del notifier.
      // La contraseña no lleva trim() porque los espacios pueden ser
      // parte intencional de la contraseña elegida por el usuario.
      await context.read<AuthNotifier>().register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            username: _usernameController.text.trim(),
            fullName: _fullNameController.text.trim(),
          );

      if (mounted) {
        // SnackBar de éxito en verde suave — coherente con el resto de la app.
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
                  width: 32, height: 32,
                  decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFF16A34A), size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cuenta creada. Revisa tu email para confirmar.',
                    style: TextStyle(
                        color: Color(0xFF166534), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        // No navegamos manualmente — el StreamBuilder de main.dart detecta
        // el cambio de sesión y redirige automáticamente.
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      // finally garantiza que _isLoading vuelve a false tanto si el
      // registro fue exitoso como si falló.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // SnackBar de error reutilizable — evita repetir el mismo bloque
  // en cada validación. Coherente con el estilo del resto de la app.
  void _showErrorSnackBar(String mensaje) {
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
              width: 32, height: 32,
              decoration: const BoxDecoration(
                  color: Color(0xFFFFE0E0), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFE53935), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(mensaje,
                  style: const TextStyle(
                      color: Color(0xFFC62828), fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // AppBar blanco con título naranja — coherente con el resto de
      // pantallas secundarias de la app (check_in, edit_profile).
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.primary),
        title: const Text(
          'Crear cuenta',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            fontSize: 16,
          ),
        ),
      ),
      body: Center(
        // SingleChildScrollView permite desplazar el formulario cuando
        // el teclado virtual sube y reduce el espacio disponible.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logoconletra.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),

              // Campos en orden: nombre completo → usuario → email → contraseña.
              // Todos usan _buildTextField para garantizar coherencia visual
              // con LoginScreen — principio DRY.
              _buildTextField(
                controller: _fullNameController,
                label: 'Nombre completo',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _usernameController,
                label: 'Nombre de usuario',
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 35),

              // Botón de registro. Se deshabilita durante la petición
              // mostrando un spinner en lugar del texto.
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Crear cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Navigator.pop() vuelve a LoginScreen sin añadir una nueva
              // ruta a la pila — equivalente al botón de retroceso del dispositivo.
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '¿Ya tienes cuenta? Inicia sesión',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET AUXILIAR: _buildTextField
  // Campo de texto reutilizable con decoración coherente con LoginScreen.
  // Centralizar la decoración en un único método garantiza que cualquier
  // cambio de estilo se aplique a todos los campos simultáneamente.
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}