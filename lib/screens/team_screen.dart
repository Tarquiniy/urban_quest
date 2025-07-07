import 'package:urban_quest/models/team.dart';
import 'package:urban_quest/models/team_invitation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/screens/team_details_screen.dart';
import 'package:urban_quest/screens/create_team_screen.dart';
import 'package:urban_quest/screens/join_team_screen.dart';
import 'package:urban_quest/widgets/team_card.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({Key? key}) : super(key: key);

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeams();
      _loadInvitations();
    });
  }

  Future<void> _loadTeams() async {
    final authProvider = context.read<AuthProvider>();
    final teamProvider = context.read<TeamProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      await teamProvider.loadUserTeams(userId);
    }
  }

  Future<void> _loadInvitations() async {
    final authProvider = context.read<AuthProvider>();
    final teamProvider = context.read<TeamProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      await teamProvider.loadInvitations(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teamProvider = context.watch<TeamProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои команды'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadTeams();
              _loadInvitations();
            },
          ),
        ],
      ),
      body: _buildBody(theme, teamProvider, authProvider),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildBody(
      ThemeData theme, TeamProvider teamProvider, AuthProvider authProvider) {
    if (teamProvider.isLoading && teamProvider.userTeams.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTeams();
        await _loadInvitations();
      },
      child: CustomScrollView(
        slivers: [
          if (teamProvider.receivedInvitations.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Приглашения в команды',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ),
          if (teamProvider.receivedInvitations.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final invitation = teamProvider.receivedInvitations[index];
                  return _buildInvitationCard(invitation, theme);
                },
                childCount: teamProvider.receivedInvitations.length,
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Мои команды',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          if (teamProvider.userTeams.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.group, size: 80, color: Colors.grey),
                    const SizedBox(height: 20),
                    Text(
                      'Вы пока не состоите ни в одной команде',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Создайте новую команду или присоединитесь к существующей',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final team = teamProvider.userTeams[index];
                  return TeamCard(
                    team: team,
                    onTap: () => _openTeamDetails(team),
                  );
                },
                childCount: teamProvider.userTeams.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(TeamInvitation invitation, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Приглашение в команду ${invitation.teamName}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'От: ${invitation.inviterUsername}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _respondToInvitation(invitation, false),
                  child: const Text('Отклонить'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _respondToInvitation(invitation, true),
                  child: const Text('Принять'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respondToInvitation(
      TeamInvitation invitation, bool accept) async {
    final teamProvider = context.read<TeamProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    try {
      await teamProvider.respondToInvitation(
        invitationId: invitation.id,
        accept: accept,
        teamId: invitation.teamId,
        userId: userId,
      );

      if (accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы приняли приглашение!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы отклонили приглашение')),
        );
      }

      await _loadTeams();
      await _loadInvitations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    }
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'join_team',
          mini: true,
          onPressed: () => _openJoinTeamScreen(),
          child: const Icon(Icons.group_add),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'create_team',
          onPressed: () => _openCreateTeamScreen(),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }

  void _openTeamDetails(Team team) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailsScreen(team: team),
      ),
    );
  }

  void _openCreateTeamScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateTeamScreen(),
      ),
    ).then((_) {
      _loadTeams();
      _loadInvitations();
    });
  }

  void _openJoinTeamScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinTeamScreen(),
      ),
    ).then((_) {
      _loadTeams();
      _loadInvitations();
    });
  }
}
