import 'package:urban_quest/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/providers/quest_provider.dart';
import 'package:urban_quest/providers/auth_provider.dart';
import 'package:urban_quest/screens/live_tracking_screen.dart';
import 'package:urban_quest/screens/home_screen.dart';

class ArrivalConfirmationScreen extends StatefulWidget {
  final String locationId;
  final String questId;

  const ArrivalConfirmationScreen(
      {Key? key, required this.locationId, required this.questId})
      : super(key: key);

  @override
  State<ArrivalConfirmationScreen> createState() =>
      _ArrivalConfirmationScreenState();
}

class _ArrivalConfirmationScreenState extends State<ArrivalConfirmationScreen> {
  bool _completingQuest = false;
  Location? _location; // Добавляем поле для хранения локации

  @override
  void initState() {
    super.initState();
    _loadLocation(); // Загружаем локацию при инициализации
  }

  Future<void> _loadLocation() async {
    final questProvider = Provider.of<QuestProvider>(context, listen: false);
    final location = await questProvider.getLocationById(widget.locationId);
    if (mounted) {
      setState(() {
        _location = location;
      });
    }
  }

  void _openMapApp(BuildContext context, String app, Location location) async {
    String mapQuery = Uri.encodeComponent(location.address ?? "");

    String url;
    switch (app) {
      case 'google':
        url = 'https://www.google.com/maps/search/?api=1&query=$mapQuery';
        break;
      case 'yandex':
        url = 'https://yandex.ru/maps/?text=$mapQuery';
        break;
      case '2gis':
        url = 'https://2gis.ru/search/$mapQuery';
        break;
      default:
        return;
    }

    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть приложение карты')),
      );
    }
  }

  void _showMapOptions(BuildContext context, Location location) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Открыть в Google Maps'),
            onTap: () {
              Navigator.pop(context);
              _openMapApp(context, 'google', location);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Открыть в Яндекс.Картах'),
            onTap: () {
              Navigator.pop(context);
              _openMapApp(context, 'yandex', location);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Открыть в 2GIS'),
            onTap: () {
              Navigator.pop(context);
              _openMapApp(context, '2gis', location);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _completeQuest() async {
    if (!mounted) return;

    setState(() {
      _completingQuest = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final questProvider = Provider.of<QuestProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id;

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ошибка: пользователь не найден!")),
          );
        }
        return;
      }

      // Завершаем квест
      await questProvider.completeQuest(
          context, userId, widget.questId, widget.locationId);

      // Переходим на экран с компасом
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LiveTrackingScreen(
              location: _location!,
              questId: widget.questId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Ошибка при завершении квеста: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ошибка при завершении квеста!")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _completingQuest = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_location == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Подтверждение прибытия"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Отлично! Хочешь перейти в приложение карты или доберёшься сам?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _completingQuest
                  ? null
                  : () {
                      LocationService.startTracking(
                        Position(
                          latitude: _location!.latitude,
                          longitude: _location!.longitude,
                          timestamp: DateTime.now(),
                          accuracy: 5.0,
                          altitude: 0.0,
                          altitudeAccuracy: 1.0,
                          heading: 0.0,
                          headingAccuracy: 1.0,
                          speed: 0.0,
                          speedAccuracy: 1.0,
                        ),
                        widget.questId,
                        widget.locationId,
                      );

                      _showMapOptions(context, _location!);
                    },
              child: _completingQuest
                  ? const CircularProgressIndicator()
                  : const Text("Открыть карту"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _completingQuest
                  ? null
                  : () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LiveTrackingScreen(
                            location: _location!,
                            questId: widget.questId,
                          ),
                        ),
                      );
                    },
              child: _completingQuest
                  ? const CircularProgressIndicator()
                  : const Text("Я доберусь сам"),
            ),
          ],
        ),
      ),
    );
  }
}
