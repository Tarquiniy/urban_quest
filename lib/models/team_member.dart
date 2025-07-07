class TeamMember {
  final String teamId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final DateTime joinedAt;
  final String? role;

  TeamMember({
    required this.teamId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.joinedAt,
    this.role,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      role: json['role'] as String?,
    );
  }

  TeamMember copyWith({
    String? teamId,
    String? userId,
    String? username,
    String? avatarUrl,
    DateTime? joinedAt,
    String? role,
  }) {
    return TeamMember(
      teamId: teamId ?? this.teamId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      joinedAt: joinedAt ?? this.joinedAt,
      role: role ?? this.role,
    );
  }
}
