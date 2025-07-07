import 'package:urban_quest/models/team_quest_status.dart';
import 'package:urban_quest/providers/achievement_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/screens/arrival_confirmation_screen.dart';
import 'package:urban_quest/screens/quest_screen.dart';
import 'package:flutter/material.dart';
import 'package:urban_quest/models/quest.dart';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/models/question.dart';
import 'package:urban_quest/models/answer.dart';
import 'package:urban_quest/models/quest_status.dart';
import 'package:urban_quest/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/screens/completion_screen.dart';
import 'package:urban_quest/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class QuestProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Quest> _quests = [];
  List<Location> _locations = [];
  List<Question> _questions = [];
  List<Answer> _answers = [];
  bool _isLoading = false;
  String? _pausedQuestId;
  List<TeamQuestStatus> _teamQuests = [];
  List<TeamQuestStatus> get teamQuests => _teamQuests;

  List<Quest> get quests => _quests;
  List<Location> get locations => _locations;
  List<Question> get questions => _questions;
  List<Answer> get answers => _answers;
  bool get isLoading => _isLoading;
  String? get pausedQuestId => _pausedQuestId;

  Future<void> loadQuests() async {
    if (_isLoading) return;

    _isLoading = true;
    // Не вызываем notifyListeners() здесь, чтобы не прерывать build-процесс

    try {
      final results = await Future.wait([
        _supabaseService.getQuests(),
        _supabaseService.getQuestLocations(),
      ]);

      _quests = results[0] as List<Quest>;
      _locations = results[1] as List<Location>;
      _quests.sort((a, b) => a.questOrder.compareTo(b.questOrder));

      for (var location in _locations) {
        final questions =
            await _supabaseService.getQuestionsForLocation(location.id);
        _questions.addAll(questions);

        for (var question in questions) {
          final answers =
              await _supabaseService.getAnswersForQuestion(question.id);
          _answers.addAll(answers);
        }
      }

      await _loadPausedQuest();

      // Уведомляем слушателей после завершения build-фазы
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Ошибка загрузки квестов: $e');
      // Также уведомляем об ошибке после build-фазы
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadTeamQuests(String teamId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabaseService.supabase
          .from('team_quest_statuses')
          .select()
          .eq('team_id', teamId);

      _teamQuests =
          (response as List).map((e) => TeamQuestStatus.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Ошибка загрузки командных квестов: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> startTeamQuest(
      String teamId, String questId, int totalMembers) async {
    try {
      // Получаем первую локацию для этого квеста
      final firstLocation = _locations.firstWhere(
        (loc) => loc.questId == questId,
        orElse: () => Location(
          id: '',
          questId: '',
          name: '',
          latitude: 0,
          longitude: 0,
          description: '',
          locationOrder: 1,
        ),
      );

      await _supabaseService.supabase.from('team_quest_statuses').upsert({
        'team_id': teamId,
        'quest_id': questId,
        'status': 'in_progress',
        'location_order': firstLocation.locationOrder,
        'total_members': totalMembers,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'team_id,quest_id');

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка при старте командного квеста: $e');
      rethrow;
    }
  }

  Future<void> completeTeamQuest(
    BuildContext context,
    String teamId,
    String questId,
    String locationId,
  ) async {
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);

    try {
      // Обновляем статус квеста
      await _supabaseService.supabase
          .from('team_quest_statuses')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('team_id', teamId)
          .eq('quest_id', questId);

      // Добавляем очки команде
      await teamProvider.addTeamQuestPoints(teamId, 50);

      // Проверяем достижения
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        final achievementProvider =
            Provider.of<AchievementProvider>(context, listen: false);
        await achievementProvider.checkAndUnlockAchievements(
            authProvider.currentUser!, context);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка завершения командного квеста: $e');
      rethrow;
    }
  }

  Future<TeamQuestStatus?> getTeamQuestStatus(
      String teamId, String questId) async {
    try {
      final response = await _supabaseService.supabase
          .from('team_quest_statuses')
          .select()
          .eq('team_id', teamId)
          .eq('quest_id', questId)
          .maybeSingle();

      return response != null ? TeamQuestStatus.fromJson(response) : null;
    } catch (e) {
      debugPrint('Ошибка получения статуса командного квеста: $e');
      return null;
    }
  }

  Location? getLocationForQuest(String questId) {
    return locations.firstWhere((loc) => loc.questId == questId);
  }

  Future<void> _loadPausedQuest() async {
    final prefs = await SharedPreferences.getInstance();
    _pausedQuestId = prefs.getString('paused_quest_id');
  }

  Future<void> pauseQuest(String questId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paused_quest_id', questId);
    _pausedQuestId = questId;
    notifyListeners();
  }

  Future<void> startQuest(String userId, String questId) async {
    debugPrint('=== START QUEST CALLED ===');
    debugPrint('Starting quest: userId=$userId, questId=$questId');
    debugPrint('Caller: ${StackTrace.current}');
    final currentStatus = await getQuestStatus(questId);
    if (currentStatus != null && currentStatus['status'] == 'completed') {
      debugPrint('Квест $questId уже завершен, пропускаем старт');
      return;
    }

    try {
      // Получаем первую локацию для этого квеста
      final firstLocation = _locations.firstWhere(
        (loc) => loc.questId == questId,
        orElse: () => Location(
          id: '',
          questId: '',
          name: '',
          latitude: 0,
          longitude: 0,
          description: '',
          locationOrder: 1,
        ),
      );

      // Используем upsert для вставки или обновления статуса квеста
      await _supabaseService.supabase.from('quest_statuses').upsert({
        'user_id': userId,
        'quest_id': questId,
        'status': 'in_progress',
        'location_order': firstLocation.locationOrder,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now()
            .toIso8601String(), // Для обновления, если запись уже есть
      }, onConflict: 'user_id,quest_id'); // Указываем столбцы для конфликта

      debugPrint('Quest status record created or updated');

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка при старте квеста: $e');
      rethrow;
    }
  }

  Future<void> ensureQuestionsLoaded(String locationId) async {
    if (_questions.where((q) => q.locationId == locationId).isEmpty) {
      await loadPoetQuestions(locationId);
    }
  }

  Future<void> loadPoetQuestions(String locationId) async {
    try {
      final response = await _supabaseService.supabase
          .from('quest_questions')
          .select()
          .eq('location_id', locationId);

      if (response.isNotEmpty) {
        _questions.removeWhere(
            (q) => q.locationId == locationId); // Удаляем старые вопросы
        _questions.addAll(response.map((q) => Question.fromJson(q)));
        notifyListeners();
      } else {
        debugPrint(
            "⚠️ Вопросы для локации $locationId не найдены в базе данных!");
      }
    } catch (e) {
      debugPrint('Ошибка загрузки вопросов: $e');
      rethrow;
    }
  }

  Future<void> loadPoetQuestionsWithAnswers(
      String userId, String locationId) async {
    final questionsResponse = await _supabaseService.supabase
        .from('questions')
        .select()
        .eq('location_id', locationId);

    if (questionsResponse.isNotEmpty) {
      List<Question> loadedQuestions =
          questionsResponse.map((q) => Question.fromJson(q)).toList();

      final answeredResponse = await _supabaseService.supabase
          .from('answered_questions')
          .select('question_id')
          .eq('user_id', userId);

      List<String> answeredQuestionIds =
          answeredResponse.map((q) => q['question_id'] as String).toList();

      for (var question in loadedQuestions) {
        if (answeredQuestionIds.contains(question.id)) {
          question.answered = true; // ✅ Сохраняем состояние ответов
        }
      }

      _questions = loadedQuestions;
      notifyListeners();
    } else {
      debugPrint("⚠️ Вопросы для локации $locationId не найдены!");
    }
  }

  String? getQuestIdByLocation(String locationId) {
    final quest = quests.firstWhere(
      (q) => q.locationId == locationId,
      orElse: () => Quest(
          id: '',
          name: '',
          description: '',
          imageUrl: '',
          locationId: '',
          questOrder: -1,
          category: ''),
    );
    return quest.id.isNotEmpty ? quest.id : null;
  }

  double getQuestProgress(String questId) {
    final totalQuestions = _questions.where((q) => q.questId == questId).length;
    if (totalQuestions == 0) return 0.0;

    final answeredQuestions = _questions.where((q) => q.answered).length;
    return answeredQuestions / totalQuestions;
  }

  Future<void> updateQuestProgress(
    String userId,
    String questId,
    int answeredCount,
    TeamProvider teamProvider,
  ) async {
    try {
      final questions =
          getQuestionsForLocation(getLocationForQuest(questId)?.id ?? '');
      final totalQuestions = questions.length;
      final progress =
          totalQuestions > 0 ? answeredCount / totalQuestions : 0.0;

      // Для индивидуальных квестов
      await _supabaseService.supabase.from('quest_statuses').upsert({
        'user_id': userId,
        'quest_id': questId,
        'progress': progress,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,quest_id');

      // Для командных квестов
      if (teamProvider.hasTeam && teamProvider.currentTeam != null) {
        final teamId = teamProvider.currentTeam!.id;
        await _supabaseService.supabase.from('team_quest_statuses').upsert({
          'team_id': teamId,
          'quest_id': questId,
          'progress': progress,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'team_id,quest_id');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка обновления прогресса: $e');
      rethrow;
    }
  }

  Future<void> addPointsAndXP(
      BuildContext context, String userId, int points, int experience) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final achievementProvider =
        Provider.of<AchievementProvider>(context, listen: false);

    // Обновляем опыт (теперь передаем context)
    await authProvider.updateUserExperience(experience, context);

    // Обновляем баллы
    await authProvider.updateUserPoints(points);

    // Проверяем достижения (теперь передаем context)
    if (authProvider.currentUser != null) {
      await achievementProvider.initialize(authProvider.currentUser!.id);
      await achievementProvider.checkAndUnlockAchievements(
          authProvider.currentUser!, context);
    }

    notifyListeners();
  }

  Future<void> resumeQuest(String questId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await _supabaseService.supabase
          .from('quest_statuses')
          .update({
            'status': 'in_progress',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('quest_id', questId);

      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming quest: $e');
      rethrow;
    }
  }

  Future<bool> isQuestCompleted(String userId, String questId) async {
    final response = await _supabaseService.supabase
        .from('quest_statuses')
        .select('status')
        .eq('user_id', userId)
        .eq('quest_id', questId)
        .maybeSingle();

    return response != null && response['status'] == 'completed';
  }

  Location? getLocationById(String locationId) {
    try {
      return _locations.firstWhere((location) => location.id == locationId);
    } catch (e) {
      return null;
    }
  }

  List<Question> getQuestionsForLocation(String locationId) {
    return _questions
        .where((question) => question.locationId == locationId)
        .toList();
  }

  Future<List<Answer>> getAnswersForQuestion(String questionId) async {
    final response = await _supabaseService.supabase
        .from('answers')
        .select('*')
        .eq('question_id', questionId);

    print("Ответы для вопроса $questionId: $response");

    return response.map((json) => Answer.fromJson(json)).toList();
  }

  Location? getNextLocation(String currentLocationId) {
    _locations.sort((a, b) => a.locationOrder.compareTo(b.locationOrder));
    for (int i = 0; i < _locations.length - 1; i++) {
      if (_locations[i].id == currentLocationId) {
        return _locations[i + 1];
      }
    }
    return null;
  }

  Future<List<Location>> getLocationsForQuest(String questId) async {
    try {
      final response = await _supabaseService.supabase
          .from('quest_locations')
          .select()
          .eq('quest_id', questId)
          .order('location_order', ascending: true);

      return (response as List<dynamic>)
          .map((e) => Location.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Ошибка при загрузке локаций: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLibraryInfo(String locationId) async {
    try {
      final response = await _supabaseService.supabase
          .from('libraries')
          .select('name, address, poet_name, poet_bio')
          .eq('location_id', locationId)
          .maybeSingle();
      if (response != null) {
        return response == null
            ? null
            : {
                'libraryName': response['name'],
                'libraryAddress': response['address'],
                'poetName': response['poet_name'] ?? 'Нет информации о поэте',
                'poetBio':
                    response['poet_bio'] ?? 'Нет информации о биографии поэта',
              };
      }
      return null;
    } catch (e) {
      print('Ошибка при получении информации о библиотеке: $e');
      return null;
    }
  }

  Future<List<Quest>> getActiveQuests(String userId) async {
    final response = await _supabaseService.supabase
        .from('quest_statuses')
        .select('quest_id')
        .eq('user_id', userId)
        .eq('status', 'in_progress');

    if (response.isEmpty) return [];

    List<String> activeQuestIds =
        response.map<String>((row) => row['quest_id'] as String).toList();

    return quests.where((q) => activeQuestIds.contains(q.id)).toList();
  }

  Future<void> loadUserProgress(String userId, String questId) async {
    final response = await _supabaseService.supabase
        .from('answered_questions')
        .select('question_id')
        .eq('user_id', userId)
        .eq('quest_id', questId);

    List<String> answeredQuestionIds =
        response.map<String>((row) => row['question_id'] as String).toList();

    // Обновляем состояние вопросов в текущем списке
    for (var question in _questions) {
      if (answeredQuestionIds.contains(question.id)) {
        question.answered = true;
      }
    }

    notifyListeners(); // 🔄 Обновляем UI
  }

  Future<Map<String, dynamic>?> getQuestStatus(String questId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    return await _supabaseService.supabase
        .from('quest_statuses')
        .select()
        .eq('user_id', userId)
        .eq('quest_id', questId)
        .maybeSingle();
  }

  Future<Quest?> getCurrentQuest(String userId) async {
    try {
      final response = await _supabaseService.supabase
          .from('quest_statuses')
          .select('quest_id, quests(*)')
          .eq('user_id', userId)
          .eq('status', 'in_progress')
          .limit(1)
          .maybeSingle();

      if (response != null && response['quests'] != null) {
        return Quest.fromJson(response['quests'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Ошибка при получении текущего квеста: $e');
      return null;
    }
  }

  Future<void> updateQuestStatus(QuestStatus questStatus) async {
    await _supabaseService.upsertQuestStatus(questStatus);
  }

  Future<Quest?> getNextQuest(String currentQuestId) async {
    try {
      final currentQuest = _quests.firstWhere((q) => q.id == currentQuestId);

      // Ищем квест с порядковым номером на 1 больше текущего
      final nextQuest = _quests.firstWhere(
        (q) => q.questOrder == currentQuest.questOrder + 1,
        orElse: () => Quest(
          id: '',
          name: '',
          description: '',
          imageUrl: '',
          locationId: '',
          questOrder: -1,
          category: '',
        ),
      );

      return nextQuest.id.isNotEmpty ? nextQuest : null;
    } catch (e) {
      debugPrint('Ошибка при получении следующего квеста: $e');
      return null;
    }
  }

  Future<void> startNextQuest(
      BuildContext context, String currentQuestId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      print('Пользователь не авторизован');
      return;
    }

    final nextQuestId = await _supabaseService.getNextQuestId(currentQuestId);

    if (nextQuestId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => QuestScreen(questId: nextQuestId)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Поздравляем! Вы прошли все квесты!')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAchievements() async {
    final response = await _supabaseService.supabase
        .from('achievements')
        .select('id, name, description, experience_required, icon');

    if (response != null && response is List) {
      return response.cast<Map<String, dynamic>>();
    } else {
      return [];
    }
  }

  Future<bool> areAllQuestsCompleted(String userId) async {
    final completedQuestsCount =
        await _supabaseService.getCompletedQuestsCount(userId);
    final totalQuestsCount = _quests.length;
    return completedQuestsCount >= totalQuestsCount;
  }

  Future<void> completeQuest(BuildContext context, String userId,
      String questId, String locationId) async {
    print(
        'Завершение квеста: userId=$userId, questId=$questId, locationId=$locationId');

    try {
      if (!areAllQuestionsAnswered(locationId)) {
        print('Не все вопросы отвечены, квест не может быть завершен');
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);

      // Награда за завершение квеста
      const int questPoints = 50;
      const int questExp = 100;

      // Обновляем пользователя
      authProvider.currentUser?.addExperience(questExp, context: context);
      authProvider.currentUser?.points += questPoints;
      authProvider.currentUser?.totalQuestsCompleted++;
      await authProvider.updateUserData();

      // Обновляем команду, если квест командный
      if (teamProvider.hasTeam && teamProvider.currentTeam != null) {
        teamProvider.currentTeam?.addQuestCompletion(questPoints);
        await teamProvider.updateTeamPoints(
            teamProvider.currentTeam!.id, teamProvider.currentTeam!.points);
      }

      final response = await _supabaseService.supabase
          .from('quest_statuses')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('quest_id', questId)
          .eq('status', 'in_progress');

      print('Статус квеста обновлен в Supabase: $response');

      // Проверяем достижения
      final achievementProvider =
          Provider.of<AchievementProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        await achievementProvider.checkAndUnlockAchievements(
            authProvider.currentUser!, context);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('paused_quest_id');
      _pausedQuestId = null;

      final allCompleted = await areAllQuestsCompleted(userId);
      if (allCompleted) {
        await NotificationService.showAllQuestsCompletedNotification();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CompletionScreen()),
        );
      } else {
        final nextQuest = await getNextQuest(questId);
        if (nextQuest != null) {
          await startQuest(userId, nextQuest.id);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => QuestScreen(questId: nextQuest.id)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CompletionScreen()),
          );
        }
      }

      notifyListeners();
    } catch (e) {
      print('Ошибка в completeQuest: $e');
      rethrow;
    }
  }

  Future<String?> getFirstQuestId() async {
    return await _supabaseService.getFirstQuestId();
  }

  Future<void> addExperience(String userId, int points) async {
    final response = await _supabaseService.supabase
        .from('users')
        .select('experience, level')
        .eq('id', userId)
        .single();

    if (response != null) {
      int currentExp = response['experience'] ?? 0;
      int newExp = currentExp + points;
      int newLevel = _calculateLevel(newExp);

      await _supabaseService.supabase
          .from('users')
          .update({'experience': newExp, 'level': newLevel}).eq('id', userId);

      notifyListeners();
    }
  }

  bool isQuestionAnswered(String questionId) {
    return _questions.any((q) => q.id == questionId && q.answered);
  }

  Future<int> getAnsweredQuestionsCount(String questId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _supabaseService.supabase
        .from('answered_questions')
        .select('question_id')
        .eq('user_id', userId)
        .eq('quest_id', questId);

    return response.length;
  }

  Future<void> markQuestionAsAnswered(
    String userId,
    String questId,
    String questionId,
    TeamProvider teamProvider,
  ) async {
    try {
      // Для командных квестов
      if (teamProvider.hasTeam && teamProvider.currentTeam != null) {
        await _supabaseService.supabase
            .rpc('upsert_team_quest_progress', params: {
          'p_team_id': teamProvider.currentTeam!.id,
          'p_quest_id': questId,
          'p_question_id': questionId,
          'p_user_id': userId,
        });
      }

      // Для индивидуальных квестов - используем upsert
      await _supabaseService.supabase.from('answered_questions').upsert({
        'user_id': userId,
        'quest_id': questId,
        'question_id': questionId,
        'answered_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,question_id');

      // Обновляем локальное состояние
      final index = _questions.indexWhere((q) => q.id == questionId);
      if (index != -1) {
        _questions[index] = _questions[index].copyWith(answered: true);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking question as answered: $e');
      rethrow;
    }
  }

  Future<bool> checkAndShowCompletion(
      String locationId, String userId, BuildContext context) async {
    final allAnswered = await checkAllQuestionsAnswered(locationId, userId);
    if (allAnswered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletionDialog(context, locationId);
      });
    }
    return allAnswered;
  }

  void _showCompletionDialog(BuildContext context, String locationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Поздравляем!'),
        content: Text(
            'Вы ответили на все вопросы этой локации! Перейдите к подтверждению прибытия.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Позже'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Закрываем диалог
              _navigateToArrivalConfirmation(context, locationId);
            },
            child: Text('Подтвердить прибытие'),
          ),
        ],
      ),
    );
  }

  void _navigateToArrivalConfirmation(BuildContext context, String locationId) {
    final questProvider = Provider.of<QuestProvider>(context, listen: false);
    final questId = questProvider.getQuestIdByLocation(locationId);

    if (questId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArrivalConfirmationScreen(
            locationId: locationId,
            questId: questId,
          ),
        ),
      );
    }
  }

  Future<bool> checkAllQuestionsAnswered(
      String locationId, String userId) async {
    try {
      // Получаем все вопросы для локации
      final questions = getQuestionsForLocation(locationId);
      if (questions.isEmpty) return false;

      // Проверяем в базе данных, какие вопросы уже отвечены
      final response = await _supabaseService.supabase
          .from('answered_questions')
          .select('question_id')
          .eq('user_id', userId)
          .inFilter('question_id', questions.map((q) => q.id).toList());

      final answeredQuestionIds =
          response.map((q) => q['question_id'] as String).toList();

      // Обновляем локальное состояние
      for (var question in questions) {
        question.answered = answeredQuestionIds.contains(question.id);
      }

      // Проверяем, что все вопросы отвечены
      return questions.every((q) => q.answered);
    } catch (e) {
      debugPrint('Error checking answered questions: $e');
      return false;
    }
  }

  Future<List<QuestStatus>> getIndividualQuestStatuses(String userId) async {
    try {
      final response = await _supabaseService.supabase
          .from('quest_statuses')
          .select()
          .eq('user_id', userId)
          .filter(
              'team_id', 'is', 'null') // Фильтруем только индивидуальные квесты
          .order('created_at', ascending: false);

      return (response as List).map((e) => QuestStatus.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Ошибка загрузки индивидуальных квестов: $e');
      return [];
    }
  }
//  Future<List<QuestStatus>> getIndividualQuestStatuses(String userId) async {
//    try {
//      final response = await _supabaseService.supabase
//          .from('quest_statuses')
//          .select()
//          .eq('user_id', userId)
//          .filter('team_id', 'is', 'null') // Правильный способ фильтрации NULL
//          .eq('status', 'in_progress');
//
//      return (response as List).map((e) => QuestStatus.fromJson(e)).toList();
//    } catch (e) {
//      debugPrint('Ошибка загрузки индивидуальных квестов: $e');
//      return [];
//    }
//  }

  Future<void> forceCompleteQuest(String userId, String questId) async {
    try {
      await _supabaseService.supabase.from('quest_statuses').upsert({
        'user_id': userId,
        'quest_id': questId,
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,quest_id');

      debugPrint(
          'Квест $questId принудительно завершен для пользователя $userId');

      // Очищаем paused_quest_id
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('paused_quest_id');
      _pausedQuestId = null;

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка при принудительном завершении квеста: $e');
      rethrow;
    }
  }

  int _calculateLevel(int experience) {
    return (experience / 500).floor() + 1;
  }

  Future<void> loadAnsweredQuestions(String userId) async {
    final response = await _supabaseService.supabase
        .from('answered_questions')
        .select('question_id')
        .eq('user_id', userId);

    List<String> answeredIds =
        response.map<String>((q) => q['question_id'] as String).toList();

    for (var question in _questions) {
      question.answered = answeredIds.contains(question.id);
    }

    notifyListeners();
  }

  bool areAllQuestionsAnswered(String locationId) {
    final locationQuestions =
        _questions.where((q) => q.locationId == locationId).toList();
    if (locationQuestions.isEmpty) {
      debugPrint('DEBUG: Нет вопросов для локации $locationId');
      return false;
    }

    // Проверяем, что все вопросы для локации отвечены
    final allAnswered = locationQuestions.every((q) => q.answered);
    debugPrint(
        'DEBUG: Для локации $locationId отвечено ${locationQuestions.where((q) => q.answered).length} из ${locationQuestions.length} вопросов');

    return allAnswered;
  }
}
