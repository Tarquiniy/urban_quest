import 'dart:async';
import 'dart:convert';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/screens/arrival_confirmation_screen.dart';
import 'package:urban_quest/screens/library_info_screen.dart';
import 'package:urban_quest/screens/quest_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:urban_quest/main.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final StreamController<Map<String, dynamic>>
      _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationStreamController.stream;

  static final SupabaseClient _supabase = Supabase.instance.client;

  static bool appInForeground = true;
  static bool _initialized = false;
  static Timer? _checkTimer;
  static final Map<String, DateTime> _lastNotificationTimes = {};

  static void handleNotificationTap(Map<String, dynamic> payload) {
    try {
      final type = payload['type'] ??
          (payload.containsKey('location_id') ? 'arrival_notification' : null);

      if (type == 'team_invitation') {
        _showInvitationDialog(
          teamId: payload['team_id'],
          teamName: payload['team_name'],
          inviterUsername: payload['inviter_username'],
          invitationId: payload['invitation_id'],
        );
      } else if (type == 'arrival_notification' ||
          payload.containsKey('location_id')) {
        final locationId = payload['location_id']?.toString();
        final questId = payload['quest_id']?.toString();

        if (locationId != null && questId != null) {
          _navigateToArrivalConfirmation(locationId, questId);
        }
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка обработки уведомления: ${e.toString()}')),
        );
      }
    }
  }

  static void _navigateToArrivalConfirmation(
      String locationId, String questId) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArrivalConfirmationScreen(
            locationId: locationId,
            questId: questId,
          ),
        ),
      );
    }
  }

  static Future<void> showArrivalNotification({
    required String locationId,
    required String questId,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'arrival_notifications',
      'Уведомления о прибытии',
      importance: Importance.high,
      priority: Priority.high,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    // Используем оба формата payload для совместимости
    final jsonPayload = {
      'type': 'arrival_notification',
      'location_id': locationId,
      'quest_id': questId,
    };

    final stringPayload = '$locationId,$questId';

    await _notificationsPlugin.show(
      'arrival_$locationId'.hashCode,
      'Вы приближаетесь к точке назначения',
      'Осталось менее 100 метров до следующей точки квеста',
      const NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      ),
      payload:
          stringPayload, // Можно использовать jsonEncode(jsonPayload) для JSON
    );
  }

  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(
      defaultActionName: 'Открыть уведомление',
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint("Notification tapped: payload=${response.payload}");

        if (response.payload == null) return;

        try {
          // Обрабатываем payload
          final payload = _parseNotificationPayload(response.payload!);
          if (payload != null) {
            _handleNotificationTap(payload);
          }
        } catch (e) {
          debugPrint("Error handling notification: $e");
          _showErrorSnackbar('Ошибка обработки уведомления');
        }
      },
    );

    _initialized = true;
  }

  static void _handleNotificationTap(Map<String, dynamic> payload) {
    final type = payload['type'] ??
        (payload.containsKey('location_id') ? 'arrival_notification' : null);

    if (type == 'arrival_notification') {
      _openLibraryInfoScreen(
        payload['location_id']?.toString(),
        payload['quest_id']?.toString(),
      );
    }
  }

  static void _openLibraryInfoScreen(
      String? locationId, String? questId) async {
    if (locationId == null || questId == null) {
      debugPrint("Invalid locationId or questId");
      return;
    }

    // Получаем контекст через navigatorKey
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    // Получаем провайдер квестов
    final questProvider = Provider.of<QuestProvider>(context, listen: false);

    // Получаем информацию о локации
    final location = await questProvider.getLocationById(locationId);
    if (location == null) {
      debugPrint("Location not found for id: $locationId");
      return;
    }

    // Переходим на экран информации о библиотеке
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => LibraryInfoScreen(
          location: location,
          questId: questId,
        ),
      ),
    );
  }

  static void _showErrorSnackbar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  static Map<String, dynamic>? _parseNotificationPayload(String payload) {
    try {
      // Пробуем разобрать как JSON
      if (payload.startsWith('{')) {
        return jsonDecode(payload) as Map<String, dynamic>;
      }

      // Пробуем разобрать как строку locationId,questId
      final parts = payload.split(',');
      if (parts.length == 2) {
        return {
          'type': 'arrival_notification',
          'location_id': parts[0],
          'quest_id': parts[1],
        };
      }
    } catch (e) {
      debugPrint("Error parsing notification payload: $e");
    }
    return null;
  }

  static void startCheckingInvitations(String userId) {
    _checkTimer?.cancel(); // Отменяем предыдущий таймер, если он был
    _checkTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkForNewInvitations(userId);
    });
  }

  static void stopChecking() {
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint("✅ Notification checking stopped");
  }

  static Future<void> _checkForNewInvitations(String userId) async {
    try {
      final response = await _supabase
          .from('team_invitations')
          .select()
          .eq('invitee_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final invitation = response.first;
        await _showInvitationNotification(invitation);
      }
    } catch (e) {
      debugPrint('Ошибка проверки приглашений: $e');
    }
  }

  static Future<void> _showInvitationNotification(
      Map<String, dynamic> invitation) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'team_invitations',
      'Приглашения в команды',
      importance: Importance.high,
      priority: Priority.high,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    final payload = {
      'type': 'team_invitation',
      'team_id': invitation['team_id'],
      'team_name': invitation['team_name'],
      'inviter_username': invitation['inviter_username'],
      'invitation_id': invitation['id'],
    };

    await _notificationsPlugin.show(
      invitation['id'].hashCode,
      'Приглашение в команду',
      '${invitation['inviter_username']} приглашает вас в команду ${invitation['team_name']}',
      const NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      ),
      payload: jsonEncode(payload),
    );
  }

  static void _showInvitationDialog({
    required String teamId,
    required String teamName,
    required String inviterUsername,
    required String invitationId,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Приглашение в команду'),
        content: Text('$inviterUsername приглашает вас в команду $teamName'),
        actions: [
          TextButton(
            onPressed: () =>
                _respondToInvitation(context, invitationId, teamId, false),
            child: const Text('Отклонить'),
          ),
          TextButton(
            onPressed: () =>
                _respondToInvitation(context, invitationId, teamId, true),
            child: const Text('Принять'),
          ),
        ],
      ),
    );
  }

  static void _respondToInvitation(
    BuildContext context,
    String invitationId,
    String teamId,
    bool accept,
  ) {
    Navigator.pop(context);
    Provider.of<TeamProvider>(context, listen: false).respondToInvitation(
      invitationId: invitationId,
      accept: accept,
      teamId: teamId,
      userId: Provider.of<AuthProvider>(context, listen: false).currentUser!.id,
    );
  }

  static Future<void> sendTeamInvitation({
    required String teamId,
    required String teamName,
    required String inviterId,
    required String inviterUsername,
    required String inviteeId,
    required String invitationId,
  }) async {
    try {
      // Сохраняем уведомление в базу
      await _supabase.from('notifications').insert({
        'user_id': inviteeId,
        'title': 'Приглашение в команду',
        'message': '$inviterUsername приглашает вас в команду $teamName',
        'payload': {
          'type': 'team_invitation',
          'team_id': teamId,
          'team_name': teamName,
          'inviter_id': inviterId,
          'inviter_username': inviterUsername,
          'invitation_id': invitationId,
        },
      });

      debugPrint("✅ Приглашение отправлено (ID: $invitationId)");
    } catch (e) {
      debugPrint('❌ Ошибка отправки: ${e.toString()}');
      rethrow;
    }
  }

  static Future<void> sendTeamInvitationNotification({
    required String teamId,
    required String teamName,
    required String inviterId,
    required String inviterUsername,
    required String inviteeId,
    required String invitationId,
  }) async {
    try {
      // Сохраняем уведомление в базу данных для получателя
      await _supabase.from('user_notifications').insert({
        'user_id': inviteeId,
        'title': 'Приглашение в команду',
        'message': '$inviterUsername приглашает вас в команду $teamName',
        'payload': {
          'type': 'team_invitation',
          'team_id': teamId,
          'team_name': teamName,
          'inviter_username': inviterUsername,
          'invitation_id': invitationId,
        },
        'created_at': DateTime.now().toIso8601String(),
        'read': false,
      });

      // Отправляем push-уведомление через Supabase Realtime
      final channel = _supabase.channel('notifications_$inviteeId');

      await channel.subscribe();
      await _supabase.from('notifications').insert({
        'user_id': inviteeId,
        'type': 'team_invitation',
        'data': {
          'title': 'Приглашение в команду',
          'body': '$inviterUsername приглашает вас в команду $teamName',
          'team_id': teamId,
          'team_name': teamName,
          'inviter_username': inviterUsername,
          'invitation_id': invitationId,
        },
      });

      debugPrint("✅ Приглашение отправлено получателю (ID: $invitationId)");
    } catch (e) {
      debugPrint('❌ Ошибка отправки приглашения: $e');
      rethrow;
    }
  }

  // Инициализация слушателя уведомлений
  static void initNotificationListener(String userId) {
    final channel = _supabase.channel('user_${userId}_notifications');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final notification = payload.newRecord;
            if (notification['user_id'] == userId) {
              showLocalNotification(
                title: notification['title'],
                body: notification['message'],
                payload: notification['payload'],
              );
            }
          },
        )
        .subscribe();
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    required dynamic payload,
  }) async {
    if (!_initialized) await init();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'team_invitations',
      'Приглашения в команды',
      importance: Importance.high,
      priority: Priority.high,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    await _notificationsPlugin.show(
      payload['invitation_id'].hashCode,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        linux: linuxDetails,
      ),
      payload: jsonEncode(payload),
    );
  }

  static Future<void> showQuestNotification({
    required String title,
    required String message,
    required String questId,
    required String locationId,
  }) async {
    if (!_initialized) await init();

    final key = '$questId-$locationId';
    final lastTime = _lastNotificationTimes[key];
    if (lastTime != null &&
        DateTime.now().difference(lastTime) < const Duration(minutes: 5)) {
      debugPrint("Notification was shown recently, skipping");
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'quest_channel',
      'Quest Notifications',
      channelDescription: 'Notifications for quest updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    final String payload = jsonEncode({
      'type': 'arrival_notification',
      'location_id': locationId,
      'quest_id': questId,
    });

    await _notificationsPlugin.show(
      key.hashCode,
      title,
      message,
      details,
      payload: payload,
    );

    _lastNotificationTimes[key] = DateTime.now();
  }

  static Future<void> showAllQuestsCompletedNotification() async {
    if (!_initialized) await init();

    debugPrint("📢 Showing all quests completed notification");

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'quest_channel',
      'Quest Notifications',
      channelDescription: 'Notifications for quest updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const LinuxNotificationDetails linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.normal,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      'all_quests'.hashCode,
      'Поздравляем!',
      'Вы завершили все квесты!',
      details,
      payload: 'all_quests_completed',
    );

    debugPrint("✅ All quests completed notification shown");
  }
}
