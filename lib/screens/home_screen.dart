import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/screens/achievements_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/providers/theme_provider.dart';
import 'package:urban_quest/screens/leaderboard_screen.dart';
import 'package:urban_quest/screens/profile_screen.dart';
import 'package:urban_quest/screens/team_screen.dart';
import 'package:urban_quest/screens/quest_screen.dart';
import 'package:urban_quest/widgets/animated_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_quest/models/quest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasPausedQuest = false;
  String? _pausedQuestId;
  bool _isLoadingTeamQuests = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuestProvider>(context, listen: false).loadQuests();
      _checkPausedQuest();
      _loadCurrentQuest();
      _loadActiveTeamQuests();
    });
  }

  Future<void> _loadActiveTeamQuests() async {
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);
    if (!teamProvider.hasTeam) return;

    setState(() => _isLoadingTeamQuests = true);
    try {
      await Provider.of<QuestProvider>(context, listen: false)
          .loadTeamQuests(teamProvider.currentTeam!.id);
    } catch (e) {
      debugPrint('Ошибка загрузки командных квестов: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingTeamQuests = false);
      }
    }
  }

  Widget _buildActiveTeamQuests(BuildContext context, ThemeData theme) {
    final teamProvider = Provider.of<TeamProvider>(context);
    final questProvider = Provider.of<QuestProvider>(context);

    if (!teamProvider.hasTeam || questProvider.teamQuests.isEmpty) {
      return const SizedBox();
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Активные командные квесты',
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 10),
        ...questProvider.teamQuests.map((teamQuest) {
          final quest = questProvider.quests.firstWhere(
            (q) => q.id == teamQuest.questId,
            orElse: () => Quest(
              id: '',
              name: 'Неизвестный квест',
              description: '',
              imageUrl: '',
              locationId: '',
              questOrder: 0,
              category: '',
            ),
          );

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ListTile(
              leading: _buildQuestImage(quest.imageUrl, theme),
              title: Text(quest.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: teamQuest.completionProgress,
                    backgroundColor: Colors.grey[200],
                    color: theme.primaryColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(teamQuest.completionProgress * 100).toStringAsFixed(0)}% завершено',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuestScreen(
                      questId: quest.id,
                      isTeamQuest: true,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildQuestImage(String imageUrl, ThemeData theme) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          imageUrl,
          headers: {
            if (Supabase.instance.client.auth.currentSession != null)
              'Authorization':
                  'Bearer ${Supabase.instance.client.auth.currentSession!.accessToken}'
          },
          fit: BoxFit.cover,
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
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.help_outline,
            color: theme.primaryColor,
          ),
        ),
      ),
    );
  }

  Future<void> _checkPausedQuest() async {
    final prefs = await SharedPreferences.getInstance();
    final pausedQuestId = prefs.getString('paused_quest_id');

    if (pausedQuestId != null) {
      setState(() {
        _hasPausedQuest = true;
        _pausedQuestId = pausedQuestId;
      });
    }
  }

  Future<void> _loadCurrentQuest() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    if (userId != null) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questProvider = Provider.of<QuestProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urban Quest'),
        actions: [
          IconButton(
            icon: Icon(
                themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => themeProvider.toggleTheme(),
          ),
        ],
      ),
      drawer: _buildDrawer(context, theme, authProvider),
      body: questProvider.isLoading || _isLoadingTeamQuests
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, theme),
    );
  }

  Widget _buildDrawer(
      BuildContext context, ThemeData theme, AuthProvider authProvider) {
    return SizedBox(
      width:
          MediaQuery.of(context).size.width * 0.55, // Drawer шириной 75% экрана
      child: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity, // Растянуть по ширине
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withOpacity(0.85)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Urban Quest',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.person, "Профиль", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(user: authProvider.currentUser!),
                ),
              );
            }),
            _buildDrawerItem(Icons.group, "Мои команды", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeamScreen()),
              );
            }),
            _buildDrawerItem(Icons.leaderboard, "Лидерборд", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const LeaderboardScreen()),
              );
            }),
            _buildDrawerItem(Icons.emoji_events, "Достижения", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AchievementsScreen()),
              );
            }),
            _buildDrawerItem(Icons.settings, "Настройки", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Экран настроек скоро будет доступен")),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text("Выйти"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 18)),
      onTap: onTap,
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    return Container(
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
      child: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                "Добро пожаловать в Urban Quest!",
                style: theme.textTheme.headlineMedium
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Исследуйте город, выполняйте квесты и получайте награды!",
                style:
                    theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              if (_hasPausedQuest) _buildPausedQuestCard(context, theme),
              const SizedBox(height: 20),
              _buildStartQuestButton(context, theme),
              _buildActiveTeamQuests(context, theme),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPausedQuestCard(BuildContext context, ThemeData theme) {
    return AnimatedCard(
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: theme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.play_circle_fill, size: 50, color: theme.primaryColor),
              const SizedBox(height: 10),
              Text('Продолжить квест', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          QuestScreen(questId: _pausedQuestId!),
                    ),
                  );
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartQuestButton(BuildContext context, ThemeData theme) {
    final questProvider = Provider.of<QuestProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);

    return FutureBuilder<List<Quest>>(
      future: questProvider.getActiveQuests(userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Ошибка: ${snapshot.error}');
        } else {
          final activeQuests = snapshot.data!;

          if (activeQuests.isNotEmpty) {
            return ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        QuestScreen(questId: activeQuests.first.id),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Продолжить квест',
                style:
                    theme.textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            );
          } else {
            return FutureBuilder<bool>(
              future: questProvider.areAllQuestsCompleted(userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Ошибка: ${snapshot.error}');
                } else {
                  final allQuestsCompleted = snapshot.data!;

                  if (allQuestsCompleted) {
                    return ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Функция повторного прохождения квестов пока не реализована!",
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Пройти квесты заново',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    );
                  } else {
                    return Column(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            final firstQuestId =
                                await questProvider.getFirstQuestId();
                            if (firstQuestId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Нет доступных квестов!")),
                              );
                              return;
                            }

                            if (teamProvider.hasTeam) {
                              await questProvider.startQuest(
                                  userId, firstQuestId);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QuestScreen(questId: firstQuestId),
                                ),
                              );
                            } else {
                              await questProvider.startQuest(
                                  userId, firstQuestId);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      QuestScreen(questId: firstQuestId),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            'Начать новый квест',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                        if (teamProvider.hasTeam) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Вы состоите в команде - можно начать командный квест',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    );
                  }
                }
              },
            );
          }
        }
      },
    );
  }
}
