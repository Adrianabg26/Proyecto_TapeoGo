/// badge_notifier.dart
///
/// Motor de gamificación de TapeoGo. Gestiona la carga del catálogo
/// de medallas, las medallas obtenidas por el usuario y la lógica
/// de desbloqueo de nuevos logros tras cada check-in.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/badge_model.dart';
import '../models/user_badge_model.dart';

class BadgeNotifier extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  List<BadgeModel> _allBadges = [];
  List<UserBadgeModel> _myBadges = [];
  bool _isLoading = false;

  List<BadgeModel> get allBadges => _allBadges;
  List<UserBadgeModel> get myBadges => _myBadges;
  bool get isLoading => _isLoading;

  // ───────────────────────────────────────────────────────────────────────────
  // GETTER: xpTotal
  // Calcula el XP total sumando el xpBonus de cada medalla desbloqueada.
  // Se cruzan las listas _myBadges y _allBadges para obtener el bonus
  // de cada medalla ganada por el usuario.
  // ───────────────────────────────────────────────────────────────────────────

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

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: fetchBadges
  // Carga el catálogo completo de medallas y las medallas ya obtenidas
  // por el usuario desde Supabase. Se invoca al iniciar la app y tras
  // cada desbloqueo para mantener el estado sincronizado.
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> fetchBadges(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final badgesData = await _supabase.from('badges').select();
      _allBadges = badgesData.map((b) => BadgeModel.fromJson(b)).toList();

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

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: updateAndCheckBadges
  // Realiza una consulta relacional JOIN entre 'visits' y 'bars' para
  // obtener el tipo de consumo y el distrito de cada visita del usuario.
  // Con estos datos calcula los conteos necesarios para evaluar
  // las condiciones de desbloqueo de cada medalla del catálogo.
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<BadgeModel>> updateAndCheckBadges(String userId) async {
    try {
      final response = await _supabase
          .from('visits')
          .select('record_type, bars(district)')
          .eq('user_id', userId);

      final List<dynamic> data = response;
      final int totalVisitas = data.length;

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

      final int countTriana = data
          .where((v) =>
              v['bars'] != null && v['bars']['district'] == 'Triana')
          .length;
      final int countCentro = data
          .where((v) =>
              v['bars'] != null && v['bars']['district'] == 'Centro')
          .length;

      return await _checkAchievements(
        userId: userId,
        total: totalVisitas,
        tapas: {
          'serranito': countSerranitos,
          'solomillo': countSolomillos,
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

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO PRIVADO: _checkAchievements
  // Evalúa las condiciones de desbloqueo para cada medalla del catálogo.
  // Si el usuario cumple los requisitos de una medalla que aún no tiene,
  // la inserta en 'user_badges' y actualiza el xp_total en 'profiles'.
  // Devuelve la lista de medallas nuevas para que la UI pueda
  // mostrar una animación o mensaje de felicitación al usuario.
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<BadgeModel>> _checkAchievements({
    required String userId,
    required int total,
    required Map<String, int> tapas,
    required Map<String, int> drinks,
    required Map<String, int> districts,
  }) async {
    final List<BadgeModel> newlyUnlocked = [];

    for (var badge in _allBadges) {
      final bool alreadyHasIt =
          _myBadges.any((ub) => ub.badgeId == badge.id);
      if (alreadyHasIt) continue;

      bool meetsRequirement = false;

      switch (badge.id) {
        case 'bautismo':
          meetsRequirement = total >= 1;
          break;
        case 'explorador':
          meetsRequirement = total >= 10;
          break;
        case 'serranito_oro':
          meetsRequirement = (tapas['serranito'] ?? 0) >= 3;
          break;
        case 'rey_solomillo':
          meetsRequirement = (tapas['solomillo'] ?? 0) >= 3;
          break;
        case 'maestro_croqueta':
          meetsRequirement = (tapas['croquetas'] ?? 0) >= 3;
          break;
        case 'cerveceros':
          meetsRequirement = (drinks['cerveza'] ?? 0) >= 5;
          break;
        case 'catador_vinos':
          meetsRequirement = (drinks['vino'] ?? 0) >= 5;
          break;
        case 'explorador_triana':
          meetsRequirement = (districts['triana'] ?? 0) >= 3;
          break;
        case 'corazon_centro':
          meetsRequirement = (districts['centro'] ?? 0) >= 3;
          break;
      }

      if (meetsRequirement) {
        await _supabase.from('user_badges').insert({
          'user_id': userId,
          'badge_id': badge.id,
        });

        newlyUnlocked.add(badge);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await fetchBadges(userId);

      await _supabase
          .from('profiles')
          .update({'xp_total': xpTotal}).eq('id', userId);
    }

    return newlyUnlocked;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MÉTODO: clearBadges
  // Limpia las listas de medallas al cerrar sesión para evitar que los
  // datos del usuario anterior sean visibles si otro usuario inicia
  // sesión en el mismo dispositivo.
  // Se invoca desde AuthNotifier.logout().
  // ───────────────────────────────────────────────────────────────────────────

  void clearBadges() {
    _allBadges = [];
    _myBadges = [];
    _isLoading = false;
    notifyListeners();
  }
}