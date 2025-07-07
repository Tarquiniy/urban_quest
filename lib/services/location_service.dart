import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';
import 'package:flutter/material.dart';

class LocationService {
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    );
  }

  static Future<bool> _checkPermissions() async {
    final status = await Permission.location.status;
    if (!status.isGranted) {
      final result = await Permission.location.request();
      return result.isGranted;
    }
    return true;
  }

  static void startTracking(
      Position targetPosition, String questId, String locationId) async {
    getPositionStream().listen((Position position) async {
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        targetPosition.latitude,
        targetPosition.longitude,
      );

      if (distance <= 100) {
        await NotificationService.showQuestNotification(
          title: "Вы почти на месте!",
          message: "Осталось менее 100 метров до цели!",
          questId: questId,
          locationId: locationId,
        );
      }
    });
  }
}
