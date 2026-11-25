import 'dog_model.dart';
import 'habitat_catalog.dart';
import 'habitat_model.dart';
import 'island_model.dart';
import 'obstacle_model.dart';

/// A local, backend-free friend used by the mock "visit a friend" feature.
/// The friend owns its own habitat/dog instances so a visitor can never
/// mutate the player's island by accident.
class MockFriend {
  final String id;
  final String name;
  final String islandName;
  final String status;
  final int level;
  final String favoriteDog;
  final List<HabitatModel> habitats;
  final Set<String> unlockedIslandIds;
  final Map<String, Set<int>> unlockedLotsByIsland;
  final Map<String, List<ObstacleModel>> obstaclesByIsland;
  int helpCount;

  MockFriend({
    required this.id,
    required this.name,
    required this.islandName,
    required this.status,
    required this.level,
    this.favoriteDog = 'Golden Retriever',
    required this.habitats,
    Set<String>? unlockedIslandIds,
    Map<String, Set<int>>? unlockedLotsByIsland,
    Map<String, List<ObstacleModel>>? obstaclesByIsland,
    this.helpCount = 0,
  })  : unlockedIslandIds =
            unlockedIslandIds ?? {IslandCatalog.starterIslandId},
        unlockedLotsByIsland = unlockedLotsByIsland ??
            {
              IslandCatalog.starterIslandId: {1, 2},
            },
        obstaclesByIsland = obstaclesByIsland ?? {};

  List<DogModel> get dogs =>
      habitats.expand((habitat) => habitat.dogs).toList();

  int get habitatCount =>
      habitats.where((habitat) => habitat.type == 'habitat').length;

  int get unlockedIslandCount => unlockedIslandIds.length;

  bool isIslandUnlocked(String islandId) =>
      unlockedIslandIds.contains(islandId);

  List<HabitatModel> habitatsForIsland(String islandId) =>
      habitats.where((h) => h.islandId == islandId).toList();

  bool isLotUnlockedForIsland(String islandId, int lotNumber) =>
      unlockedLotsByIsland[islandId]?.contains(lotNumber) ?? false;

  List<ObstacleModel> obstaclesForIsland(String islandId) =>
      obstaclesByIsland.putIfAbsent(
        islandId,
        () => ObstacleModel.defaultObstacles(),
      );

  String habitatAsset(HabitatModel habitat) {
    if (habitat.isFactory) {
      return 'assets/itemsInShop/building/DogfoodFactory.png';
    }
    for (final item in HabitatCatalog.habitats) {
      if (item.id == habitat.habitatId) return item.assetImage;
    }
    return 'assets/habitats/GardenHabitat.png';
  }

  static DogModel _friendDog({
    required String id,
    required String breedId,
    required String name,
    required int level,
    required String habitatId,
    required String habitatName,
    required int now,
    int feedProgress = 0,
    String element = 'Garden Element',
  }) {
    return DogModel(
      id: id,
      breedId: breedId,
      name: name,
      level: level,
      feedProgress: feedProgress,
      feedRequired: 4,
      stage: level >= 12 ? 'Adult' : (level >= 4 ? 'Young' : 'Puppy'),
      element: element,
      habitatId: habitatId,
      habitatName: habitatName,
      adoptedAt: now,
    );
  }

  static MockFriend sample() => allFriends().first;

  static List<MockFriend> allFriends() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      _buildAlex(now),
      _buildMia(now),
      _buildZack(now),
      _buildLeo(now),
    ];
  }

  static MockFriend _buildAlex(int now) {
    return MockFriend(
      id: 'friend_alex',
      name: 'CanineKing_Alex',
      islandName: "Alex's Island",
      status: 'Online',
      level: 24,
      favoriteDog: 'Astral Hound',
      unlockedIslandIds: {
        IslandCatalog.starterIslandId,
        IslandCatalog.desertIslandId,
        IslandCatalog.iceIslandId,
        IslandCatalog.forestIslandId,
        IslandCatalog.beachIslandId,
        IslandCatalog.legendaryIslandId,
      },
      unlockedLotsByIsland: {
        IslandCatalog.starterIslandId: {1, 2},
        IslandCatalog.desertIslandId: {1, 2},
        IslandCatalog.iceIslandId: {1},
        IslandCatalog.forestIslandId: {1, 2},
        IslandCatalog.beachIslandId: {1},
        IslandCatalog.legendaryIslandId: {1},
      },
      obstaclesByIsland: {
        IslandCatalog.starterIslandId: [],
        IslandCatalog.desertIslandId: [],
      },
      habitats: [
        // Meadow (starter)
        HabitatModel(
          id: 'friend_garden',
          type: 'habitat',
          habitatId: 'garden-park',
          name: 'Sunny Garden',
          islandId: IslandCatalog.starterIslandId,
          level: 8,
          col: 5,
          row: 13,
          maxCoins: 1000,
          dogs: [
            _friendDog(
              id: 'friend_dog_golden',
              breedId: 'golden-retriever',
              name: 'Sunny',
              level: 5,
              feedProgress: 2,
              habitatId: 'friend_garden',
              habitatName: 'Sunny Garden',
              now: now,
            ),
            _friendDog(
              id: 'friend_dog_bulldog',
              breedId: 'english-bulldog',
              name: 'Biscuit',
              level: 2,
              feedProgress: 1,
              habitatId: 'friend_garden',
              habitatName: 'Sunny Garden',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'friend_oasis',
          type: 'habitat',
          habitatId: 'desert-oasis',
          name: 'Crystal Oasis',
          islandId: IslandCatalog.starterIslandId,
          level: 6,
          col: 9,
          row: 11,
          maxCoins: 2500,
          dogs: [
            _friendDog(
              id: 'friend_dog_pharaoh',
              breedId: 'pharaoh-hound',
              name: 'Cleo',
              level: 7,
              feedProgress: 3,
              habitatId: 'friend_oasis',
              habitatName: 'Crystal Oasis',
              element: 'Desert Element',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'friend_bakery',
          type: 'facility',
          habitatId: 'dogfood-factory',
          name: "Alex's Bakery",
          islandId: IslandCatalog.starterIslandId,
          level: 4,
          col: 12,
          row: 14,
          maxDogfood: 50000,
        ),
        HabitatModel(
          id: 'friend_water',
          type: 'facility',
          habitatId: 'water-station',
          name: 'Water Station',
          islandId: IslandCatalog.starterIslandId,
          level: 3,
          col: 3,
          row: 10,
          sizeW: 2,
          sizeH: 2,
        ),
        HabitatModel(
          id: 'friend_palm_1',
          type: 'decor',
          habitatId: 'golden-palm',
          name: 'Golden Palm',
          islandId: IslandCatalog.starterIslandId,
          col: 7,
          row: 9,
          sizeW: 1,
          sizeH: 1,
        ),
        HabitatModel(
          id: 'friend_palm_2',
          type: 'decor',
          habitatId: 'golden-palm',
          name: 'Golden Palm',
          islandId: IslandCatalog.starterIslandId,
          col: 11,
          row: 9,
          sizeW: 1,
          sizeH: 1,
        ),
        HabitatModel(
          id: 'friend_sign',
          type: 'decor',
          habitatId: 'bone-sign',
          name: 'Bone Sign',
          islandId: IslandCatalog.starterIslandId,
          col: 4,
          row: 16,
          sizeW: 1,
          sizeH: 1,
        ),

        // Desert island
        HabitatModel(
          id: 'alex_desert_oasis',
          type: 'habitat',
          habitatId: 'desert-oasis',
          name: 'Dune Mirage',
          islandId: IslandCatalog.desertIslandId,
          level: 9,
          col: 7,
          row: 12,
          maxCoins: 2800,
          dogs: [
            _friendDog(
              id: 'alex_dog_anubis',
              breedId: 'pharaoh-hound',
              name: 'Anubis',
              level: 13,
              feedProgress: 1,
              habitatId: 'alex_desert_oasis',
              habitatName: 'Dune Mirage',
              element: 'Desert Element',
              now: now,
            ),
            _friendDog(
              id: 'alex_dog_rex',
              breedId: 'german-shepherd',
              name: 'Rex',
              level: 8,
              feedProgress: 2,
              habitatId: 'alex_desert_oasis',
              habitatName: 'Dune Mirage',
              element: 'Desert Element',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'alex_desert_palm',
          type: 'decor',
          habitatId: 'golden-palm',
          name: 'Golden Palm',
          islandId: IslandCatalog.desertIslandId,
          col: 12,
          row: 12,
          sizeW: 1,
          sizeH: 1,
        ),

        // Ice island
        HabitatModel(
          id: 'alex_ice_peak',
          type: 'habitat',
          habitatId: 'snowy-peak',
          name: 'Glacier Lodge',
          islandId: IslandCatalog.iceIslandId,
          level: 7,
          col: 8,
          row: 13,
          maxCoins: 3200,
          dogs: [
            _friendDog(
              id: 'alex_dog_blizzard',
              breedId: 'arctic-husky',
              name: 'Blizzard',
              level: 10,
              feedProgress: 3,
              habitatId: 'alex_ice_peak',
              habitatName: 'Glacier Lodge',
              element: 'Snow Element',
              now: now,
            ),
            _friendDog(
              id: 'alex_dog_cloud',
              breedId: 'white-samoyed',
              name: 'Cloud',
              level: 6,
              feedProgress: 0,
              habitatId: 'alex_ice_peak',
              habitatName: 'Glacier Lodge',
              element: 'Snow Element',
              now: now,
            ),
          ],
        ),

        // Forest island
        HabitatModel(
          id: 'alex_forest_grove',
          type: 'habitat',
          habitatId: 'forest-meadow',
          name: 'Whispering Grove',
          islandId: IslandCatalog.forestIslandId,
          level: 6,
          col: 6,
          row: 12,
          maxCoins: 2600,
          dogs: [
            _friendDog(
              id: 'alex_dog_mochi',
              breedId: 'shiba-inu',
              name: 'Mochi',
              level: 9,
              feedProgress: 2,
              habitatId: 'alex_forest_grove',
              habitatName: 'Whispering Grove',
              element: 'Forest Element',
              now: now,
            ),
          ],
        ),

        // Beach island
        HabitatModel(
          id: 'alex_beach_cove',
          type: 'habitat',
          habitatId: 'beach-cove',
          name: 'Coral Cove',
          islandId: IslandCatalog.beachIslandId,
          level: 5,
          col: 9,
          row: 13,
          maxCoins: 3000,
          dogs: [
            _friendDog(
              id: 'alex_dog_splash',
              breedId: 'labrador',
              name: 'Splash',
              level: 7,
              feedProgress: 1,
              habitatId: 'alex_beach_cove',
              habitatName: 'Coral Cove',
              element: 'Beach Element',
              now: now,
            ),
          ],
        ),

        // Legendary island
        HabitatModel(
          id: 'alex_legendary_realm',
          type: 'habitat',
          habitatId: 'legendary-realm',
          name: 'Starlight Spire',
          islandId: IslandCatalog.legendaryIslandId,
          level: 10,
          col: 8,
          row: 12,
          maxCoins: 5000,
          dogs: [
            _friendDog(
              id: 'alex_dog_nova',
              breedId: 'astral-hound',
              name: 'Nova',
              level: 14,
              feedProgress: 2,
              habitatId: 'alex_legendary_realm',
              habitatName: 'Starlight Spire',
              element: 'Astral Element',
              now: now,
            ),
            _friendDog(
              id: 'alex_dog_chronos',
              breedId: 'chronos-dog',
              name: 'Chrono',
              level: 12,
              feedProgress: 1,
              habitatId: 'alex_legendary_realm',
              habitatName: 'Starlight Spire',
              element: 'Astral Element',
              now: now,
            ),
          ],
        ),
      ],
    );
  }

  static MockFriend _buildMia(int now) {
    return MockFriend(
      id: 'friend_mia',
      name: 'PupWhisperer_Mia',
      islandName: "Mia's Haven",
      status: 'Visiting Park',
      level: 19,
      favoriteDog: 'White Samoyed',
      unlockedIslandIds: {
        IslandCatalog.starterIslandId,
        IslandCatalog.desertIslandId,
        IslandCatalog.iceIslandId,
        IslandCatalog.forestIslandId,
      },
      unlockedLotsByIsland: {
        IslandCatalog.starterIslandId: {1, 2},
        IslandCatalog.desertIslandId: {1},
        IslandCatalog.iceIslandId: {1, 2},
        IslandCatalog.forestIslandId: {},
      },
      obstaclesByIsland: {
        IslandCatalog.starterIslandId: [],
      },
      habitats: [
        HabitatModel(
          id: 'mia_garden',
          type: 'habitat',
          habitatId: 'garden-park',
          name: 'Blossom Yard',
          islandId: IslandCatalog.starterIslandId,
          level: 7,
          col: 6,
          row: 12,
          maxCoins: 1200,
          dogs: [
            _friendDog(
              id: 'mia_dog_pug',
              breedId: 'pug',
              name: 'Pudge',
              level: 6,
              feedProgress: 1,
              habitatId: 'mia_garden',
              habitatName: 'Blossom Yard',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'mia_ice_lodge',
          type: 'habitat',
          habitatId: 'snowy-peak',
          name: 'Frosty Retreat',
          islandId: IslandCatalog.iceIslandId,
          level: 8,
          col: 7,
          row: 12,
          maxCoins: 2800,
          dogs: [
            _friendDog(
              id: 'mia_dog_flurry',
              breedId: 'white-samoyed',
              name: 'Flurry',
              level: 12,
              feedProgress: 2,
              habitatId: 'mia_ice_lodge',
              habitatName: 'Frosty Retreat',
              element: 'Snow Element',
              now: now,
            ),
            _friendDog(
              id: 'mia_dog_koda',
              breedId: 'arctic-husky',
              name: 'Koda',
              level: 8,
              feedProgress: 0,
              habitatId: 'mia_ice_lodge',
              habitatName: 'Frosty Retreat',
              element: 'Snow Element',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'mia_desert_camp',
          type: 'habitat',
          habitatId: 'desert-oasis',
          name: 'Sandstone Oasis',
          islandId: IslandCatalog.desertIslandId,
          level: 4,
          col: 8,
          row: 13,
          maxCoins: 1800,
          dogs: [
            _friendDog(
              id: 'mia_dog_shep',
              breedId: 'german-shepherd',
              name: 'Scout',
              level: 5,
              feedProgress: 3,
              habitatId: 'mia_desert_camp',
              habitatName: 'Sandstone Oasis',
              element: 'Desert Element',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'mia_forest_den',
          type: 'habitat',
          habitatId: 'forest-meadow',
          name: 'Mossy Hollow',
          islandId: IslandCatalog.forestIslandId,
          level: 5,
          col: 9,
          row: 13,
          maxCoins: 2100,
          dogs: [
            _friendDog(
              id: 'mia_dog_bagel',
              breedId: 'beagle',
              name: 'Bagel',
              level: 4,
              feedProgress: 1,
              habitatId: 'mia_forest_den',
              habitatName: 'Mossy Hollow',
              element: 'Forest Element',
              now: now,
            ),
          ],
        ),
      ],
    );
  }

  static MockFriend _buildZack(int now) {
    return MockFriend(
      id: 'friend_zack',
      name: 'DesertWolf_Zack',
      islandName: "Zack's Dunes",
      status: 'Offline',
      level: 15,
      favoriteDog: 'Pharaoh Hound',
      unlockedIslandIds: {
        IslandCatalog.starterIslandId,
        IslandCatalog.desertIslandId,
        IslandCatalog.beachIslandId,
      },
      unlockedLotsByIsland: {
        IslandCatalog.starterIslandId: {1},
        IslandCatalog.desertIslandId: {1, 2},
        IslandCatalog.beachIslandId: {},
      },
      habitats: [
        HabitatModel(
          id: 'zack_meadow',
          type: 'habitat',
          habitatId: 'garden-park',
          name: 'Canyon Outpost',
          islandId: IslandCatalog.starterIslandId,
          level: 5,
          col: 7,
          row: 13,
          maxCoins: 900,
          dogs: [
            _friendDog(
              id: 'zack_dog_tank',
              breedId: 'english-bulldog',
              name: 'Tank',
              level: 4,
              feedProgress: 2,
              habitatId: 'zack_meadow',
              habitatName: 'Canyon Outpost',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'zack_desert',
          type: 'habitat',
          habitatId: 'desert-oasis',
          name: 'Pharaoh Temple',
          islandId: IslandCatalog.desertIslandId,
          level: 8,
          col: 6,
          row: 12,
          maxCoins: 2600,
          dogs: [
            _friendDog(
              id: 'zack_dog_ra',
              breedId: 'pharaoh-hound',
              name: 'Ra',
              level: 11,
              feedProgress: 1,
              habitatId: 'zack_desert',
              habitatName: 'Pharaoh Temple',
              element: 'Desert Element',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'zack_beach',
          type: 'habitat',
          habitatId: 'beach-cove',
          name: 'Sunburn Bay',
          islandId: IslandCatalog.beachIslandId,
          level: 4,
          col: 8,
          row: 13,
          maxCoins: 2000,
          dogs: [
            _friendDog(
              id: 'zack_dog_marley',
              breedId: 'golden-retriever',
              name: 'Marley',
              level: 5,
              feedProgress: 2,
              habitatId: 'zack_beach',
              habitatName: 'Sunburn Bay',
              element: 'Beach Element',
              now: now,
            ),
          ],
        ),
      ],
    );
  }

  static MockFriend _buildLeo(int now) {
    return MockFriend(
      id: 'friend_leo',
      name: 'IslandPaws_Leo',
      islandName: "Leo's Cove",
      status: 'Online',
      level: 11,
      favoriteDog: 'Golden Retriever',
      unlockedIslandIds: {
        IslandCatalog.starterIslandId,
        IslandCatalog.desertIslandId,
      },
      unlockedLotsByIsland: {
        IslandCatalog.starterIslandId: {1},
        IslandCatalog.desertIslandId: {},
      },
      habitats: [
        HabitatModel(
          id: 'leo_garden',
          type: 'habitat',
          habitatId: 'garden-park',
          name: 'Clover Patch',
          islandId: IslandCatalog.starterIslandId,
          level: 4,
          col: 6,
          row: 12,
          maxCoins: 800,
          dogs: [
            _friendDog(
              id: 'leo_dog_buddy',
              breedId: 'golden-retriever',
              name: 'Buddy',
              level: 4,
              feedProgress: 1,
              habitatId: 'leo_garden',
              habitatName: 'Clover Patch',
              now: now,
            ),
          ],
        ),
        HabitatModel(
          id: 'leo_desert',
          type: 'habitat',
          habitatId: 'desert-oasis',
          name: 'Oasis Camp',
          islandId: IslandCatalog.desertIslandId,
          level: 3,
          col: 9,
          row: 13,
          maxCoins: 1400,
          dogs: [
            _friendDog(
              id: 'leo_dog_kobe',
              breedId: 'shiba-inu',
              name: 'Kobe',
              level: 3,
              feedProgress: 2,
              habitatId: 'leo_desert',
              habitatName: 'Oasis Camp',
              element: 'Desert Element',
              now: now,
            ),
          ],
        ),
      ],
    );
  }
}
