import 'dart:math';
import 'dog_model.dart';

class DogStageInfo {
  final int level;
  final String stage;
  final String stageLabel;
  final String stageFullTitle;
  final String sitImg;
  final String walkImg;
  final String portraitImg;
  final int feedProgress;
  final int feedRequired;
  final int kibbleCostPerFeed;
  final int coinsRewardPerFeed;
  final int xpRewardPerFeed;
  final int xpBonusOnLevelUp;
  final int coinRatePerMin;
  final bool isHusky;
  final String breedName;
  final String defaultName;
  final String description;
  final String evolutionLore;
  final bool isEvolutionLevel;

  const DogStageInfo({
    required this.level,
    required this.stage,
    required this.stageLabel,
    required this.stageFullTitle,
    required this.sitImg,
    required this.walkImg,
    required this.portraitImg,
    required this.feedProgress,
    required this.feedRequired,
    required this.kibbleCostPerFeed,
    required this.coinsRewardPerFeed,
    required this.xpRewardPerFeed,
    required this.xpBonusOnLevelUp,
    required this.coinRatePerMin,
    required this.isHusky,
    required this.breedName,
    required this.defaultName,
    required this.description,
    required this.evolutionLore,
    required this.isEvolutionLevel,
  });

  static DogStageInfo getInfo(DogModel dog) {
    final level = max(1, dog.level);
    final breedId = dog.breedId.toLowerCase();
    final isHusky = breedId.contains('husky');

    String stage = 'Puppy';
    String stageLabel = 'Puppy';
    String stageFullTitle = isHusky ? 'Husky Puppy' : 'Bulldog Puppy';

    String sitImg = isHusky
        ? 'assets/itemsInShop/dogs/HuskyPuppySit.png'
        : 'assets/dogs/BulldogPuppySit.png';
    String walkImg = isHusky
        ? 'assets/itemsInShop/dogs/HuskyPuppyWalkingCycle.png'
        : 'assets/dogs/BulldogPuppyWalkingCycle.png';
    String portraitImg = isHusky
        ? 'assets/itemsInShop/dogs/HuskyPuppySit.png'
        : 'assets/dogs/BulldogPortrait.png';

    if (level >= 12) {
      stage = 'Adult';
      stageLabel = 'Adult';
      stageFullTitle = isHusky ? 'Adult Arctic Husky' : 'Adult Dog Stage';
      sitImg = isHusky
          ? 'assets/itemsInShop/dogs/HuskyAdultSit.png'
          : 'assets/dogs/BulldogAdultSit.png';
      walkImg = isHusky
          ? 'assets/itemsInShop/dogs/HuskyAdultWalkingCycle.png'
          : 'assets/dogs/BulldogAdultWalkingCycle.png';
      portraitImg = isHusky
          ? 'assets/itemsInShop/dogs/HuskyAdultSit.png'
          : 'assets/dogs/BulldogPortrait.png';
    } else if (level >= 4) {
      stage = 'Young';
      stageLabel = 'Young Pup';
      stageFullTitle = isHusky ? 'Young Arctic Husky' : 'Young Pup Stage';
      sitImg = isHusky
          ? 'assets/itemsInShop/dogs/HuskyYoungSit.png'
          : 'assets/dogs/BulldogYoungSit.png';
      walkImg = isHusky
          ? 'assets/itemsInShop/dogs/HuskyYoungWalkingCycle.png'
          : 'assets/dogs/BulldogYoungWalkingCycle.png';
      portraitImg = isHusky
          ? 'assets/itemsInShop/dogs/HuskyYoungSit.png'
          : 'assets/dogs/BulldogYoungPortrait.png';
    }

    const feedRequired = 4;
    final feedProgress = dog.feedProgress;

    // Kibble formula from React version: 15 + pow(level, 1.25) * 8
    final kibbleCostPerFeed = (15 + pow(level, 1.25) * 8).round();
    final coinsRewardPerFeed = 25 + level * 35;
    final xpRewardPerFeed = 15 + level * 20;
    final xpBonusOnLevelUp = 60 + level * 65;
    final coinRatePerMin = 30 + level * 18;

    final breedName = isHusky ? 'Arctic Husky' : 'English Bulldog';
    final defaultName = isHusky ? 'Storm' : 'Winston';

    final description = isHusky
        ? 'Spirited, resilient, and famously athletic! The Arctic Husky thrives in snowy peaks and frosty trails, howling with joyful zest and racing with boundless agility.'
        : 'Sturdy, courageous, and remarkably affectionate! Winston the English Bulldog thrives in sunny garden parks, greeting trainers with playful waddles and unwavering loyalty.';

    final evolutionLore = level == 4
        ? 'Incredible! Your companion transformed into a swift and spirited Young Pup! Strength and coin output increased!'
        : (level == 12
            ? 'Magnificent! Your companion reached full maturity as a majestic Adult Dog! Maximum Element mastery unlocked!'
            : '');

    return DogStageInfo(
      level: level,
      stage: stage,
      stageLabel: stageLabel,
      stageFullTitle: stageFullTitle,
      sitImg: sitImg,
      walkImg: walkImg,
      portraitImg: portraitImg,
      feedProgress: feedProgress,
      feedRequired: feedRequired,
      kibbleCostPerFeed: kibbleCostPerFeed,
      coinsRewardPerFeed: coinsRewardPerFeed,
      xpRewardPerFeed: xpRewardPerFeed,
      xpBonusOnLevelUp: xpBonusOnLevelUp,
      coinRatePerMin: coinRatePerMin,
      isHusky: isHusky,
      breedName: breedName,
      defaultName: defaultName,
      description: description,
      evolutionLore: evolutionLore,
      isEvolutionLevel: level == 4 || level == 12,
    );
  }
}
