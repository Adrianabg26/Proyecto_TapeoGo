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

// StatefulWidget porque necesita:
// 1. TextEditingController para cada campo de texto (requieren dispose)
// 2. _isLoading para alternar el estado del botón durante el registro
// Si fuera StatelessWidget no podría gestionar ninguno de estos dos estados.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Un TextEditingController por cada campo de texto.
  // Permiten leer el valor actual del campo con .text y limpiarlo con .clear().
  // Se declaran aquí (no en build) para que persistan entre rebuilds del widget.
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();

  // Estado local del botón: true mientras la petición a Supabase está en curso.
  // Deshabilita el botón y muestra el spinner para evitar envíos duplicados.
  bool _isLoading = false;

  @override
  void dispose() {
    // CRÍTICO: liberar todos los controladores cuando el widget se destruye.
    // Cada TextEditingController mantiene un listener interno que consume
    // memoria. Sin dispose() se producen fugas de memoria y warnings de Flutter.
    // El orden es indiferente entre controladores, pero dispose() siempre
    // debe llamarse antes de super.dispose().
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
    // Validación local ANTES de llamar a Supabase para ahorrar una petición
    // de red innecesaria. .trim() elimina espacios en blanco al inicio y al
    // final, evitando que un usuario con solo espacios pase la validación.
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, rellena todos los campos'),
          backgroundColor: Colors.redAccent,
          // floating eleva el SnackBar sobre el contenido en lugar de
          // pegarlo al borde inferior, más visible en móvil.
          behavior: SnackBarBehavior.floating,
        ),
      );
      return; // Salida temprana: no continuar si la validación falla
    }

    // Validación de longitud mínima de contraseña (requisito de Supabase Auth).
    // Se comprueba aquí para dar feedback inmediato sin esperar la respuesta
    // del servidor, que devolvería un error menos descriptivo para el usuario.
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

    // Activar estado de carga: deshabilita el botón y muestra el spinner.
    // setState() provoca un rebuild que renderiza el CircularProgressIndicator
    // en lugar del texto del botón.
    setState(() => _isLoading = true);

    try {
      // context.read (no watch) porque solo necesitamos llamar al método,
      // no suscribirnos a cambios del notifier desde aquí.
      // Los parámetros van con .trim() para limpiar espacios accidentales
      // antes de enviarlos a Supabase.
      // La contraseña no lleva .trim() porque los espacios podrían ser
      // intencionados y parte de la contraseña elegida por el usuario.
      await context.read<AuthNotifier>().register(
            email:    _emailController.text.trim(),
            password: _passwordController.text,
            username: _usernameController.text.trim(),
            fullName: _fullNameController.text.trim(),
          );

      // mounted comprueba que el widget sigue en el árbol antes de usar
      // el context. Es necesario después de cualquier await porque el widget
      // podría haberse destruido mientras esperábamos la respuesta de Supabase.
      // Sin esta comprobación, showSnackBar lanzaría un error si el usuario
      // navegó a otra pantalla durante el registro.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada. Revisa tu email para confirmar.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // NOTA: no hay Navigator.push() aquí. La navegación a MainScreen
        // la gestiona automáticamente el StreamBuilder de main.dart cuando
        // Supabase Auth emite el evento de sesión activa tras la confirmación
        // del email. Esto evita duplicar la lógica de navegación.
      }
    } catch (e) {
      // Captura cualquier excepción lanzada por AuthNotifier.register().
      // Supabase lanza excepciones con mensajes descriptivos (email ya
      // registrado, contraseña débil, etc.) que se muestran directamente
      // al usuario con e.toString().
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
      // finally se ejecuta SIEMPRE: tanto si el try tuvo éxito como si
      // lanzó una excepción. Garantiza que _isLoading vuelva a false y
      // el botón quede habilitado en cualquier escenario.
      // Sin el finally, un error en el try dejaría el botón deshabilitado
      // permanentemente hasta que el usuario saliera de la pantalla.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,          // Sin sombra para estilo flat coherente con el resto
        foregroundColor: AppColors.titleOrange, // Color del botón de retroceso
        title: const Text(
          'Crear cuenta',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.titleOrange,
          ),
        ),
      ),
      body: Center(
        // SingleChildScrollView permite que el formulario sea desplazable
        // cuando el teclado virtual sube y reduce el espacio disponible.
        // Sin él, los campos inferiores quedarían ocultos bajo el teclado.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo a tamaño reducido (120) respecto a SplashScreen (220)
              // porque aquí comparte espacio con el formulario.
              Image.asset(
                'assets/logoconletra.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 30),

              // Los cuatro campos usan _buildTextField para garantizar
              // consistencia visual entre sí y con LoginScreen.
              // El orden nombre completo → usuario → email → contraseña
              // sigue el flujo natural de creación de cuenta.
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

              // keyboardType: emailAddress muestra el teclado optimizado
              // para emails (con @ visible sin cambiar de teclado).
              _buildTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // isPassword: true activa obscureText en el campo,
              // que oculta los caracteres con puntos mientras el usuario escribe.
              _buildTextField(
                controller: _passwordController,
                label: 'Contraseña',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 35),

              // SizedBox con width: double.infinity hace que el botón
              // ocupe todo el ancho disponible independientemente del
              // tamaño del texto que contenga.
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  // onPressed: null deshabilita el botón durante la carga.
                  // Flutter aplica automáticamente el estilo "deshabilitado"
                  // (color grisado) cuando onPressed es null.
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  // Operador ternario que alterna entre spinner y texto
                  // según el estado de _isLoading. El spinner está acotado
                  // por el SizedBox del botón (height: 55) por lo que
                  // no necesita su propio SizedBox para no desbordarse.
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

              // Navigator.pop() devuelve a LoginScreen sin añadir una nueva
              // ruta a la pila de navegación. Es la forma correcta de
              // "volver atrás" en Flutter, equivalente al botón de retroceso.
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
    // Valores por defecto para los parámetros opcionales:
    // la mayoría de campos no son contraseña y usan teclado de texto normal.
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      // obscureText oculta el texto cuando isPassword es true.
      // Solo activo en el campo de contraseña.
      obscureText: isPassword,
      // keyboardType adapta el teclado al tipo de dato esperado.
      // emailAddress muestra el @ en el teclado principal.
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        // prefixIcon añade el icono dentro del campo a la izquierda,
        // alineado verticalmente con el texto.
        prefixIcon: Icon(icon, color: Colors.orange),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        // focusedBorder sobreescribe el borde por defecto cuando el campo
        // está activo (usuario escribiendo), dándole el color naranja
        // corporativo y un borde más grueso para indicar el foco activo.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }
}