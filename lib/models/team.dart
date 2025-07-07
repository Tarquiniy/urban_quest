import 'dart:math';

import 'package:urban_quest/constants.dart';

class Team {
  final String id;
  final String name;
  final String captainId;
  final String creatorId;
  int points;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String imageUrl;
  final bool isPublic;
  final String? bannerUrl;
  final String? motto;
  final String? colorScheme;
  int experience;
  int level;
  int totalQuestsCompleted;
  int memberCount; // Добавляем поле для количества участников

  Team({
    required this.id,
    required this.name,
    required this.captainId,
    required this.creatorId,
    this.points = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    required this.imageUrl,
    this.isPublic = true,
    this.bannerUrl,
    this.motto,
    this.colorScheme,
    this.experience = 0,
    this.level = 1,
    this.totalQuestsCompleted = 0,
    this.memberCount = 1,
  });

  int experienceForLevel(int level) {
    if (level <= 1) return 0;
    return (1000 * pow(1.25, level - 1)).round();
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      captainId: json['captain_id'],
      creatorId: json['creator_id'],
      points: json['points'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      imageUrl: json['image_url'],
      isPublic: json['is_public'] ?? true,
      bannerUrl: _getFullImageUrl(json['banner_url']),
      motto: json['motto'],
      colorScheme: json['color_scheme'],
      experience: json['experience'] ?? 0,
      level: json['level'] ?? 1,
      totalQuestsCompleted: json['total_quests_completed'] ?? 0,
    );
  }

  String get fullImageUrl {
    if (imageUrl.isEmpty) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/default.png';
    }
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/$imageUrl';
  }

  static String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/default.png';
    }

    // Если URL уже полный (начинается с http) - возвращаем как есть
    if (url.startsWith('http')) return url;

    // Если URL указывает на локальный файл - возвращаем дефолтное изображение
    if (url.startsWith('file://')) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/default.png';
    }

    // Формируем полный URL для аватарки команды
    return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/$url';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'captain_id': captainId,
      'creator_id': creatorId,
      'points': points,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'image_url': imageUrl,
      'is_public': isPublic,
      'banner_url': bannerUrl,
      'motto': motto,
      'color_scheme': colorScheme,
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? creatorId,
    DateTime? createdAt,
    int? points,
    String? imageUrl,
    String? bannerUrl,
    String? motto,
    String? colorScheme,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      points: points ?? this.points,
      imageUrl: imageUrl ?? this.imageUrl,
      captainId: captainId,
      isPublic: isPublic,
      updatedAt: updatedAt,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      motto: motto ?? this.motto,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }

  double get levelProgress {
    final expForCurrentLevel = _experienceForLevel(level);
    final expForNextLevel = _experienceForLevel(level + 1);
    return (experience - expForCurrentLevel) /
        (expForNextLevel - expForCurrentLevel);
  }

  int _experienceForLevel(int level) {
    if (level <= 1) return 0;
    return (1000 * pow(1.25, level - 1)).round();
  }

  bool get canLevelUp => experience >= _experienceForLevel(level + 1);

  void addExperience(int amount) {
    experience += amount;
    while (canLevelUp) {
      level++;
      experience = _experienceForLevel(level) +
          (experience - _experienceForLevel(level + 1));
    }
  }

  void addQuestCompletion(int pointsEarned) {
    totalQuestsCompleted++;
    points += pointsEarned;
    addExperience(pointsEarned * 2); // Опыт в 2 раза больше, чем очков
  }
}
