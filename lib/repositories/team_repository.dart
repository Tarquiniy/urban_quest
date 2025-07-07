import 'package:urban_quest/models/team.dart';
import 'package:urban_quest/models/team_member.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamRepository {
  final SupabaseClient _supabase;

  TeamRepository(this._supabase);

  Future<List<Team>> getUserTeams(String userId) async {
    final response = await _supabase
        .from('team_members')
        .select('teams(*)')
        .eq('user_id', userId);

    return (response as List).map((teamData) {
      return Team.fromJson(teamData['teams'] as Map<String, dynamic>);
    }).toList();
  }

  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    final response = await _supabase
        .from('team_members')
        .select('*, users(username, avatar_url)')
        .eq('team_id', teamId);

    return (response as List).map((e) => TeamMember.fromJson(e)).toList();
  }

  Future<void> removeTeamMember(String teamId, String userId) async {
    await _supabase
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  Future<void> updateTeamAppearance({
    required String teamId,
    String? imageUrl,
    String? bannerUrl,
    String? colorScheme,
    String? motto,
  }) async {
    await _supabase.from('teams').update({
      if (imageUrl != null) 'image_url': imageUrl,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (colorScheme != null) 'color_scheme': colorScheme,
      if (motto != null) 'motto': motto,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', teamId);
  }

  Future<void> deleteTeam(String teamId) async {
    await _supabase.from('teams').delete().eq('id', teamId);
  }
}
