import 'package:urban_quest/constants.dart';
import 'package:urban_quest/models/quest.dart';
import 'package:urban_quest/models/team.dart';
import 'package:urban_quest/models/team_member.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/screens/team_chat_screen.dart';
import 'package:urban_quest/screens/team_customization_screen.dart';
import 'package:urban_quest/screens/team_quest_screen.dart';
import 'package:urban_quest/screens/invite_members_screen.dart';
import 'package:urban_quest/widgets/level_progress_bar.dart';
import 'package:urban_quest/widgets/member_list_tile.dart';
import 'package:urban_quest/widgets/stats_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamDetailsScreen extends StatefulWidget {
  final Team team;
  const TeamDetailsScreen({Key? key, required this.team}) : super(key: key);

  @override
  _TeamDetailsScreenState createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  late Team _currentTeam;
  bool _isLoadingQuests = false;
  late Future<List<TeamMember>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _currentTeam = widget.team;
    _loadTeamMembers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final teamProvider = Provider.of<TeamProvider>(context);
    if (teamProvider.currentTeam != null) {
      _currentTeam = teamProvider.currentTeam!;
    }
  }

  Future<void> _loadTeamMembers() async {
    if (!mounted) return;
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);
    _membersFuture = teamProvider.getTeamMembers(_currentTeam.id);
    setState(() {}); // Чтобы обновить UI при изменении
  }

  Future<void> _startTeamQuest() async {
    final questProvider = Provider.of<QuestProvider>(context, listen: false);
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_currentTeam.id.isEmpty) return;

    setState(() => _isLoadingQuests = true);
    try {
      final members = await teamProvider.getTeamMembers(_currentTeam.id);
      final memberCount = members.length;

      final firstQuest = questProvider.quests.firstWhere(
        (q) => true,
        orElse: () => Quest(
          id: '',
          name: '',
          description: '',
          imageUrl: '',
          locationId: '',
          questOrder: -1,
          category: '',
        ),
      );

      if (firstQuest.id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет доступных квестов')),
        );
        return;
      }

      await teamProvider.startTeamQuest(
          _currentTeam.id, firstQuest.id, memberCount);

      if (authProvider.currentUser != null) {
        await questProvider.startQuest(
            authProvider.currentUser!.id, firstQuest.id);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TeamQuestScreen(
            questId: firstQuest.id,
            teamId: _currentTeam.id,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка запуска квеста: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoadingQuests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamColor = _getTeamColor();
    final authProvider = Provider.of<AuthProvider>(context);
    final isCaptain = _currentTeam.captainId == authProvider.currentUser?.id;
    final teamProvider = Provider.of<TeamProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Информация о команде'),
        backgroundColor: teamColor,
        actions: [
          if (isCaptain)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TeamCustomizationScreen(team: _currentTeam),
                  ),
                ).then((_) {
                  if (teamProvider.currentTeam != null) {
                    setState(() {
                      _currentTeam = teamProvider.currentTeam!;
                    });
                  }
                });
              },
              tooltip: 'Настройки команды',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeamMembers,
            tooltip: 'Обновить участников',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildTeamHeader(theme, teamColor),
            _buildTeamStats(theme, teamColor),
            _buildMembersSection(theme, teamColor, isCaptain),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamHeader(ThemeData theme, Color teamColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [teamColor.withOpacity(0.8), teamColor.withOpacity(0.5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.network(
                _currentTeam.fullImageUrl,
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
                    '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/default.png',
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _currentTeam.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentTeam.motto ?? 'Без девиза',
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamStats(ThemeData theme, Color teamColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          StatsCard(
            title: 'Статистика команды',
            stats: {
              'Очки': '${_currentTeam.points}',
              'Уровень': '${_currentTeam.level}',
              'Завершено квестов': '${_currentTeam.totalQuestsCompleted}',
              'Ранг': '#${(_currentTeam.points ~/ 100) + 1}',
            },
            color: teamColor,
          ),
          const SizedBox(height: 16),
          LevelProgressBar(
            level: _currentTeam.level,
            progress: _currentTeam.levelProgress,
            nextLevelExp:
                _currentTeam.experienceForLevel(_currentTeam.level + 1),
            currentExp: _currentTeam.experience,
            color: teamColor,
          ),
          const SizedBox(height: 16),
          _buildTeamActions(theme, teamColor),
        ],
      ),
    );
  }

  Widget _buildTeamActions(ThemeData theme, Color teamColor) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isCaptain = _currentTeam.captainId == authProvider.currentUser?.id;

    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TeamChatScreen(team: _currentTeam),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: teamColor,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('Открыть чат команды'),
        ),
        const SizedBox(height: 12),

        // ✅ Теперь доступна всем участникам команды
        ElevatedButton(
          onPressed: _isLoadingQuests ? null : _startTeamQuest,
          style: ElevatedButton.styleFrom(
            backgroundColor: teamColor,
            minimumSize: const Size(double.infinity, 50),
          ),
          child: _isLoadingQuests
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Начать командный квест'),
        ),
        const SizedBox(height: 12),

        // 🔐 Только капитан может приглашать участников
        if (isCaptain)
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InviteMembersScreen(
                    teamId: _currentTeam.id,
                    teamName: _currentTeam.name,
                  ),
                ),
              ).then((_) => _loadTeamMembers());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: teamColor.withOpacity(0.9),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Пригласить участников'),
          ),
      ],
    );
  }

  Widget _buildMembersSection(
      ThemeData theme, Color teamColor, bool isCaptain) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Участники команды',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: teamColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCaptain)
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    color: teamColor,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InviteMembersScreen(
                            teamId: _currentTeam.id,
                            teamName: _currentTeam.name,
                          ),
                        ),
                      ).then((_) => _loadTeamMembers());
                    },
                    tooltip: 'Пригласить участников',
                  ),
              ],
            ),
          ),
          FutureBuilder<List<TeamMember>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Нет участников'));
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final member = snapshot.data![index];
                  return MemberListTile(
                    member: member,
                    color: teamColor,
                    isCaptain: isCaptain,
                    onRoleChange: (newRole) async {
                      final teamProvider =
                          Provider.of<TeamProvider>(context, listen: false);
                      await teamProvider.updateMemberRole(
                        _currentTeam.id,
                        member.userId,
                        newRole,
                      );
                      await _loadTeamMembers();
                    },
                    onMemberRemove: () async {
                      final teamProvider =
                          Provider.of<TeamProvider>(context, listen: false);
                      await teamProvider.removeTeamMember(
                          _currentTeam.id, member.userId);
                      await _loadTeamMembers();
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getTeamColor() {
    if (_currentTeam.colorScheme == null || _currentTeam.colorScheme!.isEmpty) {
      return Theme.of(context).primaryColor;
    }
    try {
      return Color(
          int.parse(_currentTeam.colorScheme!.replaceFirst('#', '0xff')));
    } catch (e) {
      return Theme.of(context).primaryColor;
    }
  }
}
