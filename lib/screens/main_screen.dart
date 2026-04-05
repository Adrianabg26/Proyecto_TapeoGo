/// main_screen.dart
///
/// Contenedor principal de navegación de TapeoGo tras el login.
/// Gestiona la navegación entre las secciones principales mediante
/// un BottomNavigationBar y un IndexedStack.
///
/// El IndexedStack mantiene el estado de todas las pantallas aunque
/// no estén visibles, evitando recargas innecesarias al cambiar de
/// pestaña. Por ejemplo, si el usuario mueve el mapa y va a su perfil,
/// al volver el mapa seguirá en la misma posición.
///
/// Es un StatefulWidget porque necesita gestionar el índice de la
/// pestaña activa mediante setState.

import 'package:flutter/material.dart';
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

  // Lista de pantallas gestionadas por el IndexedStack.
  // Se define como final porque nunca cambia durante el ciclo de vida.
  // Cada pantalla se instancia una sola vez y mantiene su estado.
  final List<Widget> _screens = const [
    HomeMapScreen(),
    WishlistScreen(),
    FavoritesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack mantiene todas las pantallas en memoria simultáneamente
      // y muestra solo la que corresponde al índice activo.
      // Ventaja frente a un simple if/else: preserva el estado de cada
      // pantalla aunque no esté visible.
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        // BottomNavigationBarType.fixed mantiene los iconos en posición
        // estática independientemente del número de pestañas,
        // aportando estabilidad visual al cambiar entre secciones
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
            label: 'Pasaporte',
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