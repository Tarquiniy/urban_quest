import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/models/question.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urban_quest/screens/arrival_confirmation_screen.dart';

class QuestionScreen extends StatefulWidget {
  final Question question;
  final String questId;
  final String locationId;
  final bool isTeamQuest;
  final VoidCallback? onAnswerSubmitted;

  const QuestionScreen({
    Key? key,
    required this.question,
    required this.questId,
    required this.locationId,
    this.isTeamQuest = false,
    this.onAnswerSubmitted,
  }) : super(key: key);

  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  String? _selectedAnswer;
  bool _isLoading = false;
  bool _isCorrect = false;
  bool _showHint = false;
  List<Map<String, dynamic>> _answers = [];
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    debugPrint(
        'DEBUG: QuestionScreen инициализирован для вопроса: ${widget.question.id}');
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    debugPrint('DEBUG: Загрузка ответов для вопроса: ${widget.question.id}');
    try {
      final response = await _supabase
          .from('answers')
          .select('id, text, is_correct')
          .eq('question_id', widget.question.id);

      if (response != null) {
        debugPrint('DEBUG: Получено ${response.length} ответов');
        if (mounted) {
          setState(() {
            _answers = List<Map<String, dynamic>>.from(response);
          });
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Ошибка загрузки ответов: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки ответов: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _checkAnswer(String answerId, String answerText) async {
    if (_isLoading || !mounted) return;

    setState(() {
      _isLoading = true;
      _selectedAnswer = answerId;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      final questProvider = Provider.of<QuestProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) throw Exception('User ID is null');

      final selectedAnswer = _answers.firstWhere(
        (a) => a['id'] == answerId,
        orElse: () => throw Exception('Answer not found'),
      );

      final isCorrect = selectedAnswer['is_correct'] as bool;
      setState(() => _isCorrect = isCorrect);

      // Обновляем статистику пользователя
      authProvider.currentUser?.addQuestionResult(isCorrect, _showHint);
      await authProvider.updateUserData();

      if (isCorrect) {
        // Сохраняем ответ в провайдере
        await questProvider.markQuestionAsAnswered(
          userId,
          widget.questId,
          widget.question.id,
          teamProvider,
        );

        // Показываем уведомление о награде
        _showRewardNotification(isCorrect);

        // Проверяем, все ли вопросы локации отвечены
        final allQuestionsAnswered =
            questProvider.areAllQuestionsAnswered(widget.locationId);

        if (allQuestionsAnswered && mounted) {
          await _showCompletionDialog();
        } else if (mounted) {
          if (widget.onAnswerSubmitted != null) {
            widget.onAnswerSubmitted!();
          }
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Неправильный ответ! Попробуйте еще раз.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _checkAnswer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRewardNotification(bool isCorrect) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    int expGained = isCorrect ? (_showHint ? 7 : 10) : 2;
    int pointsGained = isCorrect ? (_showHint ? 3 : 5) : 0;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCorrect
              ? 'Правильно! +$pointsGained очков и +$expGained опыта${_showHint ? " (с учетом подсказки)" : ""}'
              : 'Неправильный ответ, но вы получили +$expGained опыта за попытку',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showCompletionDialog() async {
    debugPrint('DEBUG: Показ диалога завершения локации...');
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        debugPrint('DEBUG: Диалог завершения локации построен');
        return AlertDialog(
          title: const Text('Локация завершена!'),
          content: const Text(
              'Вы ответили на все вопросы этой локации. Перейти к подтверждению прибытия?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Позже'),
              onPressed: () {
                debugPrint('DEBUG: Пользователь выбрал "Позже"');
                Navigator.of(context).pop();
                if (widget.onAnswerSubmitted != null) {
                  widget.onAnswerSubmitted!();
                }
                Navigator.pop(context, true);
              },
            ),
            TextButton(
              child: const Text('Перейти'),
              onPressed: () {
                debugPrint('DEBUG: Пользователь выбрал "Перейти"');
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArrivalConfirmationScreen(
                      locationId: widget.locationId,
                      questId: widget.questId,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    debugPrint('DEBUG: Построение интерфейса QuestionScreen');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вопрос'),
        automaticallyImplyLeading: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withOpacity(0.8),
              theme.scaffoldBackgroundColor
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.question.text,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              if (_showHint)
                Text(
                  'Подсказка: ${widget.question.hint}',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _answers.length,
                  itemBuilder: (context, index) {
                    final answer = _answers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getButtonColor(answer['id']),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => _checkAnswer(answer['id'], answer['text']),
                        child: Text(
                          answer['text'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!_showHint && widget.question.hint.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showHint = true;
                    });
                  },
                  child: const Text('Показать подсказку'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getButtonColor(String answerId) {
    if (!_isLoading && _selectedAnswer == answerId) {
      return _isCorrect ? Colors.green : Colors.red;
    }
    return Theme.of(context).primaryColor;
  }
}
