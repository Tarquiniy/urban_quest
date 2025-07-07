class TeamMessage {
  final String id;
  final String teamId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final String username; // Добавлено имя пользователя

  TeamMessage({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.username, // Инициализируем
  });

  factory TeamMessage.fromJson(Map<String, dynamic> json) {
    return TeamMessage(
      id: json['id'],
      teamId: json['team_id'],
      userId: json['user_id'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      username: json['users']
          ['username'], // Получаем из связанной таблицы 'users'
    );
  }
}
