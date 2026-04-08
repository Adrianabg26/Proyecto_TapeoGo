/// splash_screen.dart
///
/// Pantalla de bienvenida que se muestra durante la inicialización de la app.
/// Muestra el logo de TapeoGo mientras el StreamBuilder de main.dart
/// comprueba si hay una sesión activa guardada en el dispositivo.
///
/// Es un StatefulWidget porque usa AnimationController para animar
/// la entrada del logo con un efecto de fundido y escala suave.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

// StatefulWidget porque necesita AnimationController, que requiere
// ciclo de vida (initState para crear, dispose para liberar).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// SingleTickerProviderStateMixin proporciona el "ticker" que necesita
// AnimationController para sincronizarse con el framerate de la pantalla.
// Se usa "Single" porque solo hay un AnimationController en este widget.
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  // "late" porque se inicializan en initState, no en la declaración.
  // Dart garantiza que estarán asignados antes de usarse si initState
  // se ejecuta correctamente, por eso no necesitan ser nullables.
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // AnimationController es el "reloj" de la animación.
    // duration define cuánto dura el ciclo completo (0.0 → 1.0).
    // vsync: this conecta el controlador con el ticker del mixin,
    // lo que evita que la animación consuma recursos cuando el widget
    // no está visible (por ejemplo, si la app va a segundo plano).
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Tween define el rango de valores: de 0.0 (transparente) a 1.0 (opaco).
    // CurvedAnimation aplica una curva de velocidad sobre el controlador.
    // Interval(0.0, 0.7) significa que esta animación solo actúa durante
    // el primer 70% del tiempo total (0ms → 840ms de los 1200ms).
    // Curves.easeIn hace que empiece lento y acelere hacia el final.
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    // Escala de 0.7 (70% del tamaño final) a 1.0 (tamaño normal).
    // Interval(0.0, 0.8) → actúa durante el primer 80% del tiempo (960ms).
    // Curves.easeOutBack produce el efecto de "rebote suave": el logo
    // llega al tamaño final y lo supera ligeramente antes de asentarse.
    // Este efecto da la sensación de que el logo "aterriza" en su posición.
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    // forward() arranca la animación desde el valor inicial (0.0)
    // hasta el valor final (1.0). Se llama aquí porque queremos que
    // empiece inmediatamente al aparecer la pantalla.
    _animationController.forward();
  }

  @override
  void dispose() {
    // CRÍTICO: liberar el AnimationController cuando el widget se destruye.
    // Si no se hace, el controlador sigue consumiendo recursos y ejecutando
    // callbacks aunque el widget ya no esté en pantalla, lo que provoca
    // errores del tipo "setState called after dispose".
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        // AnimatedBuilder escucha los cambios del controlador y reconstruye
        // solo el subárbol que depende de la animación, en cada frame.
        // Es más eficiente que llamar a setState() manualmente porque
        // no reconstruye el widget completo, solo el builder.
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // FadeTransition conecta directamente la opacidad del widget
            // con _fadeAnimation. Cada frame que el controlador avanza,
            // FadeTransition actualiza la opacidad sin reconstruir el árbol.
            return FadeTransition(
              opacity: _fadeAnimation,
              // ScaleTransition hace lo mismo para la escala: aplica
              // la transformación de tamaño frame a frame sin rebuild.
              // Ambas transiciones actúan simultáneamente, produciendo
              // el efecto combinado de "aparición con crecimiento suave".
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo principal. Se carga desde assets, 
                    // declarado en pubspec.yaml bajo assets:.
                    // height: 220 con BoxFit.contain garantiza que el logo
                    // nunca se deforma ni sale de sus límites.
                    Image.asset(
                      'assets/images/logoconletra.png',
                      height: 220,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // CircularProgressIndicator acotado en un SizedBox.
                    // Sin el SizedBox, el indicador intentaría ocupar
                    // todo el ancho disponible dentro de la Column.
                    // strokeWidth: 3 lo hace más fino y elegante que
                    // el valor por defecto (4.0).
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tagline estático, no anima por separado.
                    // Al estar dentro de FadeTransition y ScaleTransition,
                    // hereda ambas animaciones junto al resto del Column.
                    const Text(
                      'Tu pasaporte gastronómico por Sevilla',
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