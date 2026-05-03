/// bar_details_screen.dart
///
/// Pantalla de ficha completa de un establecimiento en TapeoGo.
/// Muestra imagen colapsable, información del bar, tapa estrella,
/// botones de favorito/pendiente y acceso al check-in.
///
/// Patrón sticky footer: el botón de check-in se asigna a bottomNavigationBar
/// para que permanezca visible independientemente del scroll.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bar_model.dart';
import '../notifiers/favorite_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/wishlist_notifier.dart';
import '../utils/app_colors.dart';
import 'check_in_screen.dart';
import 'package:tapeo_go/utils/ui_helpers.dart';
import 'package:url_launcher/url_launcher.dart';

class BarDetailsScreen extends StatefulWidget {
  final BarModel bar;
  const BarDetailsScreen({super.key, required this.bar});

  @override
  State<BarDetailsScreen> createState() => _BarDetailsScreenState();
}

class _BarDetailsScreenState extends State<BarDetailsScreen> {
  // ─────────────────────────────────────────────────────────────────────────
  // GETTER: _isOpenNow
  // Calcula si el bar está abierto en este momento comparando la hora actual
  // con el horario del día correspondiente en opening_hours.
  // No requiere consulta a Supabase — el cálculo se hace en cliente.
  // Devuelve false si el bar no tiene horario registrado o cierra ese día.
  // Los bares que cierran a las 00:00 usan 1440 minutos (24×60) para evitar
  // que closeMinutes sea 0 y el bar nunca aparezca como abierto.
  // ─────────────────────────────────────────────────────────────────────────
  bool get _isOpenNow {
    if (widget.bar.openingHours == null) return false;

    const dayKeys = {
      1: 'lun',
      2: 'mar',
      3: 'mie',
      4: 'jue',
      5: 'vie',
      6: 'sab',
      7: 'dom',
    };

    final todayKey = dayKeys[DateTime.now().weekday]!;
    final hoursText = widget.bar.openingHours![todayKey];
    if (hoursText == null) return false;

    final parts = hoursText.split('-');
    if (parts.length != 2) return false;

    final now = TimeOfDay.now();
    final open = _parseTime(parts[0]);
    final close = _parseTime(parts[1]);
    if (open == null || close == null) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;

    // 00:00 se interpreta como medianoche (1440 min) para cubrir bares
    // con horario nocturno que cierran a las 00:00.
    final closeMinutes = (close.hour == 0 && close.minute == 0)
        ? 24 * 60
        : close.hour * 60 + close.minute;

    return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
  }

  // Convierte un string "HH:mm" en TimeOfDay.
  // Devuelve null si el formato no es válido para evitar excepciones.
  TimeOfDay? _parseTime(String time) {
    final parts = time.trim().split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    // context.watch suscribe el widget a cambios en favoritos y pendientes.
    // Cuando el usuario pulsa cualquiera de los botones, el widget
    // se reconstruye automáticamente mostrando el nuevo estado visual.
    final favoriteNotifier = context.watch<FavoriteNotifier>();
    final wishlistNotifier = context.watch<WishlistNotifier>();

    // context.read en lugar de watch: el userId no cambia durante la sesión.
    final String? userId = context.read<AuthNotifier>().currentUserId;

    final bool isFav = favoriteNotifier.isFavorite(widget.bar.id);
    final bool isWish = wishlistNotifier.isInWishlist(widget.bar.id);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: _buildStickyCheckInButton(),
      body: CustomScrollView(
        slivers: [
          // ─────────────────────────────────────────────────────────────────
          // SliverAppBar colapsable con imagen del bar.
          // pinned: true mantiene la barra de navegación visible al hacer scroll.
          // expandedHeight define la altura máxima antes de colapsar.
          // ─────────────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              // CollapseMode.pin fija el fondo mientras la barra se colapsa.
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeaderImage(),

                  // Gradiente superior para legibilidad del botón de volver
                  // sobre cualquier color de imagen de fondo.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Botón de volver posicionado respetando el padding
                  // de la barra de estado del dispositivo (notch/isla dinámica).
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  // Chip de distrito y estado — esquina inferior izquierda de la imagen.
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      children: [
                        // Chip de distrito — siempre visible
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.place_rounded,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                widget.bar.district,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Chip "Abierto ahora" — solo visible si _isOpenNow devuelve true.
                        // Se muestra junto al distrito en la misma esquina inferior izquierda.
                        if (_isOpenNow) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.circle,
                                    color: Colors.white, size: 6),
                                SizedBox(width: 4),
                                Text(
                                  'Abierto ahora',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─────────────────────────────────────────────────────────────────
          // Contenido scrollable de la ficha del bar.
          // El padding inferior de 100px evita que el sticky footer
          // tape el último elemento al llegar al final del scroll.
          // ─────────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Nombre del establecimiento ──
                  Text(
                    widget.bar.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.titleOrange,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Descripción ──
                  // Si está vacía en la BD se muestra un texto de sustitución
                  // para evitar áreas en blanco que rompan el layout.
                  Text(
                    widget.bar.description.isNotEmpty
                        ? widget.bar.description
                        : 'Este establecimiento aún no tiene descripción.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tapa estrella ──
                  // Destaca la especialidad del bar, que es también el campo
                  // record_type clave para el motor de gamificación.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TAPA ESTRELLA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange[400],
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.bar.specialtyTapa,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.titleOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Información del establecimiento ──
                  // Solo se renderiza si hay teléfono u horario en la BD.
                  // La dirección siempre aparece porque es required en BarModel.
                  if (widget.bar.phone != null ||
                      widget.bar.openingHours != null)
                    _buildInfoSection(),

                  const SizedBox(height: 20),

                  // ── Botones de favorito y pendiente ──
                  // Posicionados dentro del cuerpo scrollable, justo antes
                  // del sticky footer, para no competir visualmente con el check-in.
                  // El estado activo se comunica mediante color del icono y borde.
                  // El texto del botón pendiente cambia a "Guardado" al activarse.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: userId == null
                              ? null
                              : () => favoriteNotifier.toggleFavorite(
                                  userId, widget.bar),
                          icon: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: isFav ? AppColors.primary : Colors.grey[600],
                          ),
                          label: Text(
                            'Favorito',
                            style: TextStyle(
                              color:
                                  isFav ? AppColors.primary : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color:
                                  isFav ? AppColors.primary : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: userId == null
                              ? null
                              : () => isWish
                                  ? wishlistNotifier.removeFromWishlist(
                                      userId, widget.bar)
                                  : wishlistNotifier.addToWishlist(
                                      userId, widget.bar),
                          icon: Icon(
                            isWish
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 18,
                            color:
                                isWish ? AppColors.primary : Colors.grey[600],
                          ),
                          label: Text(
                            isWish ? 'Guardado' : 'Pendiente',
                            style: TextStyle(
                              color:
                                  isWish ? AppColors.primary : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: isWish
                                  ? AppColors.primary
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildHeaderImage
  // Carga la imagen del bar desde Supabase Storage.
  // Si la URL es null o vacía, o si la descarga falla, muestra el placeholder.
  // alignment: (0, -0.8) encuadra la imagen en el tercio superior
  // para que la fachada del local sea siempre visible.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderImage() {
    final bool hasImage =
        widget.bar.mainImageUrl != null && widget.bar.mainImageUrl!.isNotEmpty;

    return hasImage
        ? Image.network(
            widget.bar.mainImageUrl!,
            fit: BoxFit.cover,
            alignment: const Alignment(0.0, -0.8),
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => _imagePlaceholder(),
          )
        : _imagePlaceholder();
  }

  // ─────────────────────────────────────────────────────────────────────────
// WIDGET: _imagePlaceholder
// Placeholder de marca para locales sin imagen.
// Mismo diseño que HomeMapScreen — iconografía gastronómica decorativa
// con iconos en las esquinas y cámara centrada.
// SizedBox.expand ocupa exactamente el espacio del SliverAppBar.
// ─────────────────────────────────────────────────────────────────────────
Widget _imagePlaceholder() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final double h = constraints.maxHeight == double.infinity
          ? 280
          : constraints.maxHeight;
      final double w = constraints.maxWidth == double.infinity
          ? double.infinity
          : constraints.maxWidth;

      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.05), width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          children: [
            UIHelpers.buildDecorativeIcon(
                icon: Icons.local_pizza_rounded,
                top: -20, left: -10, size: 120, angle: 0.5),
            UIHelpers.buildDecorativeIcon(
                icon: Icons.wine_bar_rounded,
                bottom: -15, right: -10, size: 130, angle: -0.3),
            UIHelpers.buildDecorativeIcon(
                icon: Icons.restaurant_menu_rounded,
                top: 60, right: 40, size: 70, angle: 0.2),
            UIHelpers.buildDecorativeIcon(
                icon: Icons.bakery_dining_rounded,
                bottom: 40, left: 30, size: 80, angle: -0.4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_enhance_rounded,
                  size: 52,
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 6),
                Text(
                  'IMAGEN EN CONSTRUCCIÓN',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primary.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildStickyCheckInButton
  // Botón principal de acceso al flujo de check-in.
  // Al asignarse a Scaffold.bottomNavigationBar queda fuera del
  // CustomScrollView y permanece visible en todo momento.
  // El padding inferior de 24px respeta el home indicator de iOS
  // y la barra de navegación de Android.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStickyCheckInButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt_rounded, size: 20),
          label: const Text(
            'Hacer Check-in',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CheckInScreen(bar: widget.bar),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildInfoSection
  // Bloque de información del establecimiento: teléfono, dirección y horario.
  // Solo se renderiza si al menos uno de los campos tiene datos en Supabase.
  // La dirección siempre se muestra — está en bar.address que es required.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INFORMACIÓN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Teléfono — solo si está disponible en la BD.
              if (widget.bar.phone != null)
                _buildInfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Teléfono',
                  value: widget.bar.phone!,
                  isLink: true,
                  onTap: () async {
                    final uri = Uri(scheme: 'tel', path: widget.bar.phone);
                    await launchUrl(uri);
                  },
                ),

              // Separador solo si hay teléfono y hay más campos debajo.
              if (widget.bar.phone != null)
                Divider(height: 1, color: Colors.grey[200]),

              // Dirección — siempre visible (campo required en BarModel).
              _buildInfoRow(
                icon: Icons.place_rounded,
                label: 'Dirección',
                value: '${widget.bar.address} · ${widget.bar.district}',
              ),

              // Horario — solo si está disponible en la BD.
              if (widget.bar.openingHours != null) ...[
                Divider(height: 1, color: Colors.grey[200]),
                _buildScheduleRow(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildInfoRow
  // Fila reutilizable del bloque de información.
  // isLink aplica color naranja al valor para indicar que es pulsable.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isLink ? AppColors.primary : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            if (isLink)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIDGET: _buildScheduleRow
  // Fila de horario semanal con el día actual resaltado en naranja.
  // Obtiene el día actual mediante DateTime.now().weekday (1=lun, 7=dom).
  // Si el bar cierra ese día el valor es null y se muestra "Cerrado".
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildScheduleRow() {
    const dayKeys = {
      1: 'lun',
      2: 'mar',
      3: 'mie',
      4: 'jue',
      5: 'vie',
      6: 'sab',
      7: 'dom',
    };
    const dayLabels = {
      'lun': 'Lunes',
      'mar': 'Martes',
      'mie': 'Miércoles',
      'jue': 'Jueves',
      'vie': 'Viernes',
      'sab': 'Sábado',
      'dom': 'Domingo',
    };

    final todayKey = dayKeys[DateTime.now().weekday]!;
    final hours = widget.bar.openingHours!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.access_time_rounded,
                size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Horario',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                // Itera sobre los 7 días mostrando cada uno en su fila.
                ...dayKeys.entries.map((entry) {
                  final key = entry.value;
                  final label = dayLabels[key]!;
                  final hoursText = hours[key] ?? 'Cerrado';
                  final isToday = key == todayKey;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                            color:
                                isToday ? AppColors.primary : Colors.grey[600],
                          ),
                        ),
                        Text(
                          hoursText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                            color:
                                isToday ? AppColors.primary : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
