class DogModel {
  final String id;
  final String breedId;
  String name;
  int level;
  int feedProgress; // 0 to 3 (4 feeds per level)
  final int feedRequired;
  String stage; // 'Puppy' | 'Young' | 'Adult'
  final String element;
  String habitatId;
  String habitatName;
  final int adoptedAt;
  int lastBathedAt;

  static const int bathIntervalMs = 2 * 24 * 60 * 60 * 1000; // 2 days

  bool get isPuppy => stage == 'Puppy';
  bool get isYoung => stage == 'Young';
  bool get isAdult => stage == 'Adult';
  bool get isDirty =>
      (DateTime.now().millisecondsSinceEpoch - lastBathedAt) >= bathIntervalMs;

  DogModel({
    required this.id,
    required this.breedId,
    required this.name,
    this.level = 1,
    this.feedProgress = 0,
    this.feedRequired = 4,
    this.stage = 'Puppy',
    this.element = 'Garden Element',
    required this.habitatId,
    required this.habitatName,
    int? adoptedAt,
    int? lastBathedAt,
  }) : adoptedAt = adoptedAt ?? DateTime.now().millisecondsSinceEpoch,
       lastBathedAt = lastBathedAt ?? 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'breedId': breedId,
        'name': name,
        'level': level,
        'feedProgress': feedProgress,
        'feedRequired': feedRequired,
        'stage': stage,
        'element': element,
        'habitatId': habitatId,
        'habitatName': habitatName,
        'adoptedAt': adoptedAt,
        'lastBathedAt': lastBathedAt,
      };

  factory DogModel.fromJson(Map<String, dynamic> json) {
    final lvl = json['level'] as int? ?? 1;
    final stageStr = lvl >= 12 ? 'Adult' : (lvl >= 4 ? 'Young' : 'Puppy');
    return DogModel(
      id: json['id'] as String? ?? 'dog_${DateTime.now().millisecondsSinceEpoch}',
      breedId: json['breedId'] as String? ?? 'english-bulldog',
      name: json['name'] as String? ?? 'Winston',
      level: lvl,
      feedProgress: json['feedProgress'] as int? ?? 0,
      feedRequired: json['feedRequired'] as int? ?? 4,
      stage: json['stage'] as String? ?? stageStr,
      element: json['element'] as String? ?? 'Garden Element',
      habitatId: json['habitatId'] as String? ?? 'hab_starter_garden',
      habitatName: json['habitatName'] as String? ?? 'Garden Park',
      adoptedAt: json['adoptedAt'] as int?,
      lastBathedAt: json['lastBathedAt'] as int?,
    );
  }
}
