import 'habitat_catalog.dart';
import 'habitat_model.dart';
import 'dog_model.dart';

/// A local, backend-free friend used by the mock "visit a friend" feature.
/// The friend owns its own habitat/dog instances so a visitor can never
/// mutate the player's island by accident.
class MockFriend {
  final String id;
  final String name;
  final String islandName;
  final String status;
  final int level;
  final List<HabitatModel> habitats;
  int helpCount;

  MockFriend({
    required this.id,
    required this.name,
    required this.islandName,
    required this.status,
    required this.level,
    required this.habitats,
    this.helpCount = 0,
  });

  List<DogModel> get dogs =>
      habitats.expand((habitat) => habitat.dogs).toList();

  int get habitatCount =>
      habitats.where((habitat) => habitat.type == 'habitat').length;

  String habitatAsset(HabitatModel habitat) {
    if (habitat.isFactory) {
      return 'assets/itemsInShop/building/DogfoodFactory.png';
    }
    for (final item in HabitatCatalog.habitats) {
      if (item.id == habitat.habitatId) return item.assetImage;
    }
    return 'assets/habitats/GardenHabitat.png';
  }

  static MockFriend sample() {
    final now = DateTime.now().millisecondsSinceEpoch;

    DogModel friendDog({
      required String id,
      required String breedId,
      required String name,
      required int level,
      required String habitatId,
      required String habitatName,
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

    return MockFriend(
      id: 'friend_alex',
      name: 'CanineKing_Alex',
      islandName: "Alex's Island",
      status: 'Online',
      level: 24,
      habitats: [
        HabitatModel(
          id: 'friend_garden',
          type: 'habitat',
          habitatId: 'garden-park',
          name: 'Sunny Garden',
          level: 8,
          col: 5,
          row: 13,
          maxCoins: 1000,
          dogs: [
            friendDog(
              id: 'friend_dog_golden',
              breedId: 'golden-retriever',
              name: 'Sunny',
              level: 5,
              feedProgress: 2,
              habitatId: 'friend_garden',
              habitatName: 'Sunny Garden',
            ),
            friendDog(
              id: 'friend_dog_bulldog',
              breedId: 'english-bulldog',
              name: 'Biscuit',
              level: 2,
              feedProgress: 1,
              habitatId: 'friend_garden',
              habitatName: 'Sunny Garden',
            ),
          ],
        ),
        HabitatModel(
          id: 'friend_oasis',
          type: 'habitat',
          habitatId: 'desert-oasis',
          name: 'Crystal Oasis',
          level: 6,
          col: 9,
          row: 11,
          maxCoins: 2500,
          dogs: [
            friendDog(
              id: 'friend_dog_pharaoh',
              breedId: 'pharaoh-hound',
              name: 'Cleo',
              level: 7,
              feedProgress: 3,
              habitatId: 'friend_oasis',
              habitatName: 'Crystal Oasis',
              element: 'Desert Element',
            ),
          ],
        ),
        HabitatModel(
          id: 'friend_bakery',
          type: 'facility',
          habitatId: 'dogfood-factory',
          name: "Alex's Bakery",
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
          col: 4,
          row: 16,
          sizeW: 1,
          sizeH: 1,
        ),
      ],
    );
  }
}
