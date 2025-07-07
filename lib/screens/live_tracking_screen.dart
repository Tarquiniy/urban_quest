import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:urban_quest/models/location.dart';
import 'package:urban_quest/screens/library_info_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Location location;
  final String questId;

  const LiveTrackingScreen(
      {Key? key, required this.location, required this.questId})
      : super(key: key);

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  bool _isNearby = false;
  Position? _currentPosition;
  double? _direction;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassSubscription;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _startTracking();
    _startCompass();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);
  }

  void _startTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((Position position) {
      if (!mounted) return;

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        widget.location.latitude,
        widget.location.longitude,
      );

      if (distance <= 10) {
        setState(() => _isNearby = true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => LibraryInfoScreen(
                  location: widget.location, questId: widget.questId)),
        );
      } else {
        setState(() {
          _isNearby = false;
          _currentPosition = position;
        });
      }
    });
  }

  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (!mounted || _currentPosition == null) return;

      setState(() {
        _direction = _calculateBearing(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          widget.location.latitude,
          widget.location.longitude,
          event.heading ?? 0,
        );
      });
    });
  }

  double _calculateBearing(
      double lat1, double lon1, double lat2, double lon2, double heading) {
    double phi1 = lat1 * pi / 180, phi2 = lat2 * pi / 180;
    double deltaLambda = (lon2 - lon1) * pi / 180;
    double y = sin(deltaLambda) * cos(phi2);
    double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
    double bearing = atan2(y, x) * 180 / pi;
    return ((bearing - heading + 360) % 360) * (pi / 180);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _compassSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Навигация к цели')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade800, Colors.deepPurple.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.scale(scale: _animation.value, child: child);
                },
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: _isNearby
                      ? Colors.green.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.3),
                  child: Icon(Icons.location_on,
                      size: 80, color: _isNearby ? Colors.green : Colors.blue),
                ),
              ),
              const SizedBox(height: 30),
              if (_direction != null)
                Transform.rotate(
                  angle: _direction!,
                  child: const Icon(Icons.navigation,
                      size: 100, color: Colors.white),
                ),
              const SizedBox(height: 20),
              Text(
                _isNearby ? "Вы на месте!" : "Идём к цели...",
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                _currentPosition != null
                    ? "${Geolocator.distanceBetween(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        widget.location.latitude,
                        widget.location.longitude,
                      ).toStringAsFixed(1)} м"
                    : "Определение расстояния...",
                style: const TextStyle(fontSize: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
