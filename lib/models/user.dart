import 'dart:math';

import 'package:urban_quest/constants.dart';
import 'package:flutter/material.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String password;
  int points;
  final String? avatarUrl;
  int experience;
  int level;
  int totalQuestsCompleted;
  int totalLocationsVisited;
  int totalQuestionsAnswered;
  int consecutiveDaysLoggedIn;
  DateTime lastLoginDate;
  List<String> unlockedAchievements;
  int correctAnswers;
  int incorrectAnswers;
  int hintsUsed;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.points = 0,
    this.avatarUrl,
    required this.experience,
    required this.level,
    this.totalQuestsCompleted = 0,
    this.totalLocationsVisited = 0,
    this.totalQuestionsAnswered = 0,
    this.consecutiveDaysLoggedIn = 1,
    required this.lastLoginDate,
    this.unlockedAchievements = const [],
    this.correctAnswers = 0,
    this.incorrectAnswers = 0,
    this.hintsUsed = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      password: json['password'] ?? '',
      points: json['points'] is int
          ? json['points']
          : int.tryParse(json['points']?.toString() ?? '0') ?? 0,
      avatarUrl: json['avatar_url'],
      experience: json['experience'] ?? 0,
      level: json['level'] ?? 1,
      totalQuestsCompleted: json['total_quests_completed'] ?? 0,
      totalLocationsVisited: json['total_locations_visited'] ?? 0,
      totalQuestionsAnswered: json['total_questions_answered'] ?? 0,
      consecutiveDaysLoggedIn: json['consecutive_days_logged_in'] ?? 1,
      lastLoginDate: json['last_login_date'] != null
          ? DateTime.parse(json['last_login_date'])
          : DateTime.now(),
      unlockedAchievements: json['unlocked_achievements'] != null
          ? List<String>.from(json['unlocked_achievements'])
          : [],
      correctAnswers: json['correct_answers'] ?? 0,
      incorrectAnswers: json['incorrect_answers'] ?? 0,
      hintsUsed: json['hints_used'] ?? 0,
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? password,
    int? points,
    String? avatarUrl,
    int? experience,
    int? level,
    int? totalQuestsCompleted,
    int? totalLocationsVisited,
    int? totalQuestionsAnswered,
    int? consecutiveDaysLoggedIn,
    DateTime? lastLoginDate,
    List<String>? unlockedAchievements,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      points: points ?? this.points,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      experience: experience ?? this.experience,
      level: level ?? this.level,
      totalQuestsCompleted: totalQuestsCompleted ?? this.totalQuestsCompleted,
      totalLocationsVisited:
          totalLocationsVisited ?? this.totalLocationsVisited,
      totalQuestionsAnswered:
          totalQuestionsAnswered ?? this.totalQuestionsAnswered,
      consecutiveDaysLoggedIn:
          consecutiveDaysLoggedIn ?? this.consecutiveDaysLoggedIn,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
    );
  }

  String get fullAvatarUrl {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.userAvatarsBucket}/${Constants.defaultAvatar}';
    }

    // Если URL уже полный - возвращаем как есть
    if (avatarUrl!.startsWith('http')) return avatarUrl!;

    // Если URL указывает на локальный файл - возвращаем дефолтное изображение
    if (avatarUrl!.startsWith('file://')) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.userAvatarsBucket}/${Constants.defaultAvatar}';
    }

    // Формируем полный URL для аватарки пользователя
    return '${Constants.storageBaseUrl}/object/public/${Constants.userAvatarsBucket}/$avatarUrl';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'points': points,
      'avatar_url': avatarUrl,
      'experience': experience,
      'level': level,
      'total_quests_completed': totalQuestsCompleted,
      'total_locations_visited': totalLocationsVisited,
      'total_questions_answered': totalQuestionsAnswered,
      'consecutive_days_logged_in': consecutiveDaysLoggedIn,
      'last_login_date': lastLoginDate.toIso8601String(),
      'unlocked_achievements': unlockedAchievements,
    };
  }

  // Рассчитывает прогресс до следующего уровня (от 0 до 1)
  double get levelProgress {
    final expForCurrentLevel = experienceForLevel(level);
    final expForNextLevel = experienceForLevel(level + 1);
    return (experience - expForCurrentLevel) /
        (expForNextLevel - expForCurrentLevel);
  }

  // Форматированное отображение текущего уровня (например, "Уровень 15")
  String get formattedLevel => 'Уровень $level';

  // Форматированное отображение опыта (например, "1250/2000 XP")
  String get formattedExperience {
    final nextLevelExp = experienceForLevel(level + 1);
    return '$experience/$nextLevelExp XP';
  }

  // Рассчитывает количество опыта, необходимое для указанного уровня
  int experienceForLevel(int level) {
    if (level <= 1) return 0;
    // Нелинейная прогрессия: каждый уровень требует на 20% больше опыта
    return (500 * pow(1.2, level - 1)).round();
  }

  // Проверяет, достаточно ли опыта для нового уровня
  bool get canLevelUp => experience >= experienceForLevel(level + 1);

  // Метод для проверки ежедневного входа
  void checkDailyLogin() {
    final now = DateTime.now();
    final lastLogin = lastLoginDate;

    // Если последний вход был вчера - увеличиваем счетчик
    if (lastLogin.year == now.year &&
        lastLogin.month == now.month &&
        lastLogin.day == now.day - 1) {
      consecutiveDaysLoggedIn++;
    }
    // Если прошло больше дня - сбрасываем счетчик
    else if (lastLogin.difference(now).inDays.abs() > 1) {
      consecutiveDaysLoggedIn = 1;
    }

    lastLoginDate = now;

    // Награда за ежедневный вход
    if (consecutiveDaysLoggedIn % 7 == 0) {
      // Каждые 7 дней подряд - бонус
      points += 50;
      experience += 25;
    } else {
      // Обычная ежедневная награда
      points += 10;
      experience += 5;
    }
  }

  // Метод для добавления достижения
  void addAchievement(String achievementId) {
    if (!unlockedAchievements.contains(achievementId)) {
      unlockedAchievements = List.from(unlockedAchievements)
        ..add(achievementId);
    }
  }

  void addQuestionResult(bool isCorrect, bool usedHint) {
    totalQuestionsAnswered++;
    if (isCorrect) {
      correctAnswers++;
      int expGained = 10;
      int pointsGained = 5;

      if (usedHint) {
        expGained =
            (expGained * 0.7).round(); // 30% меньше за использование подсказки
        pointsGained = (pointsGained * 0.7).round();
        hintsUsed++;
      }

      addExperience(expGained);
      points += pointsGained;
    } else {
      incorrectAnswers++;
      // За неправильный ответ можно дать минимальное количество опыта
      addExperience(2);
    }
  }

  // Обновленный метод для добавления опыта с уведомлением
  void addExperience(int amount, {BuildContext? context}) {
    final oldLevel = level;
    experience += amount;

    while (canLevelUp) {
      level++;
      // Оставляем остаток опыта после повышения уровня
      experience = experienceForLevel(level) +
          (experience - experienceForLevel(level + 1));
    }

    if (context != null && level > oldLevel) {
      _showLevelUpNotification(context, oldLevel, level);
    }
  }

  void _showLevelUpNotification(
      BuildContext context, int oldLevel, int newLevel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Поздравляем! Вы достигли уровня $newLevel!'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
