class FoodRecipeModel {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final int costCoins;
  final int durationSeconds;
  final int foodAmount;
  final int xpReward;
  final String iconAsset;

  const FoodRecipeModel({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.costCoins,
    required this.durationSeconds,
    required this.foodAmount,
    required this.xpReward,
    required this.iconAsset,
  });

  String get formattedDuration {
    if (durationSeconds < 60) {
      return '${durationSeconds}s';
    } else if (durationSeconds < 3600) {
      final mins = (durationSeconds / 60).round();
      return '${mins}m';
    } else {
      final hrs = (durationSeconds / 3600).toStringAsFixed(durationSeconds % 3600 == 0 ? 0 : 1);
      return '${hrs}h';
    }
  }

  static const List<FoodRecipeModel> recipes = [
    // 1. 30 Seconds - Quick Kibble Crunch
    FoodRecipeModel(
      id: 'recipe_1',
      name: 'Puppy Crunchies',
      subtitle: 'Quick & Crispy',
      description: 'Warm crunchy bite-sized biscuits baked in a flash.',
      costCoins: 100,
      durationSeconds: 30,
      foodAmount: 100,
      xpReward: 10,
      iconAsset: 'assets/ui/dogfood.png',
    ),
    // 2. 5 Minutes - Hearty Bone Biscuits
    FoodRecipeModel(
      id: 'recipe_2',
      name: 'Tasty Bone Biscuits',
      subtitle: 'Nutrient Rich',
      description: 'Crisp golden bone biscuits packed with calcium & vitamins.',
      costCoins: 500,
      durationSeconds: 300,
      foodAmount: 500,
      xpReward: 50,
      iconAsset: 'assets/ui/icon_bread.png',
    ),
    // 3. 30 Minutes - Savory Sausage Rolls
    FoodRecipeModel(
      id: 'recipe_3',
      name: 'Savory Sausage Rolls',
      subtitle: 'Pup Favorite',
      description: 'Tender rolled savory sausages seasoned with sweet pumpkin.',
      costCoins: 2000,
      durationSeconds: 1800,
      foodAmount: 2000,
      xpReward: 200,
      iconAsset: 'assets/ui/icon_meat.png',
    ),
    // 4. 2 Hours - Royal Beef Stew
    FoodRecipeModel(
      id: 'recipe_4',
      name: 'Royal Beef Stew',
      subtitle: 'Gourmet Feast',
      description: 'Slow-simmered prime beef stew with rich marrow broth.',
      costCoins: 5000,
      durationSeconds: 7200,
      foodAmount: 5000,
      xpReward: 500,
      iconAsset: 'assets/ui/icon_honey_pot.png',
    ),
    // 5. 6 Hours - Dragon Bone Banquet
    FoodRecipeModel(
      id: 'recipe_5',
      name: 'Dragon Bone Banquet',
      subtitle: 'Grand Celebration',
      description: 'A feast of fire-roasted ribs and prime cuts for champions.',
      costCoins: 15000,
      durationSeconds: 21600,
      foodAmount: 15000,
      xpReward: 1500,
      iconAsset: 'assets/ui/icon_meat.png',
    ),
    // 6. 12 Hours - Mythic Ambrosia
    FoodRecipeModel(
      id: 'recipe_6',
      name: 'Mythic Ambrosia',
      subtitle: 'Legendary Delicacy',
      description: 'The pinnacle of canine culinary art, baked to golden perfection.',
      costCoins: 30000,
      durationSeconds: 43200,
      foodAmount: 35000,
      xpReward: 3500,
      iconAsset: 'assets/ui/icon_crown.png',
    ),
  ];

  static FoodRecipeModel? findById(String? id) {
    if (id == null) return null;
    try {
      return recipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
