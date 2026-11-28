import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dogtopia/models/dog_evolution.dart';
import 'package:dogtopia/models/dog_model.dart';
import 'package:dogtopia/models/habitat_catalog.dart';
import 'package:dogtopia/models/island_model.dart';
import 'package:dogtopia/state/game_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channels = [
      MethodChannel('xyz.luan/audioplayers.global'),
      MethodChannel('xyz.luan/audioplayers'),
    ];
    for (final ch in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (call) async => null);
    }
  });

  group('Breeding Cooldowns & Recovery', () {
    test('Rarity recovery durations match progression balance', () {
      expect(DogRarityTier.common.breedingRecoverySeconds, 12 * 3600);
      expect(DogRarityTier.uncommon.breedingRecoverySeconds, 24 * 3600);
      expect(DogRarityTier.rare.breedingRecoverySeconds, 2 * 24 * 3600);
      expect(DogRarityTier.epic.breedingRecoverySeconds, 3 * 24 * 3600);
      expect(DogRarityTier.legendary.breedingRecoverySeconds, 7 * 24 * 3600);
    });

    test('Breeding starts session, sets parent recovery cooldowns, and persists', () {
      final game = GameController(startWalkthrough: false);
      addTearDown(game.dispose);

      // Unlock Level 4 for Breeding Den and place it
      game.addCurrency(coins: 5000, xp: 6000);
      final denItem = HabitatCatalog.findById('breeding-den')!;
      expect(game.placeHabitat(denItem, 8, 8), isTrue);
      final den = game.placedHabitats.firstWhere((h) => h.habitatId == 'breeding-den');
      game.completeConstruction(den.id);

      // Add two Adult English Bulldogs to starter Garden Park
      final garden = game.placedHabitats.firstWhere((h) => h.id == 'hab_starter_garden');
      final p1 = DogModel(
        id: 'p1',
        breedId: 'english-bulldog',
        name: 'Rex',
        level: 12,
        stage: 'Adult',
        element: 'Garden Element',
        habitatId: garden.id,
        habitatName: garden.name,
      );
      final p2 = DogModel(
        id: 'p2',
        breedId: 'english-bulldog',
        name: 'Bella',
        level: 12,
        stage: 'Adult',
        element: 'Garden Element',
        habitatId: garden.id,
        habitatName: garden.name,
      );
      garden.dogs.addAll([p1, p2]);

      expect(game.startBreeding(p1, p2), isTrue);
      expect(game.isBreedingInProgress, isTrue);
      expect(p1.isInBreeding, isTrue);
      expect(p2.isInBreeding, isTrue);
      expect(p1.isOnBreedingCooldown, isTrue);
      expect(p2.isOnBreedingCooldown, isTrue);

      // Speed up breeding hatch
      game.addDiamonds(50);
      expect(game.speedUpBreeding(), isTrue);
      expect(game.isBreedingReadyToClaim, isTrue);

      // Claim puppy into Garden Park
      final claimedHab = game.claimBredPuppyToHabitat(garden.id);
      expect(claimedHab, garden.name);
      expect(game.activeBreeding, isNull);
      expect(p1.isInBreeding, isFalse);
      expect(p2.isInBreeding, isFalse);

      // Parents remain on recovery cooldown and cannot immediately breed again
      expect(p1.isOnBreedingCooldown, isTrue);
      expect(game.startBreeding(p1, p2), isFalse);

      // Persistence roundtrip preserves parent cooldowns
      final saved = game.toJson();
      final restored = GameController(startWalkthrough: false);
      addTearDown(restored.dispose);
      restored.loadFromJson(saved);
      final restoredP1 = restored.findDogByIdGlobal('p1');
      expect(restoredP1?.isOnBreedingCooldown, isTrue);
    });
  });

  group('Building Limits & Unique Restrictions', () {
    test('Breeding Den is unique (0/1 -> 1/1)', () {
      final game = GameController(startWalkthrough: false);
      addTearDown(game.dispose);

      game.addCurrency(coins: 5000, xp: 6000);
      final denItem = HabitatCatalog.findById('breeding-den')!;
      expect(game.getBuildingOwnedCount('breeding-den'), 0);
      expect(game.getBuildingLimit('breeding-den'), 1);
      expect(game.canPurchaseBuilding(denItem), isTrue);

      expect(game.placeHabitat(denItem, 8, 8), isTrue);
      expect(game.getBuildingOwnedCount('breeding-den'), 1);
      expect(game.canPurchaseBuilding(denItem), isFalse);
      expect(game.placeHabitat(denItem, 12, 8), isFalse);
    });

    test('Level 1 limits Garden Park to 1/1 and Level 5 unlocks 2nd slot', () {
      final game = GameController(startWalkthrough: false);
      addTearDown(game.dispose);

      final gardenItem = HabitatCatalog.findById('garden-park')!;
      // Starter park is already 1/1 at Level 1
      expect(game.getBuildingOwnedCount('garden-park'), 1);
      expect(game.getBuildingLimit('garden-park'), 1);
      expect(game.canPurchaseBuilding(gardenItem), isFalse);

      // Level up to 5 via XP
      game.addCurrency(xp: 10000);
      expect(game.level, greaterThanOrEqualTo(5));
      expect(game.getBuildingLimit('garden-park'), 2);
      expect(game.canPurchaseBuilding(gardenItem), isTrue);
    });
  });

  group('Building Upgrades & Construction Timers', () {
    test('Upgrading habitat increases level, capacity, and starts construction', () {
      final game = GameController(startWalkthrough: false);
      addTearDown(game.dispose);

      game.addCurrency(coins: 20000, xp: 5000);
      final garden = game.placedHabitats.firstWhere((h) => h.id == 'hab_starter_garden');
      final initialMaxCoins = garden.maxCoins;

      expect(game.upgradeHabitat(garden.id), isTrue);
      expect(garden.level, 2);
      expect(garden.maxCoins, greaterThan(initialMaxCoins));
      expect(garden.underConstruction, isTrue);
      expect(garden.constructionEndsAt, isNotNull);
    });
  });

  group('Elemental & Island Compatibility', () {
    test('Dogs only fit matching elemental habitats; islands restrict habitats', () {
      expect(HabitatCatalog.isDogCompatible('arctic-husky', 'snowy-peak'), isTrue);
      expect(HabitatCatalog.isDogCompatible('arctic-husky', 'garden-park'), isFalse);
      expect(HabitatCatalog.isDogCompatible('english-bulldog', 'snowy-peak'), isFalse);

      final desertOasis = HabitatCatalog.findById('desert-oasis')!;
      expect(IslandCatalog.isItemAllowedOnIsland(desertOasis, IslandCatalog.starterIslandId), isFalse);
      expect(IslandCatalog.isItemAllowedOnIsland(desertOasis, IslandCatalog.desertIslandId), isTrue);

      final game = GameController(startWalkthrough: false);
      addTearDown(game.dispose);
      game.addCurrency(coins: 10000, xp: 5000);
      final husky = HabitatCatalog.dogs.firstWhere((d) => d.id == 'arctic-husky');
      expect(game.adoptDog(husky, 'hab_starter_garden'), isFalse);
    });
  });

  group('Shop Offer Cooldowns & Anti-Exploit', () {
    test('Diamond Vault triggers 3-day cooldown after purchase and persists', () {
      final game = GameController(startWalkthrough: false);
      addTearDown(game.dispose);

      // Level 1 cannot buy diam_vault (requires Level 4)
      expect(game.isShopOfferAvailable('diam_vault'), isFalse);

      game.addCurrency(xp: 6000);
      expect(game.level, greaterThanOrEqualTo(4));
      expect(game.isShopOfferAvailable('diam_vault'), isTrue);

      expect(
        game.purchaseShopOffer('diam_vault', addCrystals: 1200, addCoins: 300000),
        isTrue,
      );
      expect(game.isShopOfferAvailable('diam_vault'), isFalse);
      expect(
        game.getShopOfferCooldownSeconds('diam_vault'),
        greaterThan(71 * 3600),
      );

      // Roundtrip persistence keeps cooldown active
      final saved = game.toJson();
      final restored = GameController(startWalkthrough: false);
      addTearDown(restored.dispose);
      restored.loadFromJson(saved);
      expect(restored.isShopOfferAvailable('diam_vault'), isFalse);
    });
  });
}
