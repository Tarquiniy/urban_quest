import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/models/quest.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/screens/quest_screen.dart';

class QuestListScreen extends StatefulWidget {
  const QuestListScreen({Key? key}) : super(key: key);

  @override
  _QuestListScreenState createState() => _QuestListScreenState();
}

class _QuestListScreenState extends State<QuestListScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<QuestProvider>(context, listen: false).loadQuests();
  }

  @override
  Widget build(BuildContext context) {
    final questProvider = Provider.of<QuestProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('📜 Список квестов')),
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
        child: questProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: questProvider.quests.length,
                itemBuilder: (context, index) {
                  final quest = questProvider.quests[index];
                  return _buildQuestCard(context, quest, theme, index);
                },
              ),
      ),
    );
  }

  Widget _buildQuestCard(
      BuildContext context, Quest quest, ThemeData theme, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(quest.imageUrl,
                width: 60, height: 60, fit: BoxFit.cover),
          ),
          title: Text(quest.name, style: theme.textTheme.titleMedium),
          subtitle: Text(quest.description,
              maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing:
              const Icon(Icons.play_arrow, color: Colors.deepPurple, size: 30),
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => QuestScreen(questId: quest.id)));
          },
        ),
      ),
    );
  }
}
