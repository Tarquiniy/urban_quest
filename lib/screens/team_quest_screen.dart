import 'package:urban_quest/constants.dart';
import 'package:urban_quest/models/quest.dart';
import 'package:urban_quest/models/team_quest_status.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/screens/quest_screen.dart';
import 'package:urban_quest/widgets/quest_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamQuestScreen extends StatefulWidget {
  final String questId;
  final String teamId;

  const TeamQuestScreen({
    Key? key,
    required this.questId,
    required this.teamId,
  }) : super(key: key);

  @override
  _TeamQuestScreenState createState() => _TeamQuestScreenState();
}

class _TeamQuestScreenState extends State<TeamQuestScreen> {
  bool _isLoading = true;
  TeamQuestStatus? _teamQuestStatus;
  Quest? _quest;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      final questProvider = Provider.of<QuestProvider>(context, listen: false);

      // Загружаем статус квеста команды
      _teamQuestStatus =
          await teamProvider.getTeamQuestStatus(widget.teamId, widget.questId);

      // Загружаем информацию о квесте
      await questProvider.loadQuests();
      _quest = questProvider.quests.firstWhere(
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
    } catch (e) {
      print('Ошибка загрузки данных: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getFullImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/default.png';
    }
    if (imageUrl.startsWith('http')) return imageUrl;
    return '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/$imageUrl';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Загрузка...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_quest == null || _quest!.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Не удалось загрузить квест')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_quest!.name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с изображением квеста
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _getFullImageUrl(_quest!.imageUrl),
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
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/default.png',
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Описание квеста
            Text(
              _quest!.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),

            // Прогресс команды
            if (_teamQuestStatus != null)
              QuestProgressCard(
                teamQuestStatus: _teamQuestStatus!,
                totalMembers: _teamQuestStatus!.totalMembers,
              ),
            const SizedBox(height: 20),

            // Кнопка продолжения
            ElevatedButton(
              onPressed: () {
                // Навигация к вопросам квеста
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuestScreen(
                      questId: widget.questId,
                      isTeamQuest: true,
                    ),
                  ),
                );
              },
              child: const Text('Продолжить квест'),
            ),
          ],
        ),
      ),
    );
  }
}
