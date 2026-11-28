import 'package:flutter/material.dart';
import 'habitat_catalog.dart';

class IslandDefinition {
  final String id;
  final String name;
  final String subtitle;
  final String surfaceAsset;
  final int costCoins;
  final int costCrystals;
  final int requiredLevel;
  final Color themeColor;

  const IslandDefinition({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.surfaceAsset,
    this.costCoins = 0,
    this.costCrystals = 0,
    this.requiredLevel = 1,
    required this.themeColor,
  });
}

class IslandCatalog {
  static const String starterIslandId = 'meadow';
  static const String desertIslandId = 'desert';
  static const String iceIslandId = 'ice';
  static const String forestIslandId = 'forest';
  static const String beachIslandId = 'beach';
  static const String legendaryIslandId = 'legendary';

  static const List<IslandDefinition> islands = [
    IslandDefinition(
      id: starterIslandId,
      name: 'Meadow Sanctuary',
      subtitle: 'Lush Starter Island',
      surfaceAsset: 'assets/ui/LandSurface.png',
      costCoins: 0,
      requiredLevel: 1,
      themeColor: Color(0xFF22C55E),
    ),
    IslandDefinition(
      id: desertIslandId,
      name: 'Sunlit Desert',
      subtitle: 'Golden Dunes Expansion',
      surfaceAsset: 'assets/ui/DessertSurface.png',
      costCoins: 4500,
      requiredLevel: 3,
      themeColor: Color(0xFFF59E0B),
    ),
    IslandDefinition(
      id: iceIslandId,
      name: 'Frosty Peaks',
      subtitle: 'Alpine Snow & Ice',
      surfaceAsset: 'assets/ui/IceSurface.png',
      costCoins: 8000,
      requiredLevel: 6,
      themeColor: Color(0xFF38BDF8),
    ),
    IslandDefinition(
      id: forestIslandId,
      name: 'Emerald Forest',
      subtitle: 'Ancient Woodland Clearing',
      surfaceAsset: 'assets/ui/ForestSurface.png',
      costCoins: 15000,
      requiredLevel: 10,
      themeColor: Color(0xFF16A34A),
    ),
    IslandDefinition(
      id: beachIslandId,
      name: 'Sunny Shores',
      subtitle: 'Tropical Cove & Lagoon',
      surfaceAsset: 'assets/ui/BeachSurface.png',
      costCoins: 30000,
      requiredLevel: 14,
      themeColor: Color(0xFF06B6D4),
    ),
    IslandDefinition(
      id: legendaryIslandId,
      name: 'Astral Sanctuary',
      subtitle: 'Celestial Crystal Realm',
      surfaceAsset: 'assets/ui/LegendarySurface.png',
      costCoins: 60000,
      requiredLevel: 20,
      themeColor: Color(0xFFA855F7),
    ),
  ];

  static IslandDefinition findById(String id) {
    return islands.firstWhere(
      (i) => i.id == id,
      orElse: () => islands.first,
    );
  }

  static String requiredIslandIdForItem(HabitatCatalogItem item) {
    switch (item.id) {
      case 'desert-oasis':
        return desertIslandId;
      case 'snowy-peak':
        return iceIslandId;
      case 'forest-meadow':
        return forestIslandId;
      case 'beach-cove':
        return beachIslandId;
      case 'legendary-realm':
        return legendaryIslandId;
      default:
        return starterIslandId;
    }
  }

  /// Only habitats matching the island's biome are placeable on that island.
  /// Facilities and decor can be placed on any unlocked island.
  static bool isItemAllowedOnIsland(
      HabitatCatalogItem item, String islandId) {
    if (item.type != 'habitat') return true;
    return requiredIslandIdForItem(item) == islandId;
  }

  static String requiredIslandNameForItem(HabitatCatalogItem item) {
    return findById(requiredIslandIdForItem(item)).name;
  }
}
