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
  })  : dogs = dogs ?? [],
        lastCollectTime =
            lastCollectTime ?? DateTime.now().millisecondsSinceEpoch;

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
    );
  }

  static HabitatModel createDefaultGardenPark([int? now]) {
    final time = now ?? DateTime.now().millisecondsSinceEpoch;
    return HabitatModel(
      id: 'hab_starter_garden',
      type: 'habitat',
      habitatId: 'garden-park',
      name: 'Garden Park',
      col: 11,
      row: 9,
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
