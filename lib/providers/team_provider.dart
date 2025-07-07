import 'package:urban_quest/constants.dart';
import 'package:urban_quest/main.dart';
import 'package:urban_quest/models/team_invitation.dart';
import 'package:urban_quest/models/team_leaderboard_entry.dart';
import 'package:urban_quest/models/team_quest_status.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/repositories/team_repository.dart';
import 'package:urban_quest/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:urban_quest/models/team.dart';
import 'package:urban_quest/models/team_member.dart';
import 'package:urban_quest/models/quest_status.dart';
import 'package:urban_quest/services/supabase_service.dart';
import 'package:provider/provider.dart';

class TeamProvider with ChangeNotifier {
  final TeamRepository _teamRepository;
  final SupabaseService _supabaseService = SupabaseService();
  List<Team> _userTeams = [];
  Team? _currentTeam;
  bool _isLoading = false;
  bool _hasTeam = false;
  List<TeamLeaderboardEntry> _teamLeaderboard = [];
  List<TeamMember> _teamMembers = [];
  List<QuestStatus> _teamQuestStatuses = [];

  TeamProvider(this._teamRepository);

  List<Team> get userTeams => _userTeams;
  List<TeamMember> get teamMembers => _teamMembers;
  Team? get currentTeam => _currentTeam;
  bool get isLoading => _isLoading;
  bool get hasTeam => _hasTeam;
  List<TeamLeaderboardEntry> get teamLeaderboard => _teamLeaderboard;
  List<QuestStatus> get teamQuestStatuses => _teamQuestStatuses;

  List<TeamInvitation> _sentInvitations = [];
  List<TeamInvitation> _receivedInvitations = [];

  List<TeamInvitation> get sentInvitations => _sentInvitations;
  List<TeamInvitation> get receivedInvitations => _receivedInvitations;

  Future<void> loadTeamLeaderboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabaseService.supabase
          .from('team_leaderboard')
          .select('*')
          .order('points', ascending: false);

      _teamLeaderboard = (response as List)
          .map((e) => TeamLeaderboardEntry.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('Ошибка загрузки лидерборда команд: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTeamQuestStatuses(String teamId) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[DEBUG] Loading team quest statuses for team: $teamId');

      final response = await _supabaseService.supabase
          .from('team_quest_statuses')
          .select('*')
          .eq('team_id', teamId);

      debugPrint('[DEBUG] Team quest statuses response: $response');

      final validStatuses = (response as List)
          .where((e) =>
              e['team_id'] != null &&
              e['quest_id'] != null &&
              e['status'] != null)
          .toList();

      _teamQuestStatuses =
          validStatuses.map((e) => QuestStatus.fromJson(e)).toList();
      debugPrint(
          '[DEBUG] Loaded ${_teamQuestStatuses.length} valid team quest statuses');
    } catch (e, stackTrace) {
      debugPrint('[ERROR] Error loading team quest statuses: $e');
      debugPrint(stackTrace.toString());
      _teamQuestStatuses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _stripBaseUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      if (url.startsWith('http')) {
        final uri = Uri.parse(url);
        return uri.pathSegments.last;
      }
      return url;
    } catch (e) {
      debugPrint('[ERROR] Ошибка обработки URL: $e');
      return url;
    }
  }

  Future<void> updateTeamAppearance({
    required String teamId,
    String? imageUrl,
    String? bannerUrl,
    String? colorScheme,
    String? motto,
    String? name,
  }) async {
    try {
      final updates = {
        if (imageUrl != null) 'image_url': _stripBaseUrl(imageUrl),
        if (bannerUrl != null) 'banner_url': _stripBaseUrl(bannerUrl),
        if (colorScheme != null) 'color_scheme': colorScheme,
        if (motto != null) 'motto': motto,
        if (name != null) 'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Обновляем сначала сервер
      await _supabaseService.supabase
          .from('teams')
          .update(updates)
          .eq('id', teamId);

      // Затем локальное состояние
      _updateLocalTeamData(teamId, updates);

      // Принудительно обновляем текущую команду
      if (_currentTeam?.id == teamId) {
        _currentTeam = _currentTeam!.copyWith(
          imageUrl: imageUrl ?? _currentTeam!.imageUrl,
          bannerUrl: bannerUrl ?? _currentTeam!.bannerUrl,
          colorScheme: colorScheme ?? _currentTeam!.colorScheme,
          motto: motto ?? _currentTeam!.motto,
          name: name ?? _currentTeam!.name,
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка обновления внешнего вида команды: $e');
      rethrow;
    }
  }

  String getFullTeamAvatarUrl(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/default.png';
    }
    if (fileName.startsWith('http')) return fileName;
    if (fileName.contains('object/public')) {
      return '${Constants.storageBaseUrl}/$fileName';
    }
    return '${Constants.storageBaseUrl}/object/public/${Constants.teamAvatarsBucket}/$fileName';
  }

  void _updateLocalTeamData(String teamId, Map<String, dynamic> updates) {
    final teamIndex = _userTeams.indexWhere((team) => team.id == teamId);
    if (teamIndex != -1) {
      final updatedTeam = _userTeams[teamIndex].copyWith(
        imageUrl: updates['image_url'] ?? _userTeams[teamIndex].imageUrl,
        bannerUrl: updates['banner_url'] ?? _userTeams[teamIndex].bannerUrl,
        colorScheme:
            updates['color_scheme'] ?? _userTeams[teamIndex].colorScheme,
        motto: updates['motto'] ?? _userTeams[teamIndex].motto,
        name: updates['name'] ?? _userTeams[teamIndex].name,
      );
      _userTeams[teamIndex] = updatedTeam;
    }

    if (_currentTeam?.id == teamId) {
      _currentTeam = _currentTeam!.copyWith(
        imageUrl: updates['image_url'] ?? _currentTeam!.imageUrl,
        bannerUrl: updates['banner_url'] ?? _currentTeam!.bannerUrl,
        colorScheme: updates['color_scheme'] ?? _currentTeam!.colorScheme,
        motto: updates['motto'] ?? _currentTeam!.motto,
        name: updates['name'] ?? _currentTeam!.name,
      );
    }
    notifyListeners(); // Добавлен вызов уведомления слушателей
  }

  // Остальные методы остаются без изменений
  Future<void> startTeamQuest(
      String teamId, String questId, int totalMembers) async {
    debugPrint(
        '[DEBUG] startTeamQuest called with teamId: $teamId, questId: $questId, totalMembers: $totalMembers');

    final team = _userTeams.firstWhere((team) => team.id == teamId,
        orElse: () =>
            throw Exception('Команда не найдена в списке пользователя'));

    if (_currentTeam?.id != teamId) {
      _currentTeam = team;
      debugPrint('[DEBUG] Set current team to: ${team.id}');
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[DEBUG] Getting team members for team: $teamId');
      final members = await getTeamMembers(teamId);
      debugPrint('[DEBUG] Found ${members.length} team members');

      if (members.isEmpty) {
        debugPrint('[ERROR] No members found in team');
        throw Exception('В команде нет участников');
      }

      final questProvider = Provider.of<QuestProvider>(
          navigatorKey.currentContext!,
          listen: false);

      debugPrint('[DEBUG] Starting team quest in database');
      await questProvider.startTeamQuest(teamId, questId, members.length);
      debugPrint('[DEBUG] Team quest started successfully');

      final authProvider = Provider.of<AuthProvider>(
          navigatorKey.currentContext!,
          listen: false);

      if (authProvider.currentUser != null) {
        debugPrint(
            '[DEBUG] Starting individual quest for user: ${authProvider.currentUser!.id}');
        await questProvider.startQuest(authProvider.currentUser!.id, questId);
        debugPrint('[DEBUG] Individual quest started successfully');
      }

      await loadTeamQuestStatuses(teamId);
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('[ERROR] Error starting team quest: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> pauseTeamQuest(String teamId, String questId) async {
    try {
      await _supabaseService.supabase
          .from('team_quest_statuses')
          .update({
            'status': 'paused',
            'paused_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('team_id', teamId)
          .eq('quest_id', questId);

      await loadTeamQuestStatuses(teamId);
    } catch (e) {
      debugPrint('Ошибка приостановки квеста для команды: $e');
      rethrow;
    }
  }

  Future<List<QuestStatus>> getTeamQuests(String teamId) async {
    try {
      final response = await _supabaseService.supabase
          .from('quest_statuses')
          .select()
          .eq('team_id', teamId);

      return (response as List).map((e) => QuestStatus.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Ошибка загрузки квестов команды: $e');
      return [];
    }
  }

  Future<TeamQuestStatus?> getTeamQuestStatus(
      String teamId, String questId) async {
    try {
      debugPrint(
          '[DEBUG] Getting team quest status for team: $teamId, quest: $questId');

      final response = await _supabaseService.supabase
          .from('team_quest_statuses')
          .select()
          .eq('team_id', teamId)
          .eq('quest_id', questId)
          .maybeSingle();

      if (response == null) {
        debugPrint('[DEBUG] No team quest status found');
        return null;
      }

      debugPrint('[DEBUG] Team quest status response: $response');

      if (response['team_id'] == null ||
          response['quest_id'] == null ||
          response['status'] == null) {
        debugPrint('[ERROR] Missing required fields in team quest status');
        return null;
      }

      return TeamQuestStatus.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('[ERROR] Error getting team quest status: $e');
      debugPrint(stackTrace.toString());
      return null;
    }
  }

  Future<List<QuestStatus>> getActiveTeamQuests(String teamId) async {
    try {
      final response = await _supabaseService.supabase
          .from('team_quest_statuses')
          .select()
          .eq('team_id', teamId)
          .eq('status', 'in_progress');

      return (response as List).map((e) => QuestStatus.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Ошибка получения активных квестов команды: $e');
      return [];
    }
  }

  Future<void> addTeamQuestPoints(String teamId, int points) async {
    try {
      await _supabaseService.supabase.rpc('add_team_quest_points', params: {
        'team_id': teamId,
        'points_to_add': points,
      });

      final index = _userTeams.indexWhere((team) => team.id == teamId);
      if (index != -1) {
        _userTeams[index] = _userTeams[index].copyWith(
          points: _userTeams[index].points + points,
        );
        notifyListeners();
      }

      await loadTeamLeaderboard();
    } catch (e) {
      debugPrint('Ошибка добавления очков команде: $e');
      rethrow;
    }
  }

  Future<void> loadUserTeams(String userId, {bool silent = false}) async {
    try {
      if (!silent) {
        _isLoading = true;
        notifyListeners();
      }

      _userTeams = await _teamRepository.getUserTeams(userId);
      _hasTeam = _userTeams.isNotEmpty;
    } catch (e) {
      debugPrint('Error loading user teams: $e');
      rethrow;
    } finally {
      _isLoading = false;
      if (!silent) notifyListeners();
    }
  }

  Future<void> updateMemberRole(
      String teamId, String userId, String role) async {
    try {
      await _supabaseService.supabase
          .from('team_members')
          .update({'role': role})
          .eq('team_id', teamId)
          .eq('user_id', userId);

      final index = _teamMembers.indexWhere((m) => m.userId == userId);
      if (index != -1) {
        _teamMembers[index] = TeamMember(
          teamId: _teamMembers[index].teamId,
          userId: _teamMembers[index].userId,
          username: _teamMembers[index].username,
          avatarUrl: _teamMembers[index].avatarUrl,
          joinedAt: _teamMembers[index].joinedAt,
          role: role,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating member role: $e');
      rethrow;
    }
  }

  Future<void> createTeam(String name, String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newTeam = await _supabaseService.createTeam(name, userId);
      _userTeams.add(newTeam);
      _currentTeam = newTeam;
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка создания команды: $e');
      await loadUserTeams(userId);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _supabaseService.supabase.from('teams').delete().eq('id', teamId);

      _userTeams.removeWhere((team) => team.id == teamId);
      if (_currentTeam?.id == teamId) {
        _currentTeam = null;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Ошибка удаления команды: $e');
      rethrow;
    }
  }

  Future<void> refreshUserTeams(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final teams = await _supabaseService.getUserTeams(userId);
      _userTeams = teams;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      print('Ошибка обновления списка команд: $e');
      rethrow;
    }
  }

  Future<void> joinTeam(String teamId, String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.addTeamMember(teamId, userId);
      await loadUserTeams(userId);
    } catch (e) {
      debugPrint('Error joining team: $e');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  Future<void> leaveTeam(String teamId, String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.removeTeamMember(teamId, userId);
      _userTeams.removeWhere((team) => team.id == teamId);
      if (_currentTeam?.id == teamId) {
        _currentTeam = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving team: $e');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  void setCurrentTeam(Team team) {
    _currentTeam = team;
    notifyListeners();
  }

  Future<void> updateTeamPoints(String teamId, int points) async {
    try {
      await _supabaseService.updateTeamPoints(teamId, points);
      final index = _userTeams.indexWhere((team) => team.id == teamId);
      if (index != -1) {
        _userTeams[index] = _userTeams[index].copyWith(points: points);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating team points: $e');
      rethrow;
    }
  }

  Future<void> syncTeamQuestProgress(String questId) async {
    if (_currentTeam == null) return;

    debugPrint('[SYNC] Starting team quest progress sync for quest: $questId');

    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('[SYNC] Getting completed members count');
      final response = await _supabaseService.supabase
          .from('quest_statuses')
          .select('user_id')
          .eq('quest_id', questId)
          .eq('status', 'completed')
          .inFilter(
              'user_id',
              (await getTeamMembers(_currentTeam!.id))
                  .map((m) => m.userId)
                  .toList());

      final completedCount = response.length;
      debugPrint('[SYNC] Completed count: $completedCount');

      debugPrint('[SYNC] Updating team progress');
      await _supabaseService.supabase
          .from('team_quest_statuses')
          .update({
            'members_completed': completedCount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('team_id', _currentTeam!.id)
          .eq('quest_id', questId);

      if (completedCount == (await getTeamMembers(_currentTeam!.id)).length) {
        debugPrint('[SYNC] All members completed - completing quest');
        await completeTeamQuest(_currentTeam!.id, questId, 100);
      }

      debugPrint('[SYNC] Sync completed successfully');
    } catch (e, stackTrace) {
      debugPrint('[SYNC ERROR] Error: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
      debugPrint('[SYNC] Finished sync process');
    }
  }

  Future<void> completeTeamQuest(
      String teamId, String questId, int points) async {
    try {
      await _supabaseService.supabase
          .from('team_quest_statuses')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('team_id', teamId)
          .eq('quest_id', questId);

      await addTeamQuestPoints(teamId, points);
      await loadTeamQuestStatuses(teamId);
    } catch (e) {
      debugPrint('Error completing team quest: $e');
      rethrow;
    }
  }

  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    try {
      _isLoading = true;

      final response = await _supabaseService.supabase
          .from('team_members')
          .select('*, user:users(username, avatar_url)')
          .eq('team_id', teamId);

      _teamMembers = (response as List)
          .map((e) => TeamMember(
                teamId: e['team_id'] as String,
                userId: e['user_id'] as String,
                username: e['user']['username'] as String,
                avatarUrl: e['user']['avatar_url'] as String?,
                joinedAt: DateTime.parse(e['joined_at'] as String),
                role: e['role'] as String?,
              ))
          .toList();

      return _teamMembers;
    } catch (e) {
      debugPrint('Error getting team members: $e');
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeTeamMember(String teamId, String userId) async {
    try {
      await _teamRepository.removeTeamMember(teamId, userId);
      _teamMembers.removeWhere((m) => m.userId == userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing team member: $e');
      rethrow;
    }
  }

  Future<void> sendTeamInvitation({
    required String teamId,
    required String teamName,
    required String inviterId,
    required String inviterUsername,
    required String inviteeUsername,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Получаем ID пользователя по username
      final response = await _supabaseService.supabase
          .from('users')
          .select('id, username')
          .eq('username', inviteeUsername)
          .maybeSingle();

      if (response == null) {
        throw Exception('Пользователь с таким username не найден');
      }

      final inviteeId = response['id'] as String;
      final verifiedInviteeUsername = response['username'] as String;

      // Создаем приглашение
      final invitation = await _supabaseService.supabase
          .from('team_invitations')
          .insert({
            'team_id': teamId,
            'team_name': teamName,
            'inviter_id': inviterId,
            'inviter_username': inviterUsername,
            'invitee_id': inviteeId,
            'invitee_username': verifiedInviteeUsername,
            'status': 'pending',
          })
          .select()
          .single();

      // Отправляем уведомление получателю
      await NotificationService.sendTeamInvitationNotification(
        teamId: teamId,
        teamName: teamName,
        inviterId: inviterId,
        inviterUsername: inviterUsername,
        inviteeId: inviteeId,
        invitationId: invitation['id'],
      );

      // Обновляем локальное состояние
      _sentInvitations.add(TeamInvitation.fromJson(invitation));
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка отправки приглашения: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInvitations(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final receivedResponse = await _supabaseService.supabase
          .from('team_invitations')
          .select()
          .eq('invitee_id', userId)
          .eq('status', 'pending');

      _receivedInvitations = (receivedResponse as List)
          .map((e) => TeamInvitation.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка загрузки приглашений: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> respondToInvitation({
    required String invitationId,
    required bool accept,
    required String teamId,
    required String userId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final status = accept ? 'accepted' : 'rejected';

      await _supabaseService.supabase
          .from('team_invitations')
          .update({'status': status}).eq('id', invitationId);

      if (accept) {
        await joinTeam(teamId, userId);
        // Останавливаем проверку уведомлений после принятия приглашения
        NotificationService.stopChecking();
      }

      _receivedInvitations.removeWhere((inv) => inv.id == invitationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка обработки приглашения: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
