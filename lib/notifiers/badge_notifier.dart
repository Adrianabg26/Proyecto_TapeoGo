/// badge_notifier.dart
///
/// Motor de gamificación de TapeoGo.
///
/// Gestiona tres responsabilidades:
///   - Catálogo completo de medallas disponibles (allBadges).
///   - Medallas desbloqueadas por el usuario (myBadges).
///   - Evaluación de condiciones de desbloqueo tras cada check-in.
///
/// El orden visual del catálogo se define en cliente mediante la lista
/// 'order', evitando añadir columnas de ordenación a la BD.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/badge_model.dart';
import '../models/user_badge_model.dart';

class BadgeNotifier extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<BadgeModel> _allBadges = [];
  List<UserBadgeModel> _myBadges = [];
  bool _isLoading = false;

  // Getters públicos — exponen el estado mínimo necesario a la UI.
  List<BadgeModel> get allBadges => _allBadges;
  List<UserBadgeModel> get myBadges => _myBadges;
  bool get isLoading => _isLoading;

  // Alias semánticos para BadgesGrid y BarDetailsScreen.
  List<BadgeModel> get badges => _allBadges;
  List<UserBadgeModel> get userBadges => _myBadges;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTER: xpTotal
  // Calcula el XP total acumulado sumando el xpBonus de cada medalla
  // desbloqueada por el usuario. Cruza _myBadges con _allBadges para
  // obtener el bonus de cada logro sin consultas adicionales a Supabase.
  // Se usa en _checkAchievements para actualizar xp_total en 'profiles'.
  // ─────────────────────────────────────────────────────────────────────────
  int get xpTotal {
    int total = 0;
    for (var myB in _myBadges) {
      try {
        final badgeInfo = _allBadges.firstWhere((b) => b.id == myB.badgeId);
        total += badgeInfo.xpBonus;
      } catch (e) {
        debugPrint('Medalla no encontrada en catálogo: ${myB.badgeId}');
      }
    }
    return total;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchBadges
  // Carga el catálogo completo de medallas y las medallas desbloqueadas
  // por el usuario desde Supabase en una única operación.
  //
  // El orden visual se define localmente mediante la lista 'order' para
  // reflejar la dificultad progresiva de cada logro sin necesidad de
  // añadir columnas de ordenación a la tabla 'badges' en la BD.
  //
  // Se invoca al entrar a ProfileScreen y tras cada desbloqueo para
  // mantener el estado sincronizado con la BD.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchBadges(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Carga el catálogo completo de medallas desde la tabla 'badges'.
      final badgesData = await _supabase.from('badges').select();
      final badges = badgesData.map((b) => BadgeModel.fromJson(b)).toList();

      // Orden visual del catálogo definido en cliente.
      // El orden refleja la dificultad progresiva de cada logro:
      // bienvenida → exploración → barrios → tapas → bebidas.
      const order = [
        'bautismo',
        'explorador',
        'corazon_centro',
        'explorador_triana',
        'serranito_oro',
        'rey_solomillo',
        'maestro_croqueta',
        'cerveceros',
        'catador_vinos',
      ];

      // Reordena las medallas según la lista 'order', filtrando las que
      // no existan en la BD para evitar errores si el catálogo cambia.
      _allBadges = order
          .where((id) => badges.any((b) => b.id == id))
          .map((id) => badges.firstWhere((b) => b.id == id))
          .toList();

      // Carga las medallas desbloqueadas por el usuario desde 'user_badges'.
      final myBadgesData = await _supabase
          .from('user_badges')
          .select()
          .eq('user_id', userId);
      _myBadges =
          myBadgesData.map((ub) => UserBadgeModel.fromJson(ub)).toList();
    } catch (e) {
      debugPrint('Error cargando medallas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateAndCheckBadges
  // Punto de entrada del motor de gamificación tras cada check-in GPS.
  //
  // Consulta todas las visitas verificadas del usuario con un JOIN a
  // 'bars' para obtener el district de cada visita. A partir de esos
  // datos calcula los conteos necesarios para evaluar las condiciones
  // de desbloqueo de cada medalla.
  //
  // Solo se evalúan visitas con gps_verified = true para garantizar
  // que las medallas reflejan presencia física real en el establecimiento.
  //
  // Devuelve la lista de medallas recién desbloqueadas para que
  // CheckInScreen pueda mostrar la celebración al usuario.
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<BadgeModel>> updateAndCheckBadges(String userId) async {
    try {
      // JOIN entre 'visits' y 'bars' para obtener record_type y district
      // de cada visita verificada — base del motor de gamificación.
      final response = await _supabase
          .from('visits')
          .select('record_type, bars(district)')
          .eq('user_id', userId)
          .eq('gps_verified', true);

      final List<dynamic> data = response;
      final int totalVisitas = data.length;

      // Conteo por tipo de tapa para evaluar medallas de especialidad.
      final int countSerranitos =
          data.where((v) => v['record_type'] == 'serranito').length;
      final int countSolomillos =
          data.where((v) => v['record_type'] == 'solomillo_whisky').length;
      final int countCroquetas =
          data.where((v) => v['record_type'] == 'croquetas').length;
      final int countCervezas =
          data.where((v) => v['record_type'] == 'cerveza').length;
      final int countVinos =
          data.where((v) => v['record_type'] == 'vino').length;

      // Conteo por distrito para evaluar medallas geográficas.
      // El JOIN con 'bars' es necesario porque district no se almacena
      // en 'visits' — se obtiene del establecimiento visitado.
      final int countTriana = data
          .where((v) =>
              v['bars'] != null && v['bars']['district'] == 'Triana')
          .length;
      final int countCentro = data
          .where((v) =>
              v['bars'] != null && v['bars']['district'] == 'Centro')
          .length;

      // Delega la evaluación de condiciones a _checkAchievements.
      return await _checkAchievements(
        userId: userId,
        total: totalVisitas,
        tapas: {
          'serranito': countSerranitos,
          'solomillo_whisky': countSolomillos,
          'croquetas': countCroquetas,
        },
        drinks: {
          'cerveza': countCervezas,
          'vino': countVinos,
        },
        districts: {
          'triana': countTriana,
          'centro': countCentro,
        },
      );
    } catch (e) {
      debugPrint('Error en evaluación de medallas: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _checkAchievements
  // Evalúa las condiciones de desbloqueo para cada medalla del catálogo.
  //
  // Itera sobre _allBadges saltando las que el usuario ya posee. Para
  // cada medalla pendiente, evalúa su condición mediante un switch por
  // badge.id. Si se cumple, inserta el registro en 'user_badges'.
  //
  // Al terminar, si hay medallas nuevas:
  // 1. Recarga el catálogo con fetchBadges() para sincronizar _myBadges.
  // 2. Actualiza xp_total en 'profiles' sumando el bonus de cada medalla.
  // 3. Devuelve la lista de medallas nuevas para que CheckInScreen
  //    muestre el AlertDialog y el ConfettiWidget de celebración.
  //
  // Si no hay medallas nuevas no realiza ninguna escritura en Supabase,
  // evitando operaciones innecesarias tras cada check-in.
  // ─────────────────────────────────────────────────────────────────────────
  Future<List<BadgeModel>> _checkAchievements({
    required String userId,
    required int total,
    required Map<String, int> tapas,
    required Map<String, int> drinks,
    required Map<String, int> districts,
  }) async {
    final List<BadgeModel> newlyUnlocked = [];

    for (var badge in _allBadges) {
      // Salta las medallas que el usuario ya ha desbloqueado.
      final bool alreadyHasIt =
          _myBadges.any((ub) => ub.badgeId == badge.id);
      if (alreadyHasIt) continue;

      bool meetsRequirement = false;

      // Evaluación de la condición específica de cada medalla por su ID.
      switch (badge.id) {
        case 'bautismo':
          // Primera visita verificada — recompensa de bienvenida.
          meetsRequirement = total >= 1;
          break;
        case 'explorador':
          // 10 visitas totales — objetivo de retención a medio plazo.
          meetsRequirement = total >= 10;
          break;
        case 'serranito_oro':
          // 3 serranitos — incentiva la categorización del consumo.
          meetsRequirement = (tapas['serranito'] ?? 0) >= 3;
          break;
        case 'rey_solomillo':
          // 3 solomillos al whisky — especialidad sevillana premium.
          meetsRequirement = (tapas['solomillo_whisky'] ?? 0) >= 3;
          break;
        case 'maestro_croqueta':
          // 3 croquetas — tapa más popular del tapeo sevillano.
          meetsRequirement = (tapas['croquetas'] ?? 0) >= 3;
          break;
        case 'cerveceros':
          // 5 cervezas — incentiva la visita a bares de barril.
          meetsRequirement = (drinks['cerveza'] ?? 0) >= 5;
          break;
        case 'catador_vinos':
          // 5 vinos — promueve la cultura vinícola local.
          meetsRequirement = (drinks['vino'] ?? 0) >= 5;
          break;
        case 'explorador_triana':
          // 3 bares en Triana — medalla geográfica de barrio.
          meetsRequirement = (districts['triana'] ?? 0) >= 3;
          break;
        case 'corazon_centro':
          // 3 bares en Centro — incentiva la movilidad entre distritos.
          meetsRequirement = (districts['centro'] ?? 0) >= 3;
          break;
      }

      if (meetsRequirement) {
        // Inserta el registro de desbloqueo en 'user_badges'.
        // unlocked_at se genera automáticamente con DEFAULT now() en PostgreSQL.
        await _supabase.from('user_badges').insert({
          'user_id': userId,
          'badge_id': badge.id,
        });
        newlyUnlocked.add(badge);
      }
    }

    // Solo actualiza Supabase si hay medallas nuevas — evita escrituras
    // innecesarias en check-ins donde no se desbloquea ningún logro.
    if (newlyUnlocked.isNotEmpty) {
      // Recarga _myBadges para incluir las medallas recién desbloqueadas.
      await fetchBadges(userId);

      // Actualiza xp_total en 'profiles' con el nuevo total acumulado.
      // xpTotal es un getter que suma el xpBonus de todas las medallas
      // desbloqueadas — no requiere consultas adicionales a Supabase.
      await _supabase
          .from('profiles')
          .update({'xp_total': xpTotal}).eq('id', userId);
    }

    return newlyUnlocked;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearBadges
  // Limpia el estado en memoria al cerrar sesión.
  // Se invoca desde AuthNotifier.logout() para garantizar que las medallas
  // del usuario anterior no sean visibles si otro usuario inicia sesión
  // en el mismo dispositivo.
  // ─────────────────────────────────────────────────────────────────────────
  void clearBadges() {
    _allBadges = [];
    _myBadges = [];
    _isLoading = false;
    notifyListeners();
  }
}