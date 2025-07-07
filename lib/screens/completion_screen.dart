import 'package:flutter/material.dart';
import 'package:urban_quest/screens/home_screen.dart';

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Поздравляем!"),
        automaticallyImplyLeading: false, // ❌ Убираем кнопку "назад"
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, size: 100, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                "Все квесты успешно завершены!",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false, // Убираем все предыдущие экраны
                  );
                },
                child: const Text("На главную"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
