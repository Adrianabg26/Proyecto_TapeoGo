/// main.dart
///
/// Punto de entrada de TapeoGo. Inicializa Supabase, configura el árbol
/// de providers con todos los notifiers y gestiona la navegación raíz
/// mediante un StreamBuilder que escucha el estado de autenticación.
///
/// El patrón "Portero Automatizado" con StreamBuilder garantiza que
/// la app siempre muestre la pantalla correcta según el estado de sesión,
/// sin necesidad de gestionar la navegación manualmente tras el login
/// o el logout.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

Future<void> main() async {
  // Obligatorio al usar plugins que acceden a hardware (GPS, cámara).
  // Garantiza que el motor de Flutter esté vinculado antes de iniciar
  // procesos asíncronos.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos Supabase antes de arrancar la app para garantizar
  // que la base de datos y el sistema de autenticación estén disponibles.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Creamos las instancias de los notifiers antes de pasarlas al árbol
  // de providers para poder registrarlas en AuthNotifier.
  final authNotifier = AuthNotifier();
  final badgeNotifier = BadgeNotifier();
  final favoriteNotifier = FavoriteNotifier();
  final mapNotifier = MapNotifier();
  final profileNotifier = ProfileNotifier();
  final visitNotifier = VisitNotifier();
  final wishlistNotifier = WishlistNotifier();

  // Registramos en AuthNotifier las referencias a todos los notifiers
  // que deben limpiarse al cerrar sesión. Esto evita que los datos
  // del usuario anterior sean visibles si otro inicia sesión en el
  // mismo dispositivo.
  authNotifier.registerNotifiers(
    badgeNotifier: badgeNotifier,
    favoriteNotifier: favoriteNotifier,
    mapNotifier: mapNotifier,
    profileNotifier: profileNotifier,
    visitNotifier: visitNotifier,
    wishlistNotifier: wishlistNotifier,
  );

  runApp(
    // MultiProvider inyecta todos los notifiers en la raíz del árbol
    // de widgets, permitiendo que cualquier pantalla acceda a ellos
    // sin acoplamiento directo entre pantallas y lógica de negocio.
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
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          primary: Colors.orange,
        ),
        useMaterial3: true,
      ),

      // StreamBuilder actúa como "portero automatizado".
      // Escucha onAuthStateChange de Supabase y redirige automáticamente
      // entre LoginScreen y MainScreen según el estado de sesión,
      // sin necesidad de navegación manual tras login o logout.
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Fase de sincronización: comprobando si hay sesión guardada
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }

          final session = snapshot.hasData ? snapshot.data!.session : null;

          if (session != null) {
            return const MainScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
