import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/dog_model.dart';
import '../models/habitat_model.dart';
import '../models/task_model.dart';
import '../models/habitat_catalog.dart';
import '../models/dog_evolution.dart';
import '../models/obstacle_model.dart';
import '../models/food_recipe_model.dart';
import '../models/walkthrough_step.dart';
import '../services/audio_service.dart';

class GameController extends ChangeNotifier {
  // Currencies
  int _coins = 5000;
  int _crystals = 25;
  int _kibble = 1000;
  int _level = 1;
  int _xp = 0;
  int _maxXp = 500;

  // Audio settings
  bool _sfxEnabled = true;
  bool _bgmEnabled = true;
  double _sfxVolume = 0.8;
  double _bgmVolume = 0.5;

  // Grid visibility
  bool _gridVisible = false;

  // World objects
  List<HabitatModel> _placedHabitats = [
    HabitatModel.createDefaultGardenPark(),
    HabitatModel.createDefaultDogfoodFactory(),
  ];

  // Active tasks
  List<TaskModel> _tasks = TaskModel.defaultTasks();

  // Selected habitat for HUD interaction
  String? _selectedHabitatId;

  // Lot expansion state (2 Lots for sale: Lot 1 = Top/Bench [c < 13, r < 11], Lot 2 = Right [c >= 13])
  bool _isLot1Unlocked = false;
  bool _isLot2Unlocked = false;

  // Obstacles scattered across the island (clearable with gold)
  List<ObstacleModel> _obstacles = ObstacleModel.defaultObstacles();
  String? _selectedObstacleId;

  Timer? _incomeTimer;

  // Interactive Dog Wizard walkthrough state
  bool _walkthroughActive = true;
  int _walkthroughStepIndex = 0;
  bool _walkthroughRewardClaimed = false;

  GameController({bool startWalkthrough = true}) {
    _walkthroughActive = startWalkthrough;
    SoundManager.instance.setBgmEnabled(_bgmEnabled);
    SoundManager.instance.setSfxEnabled(_sfxEnabled);
    SoundManager.instance.setBgmVolume(_bgmVolume);
    SoundManager.instance.setSfxVolume(_sfxVolume);
    _startIncomeTimer();
  }

  // Getters
  int get coins => _coins;
  int get crystals => _crystals;
  int get kibble => _kibble;
  int get level => _level;
  int get xp => _xp;
  int get maxXp => _maxXp;
  bool get sfxEnabled => _sfxEnabled;
  bool get bgmEnabled => _bgmEnabled;
  double get sfxVolume => _sfxVolume;
  double get bgmVolume => _bgmVolume;
  bool get gridVisible => _gridVisible;
  List<HabitatModel> get placedHabitats => _placedHabitats;
  List<TaskModel> get tasks => _tasks;
  String? get selectedHabitatId => _selectedHabitatId;
  bool get isLot1Unlocked => _isLot1Unlocked;
  bool get isLot2Unlocked => _isLot2Unlocked;
  bool get isLotExpansionUnlocked => _isLot1Unlocked && _isLot2Unlocked;
  List<ObstacleModel> get obstacles => _obstacles;
  String? get selectedObstacleId => _selectedObstacleId;

  bool get walkthroughActive => _walkthroughActive;
  int get walkthroughStepIndex => _walkthroughStepIndex;
  int get walkthroughTotalSteps => WalkthroughStep.steps.length;
  bool get walkthroughRewardClaimed => _walkthroughRewardClaimed;

  WalkthroughStep? get currentWalkthroughStep {
    if (!_walkthroughActive) return null;
    if (_walkthroughStepIndex < 0 ||
        _walkthroughStepIndex >= WalkthroughStep.steps.length) {
      return null;
    }
    return WalkthroughStep.steps[_walkthroughStepIndex];
  }

  /// Prevents softlocks during tutorial replay (e.g. factory already baking or out of kibble).
  bool get canBypassCurrentWalkthroughStep {
    final step = currentWalkthroughStep;
    if (step == null || !step.requireAction) return true;
    switch (step.id) {
      case WalkthroughStepId.selectGarden:
        return !_placedHabitats.any((h) => h.id == 'hab_starter_garden');
      case WalkthroughStepId.enterHabitatCare:
        final garden = _placedHabitats.firstWhere(
          (h) => h.id == 'hab_starter_garden',
          orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
        );
        return garden.id.isEmpty || garden.dogs.isEmpty;
      case WalkthroughStepId.feedDog:
        final garden = _placedHabitats.firstWhere(
          (h) => h.id == 'hab_starter_garden',
          orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
        );
        if (garden.id.isEmpty || garden.dogs.isEmpty) return true;
        final nextCost = DogStageInfo.getInfo(garden.dogs.first).kibbleCostPerFeed;
        return _kibble < nextCost;
      case WalkthroughStepId.selectFactory:
        return !_placedHabitats.any((h) => h.id == 'hab_starter_factory');
      case WalkthroughStepId.bakeRecipe:
        final factory = _placedHabitats.firstWhere(
          (h) => h.id == 'hab_starter_factory',
          orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
        );
        return factory.id.isEmpty || factory.isBaking || _coins < 50;
      case WalkthroughStepId.speedUpBaking:
        final factory = _placedHabitats.firstWhere(
          (h) => h.id == 'hab_starter_factory',
          orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
        );
        return factory.id.isEmpty || !factory.isBaking || _crystals < 1;
      case WalkthroughStepId.collectKibble:
        final factory = _placedHabitats.firstWhere(
          (h) => h.id == 'hab_starter_factory',
          orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
        );
        return factory.id.isEmpty || !factory.readyToCollectDogfood;
      default:
        return false;
    }
  }

  void advanceWalkthrough() {
    if (!_walkthroughActive) return;
    final current = currentWalkthroughStep;
    if (current == null) {
      _walkthroughActive = false;
      notifyListeners();
      return;
    }

    if (current.id == WalkthroughStepId.graduation) {
      _completeWalkthrough(grantReward: true);
      return;
    }

    if (_walkthroughStepIndex + 1 >= WalkthroughStep.steps.length) {
      _completeWalkthrough(grantReward: true);
      return;
    }

    _walkthroughStepIndex += 1;
    SoundManager.instance.playWalkthroughStepComplete();
    notifyListeners();
  }

  void skipWalkthrough() {
    if (!_walkthroughActive) return;
    _walkthroughActive = false;
    SoundManager.instance.playClick();
    notifyListeners();
  }

  void restartWalkthrough() {
    _selectedHabitatId = null;
    _selectedObstacleId = null;
    _walkthroughStepIndex = 0;
    _walkthroughActive = true;
    SoundManager.instance.playWalkthroughPop();
    notifyListeners();
  }

  void _completeWalkthrough({required bool grantReward}) {
    _walkthroughActive = false;
    if (grantReward && !_walkthroughRewardClaimed) {
      _walkthroughRewardClaimed = true;
      _coins += 500;
      _crystals += 5;
      _addXp(100);
      SoundManager.instance.playQuestReward();
    } else {
      SoundManager.instance.playClick();
    }
    notifyListeners();
  }

  void onWalkthroughRouteChanged(String route) {
    final step = currentWalkthroughStep;
    if (step == null) return;

    if (step.id == WalkthroughStepId.enterHabitatCare && route == 'habitat') {
      _walkthroughStepIndex += 1;
      SoundManager.instance.playWalkthroughStepComplete();
      notifyListeners();
    } else if (step.id == WalkthroughStepId.backFromHabitat && route == 'world') {
      _selectedHabitatId = null;
      _walkthroughStepIndex += 1;
      SoundManager.instance.playWalkthroughStepComplete();
      notifyListeners();
    } else if (step.id == WalkthroughStepId.enterFactory && route == 'factory') {
      _walkthroughStepIndex += 1;
      SoundManager.instance.playWalkthroughStepComplete();
      notifyListeners();
    } else if (step.id == WalkthroughStepId.backFromFactory && route == 'world') {
      _selectedHabitatId = null;
      _walkthroughStepIndex += 1;
      SoundManager.instance.playWalkthroughStepComplete();
      notifyListeners();
    }
  }

  bool isTileUnlocked(int col, int row) {
    if (row >= 11) return true; // Entire bottom strip always unlocked (starter + south expansion)
    if (col < 13 && row < 11) return _isLot1Unlocked; // Expansion Lot 1 (Top-left / Bench)
    return _isLot2Unlocked; // Expansion Lot 2 (Top-right, locked)
  }

  ObstacleModel? get selectedObstacle {
    if (_selectedObstacleId == null) return null;
    try {
      return _obstacles.firstWhere((o) => o.id == _selectedObstacleId);
    } catch (_) {
      return null;
    }
  }

  void selectObstacle(String? id) {
    _selectedObstacleId = id;
    if (id != null) {
      _selectedHabitatId = null; // Deselect habitat when selecting obstacle
      SoundManager.instance.playClick();
    }
    notifyListeners();
  }

  bool unlockLot1() {
    if (_isLot1Unlocked) return false;
    const cost = 2500;
    if (_coins < cost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= cost;
    _isLot1Unlocked = true;
    _addXp(120);
    SoundManager.instance.playLevelUp();
    notifyListeners();
    return true;
  }

  bool unlockLot2() {
    if (_isLot2Unlocked) return false;
    const cost = 2500;
    if (_coins < cost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= cost;
    _isLot2Unlocked = true;
    _addXp(120);
    SoundManager.instance.playLevelUp();
    notifyListeners();
    return true;
  }

  bool unlockLotExpansion() {
    if (!_isLot1Unlocked) return unlockLot1();
    if (!_isLot2Unlocked) return unlockLot2();
    return false;
  }

  bool startClearingObstacle(String obstacleId) {
    final obs = _obstacles.firstWhere(
      (o) => o.id == obstacleId,
      orElse: () => ObstacleModel(
          id: '', type: '', name: '', col: 0, row: 0, imageAsset: ''),
    );
    if (obs.id.isEmpty || obs.isClearing) return false;
    if (_coins < obs.clearCost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= obs.clearCost;
    obs.isClearing = true;
    obs.clearingEndsAt =
        DateTime.now().millisecondsSinceEpoch + obs.clearDuration * 1000;
    _selectedObstacleId = obs.id;
    SoundManager.instance.playChop();
    notifyListeners();
    return true;
  }

  bool completeClearingObstacle(String obstacleId) {
    final idx = _obstacles.indexWhere((o) => o.id == obstacleId);
    if (idx == -1) return false;

    final obs = _obstacles[idx];
    _addXp(obs.xpReward);
    _obstacles.removeAt(idx);
    if (_selectedObstacleId == obstacleId) {
      _selectedObstacleId = null;
    }
    SoundManager.instance.playChop();
    notifyListeners();
    return true;
  }

  bool speedUpClearingObstacle(String obstacleId, int crystalsCost) {
    final obs = _obstacles.firstWhere(
      (o) => o.id == obstacleId,
      orElse: () => ObstacleModel(
          id: '', type: '', name: '', col: 0, row: 0, imageAsset: ''),
    );
    if (obs.id.isEmpty || !obs.isClearing) return false;
    if (_crystals < crystalsCost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _crystals -= crystalsCost;
    obs.clearingEndsAt = DateTime.now().millisecondsSinceEpoch;
    SoundManager.instance.playLevelUp();
    return completeClearingObstacle(obstacleId);
  }

  HabitatModel? get selectedHabitat {
    if (_selectedHabitatId == null) return null;
    try {
      return _placedHabitats.firstWhere((h) => h.id == _selectedHabitatId);
    } catch (_) {
      return null;
    }
  }

  void selectHabitat(String? id) {
    _selectedHabitatId = id;
    if (id != null) {
      _selectedObstacleId = null;
      SoundManager.instance.playClick();
      final step = currentWalkthroughStep;
      if (step != null &&
          ((step.id == WalkthroughStepId.selectGarden &&
                  id == 'hab_starter_garden') ||
              (step.id == WalkthroughStepId.selectFactory &&
                  id == 'hab_starter_factory'))) {
        _walkthroughStepIndex += 1;
        SoundManager.instance.playWalkthroughStepComplete();
      }
    }
    notifyListeners();
  }

  void toggleGrid() {
    _gridVisible = !_gridVisible;
    SoundManager.instance.playClick();
    notifyListeners();
  }

  void setGridVisible(bool visible) {
    _gridVisible = visible;
    notifyListeners();
  }

  void toggleSfx() {
    _sfxEnabled = !_sfxEnabled;
    SoundManager.instance.setSfxEnabled(_sfxEnabled);
    if (_sfxEnabled) {
      SoundManager.instance.playClick();
    }
    notifyListeners();
  }

  void toggleBgm() {
    _bgmEnabled = !_bgmEnabled;
    SoundManager.instance.setBgmEnabled(_bgmEnabled);
    notifyListeners();
  }

  void setSfxVolume(double volume) {
    _sfxVolume = volume.clamp(0.0, 1.0);
    SoundManager.instance.setSfxVolume(_sfxVolume);
    notifyListeners();
  }

  void setBgmVolume(double volume) {
    _bgmVolume = volume.clamp(0.0, 1.0);
    SoundManager.instance.setBgmVolume(_bgmVolume);
    notifyListeners();
  }

  void _startIncomeTimer() {
    _incomeTimer?.cancel();
    _incomeTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      tickIncome();
    });
  }

  void tickIncome() {
    bool changed = false;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final h in _placedHabitats) {
      if (h.isFactory) {
        // Dragon City Farm logic: Check if active baking finished
        if (h.bakingEndsAt != null && !h.readyToCollectDogfood) {
          if (now >= h.bakingEndsAt!) {
            h.dogfoodAccumulated = h.bakingFoodAmount ?? 0;
            h.readyToCollectDogfood = true;
            changed = true;
          }
        }
      } else if (h.type == 'habitat' && h.maxCoins > 0) {
        if (h.dogs.isNotEmpty && h.coinsAccumulated < h.maxCoins) {
          final dogRate = h.dogs.fold<int>(
              0, (sum, d) => sum + (30 + (d.level * 15)));
          final add = min(h.maxCoins - h.coinsAccumulated, max(25, (dogRate / 4).round()));
          h.coinsAccumulated += add;
          if (h.coinsAccumulated >= (h.maxCoins * 0.35).floor()) {
            h.readyToCollect = true;
          }
          changed = true;
        }
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  bool startBakingFood(String habitatId, FoodRecipeModel recipe) {
    final h = _placedHabitats.firstWhere((it) => it.id == habitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (h.id.isEmpty || !h.isFactory) return false;
    if (_coins < recipe.costCoins) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
    if (h.isBaking || (h.readyToCollectDogfood && h.dogfoodAccumulated > 0)) return false;

    _coins -= recipe.costCoins;
    final now = DateTime.now().millisecondsSinceEpoch;
    h.bakingRecipeId = recipe.id;
    h.bakingRecipeName = recipe.name;
    h.bakingFoodAmount = recipe.foodAmount;
    h.bakingXpReward = recipe.xpReward;
    h.bakingCostCoins = recipe.costCoins;
    h.bakingDurationSeconds = recipe.durationSeconds;
    h.bakingStartedAt = now;
    h.bakingEndsAt = now + recipe.durationSeconds * 1000;
    h.readyToCollectDogfood = false;
    h.dogfoodAccumulated = 0;

    SoundManager.instance.playBake();
    if (currentWalkthroughStep?.id == WalkthroughStepId.bakeRecipe) {
      _walkthroughStepIndex += 1;
      SoundManager.instance.playWalkthroughStepComplete();
    }
    notifyListeners();
    return true;
  }

  bool speedUpBaking(String habitatId) {
    final h = _placedHabitats.firstWhere((it) => it.id == habitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (h.id.isEmpty || !h.isBaking) return false;

    final remainingSecs = h.bakingRemainingSeconds;
    final crystalsNeeded = max(1, (remainingSecs / 900).ceil());
    if (_crystals < crystalsNeeded) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _crystals -= crystalsNeeded;
    h.bakingEndsAt = DateTime.now().millisecondsSinceEpoch;
    h.dogfoodAccumulated = h.bakingFoodAmount ?? 0;
    h.readyToCollectDogfood = true;

    SoundManager.instance.playLevelUp();
    if (currentWalkthroughStep?.id == WalkthroughStepId.speedUpBaking) {
      _walkthroughStepIndex += 1;
      SoundManager.instance.playWalkthroughStepComplete();
    }
    notifyListeners();
    return true;
  }

  bool collectCoins(String habitatId) {
    final h = _placedHabitats.firstWhere((it) => it.id == habitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (h.id.isEmpty || h.coinsAccumulated <= 0) return false;

    _coins += h.coinsAccumulated;
    h.coinsAccumulated = 0;
    h.readyToCollect = false;
    h.lastCollectTime = DateTime.now().millisecondsSinceEpoch;
    SoundManager.instance.playCollectCoins();
    notifyListeners();
    return true;
  }

  bool collectDogfood(String habitatId) {
    final h = _placedHabitats.firstWhere((it) => it.id == habitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (h.id.isEmpty) return false;

    final amountToCollect = h.dogfoodAccumulated > 0
        ? h.dogfoodAccumulated
        : (h.isBakingFinished ? (h.bakingFoodAmount ?? 0) : 0);
    if (amountToCollect <= 0) return false;

    _kibble += amountToCollect;
    if (h.bakingXpReward != null && h.bakingXpReward! > 0) {
      _addXp(h.bakingXpReward!);
    }
    h.dogfoodAccumulated = 0;
    h.readyToCollectDogfood = false;
    h.bakingRecipeId = null;
    h.bakingRecipeName = null;
    h.bakingFoodAmount = null;
    h.bakingXpReward = null;
    h.bakingCostCoins = null;
    h.bakingDurationSeconds = null;
    h.bakingStartedAt = null;
    h.bakingEndsAt = null;

    SoundManager.instance.playCollectKibble();
    if (currentWalkthroughStep?.id == WalkthroughStepId.collectKibble) {
      _walkthroughStepIndex += 1;
      SoundManager.instance.playWalkthroughStepComplete();
    }
    notifyListeners();
    return true;
  }

  bool canAfford(int costCoins, int costCrystals) {
    return _coins >= costCoins && _crystals >= costCrystals;
  }

  bool placeHabitat(HabitatCatalogItem item, int col, int row) {
    if (!canAfford(item.costCoins, item.costCrystals)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= item.costCoins;
    _crystals -= item.costCrystals;
    _addXp(150);

    final now = DateTime.now().millisecondsSinceEpoch;
    final newHab = HabitatModel(
      id: 'hab_$now',
      type: item.type,
      habitatId: item.id,
      name: item.name,
      col: col,
      row: row,
      sizeW: item.sizeW,
      sizeH: item.sizeH,
      maxCoins: item.maxCoins,
      maxDogfood: item.maxDogfood,
      underConstruction: true,
      constructionDuration: 30,
      constructionEndsAt: now + 30 * 1000,
    );

    _placedHabitats.add(newHab);
    _selectedHabitatId = newHab.id;
    SoundManager.instance.playBuild();
    notifyListeners();
    return true;
  }

  void moveHabitat(String habitatId, int newCol, int newRow) {
    for (final h in _placedHabitats) {
      if (h.id == habitatId) {
        h.col = newCol;
        h.row = newRow;
        break;
      }
    }
    SoundManager.instance.playBuild();
    notifyListeners();
  }

  void completeConstruction(String habitatId) {
    for (final h in _placedHabitats) {
      if (h.id == habitatId) {
        h.underConstruction = false;
        h.constructionEndsAt = null;
        _addXp(50);
        SoundManager.instance.playLevelUp();
        notifyListeners();
        break;
      }
    }
  }

  bool adoptDog(DogCatalogItem dogItem, String targetHabitatId) {
    if (!canAfford(dogItem.costCoins, dogItem.costCrystals)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    final hab = _placedHabitats.firstWhere((h) => h.id == targetHabitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (hab.id.isEmpty) return false;

    _coins -= dogItem.costCoins;
    _crystals -= dogItem.costCrystals;
    _addXp(200);

    final newDog = DogModel(
      id: 'dog_${DateTime.now().millisecondsSinceEpoch}',
      breedId: dogItem.id,
      name: dogItem.id.contains('husky') ? 'Storm' : 'Max',
      level: 1,
      feedProgress: 0,
      stage: 'Puppy',
      element: dogItem.element,
      habitatId: hab.id,
      habitatName: hab.name,
    );

    hab.dogs.add(newDog);
    SoundManager.instance.playLevelUp();
    SoundManager.instance.playDogBark(isPuppy: true, force: true);
    notifyListeners();
    return true;
  }

  /// Dragon City 4-step Feeding system:
  /// Consumes kibble, gives Coins & XP, advances feed progress.
  /// On 4th feed -> levels up!
  bool feedDog(String habitatId, String dogId) {
    for (final h in _placedHabitats) {
      if (h.id == habitatId) {
        for (final d in h.dogs) {
          if (d.id == dogId) {
            final info = DogStageInfo.getInfo(d);
            if (_kibble < info.kibbleCostPerFeed) {
              SoundManager.instance.playSadWhimper();
              return false;
            }

            _kibble -= info.kibbleCostPerFeed;
            _coins += info.coinsRewardPerFeed;
            _addXp(info.xpRewardPerFeed);
            SoundManager.instance.playFeed();

            d.feedProgress += 1;
            if (d.feedProgress >= 4) {
              d.feedProgress = 0;
              d.level += 1;
              _addXp(info.xpBonusOnLevelUp);
              if (d.level >= 12) {
                d.stage = 'Adult';
              } else if (d.level >= 4) {
                d.stage = 'Young';
              }
              SoundManager.instance.playLevelUp();
              SoundManager.instance.playDogBark(isPuppy: d.stage == 'Puppy', force: true);
            }
            if (currentWalkthroughStep?.id == WalkthroughStepId.feedDog) {
              final nextCost = DogStageInfo.getInfo(d).kibbleCostPerFeed;
              if (_kibble < nextCost) {
                _walkthroughStepIndex += 1;
                SoundManager.instance.playWalkthroughStepComplete();
              }
            }
            notifyListeners();
            return true;
          }
        }
      }
    }
    return false;
  }

  void renameDog(String habitatId, String dogId, String newName) {
    for (final h in _placedHabitats) {
      if (h.id == habitatId) {
        for (final d in h.dogs) {
          if (d.id == dogId) {
            d.name = newName.trim();
            SoundManager.instance.playClick();
            notifyListeners();
            return;
          }
        }
      }
    }
  }

  bool sellDog(String habitatId, String dogId, int refundCoins) {
    for (final h in _placedHabitats) {
      if (h.id == habitatId) {
        final initialLen = h.dogs.length;
        h.dogs.removeWhere((d) => d.id == dogId);
        if (h.dogs.length < initialLen) {
          _coins += refundCoins;
          SoundManager.instance.playSadWhimper();
          notifyListeners();
          return true;
        }
      }
    }
    return false;
  }

  bool transferDog(String fromHabitatId, String toHabitatId, String dogId) {
    if (fromHabitatId == toHabitatId) return false;
    final fromHab = _placedHabitats.firstWhere(
      (h) => h.id == fromHabitatId,
      orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
    );
    final toHab = _placedHabitats.firstWhere(
      (h) => h.id == toHabitatId,
      orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
    );
    if (fromHab.id.isEmpty || toHab.id.isEmpty) return false;
    if (toHab.dogs.length >= 4) return false;

    final dogIdx = fromHab.dogs.indexWhere((d) => d.id == dogId);
    if (dogIdx == -1) return false;

    final dog = fromHab.dogs.removeAt(dogIdx);
    dog.habitatId = toHab.id;
    dog.habitatName = toHab.name;
    toHab.dogs.add(dog);

    SoundManager.instance.playLevelUp();
    SoundManager.instance.playDogBark(isPuppy: dog.isPuppy);
    notifyListeners();
    return true;
  }

  void careAction(String action) {
    switch (action) {
      case 'bath':
        _coins += 300;
        _addXp(50);
        break;
      case 'play':
        _coins += 250;
        _addXp(40);
        break;
      case 'brush':
        _crystals += 3;
        _addXp(80);
        break;
      case 'pet':
        _coins += 50;
        _addXp(10);
        break;
    }
    SoundManager.instance.playPet();
    SoundManager.instance.playDogBark(isPuppy: true);
    notifyListeners();
  }

  void completeTask(String taskId) {
    for (final t in _tasks) {
      if (t.id == taskId && !t.done) {
        t.done = true;
        _coins += t.rewardCoins;
        _crystals += t.rewardCrystals;
        _addXp(t.rewardXp);
        SoundManager.instance.playQuestReward();
        notifyListeners();
        return;
      }
    }
  }

  bool spendCurrency({int coins = 0, int crystals = 0, int kibble = 0}) {
    if (_coins < coins || _crystals < crystals || _kibble < kibble) return false;
    _coins -= coins;
    _crystals -= crystals;
    _kibble -= kibble;
    notifyListeners();
    return true;
  }

  void addCoins(int amount) => addCurrency(coins: amount);
  void addDiamonds(int amount) => addCurrency(crystals: amount);
  void addCrystals(int amount) => addCurrency(crystals: amount);
  void addKibble(int amount) => addCurrency(kibble: amount);

  void addCurrency({int coins = 0, int crystals = 0, int kibble = 0, int xp = 0}) {
    _coins += coins;
    _crystals += crystals;
    _kibble += kibble;
    if (xp > 0) _addXp(xp);
    notifyListeners();
  }

  void _addXp(int amount) {
    _xp += amount;
    while (_xp >= _maxXp) {
      _xp -= _maxXp;
      _level += 1;
      _maxXp = (_maxXp * 1.3).floor();
      // Level up rewards
      _crystals += 5;
      _coins += 500;
      SoundManager.instance.playLevelUp();
    }
  }

  @override
  void dispose() {
    _incomeTimer?.cancel();
    super.dispose();
  }
}
