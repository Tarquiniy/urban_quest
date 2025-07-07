import 'package:urban_quest/models/team_quest_status.dart';
import 'package:flutter/material.dart';

class QuestProgressCard extends StatelessWidget {
  final TeamQuestStatus teamQuestStatus;
  final int totalMembers;

  const QuestProgressCard({
    Key? key,
    required this.teamQuestStatus,
    required this.totalMembers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = teamQuestStatus.membersCompleted / totalMembers;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Прогресс команды',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${teamQuestStatus.membersCompleted}/$totalMembers участников',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
