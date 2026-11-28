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
  final int buildDurationSeconds;
  final String rarity; // 'Common' | 'Uncommon' | 'Rare' | 'Epic' | 'Legendary'
  final bool isUnique;

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
    this.buildDurationSeconds = 60,
    this.rarity = 'Common',
    this.isUnique = false,
  });

  int get maxUpgradeLevel =>
      (type == 'habitat' || id == 'dogfood-factory') ? 3 : 1;

  int upgradeCostForLevel(int currentLevel) {
    final base = costCoins > 0 ? costCoins : (costCrystals * 150);
    return (base * (currentLevel + 1) * 1.25).round();
  }

  int upgradeRequiredPlayerLevel(int currentLevel) {
    return requiredLevel + currentLevel * 2;
  }

  int upgradeDurationForLevel(int currentLevel) {
    // Scales with building rarity, base duration, and target level
    final multiplier = currentLevel == 1 ? 1.5 : 2.5;
    return (buildDurationSeconds * multiplier).round().clamp(60, 43200);
  }

  int maxCoinsForLevel(int level) {
    if (maxCoins <= 0) return 0;
    if (level <= 1) return maxCoins;
    if (level == 2) return (maxCoins * 1.75).round();
    return (maxCoins * 2.75).round();
  }

  int maxDogfoodForLevel(int level) {
    if (maxDogfood <= 0) return 0;
    if (level <= 1) return maxDogfood;
    if (level == 2) return (maxDogfood * 1.75).round();
    return (maxDogfood * 2.75).round();
  }

  String get formattedBuildTime {
    if (buildDurationSeconds >= 86400) {
      final days = buildDurationSeconds ~/ 86400;
      final hrs = (buildDurationSeconds % 86400) ~/ 3600;
      return hrs == 0 ? '${days}d' : '${days}d ${hrs}h';
    }
    if (buildDurationSeconds >= 3600) {
      final hrs = buildDurationSeconds ~/ 3600;
      final mins = (buildDurationSeconds % 3600) ~/ 60;
      return mins == 0 ? '${hrs}h' : '${hrs}h ${mins}m';
    }
    if (buildDurationSeconds >= 60) {
      final mins = buildDurationSeconds ~/ 60;
      final secs = buildDurationSeconds % 60;
      return secs == 0 ? '${mins}m' : '${mins}m ${secs}s';
    }
    return '${buildDurationSeconds}s';
  }

  String get assetImage => imageAsset;
  String get element => tagline;
  int get costDiamonds => costCrystals;
  String get description => desc;

  String get insideAsset {
    final hid = id.toLowerCase();
    final hname = name.toLowerCase();
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
  final int requiredLevel;
  final bool isLocked;

  String get assetImage => portraitAsset;
  int get costDiamonds => costCrystals;
  String get description => desc;
  String get habitatType {
    final h = habitatId.toLowerCase();
    if (h.contains('garden')) return 'garden';
    if (h.contains('desert') || h.contains('oasis')) return 'desert';
    if (h.contains('snow')) return 'snow';
    if (h.contains('forest') || h.contains('meadow')) return 'forest';
    if (h.contains('beach') || h.contains('cove')) return 'beach';
    if (h.contains('legend') || h.contains('celestial')) return 'legendary';
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
    this.requiredLevel = 2,
    this.isLocked = false,
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
      buildDurationSeconds: 60,
      rarity: 'Common',
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
      costCoins: 2000,
      requiredLevel: 3,
      maxCoins: 3000,
      coinRate: '120/min',
      bestFor: 'German Shepherd, Pharaoh Hound, Basenji',
      themeColor: Color(0xFFF59E0B),
      imageAsset: 'assets/habitats/OasisHabitat.png',
      buildDurationSeconds: 900,
      rarity: 'Uncommon',
    ),
    HabitatCatalogItem(
      id: 'snowy-peak',
      type: 'habitat',
      name: 'Snowy Peak',
      tagline: 'Cozy Alpine Frost Haven',
      desc:
          'Thick snowdrifts, frozen hot springs, and pine shelters. Suited for Arctic Husky and White Samoyed.',
      sizeW: 3,
      sizeH: 3,
      costCoins: 4500,
      requiredLevel: 6,
      maxCoins: 6000,
      coinRate: '180/min',
      bestFor: 'Arctic Husky, White Samoyed',
      themeColor: Color(0xFF38BDF8),
      imageAsset: 'assets/habitats/SnowHabitat.png',
      buildDurationSeconds: 14400,
      rarity: 'Rare',
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
      costCoins: 9000,
      requiredLevel: 10,
      maxCoins: 12000,
      coinRate: '300/min',
      bestFor: 'Forest Beagle, Japanese Shiba',
      themeColor: Color(0xFF22C55E),
      imageAsset: 'assets/habitats/ForestHabitat.png',
      buildDurationSeconds: 43200,
      rarity: 'Rare',
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
      costCoins: 18000,
      requiredLevel: 14,
      maxCoins: 24000,
      coinRate: '550/min',
      bestFor: 'Golden Retriever, Labrador Retriever',
      themeColor: Color(0xFF06B6D4),
      imageAsset: 'assets/habitats/BeachHabitat.png',
      buildDurationSeconds: 86400,
      rarity: 'Epic',
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
      costCrystals: 60,
      requiredLevel: 20,
      maxCoins: 75000,
      coinRate: '2000/min',
      bestFor: 'Astral Hound, Chronos Dog',
      themeColor: Color(0xFFA855F7),
      imageAsset: 'assets/habitats/LegendaryHabitat.png',
      buildDurationSeconds: 172800,
      rarity: 'Legendary',
    ),

    // ── Facilities ──
    HabitatCatalogItem(
      id: 'breeding-den',
      type: 'facility',
      name: 'Breeding Den',
      tagline: 'Discover secret dog hybrids',
      desc:
          'Pair two adult dogs to hatch new pups! Unique sanctuary building (max 1).',
      sizeW: 3,
      sizeH: 3,
      costCoins: 3500,
      requiredLevel: 4,
      maxCoins: 0,
      coinRate: 'Hatchery',
      bestFor: 'All Adult Breeds (Lv 12+)',
      themeColor: Color(0xFFF43F5E),
      imageAsset: 'assets/itemsInShop/building/BreedingDen.webp',
      buildDurationSeconds: 7200,
      rarity: 'Rare',
      isUnique: true,
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
      buildDurationSeconds: 120,
      rarity: 'Common',
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
      buildDurationSeconds: 600,
      rarity: 'Uncommon',
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
      buildDurationSeconds: 60,
      rarity: 'Uncommon',
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
      buildDurationSeconds: 30,
      rarity: 'Common',
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
      costCoins: 500,
      rarity: 'Starter Pup',
      isDefault: true,
      portraitAsset: 'assets/itemsInShop/dogs/BulldogPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/BulldogPuppySit.png',
      requiredLevel: 1,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'pug',
      name: 'Toy Pug',
      tagline: 'Playful Little Snorer',
      desc:
          'Charming, comedic, and deeply loving. Happily curls up on velvet pillows and trots along garden paths!',
      element: 'Garden Element',
      habitatId: 'garden-park',
      habitatName: 'Garden Park',
      costCoins: 1200,
      rarity: 'Common',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/PugPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/PugPuppySit.png',
      requiredLevel: 2,
      isLocked: false,
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
      costCoins: 3500,
      rarity: 'Uncommon',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/HuskyPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/HuskyPuppySit.png',
      requiredLevel: 6,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'white-samoyed',
      name: 'White Samoyed',
      tagline: 'Fluffy Smiling Cloud',
      desc:
          'Gentle, friendly, and covered in snow-white fur. Spreads joy and warmth even in sub-zero frost!',
      element: 'Snow Element',
      habitatId: 'snowy-peak',
      habitatName: 'Snowy Peak',
      costCoins: 4500,
      rarity: 'Uncommon',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/WhiteSamoyedPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/WhiteSamoyedPuppySit.png',
      requiredLevel: 8,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'beagle',
      name: 'Forest Beagle',
      tagline: 'Keen-Nosed Trail Tracker',
      desc:
          'Curious, energetic, and always on the scent of adventure among the dense green canopy of Forest Grove.',
      element: 'Forest Element',
      habitatId: 'forest-meadow',
      habitatName: 'Forest Meadow',
      costCoins: 6500,
      rarity: 'Rare',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/BeaglePuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/BeaglePuppySit.png',
      requiredLevel: 10,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'shiba-inu',
      name: 'Japanese Shiba',
      tagline: 'Noble Woodland Sentinel',
      desc:
          'Alert, confident, and spirited. Thrives in tranquil woodland shrines and lush forest moss.',
      element: 'Forest Element',
      habitatId: 'forest-meadow',
      habitatName: 'Forest Meadow',
      costCoins: 8000,
      rarity: 'Rare',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/ShibaPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/ShibaPuppySit.png',
      requiredLevel: 12,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'german-shepherd',
      name: 'German Shepherd',
      tagline: 'Dune Patrol Guardian',
      desc:
          'Intelligent, brave, and deeply loyal. Can endure scorching sands and protect the oasis gates with unwavering courage.',
      element: 'Desert Element',
      habitatId: 'desert-oasis',
      habitatName: 'Desert Oasis',
      costCoins: 2400,
      rarity: 'Epic',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/GermanPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/GermanPuppySit.png',
      requiredLevel: 3,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'pharaoh-hound',
      name: 'Pharaoh Hound',
      tagline: 'Graceful Pyramid Stalker',
      desc:
          'Ancient, sleek, and royal. Originating from desert legends with glowing amber eyes and sun-kissed speed.',
      element: 'Desert Element',
      habitatId: 'desert-oasis',
      habitatName: 'Desert Oasis',
      costCoins: 3200,
      rarity: 'Epic',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/PharaohPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/PharaohPuppySit.png',
      requiredLevel: 5,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'golden-retriever',
      name: 'Golden Retriever',
      tagline: 'Sunny Shore Swimmer',
      desc:
          'Enthusiastic, cheerful, and loves splashing in turquoise cove waters and fetching coconuts on the beach!',
      element: 'Beach Element',
      habitatId: 'beach-cove',
      habitatName: 'Beach Cove',
      costCoins: 11000,
      rarity: 'Epic',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/GoldenRetrieverPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/GoldenRetrieverPuppySit.png',
      requiredLevel: 14,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'labrador',
      name: 'Labrador Retriever',
      tagline: 'Hearty Coast Diver',
      desc:
          'Gentle water-lover with boundless spirit. Masters diving in tropical reefs and basking on warm island sand.',
      element: 'Beach Element',
      habitatId: 'beach-cove',
      habitatName: 'Beach Cove',
      costCoins: 14000,
      rarity: 'Epic',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/LabradorPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/LabradorPuppySit.png',
      requiredLevel: 16,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'astral-hound',
      name: 'Astral Hound',
      tagline: 'Celestial Stardust Wanderer',
      desc:
          'A mythical hound born from fallen constellations. Glows with ethereal starlight across the heavens.',
      element: 'Legendary Element',
      habitatId: 'legendary-realm',
      habitatName: 'Legendary Realm',
      costCoins: 25000,
      costCrystals: 60,
      rarity: 'Legendary',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/AstralPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/AstralPuppySit.png',
      requiredLevel: 20,
      isLocked: false,
    ),
    DogCatalogItem(
      id: 'chronos-dog',
      name: 'Chronos Dog',
      tagline: 'Timeless Realm Guardian',
      desc:
          'Master of cosmic timelines and ancient celestial rings. A fabled legend revered by all dog-kind.',
      element: 'Legendary Element',
      habitatId: 'legendary-realm',
      habitatName: 'Legendary Realm',
      costCoins: 35000,
      costCrystals: 100,
      rarity: 'Legendary',
      isDefault: false,
      portraitAsset: 'assets/itemsInShop/dogs/ChronosPuppySit.png',
      sitAsset: 'assets/itemsInShop/dogs/ChronosPuppySit.png',
      requiredLevel: 22,
      isLocked: false,
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

    // Snow element / Husky / Samoyed -> Snowy Peak only
    if (b.contains('husky') || b.contains('snow') || b.contains('samoyed')) {
      return h.contains('snow');
    }
    // Garden element / Bulldog / Pug -> Garden Park only
    if (b.contains('bulldog') || b.contains('garden') || b.contains('pug')) {
      return h.contains('garden');
    }
    // Desert element / German Shepherd / Pharaoh Hound -> Desert Oasis only
    if (b.contains('desert') ||
        b.contains('oasis') ||
        b.contains('shepherd') ||
        b.contains('german') ||
        b.contains('pharaoh')) {
      return h.contains('desert') || h.contains('oasis');
    }
    // Forest element / Beagle / Shiba -> Forest Meadow only
    if (b.contains('forest') ||
        b.contains('meadow') ||
        b.contains('beagle') ||
        b.contains('shiba')) {
      return h.contains('forest') || h.contains('meadow');
    }
    // Beach element / Labrador / Golden Retriever -> Beach Cove only
    if (b.contains('beach') ||
        b.contains('cove') ||
        b.contains('water') ||
        b.contains('labrador') ||
        b.contains('golden')) {
      return h.contains('beach') || h.contains('cove');
    }
    // Legendary element / Astral / Chronos -> Legendary Realm only
    if (b.contains('legend') ||
        b.contains('astral') ||
        b.contains('chronos') ||
        b.contains('celestial')) {
      return h.contains('legend') || h.contains('celestial');
    }

    return h == b;
  }

  static String requiredHabitatNameForDog({String? breedId, String? element}) {
    final b = '${breedId ?? ''} ${element ?? ''}'.toLowerCase();
    if (b.contains('husky') || b.contains('snow') || b.contains('samoyed')) {
      return 'Snowy Peak';
    }
    if (b.contains('desert') ||
        b.contains('oasis') ||
        b.contains('shepherd') ||
        b.contains('german') ||
        b.contains('pharaoh')) {
      return 'Desert Oasis';
    }
    if (b.contains('forest') ||
        b.contains('meadow') ||
        b.contains('beagle') ||
        b.contains('shiba')) {
      return 'Forest Meadow';
    }
    if (b.contains('beach') ||
        b.contains('cove') ||
        b.contains('labrador') ||
        b.contains('golden')) {
      return 'Beach Cove';
    }
    if (b.contains('legend') ||
        b.contains('astral') ||
        b.contains('chronos') ||
        b.contains('celestial')) {
      return 'Legendary Realm';
    }
    return 'Garden Park';
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
