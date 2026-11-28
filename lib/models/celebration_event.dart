import 'package:flutter/material.dart';
import 'dog_evolution.dart';
import 'dog_model.dart';
import 'habitat_catalog.dart';
import 'island_model.dart';
import 'level_milestone.dart';

class CelebrationUnlockItem {
  final String name;
  final String category;
  final String imageAsset;
  final Color accentColor;

  const CelebrationUnlockItem({
    required this.name,
    required this.category,
    required this.imageAsset,
    required this.accentColor,
  });
}

sealed class CelebrationEvent {
  const CelebrationEvent();
}

class DogEvolutionCelebration extends CelebrationEvent {
  final String dogName;
  final String breedName;
  final String previousStage;
  final String newStageLabel;
  final int level;
  final String sitImg;
  final String lore;
  final int coinRatePerMin;

  const DogEvolutionCelebration({
    required this.dogName,
    required this.breedName,
    required this.previousStage,
    required this.newStageLabel,
    required this.level,
    required this.sitImg,
    required this.lore,
    required this.coinRatePerMin,
  });

  factory DogEvolutionCelebration.fromDog(
    DogModel dog, {
    required String previousStage,
  }) {
    final info = DogStageInfo.getInfo(dog);
    return DogEvolutionCelebration(
      dogName: dog.name,
      breedName: info.breedName,
      previousStage: previousStage == 'Puppy' ? 'Puppy' : 'Young Pup',
      newStageLabel: info.stageLabel,
      level: info.level,
      sitImg: info.sitImg,
      lore: info.evolutionLore,
      coinRatePerMin: info.coinRatePerMin,
    );
  }
}

class PlayerLevelUpCelebration extends CelebrationEvent {
  final int newLevel;
  final List<CelebrationUnlockItem> unlockedItems;
  final LevelMilestone? milestone;

  const PlayerLevelUpCelebration({
    required this.newLevel,
    required this.unlockedItems,
    this.milestone,
  });

  factory PlayerLevelUpCelebration.forLevel(int newLevel) {
    final unlocks = <CelebrationUnlockItem>[];

    for (final island in IslandCatalog.islands) {
      if (island.requiredLevel == newLevel) {
        unlocks.add(
          CelebrationUnlockItem(
            name: island.name,
            category: 'ISLAND',
            imageAsset: island.surfaceAsset,
            accentColor: island.themeColor,
          ),
        );
      }
    }

    for (final item in HabitatCatalog.items) {
      if (item.requiredLevel == newLevel) {
        final cat = switch (item.type) {
          'facility' => 'FACILITY',
          'decor' => 'DECOR',
          _ => 'HABITAT',
        };
        unlocks.add(
          CelebrationUnlockItem(
            name: item.name,
            category: cat,
            imageAsset: item.imageAsset,
            accentColor: item.themeColor,
          ),
        );
      }
    }

    for (final dog in HabitatCatalog.dogs) {
      if (!dog.isLocked && dog.requiredLevel == newLevel) {
        unlocks.add(
          CelebrationUnlockItem(
            name: dog.name,
            category: 'NEW DOG',
            imageAsset: dog.portraitAsset,
            accentColor: const Color(0xFFF59E0B),
          ),
        );
      }
    }

    final milestone =
        newLevel % 5 == 0 ? LevelMilestone.forLevel(newLevel) : null;

    return PlayerLevelUpCelebration(
      newLevel: newLevel,
      unlockedItems: unlocks,
      milestone: milestone,
    );
  }
}
