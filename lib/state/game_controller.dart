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
import '../models/level_milestone.dart';
import '../models/walkthrough_step.dart';
import '../models/celebration_event.dart';
import '../models/island_model.dart';
import '../models/progression_models.dart';
import '../services/audio_service.dart';

class GameController extends ChangeNotifier {
  // Player profile & persistence metadata
  String _playerUsername = '';
  int _savedAt = 0;

  // Currencies
  int _coins = 5000;
  int _crystals = 25;
  int _kibble = 1000;
  int _level = 1;
  int _xp = 0;
  int _maxXp = 1200;

  static int maxXpForLevel(int level) {
    final raw = 1200 * pow(1.32, max(0, level - 1));
    return ((raw / 50).round() * 50).clamp(1200, 10000000);
  }

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

  // Lot expansion state per island (Lot 1 = Top/Bench [c < 13, r < 11], Lot 2 = Right [c >= 13])
  Map<String, Set<int>> _unlockedLotsByIsland = {};

  // Island surfaces state
  String _currentIslandId = IslandCatalog.starterIslandId;
  Set<String> _unlockedIslandIds = {IslandCatalog.starterIslandId};

  // Obstacles per island (clearable with gold)
  Map<String, List<ObstacleModel>> _obstaclesByIsland = {
    IslandCatalog.starterIslandId: ObstacleModel.defaultObstacles(),
  };
  String? _selectedObstacleId;

  Timer? _incomeTimer;

  // Interactive Dog Wizard walkthrough state
  bool _walkthroughActive = true;
  int _walkthroughStepIndex = 0;
  bool _walkthroughCompleted = false;
  bool _walkthroughRewardClaimed = false;
  bool _isIslandOverviewOpen = false;
  bool _isShopDialogOpen = false;
  bool _isSocialDialogOpen = false;
  bool _walkthroughCareCompleted = false;
  bool _walkthroughShopVisited = false;
  bool _walkthroughIslandsVisited = false;
  bool _walkthroughSocialVisited = false;
  final List<CelebrationEvent> _pendingCelebrations = [];

  // Claimed every-5-levels milestone rewards (e.g. {5, 10, 15})
  Set<int> _claimedLevelMilestones = {};

  // Water Station Hydration (10m hydrated + 60s 2x rush, 120s cooldown)
  int _lastHydrateAt = 0;
  int _hydrationRushEndsAt = 0;
  int _hydratedUntil = 0;

  // Breeding Den persistent session
  BreedingSession? _activeBreeding;

  // Shop offer cooldowns & purchase limits
  Map<String, ShopOfferState> _shopOfferStates = {};

  // Offline income tracking
  int _lastIncomeTickAt = 0;

  GameController({bool startWalkthrough = true}) {
    _walkthroughActive = startWalkthrough;
    _walkthroughCompleted = !startWalkthrough;
    if (SoundManager.instance.hasSavedAudioPrefs) {
      _bgmEnabled = SoundManager.instance.bgmEnabled;
      _bgmVolume = SoundManager.instance.bgmVolume;
      _sfxEnabled = SoundManager.instance.sfxEnabled;
      _sfxVolume = SoundManager.instance.sfxVolume;
    } else {
      SoundManager.instance.setBgmVolume(_bgmVolume, persist: false);
      SoundManager.instance.setSfxVolume(_sfxVolume, persist: false);
      SoundManager.instance.setBgmEnabled(_bgmEnabled, persist: false);
      SoundManager.instance.setSfxEnabled(_sfxEnabled, persist: false);
    }
    _startIncomeTimer();
  }

  /// Syncs locally persisted audio preferences from [SoundManager] into state.
  void syncAudioFromSoundManager() {
    if (!SoundManager.instance.hasSavedAudioPrefs) return;
    _bgmEnabled = SoundManager.instance.bgmEnabled;
    _bgmVolume = SoundManager.instance.bgmVolume;
    _sfxEnabled = SoundManager.instance.sfxEnabled;
    _sfxVolume = SoundManager.instance.sfxVolume;
    notifyListeners();
  }

  // Getters
  String get playerUsername => _playerUsername;
  bool get hasUsername => _playerUsername.trim().isNotEmpty;
  int get savedAt => _savedAt;
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
  bool isLotUnlockedForIsland(String islandId, int lotNumber) =>
      _unlockedLotsByIsland[islandId]?.contains(lotNumber) ?? false;
  bool get isLot1Unlocked => isLotUnlockedForIsland(_currentIslandId, 1);
  bool get isLot2Unlocked => isLotUnlockedForIsland(_currentIslandId, 2);
  bool get isLotExpansionUnlocked => isLot1Unlocked && isLot2Unlocked;
  String get currentIslandId => _currentIslandId;
  IslandDefinition get currentIsland => IslandCatalog.findById(_currentIslandId);
  Set<String> get unlockedIslandIds => Set.unmodifiable(_unlockedIslandIds);
  bool isIslandUnlocked(String id) => _unlockedIslandIds.contains(id);
  List<HabitatModel> get currentIslandHabitats =>
      _placedHabitats.where((h) => h.islandId == _currentIslandId).toList();
  List<ObstacleModel> obstaclesForIsland(String islandId) =>
      _obstaclesByIsland.putIfAbsent(
          islandId, () => ObstacleModel.defaultObstaclesForIsland(islandId));
  List<ObstacleModel> get currentIslandObstacles =>
      obstaclesForIsland(_currentIslandId);
  List<ObstacleModel> get obstacles => obstaclesForIsland(_currentIslandId);
  String? get selectedObstacleId => _selectedObstacleId;

  bool get walkthroughActive => _walkthroughActive;
  int get walkthroughStepIndex => _walkthroughStepIndex;
  int get walkthroughTotalSteps => WalkthroughStep.steps.length;
  bool get walkthroughCompleted => _walkthroughCompleted;
  bool get walkthroughRewardClaimed => _walkthroughRewardClaimed;
  bool get isIslandOverviewOpen => _isIslandOverviewOpen;
  bool get isShopDialogOpen => _isShopDialogOpen;
  bool get isSocialDialogOpen => _isSocialDialogOpen;
  bool get walkthroughCareCompleted => _walkthroughCareCompleted;
  bool get walkthroughShopVisited => _walkthroughShopVisited;
  bool get walkthroughIslandsVisited => _walkthroughIslandsVisited;
  bool get walkthroughSocialVisited => _walkthroughSocialVisited;
  CelebrationEvent? get currentCelebration =>
      _pendingCelebrations.isEmpty ? null : _pendingCelebrations.first;

  void dismissCelebration() {
    if (_pendingCelebrations.isEmpty) return;
    _pendingCelebrations.removeAt(0);
    notifyListeners();
  }

  void setShopDialogOpen(bool open) {
    if (_isShopDialogOpen == open) return;
    _isShopDialogOpen = open;
    notifyListeners();
  }

  void setSocialDialogOpen(bool open) {
    if (_isSocialDialogOpen == open) return;
    _isSocialDialogOpen = open;
    notifyListeners();
  }

  void markWalkthroughSocialVisited() {
    if (currentWalkthroughStep?.id == WalkthroughStepId.socialAndProgress &&
        !_walkthroughSocialVisited) {
      _walkthroughSocialVisited = true;
      SoundManager.instance.playWalkthroughStepComplete();
      notifyListeners();
    }
  }

  void markWalkthroughShopVisited() {
    if (currentWalkthroughStep?.id == WalkthroughStepId.shopAndGoals &&
        !_walkthroughShopVisited) {
      _walkthroughShopVisited = true;
      SoundManager.instance.playWalkthroughStepComplete();
      notifyListeners();
    }
  }

  void setIslandOverviewOpen(bool open) {
    if (_isIslandOverviewOpen == open) return;
    _isIslandOverviewOpen = open;
    if (!open &&
        currentWalkthroughStep?.id == WalkthroughStepId.exploreIslands &&
        !_walkthroughIslandsVisited) {
      _walkthroughIslandsVisited = true;
      SoundManager.instance.playWalkthroughStepComplete();
    }
    notifyListeners();
  }
  Set<int> get claimedLevelMilestones => Set.unmodifiable(_claimedLevelMilestones);

  /// Every-5-levels milestone list (always extends at least one milestone ahead of current level).
  List<LevelMilestone> get levelMilestones {
    final maxLevel = max(30, (((_level ~/ 5) + 2) * 5));
    return [
      for (int lvl = 5; lvl <= maxLevel; lvl += 5) LevelMilestone.forLevel(lvl),
    ];
  }

  int get nextMilestoneLevel => ((_level ~/ 5) + 1) * 5;

  bool isMilestoneClaimed(int milestoneLevel) =>
      _claimedLevelMilestones.contains(milestoneLevel);

  bool canClaimMilestone(int milestoneLevel) =>
      milestoneLevel > 0 &&
      milestoneLevel % 5 == 0 &&
      _level >= milestoneLevel &&
      !_claimedLevelMilestones.contains(milestoneLevel);

  int get unclaimedMilestoneCount {
    int count = 0;
    for (int lvl = 5; lvl <= _level; lvl += 5) {
      if (!_claimedLevelMilestones.contains(lvl)) count++;
    }
    return count;
  }

  bool claimLevelMilestone(int milestoneLevel) {
    if (!canClaimMilestone(milestoneLevel)) return false;
    final milestone = LevelMilestone.forLevel(milestoneLevel);
    _claimedLevelMilestones.add(milestoneLevel);
    _coins += milestone.rewardCoins;
    _crystals += milestone.rewardCrystals;
    _kibble += milestone.rewardKibble;
    SoundManager.instance.playQuestReward();
    notifyListeners();
    return true;
  }

  void setUsername(String name) {
    final cleaned = name.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return;
    _playerUsername =
        cleaned.length > 12 ? cleaned.substring(0, 12) : cleaned;
    SoundManager.instance.playClick();
    notifyListeners();
  }

  Map<String, dynamic> toJson() {
    _savedAt = DateTime.now().millisecondsSinceEpoch;
    return {
      'schemaVersion': 1,
      'playerUsername': _playerUsername,
      'savedAt': _savedAt,
      'coins': _coins,
      'crystals': _crystals,
      'kibble': _kibble,
      'level': _level,
      'xp': _xp,
      'maxXp': _maxXp,
      'sfxEnabled': _sfxEnabled,
      'bgmEnabled': _bgmEnabled,
      'sfxVolume': _sfxVolume,
      'bgmVolume': _bgmVolume,
      'gridVisible': _gridVisible,
      'isLot1Unlocked': isLotUnlockedForIsland(IslandCatalog.starterIslandId, 1),
      'isLot2Unlocked': isLotUnlockedForIsland(IslandCatalog.starterIslandId, 2),
      'unlockedLotsByIsland': _unlockedLotsByIsland.map(
        (k, v) => MapEntry(k, v.toList()..sort()),
      ),
      'currentIslandId': _currentIslandId,
      'unlockedIslandIds': _unlockedIslandIds.toList(),
      'walkthroughCompleted': _walkthroughCompleted,
      'walkthroughRewardClaimed': _walkthroughRewardClaimed,
      'claimedLevelMilestones': _claimedLevelMilestones.toList()..sort(),
      'lastHydrateAt': _lastHydrateAt,
      'hydrationRushEndsAt': _hydrationRushEndsAt,
      'hydratedUntil': _hydratedUntil,
      'activeBreeding': _activeBreeding?.toJson(),
      'shopOfferStates': _shopOfferStates.map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      'lastIncomeTickAt': _lastIncomeTickAt,
      'placedHabitats': _placedHabitats.map((h) => h.toJson()).toList(),
      'obstacles': obstaclesForIsland(IslandCatalog.starterIslandId)
          .map((o) => o.toJson())
          .toList(),
      'obstaclesByIsland': _obstaclesByIsland.map(
        (k, v) => MapEntry(k, v.map((o) => o.toJson()).toList()),
      ),
      'tasks': _tasks.map((t) => t.toJson()).toList(),
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    _playerUsername = (json['playerUsername'] as String? ?? '').trim();
    _savedAt = (json['savedAt'] as num?)?.toInt() ?? 0;
    _coins = (json['coins'] as num?)?.toInt() ?? 5000;
    _crystals = (json['crystals'] as num?)?.toInt() ?? 25;
    _kibble = (json['kibble'] as num?)?.toInt() ?? 1000;
    _level = (json['level'] as num?)?.toInt() ?? 1;
    _xp = (json['xp'] as num?)?.toInt() ?? 0;
    _maxXp = max(
      (json['maxXp'] as num?)?.toInt() ?? maxXpForLevel(_level),
      maxXpForLevel(_level),
    );

    _sfxEnabled = json['sfxEnabled'] as bool? ?? true;
    _lastHydrateAt = (json['lastHydrateAt'] as num?)?.toInt() ?? 0;
    _hydrationRushEndsAt = (json['hydrationRushEndsAt'] as num?)?.toInt() ?? 0;
    _hydratedUntil = (json['hydratedUntil'] as num?)?.toInt() ?? 0;
    _lastIncomeTickAt =
        (json['lastIncomeTickAt'] as num?)?.toInt() ?? _savedAt;

    final rawBreeding = json['activeBreeding'];
    if (rawBreeding is Map) {
      _activeBreeding = BreedingSession.fromJson(
        Map<String, dynamic>.from(rawBreeding),
      );
    } else {
      _activeBreeding = null;
    }

    _shopOfferStates = {};
    final rawOffers = json['shopOfferStates'];
    if (rawOffers is Map) {
      for (final entry in rawOffers.entries) {
        if (entry.value is Map) {
          _shopOfferStates[entry.key.toString()] = ShopOfferState.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    _bgmEnabled = json['bgmEnabled'] as bool? ?? true;
    _sfxVolume = (json['sfxVolume'] as num?)?.toDouble() ?? 0.8;
    _bgmVolume = (json['bgmVolume'] as num?)?.toDouble() ?? 0.5;
    _gridVisible = json['gridVisible'] as bool? ?? false;

    _unlockedLotsByIsland = {};
    final rawLotsByIsland = json['unlockedLotsByIsland'] as Map<String, dynamic>?;
    if (rawLotsByIsland != null) {
      for (final entry in rawLotsByIsland.entries) {
        final list = entry.value as List<dynamic>? ?? [];
        _unlockedLotsByIsland[entry.key] =
            list.map((e) => (e as num).toInt()).toSet();
      }
    } else {
      final legacyLot1 = json['isLot1Unlocked'] as bool? ?? false;
      final legacyLot2 = json['isLot2Unlocked'] as bool? ?? false;
      final starterLots = <int>{};
      if (legacyLot1) starterLots.add(1);
      if (legacyLot2) starterLots.add(2);
      if (starterLots.isNotEmpty) {
        _unlockedLotsByIsland[IslandCatalog.starterIslandId] = starterLots;
      }
    }
    _currentIslandId =
        json['currentIslandId'] as String? ?? IslandCatalog.starterIslandId;
    final rawIslands = json['unlockedIslandIds'] as List<dynamic>?;
    _unlockedIslandIds = rawIslands != null && rawIslands.isNotEmpty
        ? rawIslands.map((e) => e.toString()).toSet()
        : {IslandCatalog.starterIslandId};
    if (!_unlockedIslandIds.contains(_currentIslandId)) {
      _currentIslandId = IslandCatalog.starterIslandId;
    }

    _walkthroughCompleted = json['walkthroughCompleted'] as bool? ?? false;
    _walkthroughRewardClaimed =
        json['walkthroughRewardClaimed'] as bool? ?? false;
    _walkthroughActive = !_walkthroughCompleted;
    _walkthroughStepIndex = 0;

    final rawMilestones = json['claimedLevelMilestones'] as List<dynamic>?;
    _claimedLevelMilestones = rawMilestones != null
        ? rawMilestones.map((e) => (e as num).toInt()).toSet()
        : {};

    final rawHabitats = json['placedHabitats'] as List<dynamic>?;
    if (rawHabitats != null && rawHabitats.isNotEmpty) {
      _placedHabitats = rawHabitats
          .map((h) => HabitatModel.fromJson(Map<String, dynamic>.from(h as Map)))
          .toList();
    }

    _obstaclesByIsland = {};
    final rawObsByIsland = json['obstaclesByIsland'] as Map<String, dynamic>?;
    if (rawObsByIsland != null) {
      for (final entry in rawObsByIsland.entries) {
        final list = entry.value as List<dynamic>? ?? [];
        _obstaclesByIsland[entry.key] = ObstacleModel.sanitizeSavedObstacles(
          list
              .map(
                (o) => ObstacleModel.fromJson(
                  Map<String, dynamic>.from(o as Map),
                ),
              )
              .toList(),
          islandId: entry.key,
        );
      }
    } else {
      final rawObstacles = json['obstacles'] as List<dynamic>?;
      if (rawObstacles != null) {
        _obstaclesByIsland[IslandCatalog.starterIslandId] =
            ObstacleModel.sanitizeSavedObstacles(
              rawObstacles
                  .map(
                    (o) => ObstacleModel.fromJson(
                      Map<String, dynamic>.from(o as Map),
                    ),
                  )
                  .toList(),
            );
      } else {
        _obstaclesByIsland[IslandCatalog.starterIslandId] =
            ObstacleModel.defaultObstacles();
      }
    }

    final defaults = TaskModel.defaultTasks();
    final rawTasks = json['tasks'] as List<dynamic>?;
    if (rawTasks != null && rawTasks.isNotEmpty) {
      final saved = rawTasks
          .map((t) => TaskModel.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList();
      final byId = {for (final t in saved) t.id: t};
      _tasks = defaults.map((def) {
        final match = byId[def.id];
        if (match != null && match.type == def.type) {
          def.progress = match.progress;
          def.done = match.done;
        }
        return def;
      }).toList();
    } else {
      _tasks = defaults;
    }
    _syncTasksFromState();

    _selectedHabitatId = null;
    _selectedObstacleId = null;

    if (SoundManager.instance.hasSavedAudioPrefs) {
      _bgmEnabled = SoundManager.instance.bgmEnabled;
      _bgmVolume = SoundManager.instance.bgmVolume;
      _sfxEnabled = SoundManager.instance.sfxEnabled;
      _sfxVolume = SoundManager.instance.sfxVolume;
    } else {
      SoundManager.instance.setBgmVolume(_bgmVolume, persist: false);
      SoundManager.instance.setSfxVolume(_sfxVolume, persist: false);
      SoundManager.instance.setBgmEnabled(_bgmEnabled, persist: false);
      SoundManager.instance.setSfxEnabled(_sfxEnabled, persist: false);
    }

    // Resolve any baking/income progress completed while the app was closed
    for (final h in _placedHabitats) {
      for (final d in h.dogs) {
        d.isInBreeding = _activeBreeding != null &&
            (d.id == _activeBreeding!.parent1Id ||
                d.id == _activeBreeding!.parent2Id);
      }
    }
    tickIncome();
    notifyListeners();
  }

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
    _walkthroughCareCompleted = false;
    _walkthroughShopVisited = false;
    _walkthroughIslandsVisited = false;
    _walkthroughSocialVisited = false;
    SoundManager.instance.playWalkthroughStepComplete();
    notifyListeners();
  }

  void skipWalkthrough() {
    if (!_walkthroughActive) return;
    _walkthroughActive = false;
    _walkthroughCompleted = true;
    _walkthroughCareCompleted = false;
    _walkthroughShopVisited = false;
    _walkthroughIslandsVisited = false;
    _walkthroughSocialVisited = false;
    SoundManager.instance.playClick();
    notifyListeners();
  }

  void restartWalkthrough() {
    _selectedHabitatId = null;
    _selectedObstacleId = null;
    _walkthroughStepIndex = 0;
    _walkthroughCareCompleted = false;
    _walkthroughShopVisited = false;
    _walkthroughIslandsVisited = false;
    _walkthroughSocialVisited = false;
    _walkthroughActive = true;
    SoundManager.instance.playWalkthroughPop();
    notifyListeners();
  }

  void _completeWalkthrough({required bool grantReward}) {
    _walkthroughActive = false;
    _walkthroughCompleted = true;
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
    if (col < 13 && row < 11) return isLot1Unlocked; // Expansion Lot 1 (Top-left / Bench)
    return isLot2Unlocked; // Expansion Lot 2 (Top-right, locked)
  }

  ObstacleModel? get selectedObstacle {
    if (_selectedObstacleId == null) return null;
    try {
      return currentIslandObstacles.firstWhere((o) => o.id == _selectedObstacleId);
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
    if (isLot1Unlocked) return false;
    const cost = 2500;
    if (_coins < cost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= cost;
    _unlockedLotsByIsland.putIfAbsent(_currentIslandId, () => {}).add(1);
    _addXp(120);
    SoundManager.instance.playLevelUp();
    notifyListeners();
    return true;
  }

  bool unlockLot2() {
    if (isLot2Unlocked) return false;
    const cost = 2500;
    if (_coins < cost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= cost;
    _unlockedLotsByIsland.putIfAbsent(_currentIslandId, () => {}).add(2);
    _addXp(120);
    SoundManager.instance.playLevelUp();
    notifyListeners();
    return true;
  }

  bool unlockLotExpansion() {
    if (!isLot1Unlocked) return unlockLot1();
    if (!isLot2Unlocked) return unlockLot2();
    return false;
  }

  bool unlockIsland(String islandId) {
    if (_unlockedIslandIds.contains(islandId)) return false;
    final island = IslandCatalog.findById(islandId);
    if (_level < island.requiredLevel ||
        !canAfford(island.costCoins, island.costCrystals)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= island.costCoins;
    _crystals -= island.costCrystals;
    _unlockedIslandIds.add(islandId);
    _currentIslandId = islandId;
    _selectedHabitatId = null;
    _selectedObstacleId = null;
    _addXp(200);
    SoundManager.instance.playLevelUp();
    notifyListeners();
    return true;
  }

  void switchIsland(String islandId) {
    if (!_unlockedIslandIds.contains(islandId)) return;
    if (_currentIslandId == islandId) return;
    _currentIslandId = islandId;
    _selectedHabitatId = null;
    _selectedObstacleId = null;
    SoundManager.instance.playClick();
    notifyListeners();
  }

  bool startClearingObstacle(String obstacleId) {
    final list = obstaclesForIsland(_currentIslandId);
    final obs = list.firstWhere(
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
    final list = obstaclesForIsland(_currentIslandId);
    final idx = list.indexWhere((o) => o.id == obstacleId);
    if (idx == -1) return false;

    final obs = list[idx];
    _addXp(obs.xpReward);
    list.removeAt(idx);
    if (_selectedObstacleId == obstacleId) {
      _selectedObstacleId = null;
    }
    SoundManager.instance.playChop();
    notifyListeners();
    return true;
  }

  bool speedUpClearingObstacle(String obstacleId, int crystalsCost) {
    final list = obstaclesForIsland(_currentIslandId);
    final obs = list.firstWhere(
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
    final hydrated = isIslandHydrated;
    final rushActive = isHydrationRushActive;

    final elapsedMs = _lastIncomeTickAt > 0
        ? max(10000, now - _lastIncomeTickAt)
        : 10000;
    final ticks = (elapsedMs ~/ 10000).clamp(1, 8640); // Up to 24h offline
    _lastIncomeTickAt = now;

    if (_activeBreeding != null &&
        _activeBreeding!.isReady &&
        !_activeBreeding!.readyNotified) {
      _activeBreeding!.readyNotified = true;
      SoundManager.instance.playLevelUp();
      changed = true;
    }

    for (final h in _placedHabitats) {
      if (h.underConstruction &&
          h.constructionEndsAt != null &&
          now >= h.constructionEndsAt!) {
        h.underConstruction = false;
        h.constructionEndsAt = null;
        _addXp(50);
        SoundManager.instance.playLevelUp();
        changed = true;
      }
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
        if (h.dogs.isEmpty) {
          if (h.coinsAccumulated != 0 || h.readyToCollect) {
            h.coinsAccumulated = 0;
            h.readyToCollect = false;
            changed = true;
          }
        } else if (!h.underConstruction && h.coinsAccumulated < h.maxCoins) {
          final dogRate = h.dogs.fold<int>(
              0, (sum, d) => sum + (30 + (d.level * 15)));
          final levelMultiplier = 1.0 + (h.level - 1) * 0.15;
          final baseAdd = max(25, ((dogRate / 4) * levelMultiplier).round());
          var adjustedAdd = hydrated
              ? (baseAdd * 1.15).round()
              : max(10, (baseAdd * 0.5).round());
          if (rushActive && ticks == 1) {
            adjustedAdd *= 2;
          }
          final totalAdd = adjustedAdd * ticks;
          final add = min(h.maxCoins - h.coinsAccumulated, totalAdd);
          if (add > 0) {
            h.coinsAccumulated += add;
            if (h.coinsAccumulated >= (h.maxCoins * 0.35).floor()) {
              h.readyToCollect = true;
            }
            changed = true;
          }
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

    _recordTaskProgress('Bake');
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

  bool get isIslandHydrated =>
      DateTime.now().millisecondsSinceEpoch < _hydratedUntil;

  bool get isHydrationRushActive =>
      DateTime.now().millisecondsSinceEpoch < _hydrationRushEndsAt;

  int get hydrationRushRemainingSeconds {
    final diff = _hydrationRushEndsAt - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  static const int hydrationCooldownMs = 2 * 60 * 60 * 1000; // 2 hours
  static const int hydrationEffectDurationMs = 60 * 1000; // 1 minute

  int get hydrationCooldownRemainingSeconds {
    final endsAt = _lastHydrateAt + hydrationCooldownMs;
    final diff = endsAt - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  bool get canHydratePark => hydrationCooldownRemainingSeconds == 0;

  /// Activates a 1-minute 2x Hydration Rush across the island with a 2-hour
  /// cooldown, awarding instant bonus coins + XP. Returns coins awarded, or 0
  /// if still on cooldown.
  int hydratePark() {
    if (!canHydratePark) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastHydrateAt = now;
    _hydrationRushEndsAt = now + hydrationEffectDurationMs;
    _hydratedUntil = now + hydrationEffectDurationMs;

    final totalDogs = currentIslandHabitats.fold<int>(
      0,
      (sum, h) => sum + h.dogs.length,
    );
    final bonusCoins = max(25, totalDogs * 15);
    _coins += bonusCoins;
    _addXp(25);
    recordCareTask();
    SoundManager.instance.playQuestReward();
    notifyListeners();
    return bonusCoins;
  }

  bool collectCoins(String habitatId) {
    final h = _placedHabitats.firstWhere((it) => it.id == habitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (h.id.isEmpty || h.dogs.isEmpty || h.coinsAccumulated <= 0) return false;

    _coins += h.coinsAccumulated;
    h.coinsAccumulated = 0;
    h.readyToCollect = false;
    h.lastCollectTime = DateTime.now().millisecondsSinceEpoch;
    _recordTaskProgress('Collect');
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

  // ── Building Ownership Limits & Unique Restrictions ──
  int getBuildingOwnedCount(String catalogId) {
    return _placedHabitats.where((h) => h.habitatId == catalogId).length;
  }

  int getBuildingLimit(String catalogId) {
    final item = HabitatCatalog.findById(catalogId);
    if (item != null && item.isUnique) return 1;
    if (catalogId == 'breeding-den') return 1;
    if (catalogId == 'water-station') {
      return _level >= 8 ? 2 : 1;
    }
    if (catalogId == 'legendary-realm') {
      return _level >= 25 ? 2 : 1;
    }
    if (item != null && item.type == 'decor') {
      if (_level >= 10) return 6;
      if (_level >= 5) return 4;
      return 2;
    }
    // Habitats and Dogfood Factory scale with player level
    if (_level >= 15) return 4;
    if (_level >= 10) return 3;
    if (_level >= 5) return 2;
    return 1;
  }

  int? nextBuildingSlotUnlockLevel(String catalogId) {
    final item = HabitatCatalog.findById(catalogId);
    if (item != null && item.isUnique) return null;
    if (catalogId == 'breeding-den') return null;
    if (catalogId == 'water-station') {
      return _level < 8 ? 8 : null;
    }
    if (catalogId == 'legendary-realm') {
      return _level < 25 ? 25 : null;
    }
    if (item != null && item.type == 'decor') {
      if (_level < 5) return 5;
      if (_level < 10) return 10;
      return null;
    }
    if (_level < 5) return 5;
    if (_level < 10) return 10;
    if (_level < 15) return 15;
    return null;
  }

  bool canPurchaseBuilding(HabitatCatalogItem item) {
    if (_level < item.requiredLevel) return false;
    return getBuildingOwnedCount(item.id) < getBuildingLimit(item.id);
  }

  // ── Building Upgrades ──
  bool canUpgradeHabitat(HabitatModel hab) {
    final item = HabitatCatalog.findById(hab.habitatId);
    if (item == null) return false;
    if (hab.underConstruction) return false;
    if (hab.level >= item.maxUpgradeLevel) return false;
    if (_level < item.upgradeRequiredPlayerLevel(hab.level)) return false;
    return _coins >= item.upgradeCostForLevel(hab.level);
  }

  bool upgradeHabitat(String habitatId) {
    final idx = _placedHabitats.indexWhere((h) => h.id == habitatId);
    if (idx == -1) return false;
    final hab = _placedHabitats[idx];
    final item = HabitatCatalog.findById(hab.habitatId);
    if (item == null || hab.underConstruction) return false;
    if (hab.level >= item.maxUpgradeLevel) return false;

    final reqLvl = item.upgradeRequiredPlayerLevel(hab.level);
    final cost = item.upgradeCostForLevel(hab.level);
    if (_level < reqLvl || _coins < cost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= cost;
    hab.level += 1;
    hab.maxCoins = item.maxCoinsForLevel(hab.level);
    hab.maxDogfood = item.maxDogfoodForLevel(hab.level);

    final durationSec = item.upgradeDurationForLevel(hab.level - 1);
    final now = DateTime.now().millisecondsSinceEpoch;
    hab.underConstruction = true;
    hab.constructionDuration = durationSec;
    hab.constructionEndsAt = now + durationSec * 1000;

    _addXp(100 * hab.level);
    SoundManager.instance.playBuild();
    notifyListeners();
    return true;
  }

  // ── Shop Offer Cooldowns & Purchase Limits ──
  ShopOfferState getShopOfferState(String offerId) {
    final state = _shopOfferStates.putIfAbsent(
      offerId,
      () => ShopOfferState(offerId: offerId),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    if (state.cooldownEndsAt > 0 && now >= state.cooldownEndsAt) {
      state.purchasesInWindow = 0;
      state.cooldownEndsAt = 0;
      state.windowStartedAt = 0;
    }
    return state;
  }

  int getShopOfferRemainingStock(String offerId) {
    final rule = ShopOfferRule.findById(offerId);
    if (rule == null) return 999;
    final state = getShopOfferState(offerId);
    if (state.isOnCooldown()) return 0;
    return max(0, rule.maxPurchasesPerWindow - state.purchasesInWindow);
  }

  int getShopOfferCooldownSeconds(String offerId) {
    return getShopOfferState(offerId).remainingCooldownSeconds();
  }

  bool isShopOfferAvailable(String offerId) {
    final rule = ShopOfferRule.findById(offerId);
    if (rule == null) return true;
    if (_level < rule.requiredLevel) return false;
    return getShopOfferRemainingStock(offerId) > 0;
  }

  bool purchaseShopOffer(
    String offerId, {
    int costCoins = 0,
    int costCrystals = 0,
    int addCoins = 0,
    int addCrystals = 0,
    int addKibble = 0,
  }) {
    final rule = ShopOfferRule.findById(offerId);
    if (rule != null && !isShopOfferAvailable(offerId)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
    if (!canAfford(costCoins, costCrystals)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= costCoins;
    _crystals -= costCrystals;
    _coins += addCoins;
    _crystals += addCrystals;
    _kibble += addKibble;

    if (rule != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = getShopOfferState(offerId);
      if (state.windowStartedAt == 0) {
        state.windowStartedAt = now;
      }
      state.purchasesInWindow += 1;
      if (state.purchasesInWindow >= rule.maxPurchasesPerWindow) {
        state.cooldownEndsAt = now + rule.cooldownSeconds * 1000;
      }
    }

    SoundManager.instance.playQuestReward();
    notifyListeners();
    return true;
  }

  // ── Persistent Breeding System ──
  BreedingSession? get activeBreeding => _activeBreeding;
  bool get isBreedingInProgress =>
      _activeBreeding != null && !_activeBreeding!.isReady;
  bool get isBreedingReadyToClaim =>
      _activeBreeding != null && _activeBreeding!.isReady;
  bool get hasBuiltBreedingDen => _placedHabitats.any(
        (h) => h.habitatId == 'breeding-den' && !h.underConstruction,
      );

  DogModel? findDogByIdGlobal(String id) {
    for (final h in _placedHabitats) {
      for (final d in h.dogs) {
        if (d.id == id) return d;
      }
    }
    return null;
  }

  bool startBreeding(DogModel p1, DogModel p2, {int costCoins = 500}) {
    if (_activeBreeding != null) return false;
    if (!hasBuiltBreedingDen) return false;
    if (p1.id == p2.id) return false;
    if (!p1.isAdult || p1.level < 12 || !p2.isAdult || p2.level < 12) {
      return false;
    }
    if (p1.isOnBreedingCooldown || p2.isOnBreedingCooldown) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
    if (DogStageInfo.getBreedPrefix(p1.breedId) !=
        DogStageInfo.getBreedPrefix(p2.breedId)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
    if (_coins < costCoins) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= costCoins;
    _addXp(100);

    final now = DateTime.now().millisecondsSinceEpoch;
    final rarity = DogStageInfo.getRarityForBreed(p1.breedId);
    final breedingEndsAt = now + rarity.breedingDurationSeconds * 1000;
    final recoveryEndsAt =
        breedingEndsAt + rarity.breedingRecoverySeconds * 1000;

    p1.breedingCooldownEndsAt = recoveryEndsAt;
    p2.breedingCooldownEndsAt = recoveryEndsAt;
    p1.isInBreeding = true;
    p2.isInBreeding = true;

    _activeBreeding = BreedingSession(
      parent1Id: p1.id,
      parent2Id: p2.id,
      parent1BreedId: p1.breedId,
      parent2BreedId: p2.breedId,
      resultBreedId: p1.breedId,
      resultElement: p1.element,
      startedAt: now,
      endsAt: breedingEndsAt,
    );

    SoundManager.instance.playBake();
    notifyListeners();
    return true;
  }

  bool speedUpBreeding() {
    final session = _activeBreeding;
    if (session == null || session.isReady) return false;
    final cost = speedUpCostForSeconds(session.remainingSeconds);
    if (_crystals < cost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _crystals -= cost;
    session.endsAt = DateTime.now().millisecondsSinceEpoch;
    session.readyNotified = true;
    SoundManager.instance.playLevelUp();
    SoundManager.instance.playDogBark(isPuppy: true, force: true);
    notifyListeners();
    return true;
  }

  void _releaseBreedingParents() {
    final session = _activeBreeding;
    if (session == null) return;
    for (final h in _placedHabitats) {
      for (final d in h.dogs) {
        if (d.id == session.parent1Id || d.id == session.parent2Id) {
          d.isInBreeding = false;
        }
      }
    }
  }

  String? claimBredPuppyToHabitat(String habitatId) {
    final session = _activeBreeding;
    if (session == null || !session.isReady) return null;
    final habName = addBredPuppyToHabitat(
      session.resultBreedId,
      session.resultElement,
      habitatId,
    );
    if (habName == null) return null;
    _releaseBreedingParents();
    _activeBreeding = null;
    notifyListeners();
    return habName;
  }

  bool sellBredPuppy(int sellCoins) {
    final session = _activeBreeding;
    if (session == null || !session.isReady) return false;
    _coins += sellCoins;
    _releaseBreedingParents();
    _activeBreeding = null;
    SoundManager.instance.playQuestReward();
    notifyListeners();
    return true;
  }

  bool placeHabitat(HabitatCatalogItem item, int col, int row) {
    if (!IslandCatalog.isItemAllowedOnIsland(item, _currentIslandId)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
    if (!canPurchaseBuilding(item)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
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
      islandId: _currentIslandId,
      name: item.name,
      col: col,
      row: row,
      sizeW: item.sizeW,
      sizeH: item.sizeH,
      maxCoins: item.maxCoins,
      maxDogfood: item.maxDogfood,
      underConstruction: true,
      constructionDuration: item.buildDurationSeconds,
      constructionEndsAt: now + item.buildDurationSeconds * 1000,
    );

    _placedHabitats.add(newHab);
    _selectedHabitatId = newHab.id;
    _recordTaskProgress('Build');
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

  static int speedUpCostForSeconds(int remainingSeconds) {
    if (remainingSeconds <= 120) return 2;
    if (remainingSeconds <= 900) return 5;
    if (remainingSeconds <= 7200) return 10;
    return 20;
  }

  bool speedUpConstruction(String habitatId, {int? crystalsCost}) {
    final hab = _placedHabitats.firstWhere(
      (h) => h.id == habitatId,
      orElse: () => HabitatModel(
        id: '',
        habitatId: '',
        name: '',
        col: 0,
        row: 0,
      ),
    );
    if (hab.id.isEmpty || !hab.underConstruction) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingSec =
        max(0, (((hab.constructionEndsAt ?? 0) - now) / 1000).ceil());
    final cost = crystalsCost ?? speedUpCostForSeconds(remainingSec);
    if (_crystals < cost) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _crystals -= cost;
    completeConstruction(habitatId);
    return true;
  }

  bool adoptDog(DogCatalogItem dogItem, String targetHabitatId) {
    if (_level < dogItem.requiredLevel || dogItem.isLocked) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
    if (!canAfford(dogItem.costCoins, dogItem.costCrystals)) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    final hab = _placedHabitats.firstWhere((h) => h.id == targetHabitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (hab.id.isEmpty ||
        hab.type != 'habitat' ||
        hab.underConstruction ||
        hab.dogs.length >= 4) {
      SoundManager.instance.playSadWhimper();
      return false;
    }
    if (!HabitatCatalog.isHabitatCompatible(
      habitatCatalogId: hab.habitatId,
      breedId: dogItem.id,
      element: dogItem.element,
      preferredHabitatId: dogItem.habitatId,
    )) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    _coins -= dogItem.costCoins;
    _crystals -= dogItem.costCrystals;
    _addXp(200);

    final newDog = DogModel(
      id: 'dog_${DateTime.now().millisecondsSinceEpoch}',
      breedId: dogItem.id,
      name: _pickUniqueDogName(dogItem.id),
      level: 1,
      feedProgress: 0,
      stage: 'Puppy',
      element: dogItem.element,
      habitatId: hab.id,
      habitatName: hab.name,
    );

    hab.dogs.add(newDog);
    _recordTaskProgress('Build');
    SoundManager.instance.playLevelUp();
    SoundManager.instance.playDogBark(isPuppy: true, force: true);
    notifyListeners();
    return true;
  }

  /// Whether any built habitat on the current island has room (< 4 dogs) for a new puppy.
  bool get hasHabitatSpace => currentIslandHabitats.any(
        (h) => h.type == 'habitat' && !h.underConstruction && h.dogs.length < 4,
      );

  /// Places a newly bred purebred puppy into a compatible habitat with space (< 4 dogs).
  /// Returns the destination habitat name, or null if none available.
  String? addBredPuppy(String breedId, String element) {
    final openHabitats = _placedHabitats
        .where(
          (h) =>
              h.type == 'habitat' &&
              !h.underConstruction &&
              h.dogs.length < 4 &&
              HabitatCatalog.isHabitatCompatible(
                habitatCatalogId: h.habitatId,
                breedId: breedId,
                element: element,
              ),
        )
        .toList();
    if (openHabitats.isEmpty) return null;

    final hab = openHabitats.firstWhere(
      (h) => h.islandId == _currentIslandId,
      orElse: () => openHabitats.first,
    );

    final newDog = DogModel(
      id: 'dog_${DateTime.now().millisecondsSinceEpoch}',
      breedId: breedId,
      name: _pickUniqueDogName(breedId),
      level: 1,
      feedProgress: 0,
      stage: 'Puppy',
      element: element,
      habitatId: hab.id,
      habitatName: hab.name,
    );

    hab.dogs.add(newDog);
    _recordTaskProgress('Build');
    notifyListeners();
    return hab.name;
  }

  String? addBredPuppyToHabitat(
    String breedId,
    String element,
    String habitatId,
  ) {
    final idx = _placedHabitats.indexWhere(
      (h) =>
          h.id == habitatId &&
          h.type == 'habitat' &&
          !h.underConstruction &&
          h.dogs.length < 4 &&
          HabitatCatalog.isHabitatCompatible(
            habitatCatalogId: h.habitatId,
            breedId: breedId,
            element: element,
          ),
    );
    if (idx == -1) return null;
    final hab = _placedHabitats[idx];

    final newDog = DogModel(
      id: 'dog_${DateTime.now().millisecondsSinceEpoch}',
      breedId: breedId,
      name: _pickUniqueDogName(breedId),
      level: 1,
      feedProgress: 0,
      stage: 'Puppy',
      element: element,
      habitatId: hab.id,
      habitatName: hab.name,
    );

    hab.dogs.add(newDog);
    _recordTaskProgress('Build');
    notifyListeners();
    return hab.name;
  }

  static const List<String> _dogNamePool = [
    'Bella', 'Charlie', 'Luna', 'Cooper', 'Daisy', 'Milo', 'Lucy', 'Rocky',
    'Sadie', 'Buddy', 'Molly', 'Bear', 'Bailey', 'Duke', 'Lola', 'Leo',
    'Zoe', 'Buster', 'Ruby', 'Tucker', 'Penny', 'Oliver', 'Rosie', 'Jack',
    'Coco', 'Toby', 'Chloe', 'Zeus', 'Nala', 'Finn', 'Stella', 'Shadow',
    'Nova', 'Bruno', 'Mochi', 'Koda', 'Max',
  ];

  /// Picks a dog name not currently used by any owned dog, with breed-flavored
  /// options first so adopted and bred dogs don't repeat names like "Max".
  String _pickUniqueDogName(String breedId) {
    final used = _placedHabitats
        .expand((h) => h.dogs)
        .map((d) => d.name.trim().toLowerCase())
        .toSet();
    final b = breedId.toLowerCase();
    final themed = <String>[
      if (b.contains('husky') || b.contains('samoyed')) ...['Storm', 'Frost', 'Blizzard', 'Snowy'],
      if (b.contains('shiba')) ...['Kiba', 'Yuki', 'Hachi', 'Sora'],
      if (b.contains('pharaoh')) ...['Anubis', 'Sahara', 'Cairo', 'Sunny'],
      if (b.contains('astral')) ...['Comet', 'Orion', 'Nebula', 'Astro'],
      if (b.contains('chronos')) ...['Atlas', 'Chrono', 'Titan', 'Echo'],
    ];
    final candidates = [...themed, ..._dogNamePool];
    final available =
        candidates.where((n) => !used.contains(n.toLowerCase())).toList();
    if (available.isNotEmpty) {
      return available[Random().nextInt(available.length)];
    }
    final base = _dogNamePool[Random().nextInt(_dogNamePool.length)];
    var suffix = 2;
    while (used.contains('$base $suffix'.toLowerCase())) {
      suffix++;
    }
    return '$base $suffix';
  }

  /// Formats currency with commas (e.g. `12,500`) or rounded millions (`1.5M`, `2M`).
  static String formatCoins(int n) {
    if (n >= 1000000) {
      final m = (n / 1000000).toStringAsFixed(1);
      return '${m.endsWith('.0') ? m.substring(0, m.length - 2) : m}M';
    }
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
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
            _recordTaskProgress('Feed');
            SoundManager.instance.playFeed();

            d.feedProgress += 1;
            if (d.feedProgress >= 4) {
              final previousStage = d.stage;
              d.feedProgress = 0;
              d.level += 1;
              _addXp(info.xpBonusOnLevelUp);
              if (d.level >= 12) {
                d.stage = 'Adult';
              } else if (d.level >= 6) {
                d.stage = 'Young';
              }
              if (d.stage != previousStage) {
                _pendingCelebrations.add(
                  DogEvolutionCelebration.fromDog(
                    d,
                    previousStage: previousStage,
                  ),
                );
              }
              SoundManager.instance.playLevelUp();
              SoundManager.instance.playDogBark(isPuppy: d.stage == 'Puppy', force: true);
            }
            if (currentWalkthroughStep?.id == WalkthroughStepId.feedDog) {
              final nextCost = DogStageInfo.getInfo(d).kibbleCostPerFeed;
              if (_kibble < nextCost) {
                _walkthroughStepIndex += 1;
                _walkthroughCareCompleted = false;
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
          if (h.dogs.isEmpty) {
            h.coinsAccumulated = 0;
            h.readyToCollect = false;
          }
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
    if (toHab.type != 'habitat' ||
        toHab.underConstruction ||
        toHab.dogs.length >= 4) {
      return false;
    }

    final dogIdx = fromHab.dogs.indexWhere((d) => d.id == dogId);
    if (dogIdx == -1) return false;
    final candidate = fromHab.dogs[dogIdx];
    if (!HabitatCatalog.isHabitatCompatible(
      habitatCatalogId: toHab.habitatId,
      breedId: candidate.breedId,
      element: candidate.element,
    )) {
      SoundManager.instance.playSadWhimper();
      return false;
    }

    final dog = fromHab.dogs.removeAt(dogIdx);
    if (fromHab.dogs.isEmpty) {
      fromHab.coinsAccumulated = 0;
      fromHab.readyToCollect = false;
    }
    dog.habitatId = toHab.id;
    dog.habitatName = toHab.name;
    toHab.dogs.add(dog);

    SoundManager.instance.playLevelUp();
    SoundManager.instance.playDogBark(isPuppy: dog.isPuppy);
    notifyListeners();
    return true;
  }

  void _syncTasksFromState() {
    final allDogs = _placedHabitats.expand((h) => h.dogs).toList();
    if (allDogs.any((d) => d.feedProgress > 0 || d.level > 1)) {
      _recordTaskProgress('Feed');
    }
    if (_placedHabitats.any(
        (h) => h.isFactory && (h.isBaking || h.readyToCollectDogfood || h.dogfoodAccumulated > 0))) {
      _recordTaskProgress('Bake');
    }
    if (_placedHabitats.length > 2 || allDogs.length > 1) {
      _recordTaskProgress('Build');
    }
  }

  void recordCareTask() {
    _recordTaskProgress('Care');
    if (currentWalkthroughStep?.id == WalkthroughStepId.batheDog &&
        !_walkthroughCareCompleted) {
      _walkthroughCareCompleted = true;
      SoundManager.instance.playWalkthroughStepComplete();
    }
    notifyListeners();
  }

  void _recordTaskProgress(String type, [int amount = 1]) {
    for (final t in _tasks) {
      if (t.type == type && !t.done && t.progress < t.target) {
        t.progress = min(t.target, t.progress + amount);
      }
    }
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
    _recordTaskProgress('Care');
    SoundManager.instance.playPet();
    SoundManager.instance.playDogBark(isPuppy: true);
    notifyListeners();
  }

  void completeTask(String taskId) {
    for (final t in _tasks) {
      if (t.id == taskId && !t.done && t.isCompleted) {
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
      _maxXp = maxXpForLevel(_level);
      final levelUpCelebration = PlayerLevelUpCelebration.forLevel(_level);
      if (levelUpCelebration.unlockedItems.isNotEmpty) {
        _pendingCelebrations.add(levelUpCelebration);
      }
      // Milestone rewards are claimable every 5 levels (Levels 5, 10, 15, ...)
      SoundManager.instance.playLevelUp();
    }
  }

  @override
  void dispose() {
    _incomeTimer?.cancel();
    super.dispose();
  }
}
