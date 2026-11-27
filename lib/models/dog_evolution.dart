import 'dart:math';
import 'dog_model.dart';

enum DogRarityTier {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

extension DogRarityInfo on DogRarityTier {
  String get label {
    switch (this) {
      case DogRarityTier.common:
        return 'Common';
      case DogRarityTier.uncommon:
        return 'Uncommon';
      case DogRarityTier.rare:
        return 'Rare';
      case DogRarityTier.epic:
        return 'Epic';
      case DogRarityTier.legendary:
        return 'Legendary';
    }
  }

  /// Duration of the breeding process in the Breeding Den (seconds).
  int get breedingDurationSeconds {
    switch (this) {
      case DogRarityTier.common:
        return 120; // 2 minutes
      case DogRarityTier.uncommon:
        return 600; // 10 minutes
      case DogRarityTier.rare:
        return 1800; // 30 minutes
      case DogRarityTier.epic:
        return 5400; // 1.5 hours
      case DogRarityTier.legendary:
        return 14400; // 4 hours
    }
  }

  /// Individual parent recovery cooldown after breeding (seconds).
  int get breedingRecoverySeconds {
    switch (this) {
      case DogRarityTier.common:
        return 12 * 3600; // 12 hours
      case DogRarityTier.uncommon:
        return 24 * 3600; // 24 hours
      case DogRarityTier.rare:
        return 2 * 24 * 3600; // 2 days
      case DogRarityTier.epic:
        return 3 * 24 * 3600; // 3 days
      case DogRarityTier.legendary:
        return 7 * 24 * 3600; // 7 days
    }
  }

  String get formattedRecovery {
    final secs = breedingRecoverySeconds;
    if (secs >= 86400) {
      final days = secs ~/ 86400;
      return '$days ${days == 1 ? 'day' : 'days'}';
    }
    final hrs = secs ~/ 3600;
    return '$hrs hours';
  }
}

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

  static String getBreedPrefix(String breedId) {
    final b = breedId.toLowerCase();
    if (b.contains('astral')) return 'Astral';
    if (b.contains('beagle')) return 'Beagle';
    if (b.contains('bulldog')) return 'Bulldog';
    if (b.contains('chronos')) return 'Chronos';
    if (b.contains('german') || b.contains('shepherd')) return 'German';
    if (b.contains('golden')) return 'GoldenRetriever';
    if (b.contains('husky')) return 'Husky';
    if (b.contains('labrador')) return 'Labrador';
    if (b.contains('pharaoh')) return 'Pharaoh';
    if (b.contains('pug')) return 'Pug';
    if (b.contains('shiba')) return 'Shiba';
    if (b.contains('samoyed')) return 'WhiteSamoyed';
    return 'Bulldog';
  }

  static DogRarityTier getRarityForBreed(String breedId) {
    final b = breedId.toLowerCase();
    if (b.contains('astral') || b.contains('chronos')) {
      return DogRarityTier.legendary;
    }
    if (b.contains('german') ||
        b.contains('shepherd') ||
        b.contains('pharaoh') ||
        b.contains('golden') ||
        b.contains('labrador')) {
      return DogRarityTier.epic;
    }
    if (b.contains('beagle') || b.contains('shiba')) {
      return DogRarityTier.rare;
    }
    if (b.contains('husky') || b.contains('samoyed')) {
      return DogRarityTier.uncommon;
    }
    return DogRarityTier.common;
  }

  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0s';
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (days > 0) {
      return hours > 0 ? '${days}d ${hours}h' : '${days}d';
    }
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  static String getBreedDisplayName(String breedId) {
    final b = breedId.toLowerCase();
    if (b.contains('astral')) return 'Astral Hound';
    if (b.contains('beagle')) return 'Forest Beagle';
    if (b.contains('bulldog')) return 'English Bulldog';
    if (b.contains('chronos')) return 'Chronos Dog';
    if (b.contains('german') || b.contains('shepherd'))
      return 'German Shepherd';
    if (b.contains('golden')) return 'Golden Retriever';
    if (b.contains('husky')) return 'Arctic Husky';
    if (b.contains('labrador')) return 'Labrador Retriever';
    if (b.contains('pharaoh')) return 'Pharaoh Hound';
    if (b.contains('pug')) return 'Toy Pug';
    if (b.contains('shiba')) return 'Japanese Shiba';
    if (b.contains('samoyed')) return 'White Samoyed';
    return 'English Bulldog';
  }

  static DogStageInfo getInfo(DogModel dog) {
    final level = max(1, dog.level);
    final prefix = getBreedPrefix(dog.breedId);
    final breedName = getBreedDisplayName(dog.breedId);

    String stage = 'Puppy';
    String stageLabel = 'Puppy';
    if (level >= 12) {
      stage = 'Adult';
      stageLabel = 'Adult';
    } else if (level >= 6) {
      stage = 'Young';
      stageLabel = 'Young Pup';
    }

    final stageFullTitle = '$stageLabel $breedName';
    final sitImg = 'assets/itemsInShop/dogs/${prefix}${stage}Sit.png';
    final walkImg = 'assets/itemsInShop/dogs/${prefix}${stage}WalkingCycle.png';
    final portraitImg = sitImg;

    const feedRequired = 4;
    final feedProgress = dog.feedProgress;

    // Kibble formula from React version: 15 + pow(level, 1.25) * 8
    final kibbleCostPerFeed = (15 + pow(level, 1.25) * 8).round();
    final coinsRewardPerFeed = 25 + level * 35;
    final xpRewardPerFeed = 15 + level * 20;
    final xpBonusOnLevelUp = 60 + level * 65;
    final coinRatePerMin = 30 + level * 18;

    final isHusky = prefix == 'Husky';
    final defaultName = dog.name.isNotEmpty ? dog.name : breedName;
    final description =
        'A wonderful, devoted companion thriving in Dogtopia sanctuary.';

    final evolutionLore = level == 6
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
      isEvolutionLevel: level == 6 || level == 12,
    );
  }
}
