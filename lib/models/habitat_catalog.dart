import 'package:flutter/material.dart';

class HabitatCatalogItem {
  final String id;
  final String type; // 'habitat' | 'facility' | 'decor'
  final String name;
  final String tagline;
  final String desc;
  final int sizeW;
  final int sizeH;
  final int costCoins;
  final int costCrystals;
  final int requiredLevel;
  final int maxCoins;
  final String coinRate;
  final int maxDogfood;
  final String dogfoodRate;
  final String bestFor;
  final Color themeColor;
  final String imageAsset;

  const HabitatCatalogItem({
    required this.id,
    required this.type,
    required this.name,
    required this.tagline,
    required this.desc,
    this.sizeW = 3,
    this.sizeH = 3,
    this.costCoins = 0,
    this.costCrystals = 0,
    this.requiredLevel = 1,
    this.maxCoins = 1000,
    this.coinRate = '60/min',
    this.maxDogfood = 0,
    this.dogfoodRate = '',
    this.bestFor = '',
    this.themeColor = Colors.amber,
    required this.imageAsset,
  });

  String get assetImage => imageAsset;
  String get element => tagline;
  int get costDiamonds => costCrystals;
  String get description => desc;
}

class DogCatalogItem {
  final String id;
  final String name;
  final String tagline;
  final String desc;
  final String element;
  final String habitatId;
  final String habitatName;
  final int costCoins;
  final int costCrystals;
  final String rarity;
  final bool isDefault;
  final String portraitAsset;
  final String sitAsset;

  String get assetImage => portraitAsset;
  int get costDiamonds => costCrystals;
  String get description => desc;
  int get requiredLevel => costCoins > 5000 ? 5 : (costCoins > 1000 ? 3 : 1);
  String get habitatType {
    final h = habitatId.toLowerCase();
    if (h.contains('garden')) return 'garden';
    if (h.contains('desert') || h.contains('oasis')) return 'desert';
    if (h.contains('snow')) return 'snow';
    if (h.contains('forest') || h.contains('meadow')) return 'forest';
    if (h.contains('beach') || h.contains('cove')) return 'beach';
    if (h.contains('legend')) return 'legendary';
    return 'garden';
  }

  const DogCatalogItem({
    required this.id,
    required this.name,
    required this.tagline,
    required this.desc,
    required this.element,
    required this.habitatId,
    required this.habitatName,
    this.costCoins = 0,
    this.costCrystals = 0,
    required this.rarity,
    this.isDefault = false,
    required this.portraitAsset,
    required this.sitAsset,
  });
}

class HabitatCatalog {
  static const List<HabitatCatalogItem> items = [
    // ── 6 Core Habitats ──
    HabitatCatalogItem(
      id: 'garden-park',
      type: 'habitat',
      name: 'Garden Park',
      tagline: 'Toy & Companion Breed Sanctuary',
      desc:
          'Manicured flowerbeds, topiary bushes, plush cushions, and ribbons for Bulldog, Pug, and small companions.',
      sizeW: 3,
      sizeH: 3,
      costCoins: 500,
      requiredLevel: 1,
      maxCoins: 1000,
      coinRate: '60/min',
      bestFor: 'English Bulldog, Toy Pug, Japanese Shiba',
      themeColor: Color(0xFFEC4899),
      imageAsset: 'assets/habitats/GardenHabitat.png',
    ),
    HabitatCatalogItem(
      id: 'desert-oasis',
      type: 'habitat',
      name: 'Desert Oasis',
      tagline: 'Warm-Climate Sanctuary',
      desc:
          'Golden sand dunes, bright blue oasis pond, cacti, and shaded resting canopies. Suited for German Shepherds, Pharaoh Hounds, and Basenjis.',
      sizeW: 3,
      sizeH: 3,
      costCoins: 1500,
      requiredLevel: 2,
      maxCoins: 2500,
      coinRate: '120/min',
      bestFor: 'German Shepherd, Pharaoh Hound, Basenji',
      themeColor: Color(0xFFF59E0B),
      imageAsset: 'assets/habitats/OasisHabitat.png',
    ),
    HabitatCatalogItem(
      id: 'snowy-peak',
      type: 'habitat',
      name: 'Snowy Peak',
      tagline: 'Cozy Alpine Frost Haven',
      desc:
          'Thick snowdrifts, frozen hot springs, and pine shelters. Suited for Bulldog and thick-coated arctic explorers.',
      sizeW: 3,
      sizeH: 3,
      costCoins: 1500,
      requiredLevel: 4,
      maxCoins: 2500,
      coinRate: '120/min',
      bestFor: 'Arctic Husky, White Samoyed',
      themeColor: Color(0xFF38BDF8),
      imageAsset: 'assets/habitats/SnowHabitat.png',
    ),
    HabitatCatalogItem(
      id: 'forest-meadow',
      type: 'habitat',
      name: 'Forest Meadow',
      tagline: 'Active Grassy Clearing',
      desc:
          'Lush green grass, oak tree shade, wooden obstacles, and chew toys for energetic hounds.',
      sizeW: 3,
      sizeH: 3,
      costCoins: 3000,
      requiredLevel: 6,
      maxCoins: 5000,
      coinRate: '250/min',
      bestFor: 'Hunting Beagle, Golden Retriever',
      themeColor: Color(0xFF22C55E),
      imageAsset: 'assets/habitats/ForestHabitat.png',
    ),
    HabitatCatalogItem(
      id: 'beach-cove',
      type: 'habitat',
      name: 'Beach Cove',
      tagline: 'Sunny Shoreline Paradise',
      desc:
          'Crystal waves, golden beach sand, surfboards, and splash lagoons for swimmers.',
      sizeW: 3,
      sizeH: 3,
      costCoins: 6000,
      requiredLevel: 8,
      maxCoins: 10000,
      coinRate: '450/min',
      bestFor: 'Yellow Labrador, Newfoundland',
      themeColor: Color(0xFF06B6D4),
      imageAsset: 'assets/habitats/BeachHabitat.png',
    ),
    HabitatCatalogItem(
      id: 'legendary-realm',
      type: 'habitat',
      name: 'Legendary Realm',
      tagline: 'Astral Ancient Dog Realm',
      desc:
          'Hovering celestial crystals, stardust fountains, and glowing aura sanctuary for Mythic pups.',
      sizeW: 3,
      sizeH: 3,
      costCrystals: 45,
      requiredLevel: 12,
      maxCoins: 50000,
      coinRate: '2000/min',
      bestFor: 'Cerberus Pup, Galaxy Astral Pup',
      themeColor: Color(0xFFA855F7),
      imageAsset: 'assets/habitats/LegendaryHabitat.png',
    ),

    // ── Facilities ──
    HabitatCatalogItem(
      id: 'breeding-den',
      type: 'facility',
      name: 'Breeding Den',
      tagline: 'Discover secret dog hybrids',
      desc:
          'Pair two adult dogs to hatch unique hybrid pups (e.g. Husky + Shiba = Snow Fox Shiba)!',
      sizeW: 3,
      sizeH: 3,
      costCoins: 2500,
      maxCoins: 0,
      coinRate: 'Hatchery',
      bestFor: 'All Adult Breeds (Lv 4+)',
      themeColor: Color(0xFFF43F5E),
      imageAsset: 'assets/itemsInShop/building/BreedingDen.webp',
    ),
    HabitatCatalogItem(
      id: 'water-station',
      type: 'facility',
      name: 'Water Station',
      tagline: 'Hydration and quick coins',
      desc:
          'Stone water bowls and fountains to keep dogs energetic. Generates small coin bonuses.',
      sizeW: 2,
      sizeH: 2,
      costCoins: 600,
      maxCoins: 300,
      coinRate: '30/min',
      bestFor: 'Park-wide hydration',
      themeColor: Color(0xFF3B82F6),
      imageAsset: 'assets/itemsInShop/building/WaterStation.webp',
    ),
    HabitatCatalogItem(
      id: 'dogfood-factory',
      type: 'facility',
      name: 'Dogfood Factory',
      tagline: 'Automatic Kibble Bakery',
      desc:
          'Bakes fresh, nutritious kibble biscuits over time to nourish and level up your companion dogs!',
      sizeW: 3,
      sizeH: 3,
      costCoins: 1000,
      maxCoins: 0,
      maxDogfood: 300,
      dogfoodRate: '25/min',
      bestFor: 'All Dog Feeding & Evolution',
      themeColor: Color(0xFFF59E0B),
      imageAsset: 'assets/itemsInShop/building/DogfoodFactory.png',
    ),

    // ── Decorations ──
    HabitatCatalogItem(
      id: 'golden-palm',
      type: 'decor',
      name: 'Golden Palm',
      tagline: 'Tropical oasis shade',
      desc: 'Provides lovely shade for resting dogs during midday desert sun.',
      sizeW: 1,
      sizeH: 1,
      costCoins: 250,
      maxCoins: 0,
      coinRate: '+5% Comfort',
      bestFor: 'Desert Oasis decor',
      themeColor: Color(0xFFEAB308),
      imageAsset: 'assets/itemsInShop/building/GoldenPalm.webp',
    ),
    HabitatCatalogItem(
      id: 'bone-sign',
      type: 'decor',
      name: 'Bone-Shaped Sign',
      tagline: 'Cute welcoming monument',
      desc: 'Hand-carved wooden sign greeting visitors to your PupPal park.',
      sizeW: 1,
      sizeH: 1,
      costCoins: 150,
      maxCoins: 0,
      coinRate: '+3% Comfort',
      bestFor: 'Park entrance',
      themeColor: Color(0xFFF97316),
      imageAsset: 'assets/itemsInShop/building/BoneShapeSign.webp',
    ),
  ];

  static const List<DogCatalogItem> dogs = [
    DogCatalogItem(
      id: 'english-bulldog',
      name: 'English Bulldog',
      tagline: 'Loyal Garden Companion',
      desc:
          'Affectionate, sturdy, and brave companion. Loves relaxing among the lush flowerbeds and sunny Garden Park cushions!',
      element: 'Garden Element',
      habitatId: 'garden-park',
      habitatName: 'Garden Park',
      costCoins: 0,
      rarity: 'Starter Pup',
      isDefault: true,
      portraitAsset: 'assets/dogs/BulldogPortrait.png',
      sitAsset: 'assets/dogs/BulldogSit.png',
    ),
    DogCatalogItem(
      id: 'arctic-husky',
      name: 'Arctic Husky',
      tagline: 'Spirited Snow Runner',
      desc:
          'Athletic, vocal, and affectionate snow dog. Loves crisp breezes and running through snowy trails!',
      element: 'Snow Element',
      habitatId: 'snowy-peak',
      habitatName: 'Snowy Peak',
      costCoins: 800,
      rarity: 'Frost Pup',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/HuskyPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/HuskyPuppySit.png',
    ),
  ];

  static List<HabitatCatalogItem> get habitats =>
      items.where((i) => i.type == 'habitat').toList();
  static List<HabitatCatalogItem> get facilities =>
      items.where((i) => i.type == 'facility').toList();
  static List<HabitatCatalogItem> get decor =>
      items.where((i) => i.type == 'decor').toList();

  static HabitatCatalogItem? findById(String id) {
    for (final it in items) {
      if (it.id == id) return it;
    }
    return null;
  }

  static bool isDogCompatible(String breedOrElement, String habitatCatalogId) {
    final b = breedOrElement.toLowerCase();
    final h = habitatCatalogId.toLowerCase();

    // Snow element / Husky
    if (b.contains('husky') || b.contains('snow')) {
      return h.contains('snow') || h.contains('garden');
    }
    // Bulldog / Garden
    if (b.contains('bulldog') || b.contains('garden')) {
      return h.contains('garden') || h.contains('snow');
    }
    // Desert / Oasis
    if (b.contains('desert') || b.contains('oasis') || b.contains('shepherd')) {
      return h.contains('desert') || h.contains('oasis');
    }
    // Forest / Meadow
    if (b.contains('forest') || b.contains('meadow') || b.contains('beagle')) {
      return h.contains('forest') || h.contains('meadow');
    }
    // Beach / Cove
    if (b.contains('beach') || b.contains('cove') || b.contains('water') || b.contains('labrador')) {
      return h.contains('beach') || h.contains('cove');
    }
    // Legendary / Astral
    if (b.contains('legend') || b.contains('astral')) {
      return h.contains('legend');
    }

    return h == b;
  }

  static bool isHabitatCompatible({
    required String habitatCatalogId,
    String? breedId,
    String? element,
    String? preferredHabitatId,
  }) {
    final h = habitatCatalogId.toLowerCase();
    if (preferredHabitatId != null && preferredHabitatId.isNotEmpty) {
      if (h == preferredHabitatId.toLowerCase()) return true;
    }
    if (breedId != null && isDogCompatible(breedId, habitatCatalogId)) return true;
    if (element != null && isDogCompatible(element, habitatCatalogId)) return true;
    return false;
  }
}
