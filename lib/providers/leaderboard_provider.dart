import 'package:flutter/material.dart';
import 'package:urban_quest/models/team_leaderboard_entry.dart';
import 'package:urban_quest/services/supabase_service.dart';

class LeaderboardProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  // Хранилище данных для общего рейтинга пользователей
  List<TeamLeaderboardEntry> _userLeaderboard = [];
  bool _isLoading = false;

  // Геттеры для доступа к данным
  List<TeamLeaderboardEntry> get userLeaderboard => _userLeaderboard;
  bool get isLoading => _isLoading;

  // Загрузка общего рейтинга пользователей
  Future<void> loadUserLeaderboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      _userLeaderboard = (await _supabaseService.getUserLeaderboard())
          .cast<TeamLeaderboardEntry>(); // Данные уже в нужном формате
    } catch (e) {
      print('Ошибка при загрузке общего рейтинга: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Добавление очков и обновление рейтинга
  Future<void> submitScore({
    required String userId,
    required String questId,
    required int score,
  }) async {
    try {
      await _supabaseService.addLeaderboardEntry(
        userId: userId,
        questId: questId,
        score: score,
      );

      // Обновляем общий рейтинг
      await loadUserLeaderboard();
    } catch (e) {
      print('Ошибка при отправке результата: $e');
    }
  }
}
