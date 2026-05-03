/// main_screen.dart
///
/// Contenedor principal de navegación de TapeoGo tras el login.
///
/// Combina dos widgets de Flutter para gestionar la navegación:
///   - BottomNavigationBar: barra inferior con las cuatro secciones.
///   - IndexedStack: mantiene todas las pantallas en memoria simultáneamente
///     y muestra solo la que corresponde al índice activo.
///
/// La ventaja del IndexedStack frente a reconstruir la pantalla en cada
/// cambio de pestaña es que preserva el estado: el mapa mantiene su posición,
/// las listas no se recargan y los campos de texto conservan su contenido.

import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import 'home_map_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Índice de la pestaña activa. Empieza en 0 (mapa).
  int _selectedIndex = 0;

  // Callback que permite a las pantallas hijas navegar al mapa
  // sin usar Navigator.push — simplemente cambia el índice del IndexedStack.
  // Se pasa a WishlistScreen, FavoritesScreen y ProfileScreen para que
  // sus estados vacíos puedan redirigir al usuario al mapa.
  void _goToExplore() => setState(() => _selectedIndex = 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack construye todas las pantallas al arrancar
      // y las mantiene en memoria mientras la sesión está activa.
      // Solo es visible la pantalla cuyo índice coincide con _selectedIndex.
      body: IndexedStack(
        index: _selectedIndex,
        // La lista se construye en cada build (no como variable final)
        // porque las pantallas necesitan recibir _goToExplore actualizado.
        children: [
          const HomeMapScreen(),
          WishlistScreen(onGoToExplore: _goToExplore),
          FavoritesScreen(onGoToExplore: _goToExplore),
          ProfileScreen(onGoToExplore: _goToExplore),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        // BottomNavigationBarType.fixed mantiene los iconos en posición
        // fija independientemente del número de pestañas.
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Explorar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_outlined),
            activeIcon: Icon(Icons.bookmark),
            label: 'Guardados',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Mi Perfil',
          ),
        ],
      ),
    );
  }
}