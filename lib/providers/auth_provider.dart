import 'dart:async';

import 'package:bcrypt/bcrypt.dart';
import 'package:urban_quest/constants.dart';
import 'package:urban_quest/screens/home_screen.dart';
import 'package:urban_quest/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:urban_quest/models/user.dart' as CustomUser;
import 'package:urban_quest/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urban_quest/providers/achievement_provider.dart';
import 'package:uuid/uuid.dart';

class AuthProvider with ChangeNotifier {
  CustomUser.User? _currentUser;
  final _supabaseService = SupabaseService();
  bool _isLoading = false;
  SharedPreferences? _prefs;
  String? _localUserId;

  CustomUser.User? get currentUser => _currentUser;
  set currentUser(CustomUser.User? user) {
    _currentUser = user;
    notifyListeners();
    if (user != null) {
      NotificationService.startCheckingInvitations(user.id);
    } else {
      NotificationService.stopChecking();
    }
  }

  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  String get userId => _currentUser?.id ?? _localUserId ?? '';

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await checkAuthSession();
  }

  Future<void> _saveUsername(String username) async {
    if (_prefs != null) {
      await _prefs!.setString('username', username);
    }
  }

  Future<void> _removeUsername() async {
    if (_prefs != null) {
      await _prefs!.remove('username');
    }
  }

  Future<void> checkAuthSession() async {
    _isLoading = true;
    notifyListeners();

    if (_prefs != null) {
      final savedUsername = _prefs!.getString('username');
      if (savedUsername != null) {
        try {
          final user = await _supabaseService.getUserByUsername(savedUsername);
          if (user != null) {
            _currentUser = user;
          }
        } catch (e) {
          print('Ошибка при автоматическом входе: $e');
          await _removeUsername();
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> register(String username, String email, String password,
      BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[REGISTER] Starting registration for $email');

      // 1. Генерируем хеш пароля
      final salt = BCrypt.gensalt();
      final hashedPassword = BCrypt.hashpw(password, salt);

      // 2. Подготавливаем данные пользователя
      final newUser = {
        'id': const Uuid().v4(),
        'username': username,
        'email': email,
        'password': hashedPassword,
        'points': 0,
        'avatar_url': Constants.defaultAvatar,
        'experience': 0,
        'level': 1,
        'total_quests_completed': 0,
        'total_locations_visited': 0,
        'total_questions_answered': 0,
        'consecutive_days_logged_in': 1,
        'last_login_date': DateTime.now().toIso8601String(),
        'unlocked_achievements': [],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('[REGISTER] User data: $newUser');

      // 3. Простой INSERT без проверок и select()
      await _supabaseService.supabase.from('users').insert(newUser);

      debugPrint('[REGISTER] User created successfully');

      // 4. Вручную создаем объект пользователя
      _currentUser = CustomUser.User.fromJson(newUser);
      await _saveUsername(username);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[REGISTER ERROR] Failed: $e');
      debugPrint('[REGISTER ERROR] Stack: $stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка регистрации: ${e.toString()}')),
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabaseService.supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) {
        throw Exception('Пользователь не найден');
      }

      final user = CustomUser.User.fromJson(response);

      if (!BCrypt.checkpw(password, user.password)) {
        throw Exception('Неверный пароль');
      }

      currentUser = user.copyWith(
        lastLoginDate: DateTime.now(),
        consecutiveDaysLoggedIn: _calculateConsecutiveDays(user.lastLoginDate),
      );

      await _saveUsername(username);

      // Инициализируем слушатель уведомлений
      NotificationService.initNotificationListener(user.id);
    } catch (e) {
      debugPrint('[LOGIN ERROR] $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int _calculateConsecutiveDays(DateTime lastLogin) {
    final now = DateTime.now();
    final difference = now.difference(lastLogin).inDays;
    return difference == 1 ? lastLogin.day + 1 : 1;
  }

  Future<void> updateUserExperience(int exp, BuildContext context) async {
    if (_currentUser == null) return;

    try {
      // Используем новый метод addExperience из модели User
      _currentUser!.addExperience(exp);

      await _supabaseService.supabase.from('users').update({
        'experience': _currentUser!.experience,
        'level': _currentUser!.level,
      }).eq('id', _currentUser!.id);

      final updatedUser = await _supabaseService.getUserById(_currentUser!.id);
      currentUser = updatedUser;

      final achievementProvider = AchievementProvider();
      await achievementProvider.initialize(updatedUser!.id);
      await achievementProvider.checkAndUnlockAchievements(
          updatedUser, context);

      // Показываем уведомление о повышении уровня, если это произошло
      if (updatedUser.level > _currentUser!.level) {
        _showLevelUpNotification(context, updatedUser.level);
      }

      notifyListeners();
    } catch (e) {
      print('Ошибка при обновлении опыта: $e');
    }
  }

  void _showLevelUpNotification(BuildContext context, int newLevel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Поздравляем! Вы достигли $newLevel уровня!'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> updateUserPoints(int points) async {
    if (_currentUser == null) return;

    try {
      await _supabaseService.updateUserPoints(_currentUser!.id, points);

      final updatedUser = await _supabaseService.getUserById(_currentUser!.id);
      currentUser = updatedUser;

      notifyListeners();
    } catch (e) {
      print('Ошибка при обновлении баллов пользователя: $e');
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = null;
      await _removeUsername();
      NotificationService.stopChecking(); // Останавливаем проверку уведомлений
    } catch (e) {
      print('Ошибка при выходе: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserData() async {
    if (_currentUser == null) return;

    try {
      await Supabase.instance.client
          .from('users')
          .update(_currentUser!.toJson())
          .eq('id', _currentUser!.id);

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating user data: $e');
      rethrow;
    }
  }
}
