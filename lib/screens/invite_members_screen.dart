import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';

class InviteMembersScreen extends StatefulWidget {
  final String teamId;
  final String teamName;

  const InviteMembersScreen({
    Key? key,
    required this.teamId,
    required this.teamName,
  }) : super(key: key);

  @override
  _InviteMembersScreenState createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final teamProvider = Provider.of<TeamProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пригласить в команду'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username пользователя',
                hintText: 'Введите username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _sendInvitation(
                        teamProvider,
                        authProvider.currentUser!.id,
                        authProvider.currentUser!.username,
                      ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Отправить приглашение'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendInvitation(
    TeamProvider teamProvider,
    String inviterId,
    String inviterUsername,
  ) async {
    if (_usernameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await teamProvider.sendTeamInvitation(
        teamId: widget.teamId,
        teamName: widget.teamName,
        inviterId: inviterId,
        inviterUsername: inviterUsername,
        inviteeUsername: _usernameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Приглашение отправлено!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
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
}
