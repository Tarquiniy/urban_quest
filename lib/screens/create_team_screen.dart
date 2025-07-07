import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
//import 'package:chelyabinsk_quest/widgets/custom_textfield.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({Key? key}) : super(key: key);

  @override
  _CreateTeamScreenState createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfUserHasTeam();
    });
  }

  Future<void> _checkIfUserHasTeam() async {
    final teamProvider = context.read<TeamProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      // Загружаем тихо, без уведомления слушателей
      await teamProvider.loadUserTeams(userId, silent: true);
      if (teamProvider.hasTeam && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы уже состоите в команде!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamProvider = context.watch<TeamProvider>();

    if (teamProvider.hasTeam) {
      return Scaffold(
        appBar: AppBar(title: const Text('Создать команду')),
        body: const Center(
          child: Text('Вы уже создали команду и не можете создать новую'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Создать команду')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Название команды'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите название команды';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              teamProvider.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _createTeam,
                      child: const Text('Создать команду'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createTeam() async {
    if (!_formKey.currentState!.validate()) return;

    final teamProvider = context.read<TeamProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    try {
      await teamProvider.createTeam(_nameController.text, userId);
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
