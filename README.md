# TapeoGo - La Guía de Tapeo Inteligente

<div align="center">
  <img src="https://raw.githubusercontent.com/Adrianabg26/Proyecto_TapeoGo/main/assets/images/logoconletra.png" width="200"/>
</div>

**TapeoGo** es una aplicación móvil multiplataforma diseñada para digitalizar y gamificar la experiencia del tapeo tradicional. El proyecto nace como Trabajo de Fin de Grado (TFG) para el ciclo de **Desarrollo de Aplicaciones Multiplataforma (DAM)**.

---

## Características Principales

- **Exploración de Bares:** Mapa interactivo y listado de establecimientos locales.
- **Check-in con Verificación GPS:** Registro de visitas validado mediante geolocalización para asegurar la presencia física en el local.
- **Sistema de Gamificación:** Obtención de XP (experiencia) y desbloqueo de medallas exclusivas por tipos de consumo o zonas visitadas.
- **Gestión de Listas:** Separación inteligente entre "Favoritos" (locales visitados) y "Wishlist" (pendientes por descubrir).
- **Historial Reactivo:** Listado de visitas con fotos, comentarios y visualización en tiempo real.

## Stack Tecnológico

- **Frontend:** [Flutter](https://flutter.dev/) (Framework) & [Dart](https://dart.dev/) (Lenguaje).
- **Backend (BaaS):** [Supabase](https://supabase.com/) (PostgreSQL, Auth, Storage).
- **Gestión de Estado:** [Provider](https://pub.dev/packages/provider).
- **Hardware Integrado:** Cámara (Image Picker) y Geolocalización (Geolocator).

## Estructura del Proyecto

lib/

├── models/          # Entidades de datos (Visit, Bar, Badge, Profile)

├── notifiers/       # Lógica de negocio y gestión de estado (Providers)

├── screens/         # Capas de interfaz de usuario (UI)

├── widgets/         # Componentes reutilizables

├── utils/           # Funciones y utilidades

└── main.dart        # Punto de entrada y configuración de proveedores

## Seguridad y Arquitectura

El proyecto destaca por su robustez en la gestión de datos, utilizando Row Level Security (RLS) directamente en la base de datos Supabase. Esto garantiza que:

Solo el propietario de los datos pueda leer o modificar su historial.

Las fotos de las tapas se almacenan de forma segura en Buckets protegidos.

La lógica de medallas se procesa mediante consultas relacionales asíncronas para optimizar el rendimiento.

## Instalación y Ejecución

Clonar el repositorio:
git clone (https://github.com/Adrianabg26/Proyecto_TapeoGo.git )

Instalar dependencias:
flutter pub get

Configurar Supabase:
Crea un archivo de configuración o inicializa las claves URL y AnonKey en tu main.dart.

Lanzar la aplicación:
flutter run

## Licencia e Información
Proyecto desarrollado para el TFG de Desarrollo de Aplicaciones Multiplataforma (2026).
Autor: [Adriana Blanco García]
