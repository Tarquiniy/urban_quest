import 'dart:io';

import 'package:urban_quest/constants.dart';
import 'package:urban_quest/models/achievement.dart';
import 'package:urban_quest/models/quest_status.dart';
import 'package:urban_quest/models/team.dart';
import 'package:urban_quest/models/team_leaderboard_entry.dart';
import 'package:urban_quest/models/team_member.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urban_quest/models/user.dart' as CustomUser;
import 'package:urban_quest/models/quest.dart';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/models/question.dart';
import 'package:urban_quest/models/answer.dart';
import 'package:urban_quest/models/leaderboard_entry.dart';
import 'package:urban_quest/models/team_message.dart';

class SupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> createUser(CustomUser.User user) async {
    await supabase.from('users').insert({
      'id': user.id,
      'username': user.username,
      'email': user.email,
      'password': user.password,
      'points': user.points,
      'avatar_url': user.avatarUrl ?? 'default.png',
      'experience': user.experience,
      'level': user.level,
      'total_quests_completed': user.totalQuestsCompleted,
      'total_locations_visited': user.totalLocationsVisited,
      'total_questions_answered': user.totalQuestionsAnswered,
      'consecutive_days_logged_in': user.consecutiveDaysLoggedIn,
      'last_login_date': user.lastLoginDate.toIso8601String(),
      'unlocked_achievements': user.unlockedAchievements,
    });
  }

  Future<CustomUser.User?> getUserByUsername(String username) async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      return response != null ? CustomUser.User.fromJson(response) : null;
    } catch (e) {
      debugPrint('Error getting user by username: $e');
      return null;
    }
  }

  Future<CustomUser.User?> getUserById(String userId) async {
    final response =
        await supabase.from('users').select().eq('id', userId).single();
    if (response != null) {
      return CustomUser.User.fromJson(response);
    }
    return null;
  }

  Future<List<Quest>> getQuests() async {
    final response = await supabase
        .from('quests')
        .select('*')
        .order('quest_order', ascending: true);
    return (response as List<dynamic>).map((data) {
      return Quest(
        id: data['id'],
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        imageUrl: data['image_url'] ?? '',
        locationId: data['location_id'] ?? '',
        questOrder: data['quest_order'] ?? 1,
        category: data['category'] ?? '',
      );
    }).toList();
  }

  Future<List<Location>> getQuestLocations() async {
    final response = await supabase
        .from('quest_locations')
        .select()
        .order('location_order', ascending: true);
    return (response as List<dynamic>)
        .map((e) => Location.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Question>> getQuestionsForLocation(String locationId) async {
    try {
      final response = await supabase
          .from('quest_questions')
          .select()
          .eq('location_id', locationId);

      debugPrint('Получены вопросы для location $locationId: $response');

      return (response as List<dynamic>)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Ошибка при получении вопросов: $e');
      return [];
    }
  }

  Future<List<Answer>> getAnswersForQuestion(String questionId) async {
    final response =
        await supabase.from('answers').select().eq('question_id', questionId);
    return (response as List<dynamic>)
        .map((e) => Answer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitAnswer({
    required String userId,
    required String locationId,
    required bool isCorrect,
    required bool usedHint,
  }) async {
    final response = await supabase
        .from('quest_results')
        .select()
        .eq('user_id', userId)
        .eq('location_id', locationId)
        .maybeSingle();

    int attempts = response?['attempts'] ?? 0;
    bool completed = response?['completed'] ?? false;

    if (completed || attempts >= 3) return;

    attempts += 1;
    int earnedPoints = 0;
    if (isCorrect) {
      completed = true;
      earnedPoints = usedHint ? 10 : 15;
    }

    await supabase.from('quest_results').upsert({
      'user_id': userId,
      'location_id': locationId,
      'attempts': attempts,
      'completed': completed,
    });

    if (isCorrect) {
      await updateUserPoints(userId, earnedPoints);
    }
  }

  Future<void> addLocationPoints(String userId) async {
    await updateUserPoints(userId, 10);
  }

  Future<void> updateUserPoints(String userId, int points) async {
    final response = await supabase
        .from('users')
        .select('points')
        .eq('id', userId)
        .maybeSingle();

    int currentPoints = response?['points'] ?? 0;
    int newPoints = currentPoints + points;

    await supabase.from('users').update({'points': newPoints}).eq('id', userId);
  }

  Future<Map<String, int>> getUserExperience(String userId) async {
    final response = await supabase
        .from('users')
        .select('experience, level')
        .eq('id', userId)
        .single();

    if (response != null) {
      return {
        'experience': response['experience'] ?? 0,
        'level': response['level'] ?? 1,
      };
    } else {
      return {'experience': 0, 'level': 1};
    }
  }

  Future<Team> createTeam(String teamName, String userId) async {
    try {
      // Проверяем, существует ли уже команда с таким именем
      final existingTeam = await supabase
          .from('teams')
          .select()
          .eq('name', teamName)
          .maybeSingle();

      if (existingTeam != null) {
        throw Exception('Команда с таким именем уже существует');
      }

      // Создаем команду
      final teamResponse = await supabase
          .from('teams')
          .insert({
            'name': teamName,
            'captain_id': userId,
            'creator_id': userId,
            'points': 0,
            'is_active': true,
            'image_url': 'assets/images/default_team.png',
          })
          .select()
          .single();

      final team = Team.fromJson(teamResponse);

      // Добавляем пользователя в команду
      await supabase.from('team_members').insert({
        'team_id': team.id,
        'user_id': userId,
        'role': 'captain',
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Создаем запись в таблице очков
      await supabase.from('team_scores').insert({
        'team_id': team.id,
        'points': 0,
      });

      return team;
    } catch (e) {
      debugPrint('Ошибка при создании команды: $e');
      rethrow;
    }
  }

  Future<void> deleteTeam(String teamId) async {
    await supabase.from('teams').delete().eq('id', teamId);
  }

  Future<void> joinTeam(String teamId, String userId) async {
    await supabase
        .from('team_members')
        .insert({'team_id': teamId, 'user_id': userId});
  }

  Future<List<String>> getAvailableAvatars() async {
    try {
      final response =
          await supabase.storage.from(Constants.userAvatarsBucket).list();

      return response
          .where((file) => !file.name.endsWith('/')) // Исключаем папки
          .map((file) => file.name)
          .toList();
    } catch (e) {
      debugPrint('Ошибка получения списка аватарок: $e');
      return [];
    }
  }

  Future<List<Team>> getUserTeams(String userId) async {
    try {
      final response = await supabase
          .from('team_members')
          .select('teams(*)')
          .eq('user_id', userId);

      if (response == null) return [];

      return (response as List).map((teamData) {
        final teamJson = teamData['teams'] as Map<String, dynamic>;
        return Team(
          id: teamJson['id'] as String,
          name: teamJson['name'] as String,
          captainId: teamJson['captain_id'] as String,
          creatorId: teamJson['creator_id'] as String,
          points: (teamJson['points'] as num?)?.toInt() ?? 0,
          isActive: teamJson['is_active'] as bool? ?? true,
          createdAt: DateTime.parse(teamJson['created_at'] as String),
          updatedAt: DateTime.parse(teamJson['updated_at'] as String),
          imageUrl: teamJson['image_url'] as String,
          isPublic: teamJson['is_public'] as bool? ?? true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Ошибка получения команд пользователя: $e');
      rethrow;
    }
  }

  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    final response = await supabase.from('team_members').select('''
        *,
        users:user_id (username, avatar_url)
      ''').eq('team_id', teamId);

    return (response as List).map((memberData) {
      return TeamMember(
        teamId: memberData['team_id'] as String,
        userId: memberData['user_id'] as String,
        username:
            (memberData['users'] as Map<String, dynamic>)['username'] as String,
        avatarUrl: (memberData['users'] as Map<String, dynamic>)['avatar_url']
            as String?,
        joinedAt: DateTime.parse(memberData['joined_at'] as String),
        role: memberData['role'] as String?,
      );
    }).toList();
  }

  Future<List<TeamLeaderboardEntry>> getTeamLeaderboard() async {
    final response = await supabase
        .from('team_leaderboard_view')
        .select('*')
        .order('points', ascending: false);

    return (response as List)
        .map((e) => TeamLeaderboardEntry.fromJson(e))
        .toList();
  }

  Future<void> updateTeamAppearance({
    required String teamId,
    String? imageUrl,
    String? bannerUrl,
    String? colorScheme,
    String? motto,
  }) async {
    await supabase.from('teams').update({
      if (imageUrl != null) 'image_url': imageUrl,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (colorScheme != null) 'color_scheme': colorScheme,
      if (motto != null) 'motto': motto,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', teamId);
  }

  Future<List<LeaderboardEntry>> getUserLeaderboard() async {
    final response = await supabase
        .from('users')
        .select('id, username, points')
        .order('points', ascending: false);
    return (response as List<dynamic>)
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addLeaderboardEntry({
    required String userId,
    required String questId,
    required int score,
  }) async {
    await supabase.from('leaderboard').insert({
      'user_id': userId,
      'quest_id': questId,
      'score': score,
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> giveAchievement(String userId, String achievementId) async {
    await supabase.from('user_achievements').insert({
      'user_id': userId,
      'achievement_id': achievementId,
      'date_received': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendTeamMessage({
    required String teamId,
    required String userId,
    required String message,
  }) async {
    await supabase.from('team_messages').insert({
      'team_id': teamId,
      'user_id': userId,
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<TeamMessage>> getTeamMessages(String teamId) async {
    final response = await supabase
        .from('team_messages')
        .select('*, users(username)')
        .eq('team_id', teamId)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map((e) => TeamMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Stream<List<TeamMessage>> streamTeamMessages(String teamId) {
    return supabase
        .from('team_messages')
        .stream(primaryKey: ['id'])
        .eq('team_id', teamId)
        .order('created_at', ascending: true)
        .map((snapshots) => snapshots
            .map((snapshot) => TeamMessage.fromJson(snapshot))
            .toList());
  }

  Future<void> updateUserAvatar(String userId, String avatarUrl) async {
    await supabase
        .from('users')
        .update({'avatar_url': avatarUrl}).eq('id', userId);
  }

  Future<int> getCompletedQuestsCount(String userId) async {
    final response = await supabase
        .from('quest_statuses')
        .select('quest_id')
        .eq('user_id', userId)
        .eq('status', 'completed');

    return response.length;
  }

  Future<List<Achievement>> getAllAchievements() async {
    try {
      final response = await supabase.from('achievements').select('*');
      return (response as List).map((a) => Achievement.fromJson(a)).toList();
    } catch (e) {
      print('Ошибка получения достижений: $e');
      return [];
    }
  }

  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final response = await supabase
          .from('user_achievements')
          .select('achievements(*)')
          .eq('user_id', userId);

      return (response as List)
          .map((a) => Achievement.fromJson(a['achievements'] ?? {}))
          .toList();
    } catch (e) {
      print('Ошибка получения достижений пользователя: $e');
      return [];
    }
  }

  Future<void> unlockAchievement(String userId, String achievementId) async {
    await supabase.from('user_achievements').insert({
      'user_id': userId,
      'achievement_id': achievementId,
      'unlocked_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> getAchievementsCount(String userId) async {
    final response = await supabase
        .from('user_achievements')
        .select('id')
        .eq('user_id', userId);

    return response != null ? response.length : 0;
  }

  Future<List<String>> getUserVisitedLocations(String userId) async {
    final response = await supabase
        .from('user_visited_locations')
        .select('location_id')
        .eq('user_id', userId);
    return (response as List<dynamic>)
        .map((e) => e['location_id'] as String)
        .toList();
  }

  Future<void> markLocationAsVisited(String userId, String locationId) async {
    await supabase.from('user_visited_locations').insert({
      'user_id': userId,
      'location_id': locationId,
      'visited_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateUserExperience(
      String userId, int newExp, int newLevel) async {
    await supabase.from('users').update({
      'experience': newExp,
      'level': newLevel,
    }).eq('id', userId);
  }

  Future<Map<String, dynamic>?> getQuestStatus(String questId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    return await supabase
        .from('quest_statuses')
        .select()
        .eq('user_id', userId)
        .eq('quest_id', questId)
        .maybeSingle();
  }

  Future<void> upsertQuestStatus(QuestStatus questStatus) async {
    await supabase.from('quest_statuses').upsert(questStatus.toJson());
  }

  Future<String?> getNextQuestId(String currentQuestId) async {
    final response = await supabase
        .from('quests')
        .select('id')
        .gt('id', currentQuestId)
        .order('id', ascending: true)
        .limit(1);

    if (response is List && response.isNotEmpty) {
      return response.first['id'] as String;
    }
    return null;
  }

  Future<Quest?> getNextQuestByOrder(int currentQuestOrder) async {
    final response = await supabase
        .from('quests')
        .select('*')
        .eq('quest_order', currentQuestOrder + 1)
        .limit(1)
        .maybeSingle();

    if (response != null) {
      return Quest.fromJson(response);
    }
    return null;
  }

  Future<String?> getFirstQuestId() async {
    final response = await supabase
        .from('quests')
        .select('id')
        .order('id', ascending: true)
        .limit(1);

    if (response is List && response.isNotEmpty) {
      return response.first['id'] as String;
    }
    return null;
  }

  Future<List<Team>> searchTeams(String query) async {
    final response = await supabase
        .from('teams')
        .select()
        .ilike('name', '%$query%')
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((e) => Team.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addTeamMember(String teamId, String userId) async {
    await supabase
        .from('team_members')
        .insert({'team_id': teamId, 'user_id': userId});
  }

  Future<void> removeTeamMember(String teamId, String userId) async {
    await supabase
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  Future<void> updateTeamPoints(String teamId, int points) async {
    await supabase
        .from('team_scores')
        .update({'points': points}).eq('team_id', teamId);
  }

  Future<String> uploadImage(String bucket, String path, File image) async {
    try {
      final response = await supabase.storage.from(bucket).upload(path, image,
          fileOptions: FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ));

      return '${Constants.storageBaseUrl}/object/public/$bucket/$path';
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  Future<List<String>> listImages(String bucket) async {
    try {
      final response = await supabase.storage.from(bucket).list();
      return response
          .map((file) =>
              '${Constants.storageBaseUrl}/object/public/$bucket/${file.name}')
          .toList();
    } catch (e) {
      debugPrint('Error listing images: $e');
      return [];
    }
  }
}
