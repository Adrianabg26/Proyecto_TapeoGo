/// main.dart
///
/// Punto de entrada de TapeoGo.
///
/// Responsabilidades:
///   - Inicializar Supabase antes de arrancar la app.
///   - Crear e inyectar todos los notifiers en el árbol de widgets
///     mediante MultiProvider.
///   - Registrar las referencias entre notifiers para la limpieza al logout.
///   - Gestionar la navegación raíz con el patrón "Portero Automatizado":
///     un StreamBuilder que escucha onAuthStateChange de Supabase y
///     redirige automáticamente entre LoginScreen y MainScreen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'notifiers/auth_notifier.dart';
import 'notifiers/profile_notifier.dart';
import 'notifiers/favorite_notifier.dart';
import 'notifiers/wishlist_notifier.dart';
import 'notifiers/map_notifier.dart';
import 'notifiers/visit_notifier.dart';
import 'notifiers/badge_notifier.dart';

import 'screens/main_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

import 'config/supabase_config.dart';

// Key global del ScaffoldMessenger para mostrar SnackBars desde notifiers
// y pantallas dentro del IndexedStack sin conflictos de contexto.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Obligatorio cuando se usan plugins que acceden a hardware (GPS, cámara).
  // Garantiza que el motor de Flutter esté listo antes de operaciones async.
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase debe inicializarse antes de runApp para que la BD y el
  // sistema de autenticación estén disponibles desde el primer frame.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Creamos las instancias manualmente antes de inyectarlas en el árbol
  // para poder pasarlas a AuthNotifier.registerNotifiers().
  final authNotifier = AuthNotifier();
  final badgeNotifier = BadgeNotifier();
  final favoriteNotifier = FavoriteNotifier();
  final mapNotifier = MapNotifier();
  final profileNotifier = ProfileNotifier();
  final visitNotifier = VisitNotifier();
  final wishlistNotifier = WishlistNotifier();

  // Registramos en AuthNotifier las referencias a todos los notifiers
  // que deben limpiarse al cerrar sesión — patrón de inyección de dependencias.
  // Esto evita que los datos de un usuario sean visibles si otro inicia
  // sesión en el mismo dispositivo sin reinstalar la app.
  authNotifier.registerNotifiers(
    badgeNotifier: badgeNotifier,
    favoriteNotifier: favoriteNotifier,
    mapNotifier: mapNotifier,
    profileNotifier: profileNotifier,
    visitNotifier: visitNotifier,
    wishlistNotifier: wishlistNotifier,
  );

  runApp(
    // MultiProvider inyecta todos los notifiers en la raíz del árbol.
    // Cualquier pantalla puede acceder a ellos con context.watch/read
    // sin acoplamiento directo entre pantallas y lógica de negocio.
    // ChangeNotifierProvider.value usa las instancias ya creadas
    // en lugar de crearlas dentro del provider.
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authNotifier),
        ChangeNotifierProvider.value(value: badgeNotifier),
        ChangeNotifierProvider.value(value: favoriteNotifier),
        ChangeNotifierProvider.value(value: mapNotifier),
        ChangeNotifierProvider.value(value: profileNotifier),
        ChangeNotifierProvider.value(value: visitNotifier),
        ChangeNotifierProvider.value(value: wishlistNotifier),
      ],
      child: const TapeoGoApp(),
    ),
  );
}

class TapeoGoApp extends StatelessWidget {
  const TapeoGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapeoGo',
      debugShowCheckedModeBanner: false,
      // Key global para mostrar SnackBars desde cualquier punto de la app.
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
        ),
        useMaterial3: true,
        // Poppins como fuente global de TapeoGo.
        // Al aplicarla al textTheme base se propaga automáticamente
        // a todos los componentes: botones, diálogos, textos, AppBars.
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.light().textTheme,
        ),
      ),

      // StreamBuilder — patrón "Portero Automatizado".
      // Escucha onAuthStateChange de Supabase en tiempo real.
      // Cuando el usuario hace login o logout, Supabase emite un evento
      // y el StreamBuilder reconstruye automáticamente mostrando
      // MainScreen o LoginScreen sin navegación manual.
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // ConnectionState.waiting: comprobando sesión guardada en disco.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          // FutureBuilder anidado garantiza un mínimo de 2 segundos de
          // SplashScreen para que la animación del logo sea visible.
          return FutureBuilder(
            future: Future.delayed(const Duration(seconds: 2)),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState != ConnectionState.done) {
                return const SplashScreen();
              }

              final session = snapshot.hasData ? snapshot.data!.session : null;

              // Sesión activa → MainScreen. Sin sesión → LoginScreen.
              return session != null ? const MainScreen() : const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
