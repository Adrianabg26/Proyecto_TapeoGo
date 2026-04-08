/// login_screen.dart
///
/// Pantalla de inicio de sesión de TapeoGo. Permite al usuario
/// autenticarse mediante email y contraseña a través de AuthNotifier,
/// que delega la operación a Supabase Auth.
///
/// No gestiona la navegación post-login manualmente. El StreamBuilder
/// definido en main.dart detecta el cambio de sesión mediante
/// onAuthStateChange y redirige automáticamente al mapa principal,
/// siguiendo el patrón Observer.
///
/// Es un StatefulWidget porque gestiona estado local: los controladores
/// de texto y el indicador de carga del botón.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/auth_notifier.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    // Liberamos los controladores para evitar fugas de memoria
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _handleLogin
  // Delega la autenticación a AuthNotifier, que usa Supabase Auth internamente.
  // Separa la lógica de autenticación de la pantalla, siguiendo el patrón
  // de arquitectura del proyecto.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      await context.read<AuthNotifier>().login(
            _emailController.text.trim(),
            // No aplicamos trim() a la contraseña porque los espacios
            // forman parte válida de la misma y eliminarlos podría
            // impedir el acceso a usuarios con espacios en su contraseña
            _passwordController.text,
          );

      // No navegamos manualmente: onAuthStateChange en AuthNotifier
      // detecta el login y el StreamBuilder de main.dart redirige al mapa
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
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
              // Logo e identidad visual de la app
              Image.asset(
                'assets/images/logoconletra.png',
                height: 180,
                fit: BoxFit.contain,
              ),
              const Text(
                'Tu pasaporte gastronómico por Sevilla',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 50),

              // Campo de email
              _buildTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // Campo de contraseña
              _buildTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 35),

              // Botón principal de login.
              // Se deshabilita mientras se procesa para evitar
              // envíos duplicados y muestra un spinner como feedback.
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
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

              // Navegación a la pantalla de registro para nuevos usuarios
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: const Text(
                  '¿No tienes cuenta? Regístrate aquí',
                  style: TextStyle(
                    color: Colors.orange,
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
  // Centraliza la construcción de campos de texto para evitar duplicar
  // la decoración en cada campo. Si hay que cambiar el estilo de todos
  // los campos, solo hay que modificar este método.
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
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }
}
