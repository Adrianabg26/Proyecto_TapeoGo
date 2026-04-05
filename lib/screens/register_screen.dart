/// register_screen.dart
///
/// Pantalla de registro de nuevos usuarios en TapeoGo.
/// Permite crear una cuenta mediante email, contraseña, nombre de usuario
/// y nombre completo a través de AuthNotifier, que delega la operación
/// a Supabase Auth.
///
/// Tras el registro exitoso, Supabase envía un email de confirmación.
/// El StreamBuilder de main.dart gestiona la navegación automáticamente
/// cuando la sesión queda activa.

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    // Liberamos todos los controladores para evitar fugas de memoria
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: _handleRegister
  // Valida los campos localmente antes de enviar la petición a Supabase.
  // Delega el registro a AuthNotifier para mantener la separación entre
  // la UI y la lógica de negocio.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    // Validación básica de campos vacíos antes de llamar a Supabase
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, rellena todos los campos'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthNotifier>().register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            username: _usernameController.text.trim(),
            fullName: _fullNameController.text.trim(),
          );

      // Si el registro es exitoso mostramos un mensaje informativo.
      // La navegación la gestiona el StreamBuilder de main.dart
      // cuando Supabase confirma la sesión activa.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada. Revisa tu email para confirmar.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.titleOrange,
        title: const Text(
          'Crear cuenta',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.titleOrange,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo de TapeoGo
              Image.asset(
                'assets/logoconletra.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),

              // Campo nombre completo
              _buildTextField(
                controller: _fullNameController,
                label: 'Nombre completo',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 16),

              // Campo nombre de usuario
              _buildTextField(
                controller: _usernameController,
                label: 'Nombre de usuario',
                icon: Icons.alternate_email,
              ),
              const SizedBox(height: 16),

              // Campo email
              _buildTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Campo contraseña
              _buildTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 35),

              // Botón de registro
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
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

              // Volver al login
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '¿Ya tienes cuenta? Inicia sesión',
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
  // Centraliza la construcción de campos de texto para mantener
  // consistencia visual con LoginScreen.
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