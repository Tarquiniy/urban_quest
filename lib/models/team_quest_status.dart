// models/team_quest_status.dart
class TeamQuestStatus {
  final String teamId;
  final String questId;
  final String status; // 'active', 'paused', 'completed'
  final DateTime? pausedAt;
  final double? latitude;
  final double? longitude;
  final int membersCompleted; // Количество участников, завершивших квест
  final int totalMembers; // Общее количество участников

  TeamQuestStatus({
    required this.teamId,
    required this.questId,
    required this.status,
    this.pausedAt,
    this.latitude,
    this.longitude,
    this.membersCompleted = 0,
    required this.totalMembers,
  });

  factory TeamQuestStatus.fromJson(Map<String, dynamic> json) {
    return TeamQuestStatus(
      teamId: json['team_id'],
      questId: json['quest_id'],
      status: json['status'],
      pausedAt:
          json['paused_at'] != null ? DateTime.parse(json['paused_at']) : null,
      latitude: json['latitude'],
      longitude: json['longitude'],
      membersCompleted: json['members_completed'] ?? 0,
      totalMembers: json['total_members'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'team_id': teamId,
      'quest_id': questId,
      'status': status,
      'paused_at': pausedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'members_completed': membersCompleted,
      'total_members': totalMembers,
    };
  }

  double get completionProgress => membersCompleted / totalMembers;
}
