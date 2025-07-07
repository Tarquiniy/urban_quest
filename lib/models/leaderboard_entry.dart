class LeaderboardEntry {
  final String userId;
  final String username;
  final int points;
  final String? avatarUrl;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    required this.points,
    this.avatarUrl,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      userId: json['user_id'] ?? json['id'],
      username: json['username'],
      points: json['points'] ?? 0,
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'points': points,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
