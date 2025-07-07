import 'package:geolocator/geolocator.dart';
import 'dart:math';

class LocationUtils {
  // Функция для расчета расстояния между двумя координатами в метрах
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Радиус Земли в метрах

    double lat1Rad = _toRadians(lat1);
    double lon1Rad = _toRadians(lon1);
    double lat2Rad = _toRadians(lat2);
    double lon2Rad = _toRadians(lon2);

    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    double a = pow(sin(dLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(dLon / 2), 2);
    double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // Проверяем, находится ли пользователь в радиусе от местоположения
  static bool isWithinRadius(Position userLocation, double targetLatitude,
      double targetLongitude, double radius) {
    double distance = calculateDistance(
      userLocation.latitude,
      userLocation.longitude,
      targetLatitude,
      targetLongitude,
    );
    return distance <= radius;
  }
}
