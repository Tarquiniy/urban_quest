class Answer {
  final String id;
  final String questionId;
  final String text; // Добавляем поле 'text'
  final bool isCorrect;

  Answer({
    required this.id,
    required this.questionId,
    required this.text,
    required this.isCorrect,
  });

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      id: json['id'],
      questionId: json['question_id'],
      text: json['text'], // Убедись, что в Supabase поле называется 'answer'
      isCorrect: json['is_correct'] ?? false,
    );
  }
}
