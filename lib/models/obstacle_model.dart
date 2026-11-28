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
      // ── Lot 1 Obstacles (Top-left: Col < 13, Row < 11) ──
      ObstacleModel(
        id: 'obs_rock_1',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 8,
        row: 4,
        sizeW: 1,
        sizeH: 1,
        clearCost: 150,
        clearDuration: 25,
        xpReward: 20,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_tree_1',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 4,
        row: 5,
        sizeW: 1,
        sizeH: 1,
        clearCost: 200,
        clearDuration: 35,
        xpReward: 25,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_treerock_lot1_1',
        type: 'tree_rock',
        name: 'Rocky Grove',
        col: 10,
        row: 7,
        sizeW: 2,
        sizeH: 2,
        clearCost: 350,
        clearDuration: 60,
        xpReward: 40,
        imageAsset: 'assets/ui/TreeAndRocksObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_rock_lot1_2',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 7,
        row: 6,
        sizeW: 1,
        sizeH: 1,
        clearCost: 180,
        clearDuration: 30,
        xpReward: 22,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_tree_lot1_2',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 10,
        row: 4,
        sizeW: 1,
        sizeH: 1,
        clearCost: 220,
        clearDuration: 42,
        xpReward: 28,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),

      // ── Lot 2 Obstacles (Top-right: Col >= 13, Row < 11) ──
      ObstacleModel(
        id: 'obs_tree_2',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 17,
        row: 2,
        sizeW: 1,
        sizeH: 1,
        clearCost: 300,
        clearDuration: 55,
        xpReward: 35,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_treerock_2',
        type: 'tree_rock',
        name: 'Rocky Grove',
        col: 21,
        row: 4,
        sizeW: 2,
        sizeH: 2,
        clearCost: 500,
        clearDuration: 110,
        xpReward: 55,
        imageAsset: 'assets/ui/TreeAndRocksObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_rock_3',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 15,
        row: 6,
        sizeW: 1,
        sizeH: 1,
        clearCost: 350,
        clearDuration: 50,
        xpReward: 40,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_tree_3',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 23,
        row: 7,
        sizeW: 1,
        sizeH: 1,
        clearCost: 400,
        clearDuration: 65,
        xpReward: 45,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_rock_lot2_2',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 19,
        row: 8,
        sizeW: 1,
        sizeH: 1,
        clearCost: 280,
        clearDuration: 45,
        xpReward: 32,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_treerock_lot2_2',
        type: 'tree_rock',
        name: 'Rocky Grove',
        col: 14,
        row: 3,
        sizeW: 2,
        sizeH: 2,
        clearCost: 450,
        clearDuration: 90,
        xpReward: 50,
        imageAsset: 'assets/ui/TreeAndRocksObstacle.png',
      ),

      // ── Extra Lot 1 Obstacles (4 more, avoiding ForSale sign at col 5-6, row 3-5) ──
      ObstacleModel(
        id: 'obs_rock_lot1_extra1',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 6,
        row: 8,
        sizeW: 1,
        sizeH: 1,
        clearCost: 160,
        clearDuration: 28,
        xpReward: 20,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_tree_lot1_extra2',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 9,
        row: 8,
        sizeW: 1,
        sizeH: 1,
        clearCost: 220,
        clearDuration: 40,
        xpReward: 26,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_treerock_lot1_extra3',
        type: 'tree_rock',
        name: 'Rocky Grove',
        col: 3,
        row: 6,
        sizeW: 2,
        sizeH: 2,
        clearCost: 340,
        clearDuration: 75,
        xpReward: 38,
        imageAsset: 'assets/ui/TreeAndRocksObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_rock_lot1_extra4',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 9,
        row: 2,
        sizeW: 1,
        sizeH: 1,
        clearCost: 190,
        clearDuration: 32,
        xpReward: 24,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),

      // ── Extra Lot 2 Obstacles (4 more, avoiding ForSale sign at col 18-19, row 3-5) ──
      ObstacleModel(
        id: 'obs_tree_lot2_extra1',
        type: 'tree',
        name: 'Wild Island Tree',
        col: 21,
        row: 2,
        sizeW: 1,
        sizeH: 1,
        clearCost: 310,
        clearDuration: 60,
        xpReward: 36,
        imageAsset: 'assets/ui/TreeObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_rock_lot2_extra2',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 20,
        row: 8,
        sizeW: 1,
        sizeH: 1,
        clearCost: 350,
        clearDuration: 55,
        xpReward: 40,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_treerock_lot2_extra3',
        type: 'tree_rock',
        name: 'Rocky Grove',
        col: 16,
        row: 7,
        sizeW: 2,
        sizeH: 2,
        clearCost: 480,
        clearDuration: 120,
        xpReward: 54,
        imageAsset: 'assets/ui/TreeAndRocksObstacle.png',
      ),
      ObstacleModel(
        id: 'obs_rock_lot2_extra4',
        type: 'rock',
        name: 'Ancient Boulder',
        col: 22,
        row: 6,
        sizeW: 1,
        sizeH: 1,
        clearCost: 290,
        clearDuration: 48,
        xpReward: 32,
        imageAsset: 'assets/ui/RockObstacle.png',
      ),
    ];
  }

  static const Map<String, Map<String, ({String asset, String name})>>
  _islandThemes = {
    'desert': {
      'rock': (
        asset: 'assets/ui/DessertRockObstacle.png',
        name: 'Desert Boulder',
      ),
      'tree': (
        asset: 'assets/ui/DessertBigCactusObstacle.png',
        name: 'Giant Saguaro Cactus',
      ),
      'tree_rock': (
        asset: 'assets/ui/DessertRockBushObstacle.png',
        name: 'Desert Scrub & Rocks',
      ),
    },
    'ice': {
      'rock': (
        asset: 'assets/ui/IceRockObstacle.png',
        name: 'Frozen Boulder',
      ),
      'tree': (
        asset: 'assets/ui/IcePineTreeObstacle.png',
        name: 'Frosty Pine Tree',
      ),
      'tree_rock': (
        asset: 'assets/ui/IceSpikeRockObstacle.png',
        name: 'Glacial Spike Rocks',
      ),
    },
    'beach': {
      'rock': (
        asset: 'assets/ui/BeachRockObstacle.png',
        name: 'Coastal Boulder',
      ),
      'tree': (
        asset: 'assets/ui/BeachPalmTreeObstacle.png',
        name: 'Tropical Palm Tree',
      ),
      'tree_rock': (
        asset: 'assets/ui/BeachWreckObstacle.png',
        name: 'Washed-Up Shipwreck',
      ),
    },
    'legendary': {
      'rock': (
        asset: 'assets/ui/LegendarySpikeObstacle.png',
        name: 'Arcane Crystal Spikes',
      ),
      'tree': (
        asset: 'assets/ui/LegendaryPillarObstacle.png',
        name: 'Ancient Rune Pillar',
      ),
      'tree_rock': (
        asset: 'assets/ui/LegendaryArcObstacle.png',
        name: 'Mythic Stone Arch',
      ),
    },
  };

  /// Returns default obstacles themed for [islandId].
  static List<ObstacleModel> defaultObstaclesForIsland(String islandId) {
    final base = defaultObstacles();
    if (!_islandThemes.containsKey(islandId)) return base;
    return base.map((obs) => _applyIslandTheme(obs, islandId)).toList();
  }

  static ObstacleModel _applyIslandTheme(ObstacleModel obs, String islandId) {
    final theme = _islandThemes[islandId];
    if (theme == null) return obs;
    final variant = theme[obs.type] ?? theme['rock']!;
    return ObstacleModel(
      id: obs.id,
      type: obs.type,
      name: variant.name,
      col: obs.col,
      row: obs.row,
      sizeW: obs.sizeW,
      sizeH: obs.sizeH,
      clearCost: obs.clearCost,
      clearDuration: obs.clearDuration,
      xpReward: obs.xpReward,
      imageAsset: variant.asset,
      isClearing: obs.isClearing,
      clearingEndsAt: obs.clearingEndsAt,
    );
  }

  /// Ensures any saved default obstacles that were previously placed on an
  /// island edge or lot fence are relocated to their updated interior coords,
  /// and upgrades Desert island obstacles to desert-themed assets.
  static List<ObstacleModel> sanitizeSavedObstacles(
    List<ObstacleModel> saved, {
    String? islandId,
  }) {
    final defaultsById = {for (final d in defaultObstacles()) d.id: d};
    return saved.map((obs) {
      var updated = obs;
      final def = defaultsById[obs.id];
      if (def != null) {
        final onEdgeOrFence =
            obs.col + obs.row <= 4 ||
            obs.col - obs.row >= 21 ||
            obs.col == 12 ||
            obs.col == 13 ||
            obs.row == 10 ||
            (obs.row <= 3 && obs.col <= 7) ||
            (obs.id == 'obs_rock_lot1_extra1' &&
                ((obs.col == 2 && obs.row == 7) ||
                    (obs.col == 4 && obs.row == 8))) ||
            (obs.id == 'obs_rock_lot1_extra4' &&
                obs.col == 11 &&
                obs.row == 6) ||
            (obs.id == 'obs_treerock_lot1_extra3' &&
                obs.col == 2 &&
                obs.row == 5) ||
            (obs.id == 'obs_rock_lot2_extra4' &&
                obs.col == 24 &&
                obs.row == 7);
        if (onEdgeOrFence || (!obs.isClearing && obs.clearDuration != def.clearDuration)) {
          updated = ObstacleModel(
            id: obs.id,
            type: obs.type,
            name: obs.name,
            col: onEdgeOrFence ? def.col : obs.col,
            row: onEdgeOrFence ? def.row : obs.row,
            sizeW: obs.sizeW,
            sizeH: obs.sizeH,
            clearCost: obs.clearCost,
            clearDuration: def.clearDuration,
            xpReward: obs.xpReward,
            imageAsset: obs.imageAsset,
            isClearing: obs.isClearing,
            clearingEndsAt: obs.clearingEndsAt,
          );
        }
      }
      if (islandId != null && _islandThemes.containsKey(islandId)) {
        final expectedAsset = _islandThemes[islandId]?[updated.type]?.asset;
        if (expectedAsset != null && updated.imageAsset != expectedAsset) {
          updated = _applyIslandTheme(updated, islandId);
        }
      }
      return updated;
    }).toList();
  }
}
