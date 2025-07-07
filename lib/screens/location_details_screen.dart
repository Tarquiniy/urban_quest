import 'package:flutter/material.dart';
import 'package:urban_quest/models/location.dart';
import 'package:share_plus/share_plus.dart';

class LocationDetailsScreen extends StatelessWidget {
  final Location location;

  const LocationDetailsScreen({Key? key, required this.location})
      : super(key: key);

  Future<void> _shareLocation(BuildContext context, Location location) async {
    String text = '${location.name}\n\n${location.description}';
    if (location.imageUrl != null && location.imageUrl!.isNotEmpty) {
      text += '\n\n${location.imageUrl}';
    }
    text += '\n\n#ChelyabinskQuest'; // Добавим хэштег
    try {
      await Share.share(text, subject: location.name);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка при отправке: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(location.name),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: location.id, // Unique tag for Hero animation
                    child: location.imageUrl != null &&
                            location.imageUrl!.isNotEmpty
                        ? Image.network(
                            location.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (BuildContext context,
                                Object exception, StackTrace? stackTrace) {
                              return const Center(
                                  child:
                                      Text('Не удалось загрузить изображение'));
                            },
                          )
                        : const DecoratedBox(
                            decoration: BoxDecoration(color: Colors.grey),
                            child:
                                Center(child: Text('Изображение отсутствует')),
                          ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  _shareLocation(context, location);
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      location.description,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                if (location.interestingFacts != null &&
                    location.interestingFacts!.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Интересные факты:',
                            style: TextStyle(
                                fontSize: 18.0, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            location.interestingFacts!,
                            style: const TextStyle(fontSize: 14.0),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Text('Интересные факты отсутствуют'),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
