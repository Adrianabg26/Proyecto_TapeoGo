/// splash_screen.dart
///
/// Pantalla de bienvenida que se muestra durante la inicialización de la app.
/// Muestra el logo animado mientras el StreamBuilder de main.dart comprueba
/// si hay una sesión activa guardada en el dispositivo.
///
/// Combina dos animaciones simultáneas sobre el mismo controlador:
///   - FadeTransition: fundido de transparente a opaco.
///   - ScaleTransition: crecimiento suave con efecto easeOutBack.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// SingleTickerProviderStateMixin proporciona el vsync al AnimationController.
// Sincroniza la animación con el framerate del dispositivo y pausa el consumo
// de recursos cuando la app va a segundo plano.
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // AnimationController es el reloj de la animación.
    // Genera valores de 0.0 a 1.0 durante 1200ms.
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Interval(0.0, 0.7) limita esta animación al primer 70% del tiempo.
    // El logo aparece de transparente a opaco durante los primeros 840ms.
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    // Interval(0.0, 0.8) limita esta animación al primer 80% del tiempo.
    // easeOutBack produce el efecto de "rebote suave" al final de la escala
    // — el logo supera ligeramente el tamaño final antes de asentarse.
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    // Arranca la animación inmediatamente al aparecer la pantalla.
    _animationController.forward();
  }

  @override
  void dispose() {
    // Obligatorio liberar el AnimationController para evitar que siga
    // ejecutando callbacks después de que el widget se destruya.
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // AnimatedBuilder reconstruye solo su subárbol en cada frame
        // de la animación, sin reconstruir el widget completo.
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo principal cargado desde assets.
                    Image.asset(
                      'assets/images/logoconletra.png',
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // Spinner de carga mientras el StreamBuilder de main.dart
                    // verifica la sesión activa en Supabase.
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'Explora Sevilla tapa a tapa',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}