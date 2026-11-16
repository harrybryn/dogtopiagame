class ObstacleModel {
  final String id;
  final String type;
  final String name;
  final int col;
  final int row;
  final int sizeW;
  final int sizeH;
  final int clearCost; // Paw coins to clear
  final int clearDuration; // Seconds to clear
  final int xpReward;
  final String imageAsset;
  bool isClearing;
  int? clearingEndsAt;

  ObstacleModel({
    required this.id,
    required this.type,
    required this.name,
    required this.col,
    required this.row,
    this.sizeW = 1,
    this.sizeH = 1,
    this.clearCost = 150,
    this.clearDuration = 10,
    this.xpReward = 20,
    required this.imageAsset,
    this.isClearing = false,
    this.clearingEndsAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'col': col,
        'row': row,
        'sizeW': sizeW,
        'sizeH': sizeH,
        'clearCost': clearCost,
        'clearDuration': clearDuration,
        'xpReward': xpReward,
        'imageAsset': imageAsset,
        'isClearing': isClearing,
        'clearingEndsAt': clearingEndsAt,
      };

  factory ObstacleModel.fromJson(Map<String, dynamic> json) => ObstacleModel(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'rock',
        name: json['name'] as String? ?? 'Rock Obstacle',
        col: json['col'] as int? ?? 5,
        row: json['row'] as int? ?? 5,
        sizeW: json['sizeW'] as int? ?? 1,
        sizeH: json['sizeH'] as int? ?? 1,
        clearCost: json['clearCost'] as int? ?? 150,
        clearDuration: json['clearDuration'] as int? ?? 10,
        xpReward: json['xpReward'] as int? ?? 20,
        imageAsset: json['imageAsset'] as String? ?? 'assets/ui/RockObstacle.png',
        isClearing: json['isClearing'] as bool? ?? false,
        clearingEndsAt: json['clearingEndsAt'] as int?,
      );

  static List<ObstacleModel> defaultObstacles() {
    return [
      // ── Unlocked Western Lot Obstacles (Col < 14) ──
      ObstacleModel(
        id: 'obs_rock_1',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 6,
        row: 8,
        sizeW: 1,
        sizeH: 1,
        clearCost: 150,
        clearDuration: 8,
        xpReward: 20,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_tree_1',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 8,
        row: 14,
        sizeW: 1,
        sizeH: 1,
        clearCost: 200,
        clearDuration: 10,
        xpReward: 25,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_treerock_1',
        type: 'tree_rock',
        name: 'Rocky Grove',
        col: 5,
        row: 11,
        sizeW: 2,
        sizeH: 2,
        clearCost: 400,
        clearDuration: 16,
        xpReward: 45,
        imageAsset: 'assets/ui/TreeAndRocksObstacle.png',
      ),

      // ── Locked Eastern Lot Obstacles (Col >= 14) ──
      ObstacleModel(
        id: 'obs_rock_2',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 15,
        row: 7,
        sizeW: 1,
        sizeH: 1,
        clearCost: 250,
        clearDuration: 12,
        xpReward: 30,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_many_1',
        type: 'many',
        name: 'Overgrown Thicket',
        col: 17,
        row: 13,
        sizeW: 2,
        sizeH: 2,
        clearCost: 600,
        clearDuration: 22,
        xpReward: 65,
        imageAsset: 'assets/ui/ManyObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_tree_2',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 19,
        row: 9,
        sizeW: 1,
        sizeH: 1,
        clearCost: 300,
        clearDuration: 14,
        xpReward: 35,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_treerock_2',
        type: 'tree_rock',
        name: 'Rocky Grove',
        col: 20,
        row: 12,
        sizeW: 2,
        sizeH: 2,
        clearCost: 500,
        clearDuration: 18,
        xpReward: 50,
        imageAsset: 'assets/ui/TreeAndRocksObstacle.png',
      ),
    ];
  }
}
