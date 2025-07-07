import 'package:urban_quest/constants.dart';

class Quest {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String locationId;
  final int questOrder;
  final String category;

  Quest(
      {required this.id,
      required this.name,
      required this.description,
      required this.imageUrl,
      required this.locationId,
      required this.questOrder,
      required this.category});

  factory Quest.fromJson(Map<String, dynamic> json) {
    return Quest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Без названия',
      description: json['description'] as String? ?? '',
      imageUrl: _getFullImageUrl(json['image_url'] as String?),
      locationId: json['location_id'] as String? ?? '',
      questOrder: (json['quest_order'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
    );
  }

  static String _getFullImageUrl(String? url) {
    // Если URL не указан или пустой, возвращаем дефолтное изображение
    if (url == null || url.isEmpty) {
      return '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/default.png';
    }

    // Если URL уже полный (начинается с http), возвращаем как есть
    if (url.startsWith('http')) return url;

    // Формируем полный URL для изображения квеста
    return '${Constants.storageBaseUrl}/object/public/${Constants.questImagesBucket}/$url';
  }
}
