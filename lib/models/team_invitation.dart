class TeamInvitation {
  final String id;
  final String teamId;
  final String teamName;
  final String inviterId;
  final String inviterUsername;
  final String inviteeId;
  final String inviteeUsername;
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'rejected'

  TeamInvitation({
    required this.id,
    required this.teamId,
    required this.teamName,
    required this.inviterId,
    required this.inviterUsername,
    required this.inviteeId,
    required this.inviteeUsername,
    required this.createdAt,
    this.status = 'pending',
  });

  factory TeamInvitation.fromJson(Map<String, dynamic> json) {
    return TeamInvitation(
      id: json['id'],
      teamId: json['team_id'],
      teamName: json['team_name'],
      inviterId: json['inviter_id'],
      inviterUsername: json['inviter_username'],
      inviteeId: json['invitee_id'],
      inviteeUsername: json['invitee_username'],
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'team_name': teamName,
      'inviter_id': inviterId,
      'inviter_username': inviterUsername,
      'invitee_id': inviteeId,
      'invitee_username': inviteeUsername,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}
