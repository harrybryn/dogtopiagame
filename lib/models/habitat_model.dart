import 'dog_model.dart';

class HabitatModel {
  final String id;
  final String type; // 'habitat' | 'facility' | 'decor'
  final String habitatId; // e.g. 'garden-park', 'desert-oasis', 'breeding-den'
  String name;
  int level;
  int col;
  int row;
  final int sizeW;
  final int sizeH;
  List<DogModel> dogs;
  int coinsAccumulated;
  final int maxCoins;
  bool readyToCollect;
  int dogfoodAccumulated;
  final int maxDogfood;
  bool readyToCollectDogfood;
  int lastCollectTime;
  bool underConstruction;
  int constructionDuration;
  int? constructionEndsAt;
  String? bakingRecipeId;
  String? bakingRecipeName;
  int? bakingFoodAmount;
  int? bakingXpReward;
  int? bakingCostCoins;
  int? bakingDurationSeconds;
  int? bakingStartedAt;
  int? bakingEndsAt;

  HabitatModel({
    required this.id,
    this.type = 'habitat',
    required this.habitatId,
    required this.name,
    this.level = 1,
    required this.col,
    required this.row,
    this.sizeW = 3,
    this.sizeH = 3,
    List<DogModel>? dogs,
    this.coinsAccumulated = 0,
    this.maxCoins = 1000,
    this.readyToCollect = false,
    this.dogfoodAccumulated = 0,
    this.maxDogfood = 0,
    this.readyToCollectDogfood = false,
    int? lastCollectTime,
    this.underConstruction = false,
    this.constructionDuration = 0,
    this.constructionEndsAt,
    this.bakingRecipeId,
    this.bakingRecipeName,
    this.bakingFoodAmount,
    this.bakingXpReward,
    this.bakingCostCoins,
    this.bakingDurationSeconds,
    this.bakingStartedAt,
    this.bakingEndsAt,
  })  : dogs = dogs ?? [],
        lastCollectTime =
            lastCollectTime ?? DateTime.now().millisecondsSinceEpoch;

  bool get isFactory =>
      habitatId == 'dogfood-factory' ||
      name.toLowerCase().contains('factory') ||
      name.toLowerCase().contains('bakery');

  bool get isBaking =>
      isFactory && bakingEndsAt != null && !isBakingFinished;

  bool get isBakingFinished {
    if (!isFactory || bakingEndsAt == null) return false;
    return DateTime.now().millisecondsSinceEpoch >= bakingEndsAt!;
  }

  int get bakingRemainingSeconds {
    if (bakingEndsAt == null) return 0;
    final diff = bakingEndsAt! - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  double get bakingProgress {
    if (bakingStartedAt == null || bakingEndsAt == null) return 0.0;
    final total = bakingEndsAt! - bakingStartedAt!;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - bakingStartedAt!;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String get insideAsset {
    final hid = habitatId.toLowerCase();
    final hname = name.toLowerCase();
    if (hid.contains('factory') ||
        hid.contains('bakery') ||
        hname.contains('factory') ||
        hname.contains('bakery')) {
      return 'assets/itemsInShop/building/DogfoodFactoryInsideView.png';
    }
    if (hid.contains('oasis') ||
        hid.contains('desert') ||
        hname.contains('oasis') ||
        hname.contains('desert')) {
      return 'assets/habitats/OasisHabitatInside.png';
    }
    if (hid.contains('forest') ||
        hid.contains('meadow') ||
        hname.contains('forest') ||
        hname.contains('meadow')) {
      return 'assets/habitats/ForestHabitatInside.png';
    }
    if (hid.contains('snow') ||
        hid.contains('peak') ||
        hid.contains('frost') ||
        hname.contains('snow') ||
        hname.contains('peak') ||
        hname.contains('frost')) {
      return 'assets/habitats/SnowHabitatInside.png';
    }
    if (hid.contains('beach') ||
        hid.contains('cove') ||
        hname.contains('beach') ||
        hname.contains('cove')) {
      return 'assets/habitats/BeachHabitatInside.png';
    }
    if (hid.contains('legend') ||
        hid.contains('realm') ||
        hid.contains('astral') ||
        hid.contains('celestial') ||
        hname.contains('legend') ||
        hname.contains('realm')) {
      return 'assets/habitats/LegendaryHabitatInside.png';
    }
    return 'assets/habitats/GardenHabitatInside.png';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'habitatId': habitatId,
        'name': name,
        'level': level,
        'col': col,
        'row': row,
        'sizeW': sizeW,
        'sizeH': sizeH,
        'dogs': dogs.map((d) => d.toJson()).toList(),
        'coinsAccumulated': coinsAccumulated,
        'maxCoins': maxCoins,
        'readyToCollect': readyToCollect,
        'dogfoodAccumulated': dogfoodAccumulated,
        'maxDogfood': maxDogfood,
        'readyToCollectDogfood': readyToCollectDogfood,
        'lastCollectTime': lastCollectTime,
        'underConstruction': underConstruction,
        'constructionDuration': constructionDuration,
        'constructionEndsAt': constructionEndsAt,
        'bakingRecipeId': bakingRecipeId,
        'bakingRecipeName': bakingRecipeName,
        'bakingFoodAmount': bakingFoodAmount,
        'bakingXpReward': bakingXpReward,
        'bakingCostCoins': bakingCostCoins,
        'bakingDurationSeconds': bakingDurationSeconds,
        'bakingStartedAt': bakingStartedAt,
        'bakingEndsAt': bakingEndsAt,
      };

  factory HabitatModel.fromJson(Map<String, dynamic> json) {
    final rawDogs = json['dogs'] as List<dynamic>? ?? [];
    final dogsList = rawDogs
        .map((d) => DogModel.fromJson(d as Map<String, dynamic>))
        .toList();

    return HabitatModel(
      id: json['id'] as String? ?? 'hab_${DateTime.now().millisecondsSinceEpoch}',
      type: json['type'] as String? ?? 'habitat',
      habitatId: json['habitatId'] as String? ?? 'garden-park',
      name: json['name'] as String? ?? 'Garden Park',
      level: json['level'] as int? ?? 1,
      col: json['col'] as int? ?? 11,
      row: json['row'] as int? ?? 9,
      sizeW: json['sizeW'] as int? ?? 3,
      sizeH: json['sizeH'] as int? ?? 3,
      dogs: dogsList,
      coinsAccumulated: json['coinsAccumulated'] as int? ?? 0,
      maxCoins: json['maxCoins'] as int? ?? 1000,
      readyToCollect: json['readyToCollect'] as bool? ?? false,
      dogfoodAccumulated: json['dogfoodAccumulated'] as int? ?? 0,
      maxDogfood: json['maxDogfood'] as int? ?? 0,
      readyToCollectDogfood: json['readyToCollectDogfood'] as bool? ?? false,
      lastCollectTime: json['lastCollectTime'] as int?,
      underConstruction: json['underConstruction'] as bool? ?? false,
      constructionDuration: json['constructionDuration'] as int? ?? 0,
      constructionEndsAt: json['constructionEndsAt'] as int?,
      bakingRecipeId: json['bakingRecipeId'] as String?,
      bakingRecipeName: json['bakingRecipeName'] as String?,
      bakingFoodAmount: json['bakingFoodAmount'] as int?,
      bakingXpReward: json['bakingXpReward'] as int?,
      bakingCostCoins: json['bakingCostCoins'] as int?,
      bakingDurationSeconds: json['bakingDurationSeconds'] as int?,
      bakingStartedAt: json['bakingStartedAt'] as int?,
      bakingEndsAt: json['bakingEndsAt'] as int?,
    );
  }

  static HabitatModel createDefaultDogfoodFactory([int? now]) {
    final time = now ?? DateTime.now().millisecondsSinceEpoch;
    return HabitatModel(
      id: 'hab_starter_factory',
      type: 'facility',
      habitatId: 'dogfood-factory',
      name: 'Dogfood Factory',
      col: 9,
      row: 13,
      sizeW: 3,
      sizeH: 3,
      maxDogfood: 50000,
      dogfoodAccumulated: 0,
      readyToCollectDogfood: false,
      lastCollectTime: time,
      underConstruction: false,
    );
  }

  static HabitatModel createDefaultGardenPark([int? now]) {
    final time = now ?? DateTime.now().millisecondsSinceEpoch;
    return HabitatModel(
      id: 'hab_starter_garden',
      type: 'habitat',
      habitatId: 'garden-park',
      name: 'Garden Park',
      col: 5,
      row: 13,
      sizeW: 3,
      sizeH: 3,
      maxCoins: 1000,
      coinsAccumulated: 0,
      readyToCollect: false,
      lastCollectTime: time,
      underConstruction: false,
      dogs: [
        DogModel(
          id: 'dog_starter_bulldog',
          breedId: 'english-bulldog',
          name: 'Winston',
          level: 1,
          feedProgress: 0,
          feedRequired: 4,
          stage: 'Puppy',
          element: 'Garden Element',
          habitatId: 'hab_starter_garden',
          habitatName: 'Garden Park',
          adoptedAt: time,
        ),
      ],
    );
  }
}
