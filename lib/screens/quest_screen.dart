import 'package:urban_quest/constants.dart';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/models/question.dart';
import 'package:urban_quest/models/user.dart' as CustomUser;
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/screens/arrival_confirmation_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urban_quest/models/quest.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/screens/pause_screen.dart';
import 'package:urban_quest/screens/question_screen.dart';
import 'package:urban_quest/screens/home_screen.dart';

class QuestScreen extends StatefulWidget {
  final String questId;
  final bool isTeamQuest;

  const QuestScreen({
    Key? key,
    required this.questId,
    this.isTeamQuest = false,
  }) : super(key: key);

  @override
  _QuestScreenState createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  bool _isLoading = true;
  bool _showCompletionDialog = false;
  Location? _currentLocation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final questProvider = context.read<QuestProvider>();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;

      if (userId.isEmpty) {
        setState(() {
          _errorMessage = 'Не удалось определить пользователя';
          _isLoading = false;
        });
        return;
      }

// Загружаем пользователя из таблицы Supabase
      final userData = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userData == null) {
        setState(() {
          _errorMessage = 'Пользователь не найден в базе данных';
          _isLoading = false;
        });
        return;
      }

// Всё успешно — продолжаем
      final user = CustomUser.User.fromJson(userData);

      await questProvider.loadQuests();

      if (widget.isTeamQuest) {
        final teamProvider = context.read<TeamProvider>();
        await teamProvider.syncTeamQuestProgress(widget.questId);
      }

      await questProvider.loadUserProgress(user.id, widget.questId);
      _currentLocation = questProvider.getLocationForQuest(widget.questId);

      if (_currentLocation != null) {
        await questProvider.loadPoetQuestions(_currentLocation!.id);
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки данных: ${e.toString()}';
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadInitialData();
  }

  String _getFullImageUrl(String imageUrl) {
    // Если изображение уже полный URL, возвращаем как есть
    if (imageUrl.startsWith('http')) return imageUrl;

    // Если изображение не указано, используем дефолтное
    if (imageUrl.isEmpty) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/default.png';
    }

    // Формируем URL для конкретного изображения квеста
    return '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = context.watch<QuestProvider>();
    final quest = questProvider.quests.firstWhere(
      (q) => q.id == widget.questId,
      orElse: () => Quest(
        id: '',
        name: 'Квест не найден',
        description: '',
        imageUrl: '',
        locationId: '',
        questOrder: -1,
        category: '',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(quest.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
          ),
          if (!widget.isTeamQuest)
            IconButton(
              icon: const Icon(Icons.pause),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PauseScreen(questId: widget.questId),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : quest.id.isEmpty
                  ? const Center(child: Text('Квест не найден'))
                  : _buildContent(questProvider, quest),
    );
  }

  Widget _buildContent(QuestProvider questProvider, Quest quest) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildQuestHeader(quest),
          _buildProgressIndicator(questProvider),
          _buildQuestionsSection(questProvider),
          if (_showCompletionDialog) _buildCompletionButton(),
        ],
      ),
    );
  }

  Widget _buildQuestHeader(Quest quest) {
    final imageUrl = _getFullImageUrl(quest.imageUrl);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                headers: {
                  if (Supabase.instance.client.auth.currentSession != null)
                    'Authorization':
                        'Bearer ${Supabase.instance.client.auth.currentSession!.accessToken}'
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  // Если ошибка загрузки, пробуем загрузить дефолтное изображение
                  return Image.network(
                    '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/default.png',
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            quest.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  // Остальные методы остаются без изменений
  Widget _buildProgressIndicator(QuestProvider questProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Прогресс',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: questProvider.getQuestProgress(widget.questId),
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection(QuestProvider questProvider) {
    if (_currentLocation == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('Локация не найдена'),
      );
    }

    final questions =
        questProvider.getQuestionsForLocation(_currentLocation!.id);
    if (questions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Нет вопросов для этой локации'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => questProvider
                  .loadPoetQuestions(_currentLocation!.id)
                  .then((_) => setState(() {})),
              child: const Text('Загрузить вопросы'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вопросы',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final question = questions[index];
              return Card(
                child: ListTile(
                  title: Text(question.text),
                  leading: question.answered
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.help_outline, color: Colors.grey),
                  onTap: () => _navigateToQuestionScreen(question),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check_circle),
        label: const Text('Подтвердить прибытие'),
        onPressed: () {
          if (_currentLocation != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ArrivalConfirmationScreen(
                  locationId: _currentLocation!.id,
                  questId: widget.questId,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _navigateToQuestionScreen(Question question) async {
    final allQuestionsAnswered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionScreen(
          questId: widget.questId,
          question: question,
          locationId: _currentLocation?.id ?? '',
          isTeamQuest: widget.isTeamQuest,
        ),
      ),
    );

    if (allQuestionsAnswered == true && mounted) {
      setState(() => _showCompletionDialog = true);
    }
  }
}
