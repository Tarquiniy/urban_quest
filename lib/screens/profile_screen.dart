import 'package:urban_quest/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/models/user.dart' as prefix;
import 'package:urban_quest/models/quest.dart';
import 'package:urban_quest/screens/quest_screen.dart';
import 'package:urban_quest/screens/account_settings_screen.dart';
import 'package:urban_quest/widgets/level_progress_bar.dart';
import 'package:urban_quest/widgets/stats_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final prefix.User user;
  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<Quest>> _activeQuestsFuture;
  final SupabaseService _supabaseService = SupabaseService();
  late prefix.User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadUserQuests();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    if (authProvider.currentUser != null) {
      _currentUser = authProvider.currentUser!;
    }
  }

  Widget _buildUserInfoSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.7),
            theme.primaryColor.withOpacity(0.4),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildAnimatedAvatar(_currentUser.avatarUrl),
          const SizedBox(height: 16),
          Text(
            _currentUser.username,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LevelProgressBar(
            level: _currentUser.level,
            progress: _currentUser.levelProgress,
            nextLevelExp:
                _currentUser.experienceForLevel(_currentUser.level + 1),
            currentExp: _currentUser.experience,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    return Column(
      children: [
        StatsCard(
          title: 'Основная статистика',
          stats: {
            'Очки': '${_currentUser.points}',
            'Завершено квестов': '${_currentUser.totalQuestsCompleted}',
            'Посещено локаций': '${_currentUser.totalLocationsVisited}',
          },
          color: theme.primaryColor,
        ),
        const SizedBox(height: 12),
        StatsCard(
          title: 'Ответы на вопросы',
          stats: {
            'Всего ответов': '${_currentUser.totalQuestionsAnswered}',
            'Правильные': '${_currentUser.correctAnswers}',
            'Неправильные': '${_currentUser.incorrectAnswers}',
            'Процент правильных': _currentUser.totalQuestionsAnswered > 0
                ? '${(_currentUser.correctAnswers / _currentUser.totalQuestionsAnswered * 100).toStringAsFixed(1)}%'
                : '0%',
          },
          color: Colors.blueAccent,
        ),
      ],
    );
  }

  Future<void> _loadUserQuests() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      setState(() {
        _activeQuestsFuture = _getActiveQuests(userId);
      });
    }
  }

  Future<List<Quest>> _getActiveQuests(String userId) async {
    final questProvider = context.read<QuestProvider>();

    try {
      if (questProvider.quests.isEmpty) {
        await questProvider.loadQuests();
      }

      final response = await _supabaseService.supabase
          .from('quest_statuses')
          .select('quest_id')
          .eq('user_id', userId)
          .eq('status', 'in_progress');

      if (response.isEmpty) return [];

      List<String> activeQuestIds =
          response.map<String>((row) => row['quest_id'] as String).toList();

      return questProvider.quests
          .where((q) => activeQuestIds.contains(q.id))
          .toList();
    } catch (e) {
      debugPrint('Ошибка загрузки активных квестов: $e');
      return [];
    }
  }

  Widget _buildActiveQuestsList(ThemeData theme) {
    return FutureBuilder<List<Quest>>(
      future: _activeQuestsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }
        if (snapshot.data == null || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Нет активных квестов",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final quest = snapshot.data![index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    quest.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.help_outline,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                title: Text(
                  quest.name,
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  quest.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.primaryColor,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuestScreen(questId: quest.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AccountSettingsScreen(user: _currentUser),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.primaryColor.withOpacity(0.2),
              theme.scaffoldBackgroundColor
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildUserInfoSection(theme),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildStatsSection(theme),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Активные квесты",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildActiveQuestsList(theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedAvatar(String? avatarUrl) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CircleAvatar(
          radius: 50,
          backgroundImage: NetworkImage(
            _currentUser.fullAvatarUrl,
            headers: {
              'Authorization':
                  'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}'
            },
          ),
          backgroundColor: Colors.grey.shade300,
          onBackgroundImageError: (exception, stackTrace) {
            // Просто логируем ошибку, не возвращаем ничего
            debugPrint('Error loading avatar: $exception');
          },
          child: _currentUser.fullAvatarUrl.contains('default')
              ? Icon(Icons.person, size: 50, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
