import 'dart:async';
import 'dart:io';
import 'package:urban_quest/constants.dart';
import 'package:urban_quest/providers/team_provider.dart';
import 'package:urban_quest/repositories/team_repository.dart';
import 'package:urban_quest/services/notification_service.dart';
import 'package:urban_quest/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/providers/leaderboard_provider.dart';
import 'package:urban_quest/providers/location_provider.dart';
import 'package:urban_quest/providers/achievement_provider.dart';
import 'package:urban_quest/providers/theme_provider.dart';
import 'package:urban_quest/screens/auth/login_screen.dart';
import 'package:urban_quest/screens/home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> requestLocationPermission() async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    // Для Windows и Linux пропускаем запрос разрешений на геолокацию
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
}

class AppLifecycleTracker with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        NotificationService.appInForeground = true;
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        NotificationService.appInForeground = false;
        break;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Добавляем отслеживание жизненного цикла
  final lifecycleTracker = AppLifecycleTracker();
  WidgetsBinding.instance.addObserver(lifecycleTracker);

  // Для Windows и Linux пропускаем запрос разрешений
  if (!kIsWeb && !(Platform.isWindows || Platform.isLinux)) {
    await Geolocator.requestPermission();
    await requestLocationPermission();
  }

  await Supabase.initialize(
    url: Constants.supabaseUrl,
    anonKey: Constants.supabaseAnonKey,
  );

  final authProvider = AuthProvider();
  await authProvider.initialize();
  final supabase = Supabase.instance.client;

  final teamRepository = TeamRepository(supabase);

  // Для Windows и Linux пропускаем запрос разрешений на уведомления
  if (!kIsWeb && !(Platform.isWindows || Platform.isLinux)) {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    await NotificationService.init();
  }

  // Подписываемся на нажатия уведомлений
  NotificationService.onNotificationTap.listen((payload) {
    try {
      NotificationService.handleNotificationTap(payload);
    } catch (e) {
      debugPrint('Ошибка обработки уведомления: $e');
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => QuestProvider()..loadQuests()),
        ChangeNotifierProvider(
          create: (_) => AchievementProvider(),
        ),
        ChangeNotifierProvider(create: (_) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TeamProvider(teamRepository)),
        Provider(create: (_) => SupabaseService()),
      ],
      child: const NotificationWrapper(),
    ),
  );
}

class NotificationWrapper extends StatefulWidget {
  const NotificationWrapper({Key? key}) : super(key: key);

  @override
  State<NotificationWrapper> createState() => _NotificationWrapperState();
}

class _NotificationWrapperState extends State<NotificationWrapper> {
  @override
  Widget build(BuildContext context) {
    return const MyApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final teamProvider = Provider.of<TeamProvider>(context, listen: true);

    if (authProvider.isAuthenticated) {
      // Запускаем проверку уведомлений только если у пользователя нет команд
      if (teamProvider.userTeams.isEmpty) {
        NotificationService.startCheckingInvitations(
            authProvider.currentUser!.id);
      } else {
        NotificationService.stopChecking();
      }
    } else {
      NotificationService.stopChecking();
    }
  }

  @override
  void dispose() {
    NotificationService.stopChecking();
    super.dispose();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Urban Quest',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.currentTheme,
      navigatorKey: navigatorKey,
      home: const NotificationListenerWrapper(),
      onGenerateRoute: (settings) {
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            switch (settings.name) {
              case '/home':
                return const HomeScreen();
              case '/login':
                return const LoginScreen();
              default:
                return const AuthenticationWrapper();
            }
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        );
      },
    );
  }
}

class NotificationListenerWrapper extends StatefulWidget {
  const NotificationListenerWrapper({Key? key}) : super(key: key);

  @override
  State<NotificationListenerWrapper> createState() =>
      _NotificationListenerWrapperState();
}

class _NotificationListenerWrapperState
    extends State<NotificationListenerWrapper> {
  Timer? _notificationCheckTimer;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initNotificationListener();
  }

  @override
  void dispose() {
    _notificationCheckTimer?.cancel();
    super.dispose();
  }

  void _initNotificationListener() {
    // Запускаем проверку уведомлений каждые 10 секунд
    _notificationCheckTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkForNewNotifications();
    });
  }

  Future<void> _checkForNewNotifications() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser?.id == null) return;

    // Если пользователь изменился, обновляем ID
    if (_currentUserId != authProvider.currentUser?.id) {
      _currentUserId = authProvider.currentUser?.id;
    }

    try {
      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', _currentUserId!)
          .eq('read', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final notification = response.first;
        await _handleNotification(notification);

        // Помечаем уведомление как прочитанное
        await Supabase.instance.client
            .from('notifications')
            .update({'read': true}).eq('id', notification['id']);
      }
    } catch (e) {
      debugPrint('Ошибка проверки уведомлений: $e');
    }
  }

  Future<void> _handleNotification(Map<String, dynamic> notification) async {
    if (!mounted) return;

    final payload = notification['payload'];
    if (payload is Map<String, dynamic> &&
        payload['type'] == 'team_invitation') {
      await NotificationService.showLocalNotification(
        title: notification['title'] ?? 'Приглашение в команду',
        body: notification['message'] ?? 'Вы получили приглашение в команду',
        payload: payload,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AuthenticationWrapper();
  }
}

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({Key? key}) : super(key: key);

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<QuestProvider>(context, listen: false).loadQuests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (authProvider.isAuthenticated) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}
