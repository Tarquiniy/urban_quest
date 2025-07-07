class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int points;
  final int experienceReward;
  final String? conditionType;
  final int? conditionValue;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.points,
    required this.experienceReward,
    this.conditionType,
    this.conditionValue,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Безымянное достижение',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '🏆',
      points: (json['points'] as num?)?.toInt() ?? 0,
      experienceReward: (json['experience_reward'] as num?)?.toInt() ?? 0,
      conditionType: json['condition_type']?.toString(),
      conditionValue: (json['condition_value'] as num?)?.toInt(),
    );
  }
}
