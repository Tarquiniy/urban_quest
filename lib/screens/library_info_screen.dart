import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/screens/completion_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/screens/quest_screen.dart';

class LibraryInfoScreen extends StatelessWidget {
  final Location location;
  final String questId;

  const LibraryInfoScreen({
    Key? key,
    required this.location,
    required this.questId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Информация о библиотеке')),
      body: Container(
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  location.imageUrl ?? '',
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Text(location.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(location.description, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 30),
              _buildButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Позже"),
        ),
        ElevatedButton(
          onPressed: () async {
            // Показываем индикатор загрузки
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              await _continueToNextQuest(context);
            } catch (e) {
              Navigator.pop(context); // Закрываем индикатор загрузки
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ошибка: ${e.toString()}')),
              );
            }
          },
          child: const Text("Продолжить"),
        ),
      ],
    );
  }

  // В файле screens/library_info_screen.dart
  Future<void> _continueToNextQuest(BuildContext context) async {
    final questProvider = Provider.of<QuestProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    // Принудительно завершаем текущий квест
    await questProvider.forceCompleteQuest(userId, questId);

    // Получаем следующий квест
    final nextQuest = await questProvider.getNextQuest(questId);

    if (nextQuest != null) {
      // Начинаем следующий квест
      await questProvider.startQuest(userId, nextQuest.id);

      // Переходим на экран квеста
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuestScreen(questId: nextQuest.id),
        ),
      );
    } else {
      // Если следующего квеста нет - завершаем все квесты
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CompletionScreen()),
      );
    }
  }
}
