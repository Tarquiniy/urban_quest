import 'package:urban_quest/models/location.dart';
import 'package:flutter/material.dart';
import 'package:urban_quest/models/quest.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/screens/quest_screen.dart';

class QuestCard extends StatelessWidget {
  final Quest quest;
  final VoidCallback onTap;

  const QuestCard({Key? key, required this.quest, required this.onTap})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    final questProvider = Provider.of<QuestProvider>(context, listen: false);

    return Card(
      child: ListTile(
        title: Text(quest.name),
        subtitle: Text(quest.description),
        onTap: () {
          // Используем FutureBuilder для обработки асинхронного запроса
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FutureBuilder<List<Location>>(
                future: questProvider.getLocationsForQuest(quest.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Показываем индикатор загрузки, пока данные загружаются
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  } else if (snapshot.hasError) {
                    // Показываем сообщение об ошибке, если что-то пошло не так
                    return Scaffold(
                      appBar: AppBar(title: const Text('Ошибка')),
                      body: Center(child: Text('Ошибка: ${snapshot.error}')),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    // Показываем сообщение, если локации не найдены
                    return Scaffold(
                      appBar: AppBar(title: const Text('Ошибка')),
                      body: const Center(
                          child: Text('Локации для квеста не найдены')),
                    );
                  } else {
                    // Если данные успешно загружены, переходим на QuestScreen
                    return QuestScreen(questId: quest.id);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
