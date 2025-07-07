class Question {
  final String id;
  final String questId;
  final String locationId;
  final String text;
  final List<String> options;
  bool answered;
  final String hint;

  Question({
    required this.id,
    required this.questId,
    required this.locationId,
    required this.text,
    required this.options,
    required this.hint,
    this.answered = false,
  });

  // Добавьте этот метод
  Question copyWith({
    String? id,
    String? questId,
    String? locationId,
    String? text,
    List<String>? options,
    bool? answered,
    String? hint,
  }) {
    return Question(
      id: id ?? this.id,
      questId: questId ?? this.questId,
      locationId: locationId ?? this.locationId,
      text: text ?? this.text,
      options: options ?? this.options,
      answered: answered ?? this.answered,
      hint: hint ?? this.hint,
    );
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      questId: json['quest_id'],
      locationId: json['location_id'],
      text: json['text'],
      options: List<String>.from(json['options'] ?? []),
      answered: json['answered'] ?? false,
      hint: json['hint'],
    );
  }
}
