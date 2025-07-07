import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';

class JoinTeamScreen extends StatefulWidget {
  const JoinTeamScreen({Key? key}) : super(key: key);

  @override
  _JoinTeamScreenState createState() => _JoinTeamScreenState();
}

class _JoinTeamScreenState extends State<JoinTeamScreen> {
  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (teamProvider.hasTeam) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мои команды')),
        body: const Center(
          child: Text(
              'Вы уже состоите в команде и не можете присоединиться к другой'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Присоединиться к команде')),
      body: _buildTeamList(authProvider, teamProvider),
    );
  }

  Widget _buildTeamList(AuthProvider authProvider, TeamProvider teamProvider) {
    if (teamProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: teamProvider.userTeams.length,
      itemBuilder: (context, index) {
        final team = teamProvider.userTeams[index];
        return ListTile(
          title: Text(team.name),
          onTap: () => _joinTeam(team.id, authProvider.currentUser?.id),
        );
      },
    );
  }

  Future<void> _joinTeam(String teamId, String? userId) async {
    if (userId == null) return;

    try {
      final teamProvider = context.read<TeamProvider>();
      await teamProvider.joinTeam(teamId, userId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}')),
        );
      }
    }
  }
}
