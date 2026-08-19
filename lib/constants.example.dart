/// Copy this file to `lib/constants.dart` and fill in real values.
///
/// `lib/constants.dart` is intentionally gitignored to prevent credential leaks.
class Constants {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String storageBaseUrl = supabaseUrl.replaceFirst('/rest/v1', '');

  static const String defaultAvatar = 'default.png';
  static const String userAvatarsBucket = 'user-avatars';
  static const String teamAvatarsBucket = 'team-avatars';
  static const String questImagesBucket = 'quest-images';
  static const String locationImagesBucket = 'location-images';
}
