import 'package:flutter/material.dart';
import 'package:urban_quest/services/supabase_service.dart';
import 'package:urban_quest/models/leaderboard_entry.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<LeaderboardEntry> _userLeaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final users = await _supabaseService.getUserLeaderboard();
    if (!mounted) return;
    setState(() {
      _userLeaderboard = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Лидерборд'),
        centerTitle: true,
      ),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _userLeaderboard.length,
                itemBuilder: (context, index) {
                  final user = _userLeaderboard[index];
                  return _buildLeaderboardTile(user, index, theme);
                },
              ),
      ),
    );
  }

  Widget _buildLeaderboardTile(
      LeaderboardEntry user, int index, ThemeData theme) {
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
          leading: CircleAvatar(
            backgroundColor: _getRankColor(index),
            child: Text("${index + 1}",
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          title: Text(user.username, style: theme.textTheme.titleMedium),
          trailing:
              Text('${user.points} очков', style: theme.textTheme.bodyLarge),
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.grey;
    if (index == 2) return Colors.brown;
    return Colors.blueGrey;
  }
}
