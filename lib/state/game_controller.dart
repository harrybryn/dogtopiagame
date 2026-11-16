import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/dog_model.dart';
import '../models/habitat_model.dart';
import '../models/task_model.dart';
import '../models/habitat_catalog.dart';
import '../models/dog_evolution.dart';
import '../models/obstacle_model.dart';

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

  // Grid visibility
  bool _gridVisible = false;

  // World objects
  List<HabitatModel> _placedHabitats = [
    HabitatModel.createDefaultGardenPark(),
  ];

  // Active tasks
  List<TaskModel> _tasks = TaskModel.defaultTasks();

  // Selected habitat for HUD interaction
  String? _selectedHabitatId;

  // Lot expansion state (false = Eastern half is locked with FOR SALE sign)
  bool _isLotExpansionUnlocked = false;

  // Obstacles scattered across the island (clearable with gold)
  List<ObstacleModel> _obstacles = ObstacleModel.defaultObstacles();
  String? _selectedObstacleId;

  Timer? _incomeTimer;

  GameController() {
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
  bool get gridVisible => _gridVisible;
  List<HabitatModel> get placedHabitats => _placedHabitats;
  List<TaskModel> get tasks => _tasks;
  String? get selectedHabitatId => _selectedHabitatId;
  bool get isLotExpansionUnlocked => _isLotExpansionUnlocked;
  List<ObstacleModel> get obstacles => _obstacles;
  String? get selectedObstacleId => _selectedObstacleId;

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
    }
    notifyListeners();
  }

  bool unlockLotExpansion() {
    if (_isLotExpansionUnlocked) return false;
    const cost = 2500;
    if (_coins < cost) return false;

    _coins -= cost;
    _isLotExpansionUnlocked = true;
    _addXp(120);
    notifyListeners();
    return true;
  }

  bool startClearingObstacle(String obstacleId) {
    final obs = _obstacles.firstWhere(
      (o) => o.id == obstacleId,
      orElse: () => ObstacleModel(
          id: '', type: '', name: '', col: 0, row: 0, imageAsset: ''),
    );
    if (obs.id.isEmpty || obs.isClearing) return false;
    if (_coins < obs.clearCost) return false;

    _coins -= obs.clearCost;
    obs.isClearing = true;
    obs.clearingEndsAt =
        DateTime.now().millisecondsSinceEpoch + obs.clearDuration * 1000;
    _selectedObstacleId = obs.id;
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
    if (_crystals < crystalsCost) return false;

    _crystals -= crystalsCost;
    obs.clearingEndsAt = DateTime.now().millisecondsSinceEpoch;
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
    }
    notifyListeners();
  }

  void toggleGrid() {
    _gridVisible = !_gridVisible;
    notifyListeners();
  }

  void setGridVisible(bool visible) {
    _gridVisible = visible;
    notifyListeners();
  }

  void toggleSfx() {
    _sfxEnabled = !_sfxEnabled;
    notifyListeners();
  }

  void toggleBgm() {
    _bgmEnabled = !_bgmEnabled;
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

    for (final h in _placedHabitats) {
      if (h.habitatId == 'dogfood-factory') {
        final maxFood = h.maxDogfood > 0 ? h.maxDogfood : 300;
        if (h.dogfoodAccumulated < maxFood) {
          final add = min(maxFood - h.dogfoodAccumulated, 25);
          h.dogfoodAccumulated += add;
          if (h.dogfoodAccumulated >= 25) {
            h.readyToCollectDogfood = true;
          }
          changed = true;
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

  bool collectCoins(String habitatId) {
    final h = _placedHabitats.firstWhere((it) => it.id == habitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (h.id.isEmpty || h.coinsAccumulated <= 0) return false;

    _coins += h.coinsAccumulated;
    h.coinsAccumulated = 0;
    h.readyToCollect = false;
    h.lastCollectTime = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
    return true;
  }

  bool collectDogfood(String habitatId) {
    final h = _placedHabitats.firstWhere((it) => it.id == habitatId,
        orElse: () => HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0));
    if (h.id.isEmpty || h.dogfoodAccumulated <= 0) return false;

    _kibble += h.dogfoodAccumulated;
    h.dogfoodAccumulated = 0;
    h.readyToCollectDogfood = false;
    notifyListeners();
    return true;
  }

  bool canAfford(int costCoins, int costCrystals) {
    return _coins >= costCoins && _crystals >= costCrystals;
  }

  bool placeHabitat(HabitatCatalogItem item, int col, int row) {
    if (!canAfford(item.costCoins, item.costCrystals)) return false;

    _coins -= item.costCoins;
    _crystals -= item.costCrystals;
    _addXp(150);

    final now = DateTime.now().millisecondsSinceEpoch;
    final newHab = HabitatModel(
      id: 'hab_${now}',
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
    notifyListeners();
  }

  void completeConstruction(String habitatId) {
    for (final h in _placedHabitats) {
      if (h.id == habitatId) {
        h.underConstruction = false;
        h.constructionEndsAt = null;
        _addXp(50);
        notifyListeners();
        break;
      }
    }
  }

  bool adoptDog(DogCatalogItem dogItem, String targetHabitatId) {
    if (!canAfford(dogItem.costCoins, dogItem.costCrystals)) return false;

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
            if (_kibble < info.kibbleCostPerFeed) return false;

            _kibble -= info.kibbleCostPerFeed;
            _coins += info.coinsRewardPerFeed;
            _addXp(info.xpRewardPerFeed);

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
    notifyListeners();
  }

  void completeTask(String taskId) {
    for (final t in _tasks) {
      if (t.id == taskId && !t.done) {
        t.done = true;
        _coins += t.rewardCoins;
        _crystals += t.rewardCrystals;
        _addXp(t.rewardXp);
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
    }
  }

  @override
  void dispose() {
    _incomeTimer?.cancel();
    super.dispose();
  }
}
