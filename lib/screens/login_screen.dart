/// login_screen.dart
///
/// Pantalla de inicio de sesión de TapeoGo.
///
/// La navegación post-login no se gestiona manualmente aquí.
/// El StreamBuilder de main.dart escucha onAuthStateChange de Supabase
/// y redirige automáticamente a MainScreen cuando la sesión se activa.
/// Este patrón se denomina "Portero Automatizado" y evita código de
/// navegación manual disperso por la app.
///
/// Gestión de errores: AuthNotifier propaga las excepciones con rethrow
/// y _handleLogin las captura en el bloque catch para mostrar el SnackBar.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/auth_notifier.dart';
import '../utils/app_colors.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // _isLoading bloquea el botón durante el login para evitar
  // envíos duplicados si el usuario pulsa varias veces.
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _handleLogin
  // Valida los campos localmente antes de llamar a Supabase para evitar
  // peticiones de red innecesarias con campos vacíos.
  // La autenticación se delega a AuthNotifier, que internamente usa
  // Supabase Auth — la app nunca gestiona contraseñas directamente.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    // Validación local: campos vacíos se detectan antes de llamar a Supabase.
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
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
              const Expanded(
                child: Text(
                  'Por favor, introduce tu email y contraseña',
                  style: TextStyle(
                      color: Color(0xFFC62828), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthNotifier>().login(
            _emailController.text.trim(),
            // No se aplica trim() a la contraseña porque los espacios
            // son parte válida de ella y eliminarlos podría bloquear el acceso.
            _passwordController.text,
          );
      // No navegamos manualmente tras el login.
      // onAuthStateChange en Supabase notifica el cambio de sesión y
      // el StreamBuilder de main.dart redirige automáticamente a MainScreen.
    } catch (e) {
      if (mounted) {
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
      }
    } finally {
      // finally garantiza que _isLoading vuelve a false tanto si
      // el login fue exitoso como si falló.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo con el nombre de la app — primera impresión del usuario.
              Image.asset(
                'assets/images/logoconletra.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const Text(
                'Explora Sevilla tapa a tapa',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 50),

              // Campo de email con teclado de tipo email para mayor comodidad.
              _buildTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Campo de contraseña con obscureText para ocultar los caracteres.
              _buildTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 35),

              // Botón de login. Se deshabilita durante la petición
              // mostrando un spinner en lugar del texto.
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Iniciar sesión',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              // Enlace a RegisterScreen para usuarios nuevos.
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  '¿No tienes cuenta? Regístrate aquí',
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
  // Campo de texto reutilizable que centraliza la decoración visual.
  // Al tener un único método para todos los campos, cualquier cambio
  // de estilo se aplica de forma consistente — principio DRY.
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
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}