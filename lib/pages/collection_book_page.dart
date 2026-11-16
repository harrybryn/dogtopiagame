import 'package:flutter/material.dart';

class CollectionBookPage extends StatelessWidget {
  final VoidCallback onBackToWorld;

  const CollectionBookPage({super.key, required this.onBackToWorld});

  @override
  Widget build(BuildContext context) {
    final breeds = [
      {
        'id': 1,
        'name': 'English Bulldog',
        'rarity': 'Starter Companion',
        'stage': 'Adult',
        'image': 'assets/dogs/BulldogPortrait.png',
        'habitat': 'Garden Park · Garden Element',
        'discovered': true,
        'desc': 'Affectionate, sturdy and loyal companion for every island trainer.',
      },
      {
        'id': 2,
        'name': 'Arctic Husky',
        'rarity': 'Frost Pup',
        'stage': 'Puppy',
        'image': 'assets/itemsInShop/dogs/HuskyPuppySit.png',
        'habitat': 'Snowy Peak · Snow Element',
        'discovered': true,
        'desc': 'Athletic, vocal, and affectionate snow dog who loves crisp breezes.',
      },
      {
        'id': 3,
        'name': 'Golden Retriever',
        'rarity': 'Coming Soon',
        'stage': 'Upcoming',
        'icon': Icons.lock,
        'habitat': 'Forest Meadow · Grass Element',
        'discovered': false,
        'desc': 'Gentle, friendly, and energetic retriever.',
      },
      {
        'id': 4,
        'name': 'Japanese Shiba',
        'rarity': 'Coming Soon',
        'stage': 'Upcoming',
        'icon': Icons.lock,
        'habitat': 'Garden Park · Garden Element',
        'discovered': false,
        'desc': 'Spirited, alert, and famously proud canine companion.',
      },
      {
        'id': 5,
        'name': 'German Shepherd',
        'rarity': 'Coming Soon',
        'stage': 'Upcoming',
        'icon': Icons.lock,
        'habitat': 'Desert Oasis · Warm Element',
        'discovered': false,
        'desc': 'Noble, courageous, and highly intelligent working companion.',
      },
      {
        'id': 6,
        'name': 'Galaxy Mythic Pup',
        'rarity': 'Astral Mythic',
        'stage': 'Upcoming',
        'icon': Icons.lock,
        'habitat': 'Legendary Realm · Celestial',
        'discovered': false,
        'desc': 'Ancient celestial canine glowing with stardust energy.',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF120601),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: onBackToWorld,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Island View',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xDD2A1106),
                      foregroundColor: const Color(0xFFFEF3C7),
                      side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Title Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1005),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD97706), width: 2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.menu_book, color: Colors.amber, size: 36),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dogtopia Collection Book',
                            style: TextStyle(
                              color: Color(0xFFFEF08A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Discover and collect all canine species across the floating islands!',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Breeds Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.75,
                ),
                itemCount: breeds.length,
                itemBuilder: (context, i) {
                  final b = breeds[i];
                  final discovered = b['discovered'] as bool;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: discovered
                          ? const Color(0xFF2B1206)
                          : const Color(0x77190701),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: discovered
                            ? const Color(0xFFD97706)
                            : const Color(0xFF451A03),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Avatar Circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF140501),
                            border: Border.all(
                              color: discovered ? Colors.amber : Colors.white24,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: discovered && b['image'] != null
                              ? Image.asset(b['image'] as String,
                                  fit: BoxFit.cover)
                              : Icon(b['icon'] as IconData? ?? Icons.lock,
                                  color: Colors.white30, size: 36),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          b['name'] as String,
                          style: TextStyle(
                            color: discovered
                                ? const Color(0xFFFEF3C7)
                                : Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b['rarity'] as String,
                          style: TextStyle(
                            color: discovered ? Colors.amber : Colors.white24,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          b['habitat'] as String,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
