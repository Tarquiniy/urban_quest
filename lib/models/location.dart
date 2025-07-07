import 'package:urban_quest/constants.dart';

class Location {
  final String id;
  final String questId;
  final String name;
  final double latitude;
  final double longitude;
  final String description;
  final String? imageUrl;
  final String? interestingFacts;
  final String? hint;
  final String? address;
  final int locationOrder;

  Location({
    required this.id,
    required this.questId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.description,
    this.imageUrl,
    this.interestingFacts,
    this.hint,
    this.address,
    required this.locationOrder,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image_url'];
    // Формируем полный URL для изображения
    if (imageUrl != null && !imageUrl.startsWith('http')) {
      imageUrl =
          '${Constants.storageBaseUrl}/object/public/${Constants.locationImagesBucket}/$imageUrl';
    }

    return Location(
      id: json['id'],
      questId: json['quest_id'] as String,
      name: json['name'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'],
      imageUrl: imageUrl,
      interestingFacts: json['interesting_facts'],
      hint: json['hint'],
      address: json['address'] as String?,
      locationOrder: json['location_order'] ?? 1,
    );
  }
}
