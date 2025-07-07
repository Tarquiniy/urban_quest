import 'package:flutter/material.dart';
import 'package:urban_quest/screens/home_screen.dart';
import 'package:urban_quest/screens/quest_list_screen.dart';

class QuestCompleteScreen extends StatefulWidget {
  final String questName;
  final int rewardPoints;

  const QuestCompleteScreen(
      {Key? key, required this.questName, required this.rewardPoints})
      : super(key: key);

  @override
  _QuestCompleteScreenState createState() => _QuestCompleteScreenState();
}

class _QuestCompleteScreenState extends State<QuestCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();

    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Квест завершён!')),
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
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 100, color: Colors.amber),
                const SizedBox(height: 20),
                Text(
                  'Поздравляем!\nВы завершили квест "${widget.questName}"!',
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Вы заработали +${widget.rewardPoints} очков!',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                _buildButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => const QuestListScreen()));
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text("Начать новый квест"),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) => const HomeScreen()));
          },
          icon: const Icon(Icons.home),
          label: const Text("Вернуться в меню"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ],
    );
  }
}
