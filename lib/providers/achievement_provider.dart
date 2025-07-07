import 'package:flutter/material.dart';
import 'package:urban_quest/models/achievement.dart';
import 'package:urban_quest/services/supabase_service.dart';
import 'package:urban_quest/models/user.dart';
import 'package:lottie/lottie.dart';

class AchievementProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Achievement> _allAchievements = [];
  List<Achievement> _userAchievements = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  List<Achievement> get allAchievements => _allAchievements;
  List<Achievement> get userAchievements => _userAchievements;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  Future<void> initialize(String userId) async {
    if (_isInitialized || userId.isEmpty) return;

    // Не вызываем notifyListeners() здесь
    _isLoading = true;

    try {
      final response =
          await _supabaseService.supabase.from('achievements').select('*');

      _allAchievements =
          (response as List).map((a) => Achievement.fromJson(a)).toList();

      final userAchievementsResponse = await _supabaseService.supabase
          .from('user_achievements')
          .select('achievements(*)')
          .eq('user_id', userId);

      _userAchievements = (userAchievementsResponse as List)
          .map((a) => Achievement.fromJson(a['achievements'] ?? {}))
          .toList();

      _isInitialized = true;
    } catch (e) {
      print('Ошибка инициализации AchievementProvider: $e');
    } finally {
      _isLoading = false;
      // Уведомляем слушателей после завершения инициализации
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<void> checkAndUnlockAchievements(
      User user, BuildContext context) async {
    try {
      // Проверяем все типы достижений
      await _checkLevelAchievements(user, context);
      await _checkQuestAchievements(user.id, context);
      await _checkPointsAchievements(user, context);
      await _checkExperienceAchievements(user, context);
      await _checkLocationAchievements(user.id, context);
      await _checkFirstLoginAchievement(user, context);

      // Обновляем список достижений пользователя
      await _loadUserAchievements(user.id);
    } catch (e) {
      print('Ошибка проверки достижений: $e');
    }
  }

  Future<void> _checkLevelAchievements(User user, BuildContext context) async {
    final levelAchievements = _allAchievements.where((a) =>
        a.conditionType == 'level_reached' &&
        a.conditionValue != null &&
        user.level >= a.conditionValue! &&
        !_userAchievements.any((ua) => ua.id == a.id));

    for (var achievement in levelAchievements) {
      await _unlockAchievementWithReward(user.id, achievement, context);
    }
  }

  Future<void> _checkQuestAchievements(
      String userId, BuildContext context) async {
    final completedQuestsCount =
        await _supabaseService.getCompletedQuestsCount(userId);

    final questAchievements = _allAchievements.where((a) =>
        a.conditionType == 'quest_completed' &&
        a.conditionValue != null &&
        completedQuestsCount >= a.conditionValue! &&
        !_userAchievements.any((ua) => ua.id == a.id));

    for (var achievement in questAchievements) {
      await _unlockAchievementWithReward(userId, achievement, context);
    }
  }

  Future<void> _checkPointsAchievements(User user, BuildContext context) async {
    final pointsAchievements = _allAchievements.where((a) =>
        a.conditionType == 'points_earned' &&
        a.conditionValue != null &&
        user.points >= a.conditionValue! &&
        !_userAchievements.any((ua) => ua.id == a.id));

    for (var achievement in pointsAchievements) {
      await _unlockAchievementWithReward(user.id, achievement, context);
    }
  }

  Future<void> _checkExperienceAchievements(
      User user, BuildContext context) async {
    final expAchievements = _allAchievements.where((a) =>
        a.conditionType == 'experience_earned' &&
        a.conditionValue != null &&
        user.experience >= a.conditionValue! &&
        !_userAchievements.any((ua) => ua.id == a.id));

    for (var achievement in expAchievements) {
      await _unlockAchievementWithReward(user.id, achievement, context);
    }
  }

  Future<void> _checkLocationAchievements(
      String userId, BuildContext context) async {
    final visitedLocations =
        await _supabaseService.getUserVisitedLocations(userId);
    final locationCount = visitedLocations.length;

    final locationAchievements = _allAchievements.where((a) =>
        a.conditionType == 'locations_visited' &&
        a.conditionValue != null &&
        locationCount >= a.conditionValue! &&
        !_userAchievements.any((ua) => ua.id == a.id));

    for (var achievement in locationAchievements) {
      await _unlockAchievementWithReward(userId, achievement, context);
    }
  }

  Future<void> _checkFirstLoginAchievement(
      User user, BuildContext context) async {
    final firstLoginAchievement = _allAchievements.firstWhere(
      (a) =>
          a.conditionType == 'first_login' &&
          !_userAchievements.any((ua) => ua.id == a.id),
      orElse: () => Achievement(
        id: '',
        name: '',
        description: '',
        icon: '',
        points: 0,
        experienceReward: 0,
      ),
    );

    if (firstLoginAchievement.id.isNotEmpty) {
      await _unlockAchievementWithReward(
          user.id, firstLoginAchievement, context);
    }
  }

  Future<void> _unlockAchievementWithReward(
      String userId, Achievement achievement, BuildContext context) async {
    try {
      // Получаем текущего пользователя
      final user = await _supabaseService.getUserById(userId);
      if (user == null) return;

      // Разблокируем достижение
      await _supabaseService.unlockAchievement(userId, achievement.id);

      // Начисляем награды
      if (achievement.points > 0) {
        await _supabaseService.updateUserPoints(userId, achievement.points);
      }

      if (achievement.experienceReward > 0) {
        final newExp = user.experience + achievement.experienceReward;
        final newLevel = _calculateLevel(newExp);
        await _supabaseService.updateUserExperience(userId, newExp, newLevel);
      }

      // Показываем уведомление о новом достижении
      if (context.mounted) {
        showAchievementUnlocked(context, achievement);
      }
    } catch (e) {
      print('Ошибка при разблокировке достижения: $e');
    }
  }

  int _calculateLevel(int experience) {
    return (experience / 500).floor() + 1;
  }

  Widget buildAchievementCard(
      Achievement achievement, bool isUnlocked, ThemeData theme) {
    return Card(
      elevation: isUnlocked ? 6 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? Colors.amber.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: isUnlocked ? Colors.amber : Colors.grey,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  achievement.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(
              isUnlocked ? Icons.verified : Icons.lock,
              color: isUnlocked ? Colors.amber : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void showAchievementUnlocked(BuildContext context, Achievement achievement) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      pageBuilder: (_, __, ___) {
        return Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/achievement_unlock.json',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'НОВОЕ ДОСТИЖЕНИЕ!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildAchievementCard(achievement, true, Theme.of(context)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('ПОНЯТНО', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadAllAchievements() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allAchievements = await _supabaseService.getAllAchievements();
    } catch (e) {
      print('Ошибка загрузки достижений: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserAchievements(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userAchievements = await _supabaseService.getUserAchievements(userId);
    } catch (e) {
      print('Ошибка загрузки достижений пользователя: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
