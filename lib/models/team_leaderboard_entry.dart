class TeamLeaderboardEntry {
  final String teamId;
  final String teamName;
  final String? teamImage;
  final int points;
  final int rank;
  final int questsCompleted;

  TeamLeaderboardEntry({
    required this.teamId,
    required this.teamName,
    this.teamImage,
    required this.points,
    required this.rank,
    required this.questsCompleted,
  });

  factory TeamLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return TeamLeaderboardEntry(
      teamId: json['team_id'],
      teamName: json['team_name'],
      teamImage: json['team_image'],
      points: json['points'] ?? 0,
      rank: json['rank'] ?? 0,
      questsCompleted: json['quests_completed'] ?? 0,
    );
  }
}
