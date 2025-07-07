import 'package:urban_quest/models/achievement.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/achievement_provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  _AchievementsScreenState createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final achievementProvider = context.read<AchievementProvider>();

    if (authProvider.currentUser != null &&
        !achievementProvider.isInitialized) {
      await achievementProvider.initialize(authProvider.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final achievementProvider = Provider.of<AchievementProvider>(context);
    final theme = Theme.of(context);

    if (!achievementProvider.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Достижения'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.all_inclusive), text: 'Все'),
            Tab(icon: Icon(Icons.verified), text: 'Полученные'),
            Tab(icon: Icon(Icons.lock_open), text: 'Доступные'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAchievementsList(
              achievementProvider.allAchievements, theme, achievementProvider),
          _buildAchievementsList(
              achievementProvider.userAchievements, theme, achievementProvider),
          _buildAchievementsList(
            achievementProvider.allAchievements
                .where((a) => !achievementProvider.userAchievements
                    .any((ua) => ua.id == a.id))
                .toList(),
            theme,
            achievementProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList(List<Achievement> achievements, ThemeData theme,
      AchievementProvider achievementProvider) {
    if (achievementProvider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          final isUnlocked = achievementProvider.userAchievements
              .any((a) => a.id == achievement.id);

          return _buildAnimatedAchievementCard(
              achievement, isUnlocked, theme, index);
        },
      ),
    );
  }

  Widget _buildAnimatedAchievementCard(
      Achievement achievement, bool isUnlocked, ThemeData theme, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        // Добавляем ограничение для значения opacity
        final opacity = value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: opacity, // Используем ограниченное значение
            child: child,
          ),
        );
      },
      child: _buildAchievementCard(achievement, isUnlocked, theme),
    );
  }

  Widget _buildAchievementCard(
      Achievement achievement, bool isUnlocked, ThemeData theme) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isUnlocked
            ? () => _showAchievementDetails(achievement, theme)
            : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isUnlocked
                ? LinearGradient(
                    colors: [
                      theme.primaryColor.withOpacity(0.1),
                      theme.scaffoldBackgroundColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildIconWithGlow(achievement, isUnlocked),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked
                              ? theme.textTheme.titleMedium?.color
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUnlocked
                              ? theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.8)
                              : Colors.grey,
                        ),
                      ),
                      if (achievement.conditionValue != null) ...[
                        const SizedBox(height: 8),
                        _buildProgressIndicator(achievement, isUnlocked),
                      ],
                    ],
                  ),
                ),
                Icon(
                  isUnlocked ? Icons.verified : Icons.lock,
                  color: isUnlocked ? Colors.amber : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconWithGlow(Achievement achievement, bool isUnlocked) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUnlocked
            ? Colors.amber.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: isUnlocked ? Colors.amber : Colors.grey,
          width: 2,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          achievement.icon,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(Achievement achievement, bool isUnlocked) {
    final progress = isUnlocked ? 1.0 : 0.3; // Замените на реальный прогресс

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.withOpacity(0.2),
          color: isUnlocked ? Colors.amber : Colors.blue,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        SizedBox(height: 4),
        Text(
          isUnlocked ? 'Получено!' : 'Прогресс: ${(progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showAchievementDetails(Achievement achievement, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 16),
                Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(height: 20),
                _buildIconWithGlow(achievement, true),
                SizedBox(height: 20),
                Text(
                  achievement.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    achievement.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                SizedBox(height: 24),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRewardItem(
                        Icons.star,
                        '${achievement.points} очков',
                        Colors.amber,
                      ),
                      _buildRewardItem(
                        Icons.bolt,
                        '${achievement.experienceReward} опыта',
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardItem(IconData icon, String text, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
