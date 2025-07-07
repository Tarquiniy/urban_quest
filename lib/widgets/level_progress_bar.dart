import 'package:flutter/material.dart';

class LevelProgressBar extends StatelessWidget {
  final int level;
  final double progress;
  final int nextLevelExp;
  final int currentExp;
  final Color color;

  const LevelProgressBar({
    Key? key,
    required this.level,
    required this.progress,
    required this.nextLevelExp,
    required this.currentExp,
    this.color = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Уровень $level',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          backgroundColor: color.withOpacity(0.2),
          color: color,
          borderRadius: BorderRadius.circular(5),
        ),
        const SizedBox(height: 4),
        Text(
          '$currentExp/$nextLevelExp XP',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
