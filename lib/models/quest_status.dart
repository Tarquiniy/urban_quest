class QuestStatus {
  final String userId;
  final String? teamId; // Добавляем поддержку команд
  final String questId;
  final String status; // 'active', 'paused', 'completed'
  final DateTime? pausedAt;
  final double? latitude;
  final double? longitude;
  final int? locationOrder;
  final double? progress;

  QuestStatus({
    required this.userId,
    this.teamId,
    required this.questId,
    required this.status,
    this.pausedAt,
    this.latitude,
    this.longitude,
    this.locationOrder,
    this.progress,
  });

  factory QuestStatus.fromJson(Map<String, dynamic> json) {
    return QuestStatus(
      userId: json['user_id'],
      teamId: json['team_id'],
      questId: json['quest_id'],
      status: json['status'],
      pausedAt:
          json['paused_at'] != null ? DateTime.parse(json['paused_at']) : null,
      latitude: json['latitude'],
      longitude: json['longitude'],
      locationOrder: json['location_order'],
      progress: json['progress']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (teamId != null) 'team_id': teamId,
      'quest_id': questId,
      'status': status,
      'paused_at': pausedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location_order': locationOrder,
      'progress': progress,
    };
  }

  bool get isTeamQuest => teamId != null;
}
