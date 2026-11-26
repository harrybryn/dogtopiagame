import 'dart:math';
import 'package:flutter/material.dart';
import '../state/game_controller.dart';
import '../models/habitat_model.dart';
import '../models/dog_model.dart';
import '../models/dog_evolution.dart';
import '../models/friend_visit_model.dart';
import '../models/habitat_catalog.dart';
import '../models/walkthrough_step.dart';
import '../components/common/hover_scale.dart';
import '../services/audio_service.dart';

class HabitatCarePage extends StatefulWidget {
  final GameController game;
  final HabitatModel habitat;
  final VoidCallback onBackToWorld;
  final Function(DogModel dog, String fromHabitatId)? onStartTransferDog;
  final int initialDogIndex;
  final Map<String, GlobalKey>? walkthroughKeys;

  /// When true this is a mock friend visit: feeding uses your kibble to help
  /// the friend's dog grow, but ownership actions (rename/transfer/sell) are
  /// unavailable and you do not earn their coins.
  final bool isVisitMode;
  final MockFriend? visitFriend;

  const HabitatCarePage({
    super.key,
    required this.game,
    required this.habitat,
    required this.onBackToWorld,
    this.onStartTransferDog,
    this.initialDogIndex = 0,
    this.walkthroughKeys,
    this.isVisitMode = false,
    this.visitFriend,
  });

  @override
  State<HabitatCarePage> createState() => _HabitatCarePageState();
}

class _HabitatCarePageState extends State<HabitatCarePage>
    with SingleTickerProviderStateMixin {
  late int _selectedDogIndex;
  int _petNonce = 0;
  int _feedNonce = 0;
  int _levelUpNonce = 0;
  String? _toastMessage;

  // Interactive Bath Mini-Game state
  _BathStage _bathStage = _BathStage.none;
  final List<_DirtSpot> _dirtSpots = [];
  final List<_SoapBubble> _bubbles = [];
  final List<_FoamPatch> _foamPatches = [];
  Offset? _bathPointer;
  double _rinseProgress = 0.0;
  int _lastBathSfxMs = 0;
  late final AnimationController _bathTicker;
  final Random _bathRng = Random();

  @override
  void initState() {
    super.initState();
    _selectedDogIndex = widget.initialDogIndex.clamp(
      0,
      widget.habitat.dogs.isNotEmpty ? widget.habitat.dogs.length - 1 : 0,
    );
    _bathTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onBathTick);
    _syncDirtSpotsForCurrentDog();
  }

  void _syncDirtSpotsForCurrentDog() {
    _dirtSpots.clear();
    final dog = _currentDog;
    if (dog != null && dog.isDirty) {
      _dirtSpots.addAll([
        _DirtSpot(const Offset(0.38, 0.34), 14, seed: 1),
        _DirtSpot(const Offset(0.58, 0.30), 13, seed: 2),
        _DirtSpot(const Offset(0.47, 0.48), 16, seed: 3),
        _DirtSpot(const Offset(0.35, 0.62), 14, seed: 4),
        _DirtSpot(const Offset(0.62, 0.58), 15, seed: 5),
        _DirtSpot(const Offset(0.50, 0.74), 13, seed: 6),
      ]);
    }
  }

  @override
  void dispose() {
    _bathTicker.removeListener(_onBathTick);
    _bathTicker.dispose();
    super.dispose();
  }

  DogModel? get _currentDog {
    if (widget.habitat.dogs.isEmpty) return null;
    final idx = _selectedDogIndex.clamp(0, widget.habitat.dogs.length - 1);
    return widget.habitat.dogs[idx];
  }

  String _getInsideBackground() {
    return widget.habitat.insideAsset;
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _petDog() {
    if (_bathStage != _BathStage.none) return;
    final dog = _currentDog;
    if (widget.isVisitMode) {
      widget.visitFriend?.helpCount += 1;
      _showToast('${dog?.name ?? 'Companion'} loved the attention!');
    } else {
      widget.game.addCoins(50);
      widget.game.recordCareTask();
      _showToast('+50 Paw Coins! Companion Loved!');
    }
    setState(() => _petNonce++);
    SoundManager.instance.playPet();
    SoundManager.instance.playDogBark(isPuppy: dog?.isPuppy ?? true, force: true);
  }

  void _startBath() {
    final dog = _currentDog;
    if (dog == null) return;
    if (!dog.isDirty) {
      SoundManager.instance.playClick();
      _showToast('${dog.name} is already sparkling clean!');
      return;
    }
    SoundManager.instance.playClick();
    if (_dirtSpots.isEmpty) {
      _syncDirtSpotsForCurrentDog();
    }
    _bubbles.clear();
    _foamPatches.clear();
    _bathPointer = null;
    _rinseProgress = 0.0;
    setState(() => _bathStage = _BathStage.scrubbing);
    if (!_bathTicker.isAnimating) {
      _bathTicker.repeat();
    }
  }

  void _cancelBath() {
    _bathTicker.stop();
    setState(() {
      _bathStage = _BathStage.none;
      _bathPointer = null;
      _bubbles.clear();
      _foamPatches.clear();
      _syncDirtSpotsForCurrentDog();
    });
  }

  void _onBathTick() {
    if (!mounted || _bathStage == _BathStage.none) return;
    for (int i = _bubbles.length - 1; i >= 0; i--) {
      final b = _bubbles[i];
      b.pos = Offset(b.pos.dx + b.vx, b.pos.dy - b.vy);
      b.life -= 0.022;
      if (b.life <= 0) {
        _bubbles.removeAt(i);
      }
    }
    setState(() {});
  }

  void _onBathDrag(Offset localPos, double artW, double artH) {
    if (_bathStage == _BathStage.none) return;
    _bathPointer = localPos;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastBathSfxMs > 260) {
      _lastBathSfxMs = nowMs;
      SoundManager.instance.playPet();
    }

    if (_bathStage == _BathStage.scrubbing) {
      // Spawn soap bubbles
      for (int i = 0; i < 2; i++) {
        if (_bubbles.length < 40) {
          _bubbles.add(
            _SoapBubble(
              pos: localPos +
                  Offset(
                    (_bathRng.nextDouble() - 0.5) * 26,
                    (_bathRng.nextDouble() - 0.5) * 18,
                  ),
              radius: 4.5 + _bathRng.nextDouble() * 7.5,
              vx: (_bathRng.nextDouble() - 0.5) * 0.8,
              vy: 0.7 + _bathRng.nextDouble() * 1.1,
            ),
          );
        }
      }
      // Leave soft foam patches over the dog
      if (_foamPatches.length < 36) {
        final norm = Offset(
          (localPos.dx / max(1.0, artW)).clamp(0.15, 0.85),
          (localPos.dy / max(1.0, artH)).clamp(0.15, 0.85),
        );
        _foamPatches.add(_FoamPatch(norm, 14 + _bathRng.nextDouble() * 10));
      }

      // Scrub nearby dirt spots
      for (final spot in _dirtSpots) {
        if (spot.progress >= 1.0) continue;
        final spotPx = Offset(spot.normPos.dx * artW, spot.normPos.dy * artH);
        if ((spotPx - localPos).distance <= 38.0) {
          spot.progress = (spot.progress + 0.16).clamp(0.0, 1.0);
        }
      }

      final allClean = _dirtSpots.every((s) => s.progress >= 1.0);
      if (allClean) {
        _bathStage = _BathStage.rinsing;
        SoundManager.instance.playWalkthroughStepComplete();
      }
      setState(() {});
    } else if (_bathStage == _BathStage.rinsing) {
      _rinseProgress = (_rinseProgress + 0.04).clamp(0.0, 1.0);
      if (_bubbles.isNotEmpty && _bathRng.nextBool()) {
        _bubbles.removeAt(0);
      }
      if (_rinseProgress >= 1.0) {
        _completeBath();
      } else {
        setState(() {});
      }
    }
  }

  void _completeBath() {
    _bathTicker.stop();
    final dog = _currentDog;
    if (dog != null) {
      dog.lastBathedAt = DateTime.now().millisecondsSinceEpoch;
    }
    if (widget.isVisitMode) {
      widget.visitFriend?.helpCount += 1;
      _showToast('Sparkling clean! ${dog?.name ?? 'Companion'} feels fresh!');
    } else {
      widget.game.addCoins(75);
      widget.game.recordCareTask();
      _showToast('Sparkling clean! +75 Paw Coins!');
    }
    SoundManager.instance.playQuestReward();
    SoundManager.instance.playDogBark(isPuppy: dog?.isPuppy ?? true, force: true);
    setState(() {
      _bathStage = _BathStage.none;
      _bathPointer = null;
      _bubbles.clear();
      _foamPatches.clear();
      _dirtSpots.clear();
      _petNonce++;
      _levelUpNonce++;
    });
  }

  bool _feedVisitDog(DogModel dog) {
    final info = DogStageInfo.getInfo(dog);
    if (!widget.game.spendCurrency(kibble: info.kibbleCostPerFeed)) {
      SoundManager.instance.playSadWhimper();
      _showToast('Not enough Kibble! Produce more in the Kibble Bakery.');
      return false;
    }

    final prevLevel = dog.level;
    dog.feedProgress += 1;
    if (dog.feedProgress >= dog.feedRequired) {
      dog.feedProgress = 0;
      dog.level += 1;
      if (dog.level >= 12) {
        dog.stage = 'Adult';
      } else if (dog.level >= 4) {
        dog.stage = 'Young';
      }
    }

    widget.visitFriend?.helpCount += 1;
    SoundManager.instance.playFeed();
    if (dog.level > prevLevel) {
      SoundManager.instance.playLevelUp();
      SoundManager.instance.playDogBark(
        isPuppy: dog.stage == 'Puppy',
        force: true,
      );
      _showToast('LEVEL UP! ${dog.name} is now Level ${dog.level}!');
    }
    return true;
  }

  void _feedSteps(int steps) {
    final dog = _currentDog;
    if (dog == null) return;

    bool fedAny = false;
    bool leveledUp = false;

    if (widget.isVisitMode) {
      for (int i = 0; i < steps; i++) {
        final prevLevel = dog.level;
        if (!_feedVisitDog(dog)) break;
        fedAny = true;
        if (dog.level > prevLevel) leveledUp = true;
      }
      setState(() {
        if (fedAny) _feedNonce++;
        if (leveledUp) _levelUpNonce++;
      });
      return;
    }

    for (int i = 0; i < steps; i++) {
      final prevLevel = dog.level;
      final success = widget.game.feedDog(widget.habitat.id, dog.id);
      if (!success) {
        _showToast('Not enough Kibble! Produce more in the Kibble Bakery.');
        break;
      }
      fedAny = true;
      if (dog.level > prevLevel) {
        leveledUp = true;
        _showToast('LEVEL UP! ${dog.name} is now Level ${dog.level}!');
      }
    }
    setState(() {
      if (fedAny) _feedNonce++;
      if (leveledUp) _levelUpNonce++;
    });
  }

  void _renameCurrentDog() {
    final dog = _currentDog;
    if (dog == null) return;

    final controller = TextEditingController(text: dog.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1205),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 2),
        ),
        title: const Text(
          'RENAME DOG',
          style: TextStyle(
            color: Color(0xFFFEF08A),
            fontFamily: 'Lilita One',
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Lilita One',
            fontSize: 16,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter dog name...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF59E0B)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFEF08A), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white70, fontFamily: 'Lilita One')),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                widget.game.renameDog(widget.habitat.id, dog.id, newName);
                setState(() {});
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF3B1404),
            ),
            child: const Text('SAVE',
                style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Lilita One')),
          ),
        ],
      ),
    );
  }

  void _showSellConfirmModal() {
    final dog = _currentDog;
    if (dog == null) return;
    final refund = 300 + dog.level * 100;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1205),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 2.5),
        ),
        title: Center(
          child: Text(
            'SELL ${dog.name.toUpperCase()}?',
            style: const TextStyle(
              color: Color(0xFFFEF08A),
              fontFamily: 'Lilita One',
              fontSize: 18,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to sell ${dog.name}?\nYou will receive +$refund Paw Coins.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFEF3C7),
                fontFamily: 'Fredoka',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/ui/coins.png', width: 22, height: 22),
                const SizedBox(width: 6),
                Text(
                  '+$refund Coins',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontFamily: 'Lilita One',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white70, fontFamily: 'Lilita One')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.game.sellDog(widget.habitat.id, dog.id, refund);
              if (widget.habitat.dogs.isEmpty) {
                widget.onBackToWorld();
              } else {
                setState(() => _selectedDogIndex = 0);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('CONFIRM SELL',
                style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Lilita One')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dog = _currentDog;
    final info = dog != null ? DogStageInfo.getInfo(dog) : null;
    final hasEnoughKibble =
        info != null && widget.game.kibble >= info.kibbleCostPerFeed;

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final isCompact = screenW < 980;
    // Short landscape windows need smaller art and tighter spacing, otherwise
    // the dog info sits far below the fold and requires endless scrolling.
    final shortStage = media.size.height < 560;
    final pillW = isCompact ? 112.0 : 138.0;
    final pillH = isCompact ? 36.0 : 44.0;

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Habitat Inside Background ──
          Positioned.fill(
            child: Image.asset(
              _getInsideBackground(),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          // ── 2. Unified Responsive Top Bar ──
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBackButton(isCompact: isCompact),
                Expanded(
                  flex: isCompact ? 2 : 1,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildTitlePlaque(isCompact: isCompact),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  flex: isCompact ? 3 : 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/diamonds.png',
                            value: '${widget.game.crystals}',
                            onPlus: widget.onBackToWorld,
                            pillW: pillW,
                            pillH: pillH,
                          ),
                          SizedBox(width: isCompact ? 6 : 8),
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/coins.png',
                            value: _fmt(widget.game.coins),
                            onPlus: widget.onBackToWorld,
                            pillW: pillW,
                            pillH: pillH,
                          ),
                          SizedBox(width: isCompact ? 6 : 8),
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/dogfood.png',
                            value: _fmt(widget.game.kibble),
                            onPlus: widget.onBackToWorld,
                            pillW: pillW,
                            pillH: pillH,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Main Stage Content Area ──
          Positioned(
            top: isCompact ? 74 : 86,
            bottom: 18,
            left: isCompact ? 14 : 36,
            right: isCompact ? 14 : 48,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1060),
                // Always side-by-side, like the desktop layout. FittedBox
                // scales each column down on short landscape windows so no
                // scrolling is needed to reach the dog info.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 360,
                          child: _buildDogStage(
                            dog,
                            info,
                            hasEnoughKibble,
                            compact: shortStage,
                          ),
                        ),
                      ),
                    ),
                    if (dog != null && info != null) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 400,
                            child: _buildStatCard(
                              dog,
                              info,
                              compact: shortStage,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── 4. Toast Notification Overlay ──
          if (_toastMessage != null)
            Positioned(
              top: isCompact ? 122 : 76,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xEE1E0A02),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _toastMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFEF08A),
                      fontFamily: 'Lilita One',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackButton({required bool isCompact}) {
    return HoverScale(
      key: widget.walkthroughKeys?[WalkthroughTargets.careBackButton],
      scale: 1.06,
      onTap: widget.onBackToWorld,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14, vertical: isCompact ? 6 : 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF08A), Color(0xFFF59E0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD97706), width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66D97706),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_ios_new_rounded,
                size: 13, color: Color(0xFF3B1404)),
            const SizedBox(width: 5),
            Text(
              isCompact ? 'BACK' : 'BACK TO ISLAND',
              style: const TextStyle(
                color: Color(0xFF3B1404),
                fontFamily: 'Lilita One',
                fontSize: 12.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitlePlaque({required bool isCompact}) {
    final double plaqueW = isCompact ? 180.0 : 280.0;
    final double plaqueH = plaqueW * (160.0 / 320.0);
    return SizedBox(
      width: plaqueW,
      height: plaqueH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/ui/HabitatCare.png',
            width: plaqueW,
            height: plaqueH,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          Positioned(
            left: plaqueW * (104.0 / 320.0),
            right: plaqueW * (37.0 / 320.0),
            top: 0,
            bottom: 0,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.habitat.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Lilita One',
                    fontSize: isCompact ? 13.0 : 17.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: const [
                      Shadow(
                        color: Color(0xFF3B1404),
                        offset: Offset(0, 2),
                        blurRadius: 2,
                      ),
                      Shadow(
                        color: Colors.black,
                        offset: Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDogStage(
    DogModel? dog,
    DogStageInfo? info,
    bool hasEnoughKibble, {
    bool compact = false,
  }) {
    final artH = compact ? 132.0 : 220.0;
    final artW = compact ? 150.0 : 220.0;
    final shadowH = compact ? 18.0 : 26.0;
    final gap = compact ? 4.0 : 8.0;

    return dog == null || info == null
                      ? Center(
                          child: Text(
                            'No dogs living here yet!\nAdopt puppies from the Shop.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontFamily: 'Lilita One',
                              fontSize: 16,
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            key: widget.walkthroughKeys?[
                                WalkthroughTargets.careDogStation],
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            // 1. Dog Name Plaque with Edit Pencil & Level Pill + Left/Right arrows
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.habitat.dogs.length > 1)
                                  HoverScale(
                                    scale: 1.15,
                                    onTap: () {
                                      setState(() {
                                        _selectedDogIndex = (_selectedDogIndex - 1 + widget.habitat.dogs.length) %
                                            widget.habitat.dogs.length;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xCC290E02),
                                        border: Border.all(
                                            color: const Color(0xFFFBBF24), width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x40000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                                          size: 13, color: Color(0xFFFEF08A)),
                                    ),
                                  ),

                                HoverScale(
                                  scale: 1.05,
                                  onTap:
                                      widget.isVisitMode ? null : _renameCurrentDog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFFFBBF24), width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!widget.isVisitMode) ...[
                                          const Icon(Icons.edit_rounded,
                                              size: 13,
                                              color: Color(0xFF78350F)),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          dog.name.toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF451A03),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'LV ${dog.level}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Lilita One',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (widget.habitat.dogs.length > 1)
                                  HoverScale(
                                    scale: 1.15,
                                    onTap: () {
                                      setState(() {
                                        _selectedDogIndex =
                                            (_selectedDogIndex + 1) % widget.habitat.dogs.length;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xCC290E02),
                                        border: Border.all(
                                            color: const Color(0xFFFBBF24), width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x40000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.arrow_forward_ios_rounded,
                                          size: 13, color: Color(0xFFFEF08A)),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: compact ? 3 : 6),

                            // 2. The Companion Dog with Ground Contact Shadow & Pet / Bath interaction
                            GestureDetector(
                              key: widget.isVisitMode
                                  ? const Key('friend_pet_dog')
                                  : null,
                              behavior: HitTestBehavior.opaque,
                              onTap: _bathStage == _BathStage.none
                                  ? _petDog
                                  : null,
                              onPanStart: _bathStage != _BathStage.none
                                  ? (d) => _onBathDrag(
                                      d.localPosition, artW, artH)
                                  : null,
                              onPanUpdate: _bathStage != _BathStage.none
                                  ? (d) => _onBathDrag(
                                      d.localPosition, artW, artH)
                                  : null,
                              onPanEnd: _bathStage != _BathStage.none
                                  ? (_) => setState(() => _bathPointer = null)
                                  : null,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                clipBehavior: Clip.none,
                                children: [
                                  // Radial Ground Shadow
                                  Container(
                                    width: artW,
                                    height: shadowH,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                          Radius.elliptical(artW, shadowH)),
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xBB0F0702),
                                          Color(0x330F0702),
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.6, 1.0],
                                      ),
                                    ),
                                  ),

                                  // Interactive Dog Sprite (breathing, munching, petting, level-up)
                                  _InteractiveDogSprite(
                                    assetPath: info.sitImg,
                                    height: artH,
                                    petNonce: _petNonce,
                                    feedNonce: _feedNonce,
                                    levelUpNonce: _levelUpNonce,
                                  ),

                                  // Mud spots (shown automatically when dirty) & interactive bath overlay
                                  if (_bathStage != _BathStage.none ||
                                      dog.isDirty)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _BathOverlayPainter(
                                            stage: _bathStage,
                                            dirtSpots: _dirtSpots,
                                            foamPatches: _foamPatches,
                                            bubbles: _bubbles,
                                            pointer: _bathPointer,
                                            rinseProgress: _rinseProgress,
                                            tick: _bathTicker.value,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: gap),

                            // 3. Four-Segment Feed Progress Meter
                            Container(
                              width: 280,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xCC000000),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0x66B45309), width: 1.2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header Row: FEED PROGRESS (x/4) & NEXT LEVEL
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'FEED PROGRESS ',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 10.5,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              Text(
                                                '(${dog.feedProgress}/4)',
                                                style: const TextStyle(
                                                  color: Color(0xFFFEF08A),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF451A03),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFFF59E0B),
                                              width: 1),
                                        ),
                                        child: Text(
                                          'NEXT LEVEL ${dog.level + 1}',
                                          style: const TextStyle(
                                            color: Color(0xFFFEF08A),
                                            fontFamily: 'Lilita One',
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // 4 Segmented Slots
                                  Row(
                                    children: List.generate(4, (index) {
                                      final isFilled = index < dog.feedProgress;
                                      return Expanded(
                                        child: Container(
                                          height: 18,
                                          margin: EdgeInsets.only(
                                              right: index < 3 ? 4 : 0),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            gradient: isFilled
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFFFDE047),
                                                      Color(0xFFF59E0B),
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  )
                                                : null,
                                            color: isFilled
                                                ? null
                                                : const Color(0xFF18181B),
                                            border: Border.all(
                                              color: isFilled
                                                  ? const Color(0xFFFEF08A)
                                                  : const Color(0xFF3F3F46),
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: isFilled
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 13,
                                                  color: Color(0xFF451A03),
                                                )
                                              : null,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: gap),

                            // 4. Action Buttons (FEED, FEED x4, BATH) or Bath Status Bar
                            if (_bathStage != _BathStage.none)
                              Container(
                                width: 280,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xDD1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFF38BDF8),
                                      width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _bathStage == _BathStage.scrubbing
                                          ? Icons.soap_rounded
                                          : Icons.shower_rounded,
                                      color: const Color(0xFF38BDF8),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _bathStage == _BathStage.scrubbing
                                            ? 'Scrub all mud spots!'
                                            : 'Drag water to rinse (${(_rinseProgress * 100).round()}%)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Lilita One',
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _cancelBath,
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Color(0xFFFCA5A5),
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                            SizedBox(
                              key: widget.walkthroughKeys?[
                                  WalkthroughTargets.careFeedButton],
                              width: 280,
                              child: Row(
                                children: [
                                  // Primary Feed Button
                                  Expanded(
                                    flex: 3,
                                    child: HoverScale(
                                      scale: hasEnoughKibble ? 1.05 : 1.0,
                                      onTap: hasEnoughKibble
                                          ? () => _feedSteps(1)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 7),
                                        decoration: BoxDecoration(
                                          gradient: hasEnoughKibble
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFBBF24),
                                                    Color(0xFFD97706),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                )
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFF9CA3AF),
                                                    Color(0xFF6B7280),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFFEF3C7),
                                              width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Image.asset(
                                                'assets/ui/dogfood.png',
                                                width: 18,
                                                height: 18,
                                                fit: BoxFit.contain,
                                              ),
                                              const SizedBox(width: 6),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text(
                                                    'FEED',
                                                    style: TextStyle(
                                                      color: Color(0xFF3B1404),
                                                      fontFamily: 'Lilita One',
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                  Text(
                                                    '${info.kibbleCostPerFeed} Kibble',
                                                    style: const TextStyle(
                                                      color: Color(0xFF451A03),
                                                      fontFamily: 'Fredoka',
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      height: 1.0,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Quick Feed x4 (or remaining)
                                  Expanded(
                                    flex: 2,
                                    child: HoverScale(
                                      scale: hasEnoughKibble ? 1.05 : 1.0,
                                      onTap: hasEnoughKibble
                                          ? () => _feedSteps(
                                              4 - dog.feedProgress)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFDE047),
                                              Color(0xFFF59E0B),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white, width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'FEED X${4 - dog.feedProgress}',
                                            style: const TextStyle(
                                              color: Color(0xFF3B1404),
                                              fontFamily: 'Lilita One',
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.3,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Take a Bath Button
                                  Expanded(
                                    flex: 2,
                                    child: HoverScale(
                                      scale: 1.05,
                                      onTap: _startBath,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF38BDF8),
                                              Color(0xFF0284C7),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFE0F2FE),
                                              width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.bathtub_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'BATH',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
  }

  Widget _buildStatCard(DogModel dog, DogStageInfo info,
      {bool compact = false}) {
    final vGap = compact ? 7.0 : 14.0;
    return Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 26,
                          vertical: compact ? 10 : 22),
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.4),
                          radius: 0.9,
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFFFF9EC),
                            Color(0xFFFCE9C8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: const Color(0xFFFBBF24), width: 3.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xB3000000),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: ELEMENTS & SOURCE
                          Row(
                            children: [
                              // Elements
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ELEMENTS',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF059669),
                                                Color(0xFF15803D),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: const Color(0xFF6EE7B7),
                                                width: 1),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star_rounded,
                                                    color: Colors.white,
                                                    size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dog.element.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'Lilita One',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Source
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'SOURCE',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFFEC4899),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                  Icons.favorite_rounded,
                                                  color: Colors.white,
                                                  size: 13),
                                            ),
                                            const SizedBox(width: 5),
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFFF59E0B),
                                              ),
                                              alignment: Alignment.center,
                                              child: Image.asset(
                                                'assets/ui/coins.png',
                                                width: 14,
                                                height: 14,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Expanded(
                                              child: Text(
                                                'STARTER / SANCTUARY',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Color(0xFF78350F),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: vGap),

                              const Divider(
                                  color: Color(0x3378350F), height: 1),
                              SizedBox(height: vGap),

                              // Row 2: INCOME & MASTER POINTS
                              Row(
                                children: [
                                  // Income
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'INCOME',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(
                                                'assets/ui/coins.png',
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '+${info.coinRatePerMin}/min',
                                                style: const TextStyle(
                                                  color: Color(0xFF3B1404),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Master Points
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'MASTER POINTS',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.emoji_events_rounded,
                                                color: Color(0xFFF59E0B),
                                                size: 24,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${dog.level * 40 + 15}',
                                                style: const TextStyle(
                                                  color: Color(0xFF3B1404),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // The description is the tallest block. Drop it
                              // on short windows so the card fits without a scroll.
                              if (!compact) ...[
                                SizedBox(height: vGap),
                                const Divider(
                                    color: Color(0x3378350F), height: 1),
                                SizedBox(height: vGap),
                                const Text(
                                  'DESCRIPTION',
                                  style: TextStyle(
                                    color: Color(0xFF78350F),
                                    fontFamily: 'Lilita One',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0x66FEF3C7),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0x40D97706), width: 1),
                                  ),
                                  child: Text(
                                    info.description +
                                        (info.isHusky
                                            ? ' He loves frosty adventures and hearty meat feasts on the tundra!'
                                            : ' He loves hearty kibble feasts and cozy afternoon naps on the lawn!'),
                                    style: const TextStyle(
                                      color: Color(0xFF3B1404),
                                      fontFamily: 'Fredoka',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (compact) ...[
                                Padding(
                                  padding: EdgeInsets.only(top: vGap + 2),
                                  child: Text(
                                    info.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF78350F),
                                      fontFamily: 'Fredoka',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Row 4: Ownership actions are hidden on a friend visit.
                              if (!widget.isVisitMode)
                                Row(
                                  children: [
                                  // TRANSFER HABITAT Button
                                  Expanded(
                                    child: HoverScale(
                                      scale: 1.05,
                                      onTap: () {
                                        final compatibleOtherHabs = widget
                                            .game.placedHabitats
                                            .where((h) =>
                                                h.type == 'habitat' &&
                                                h.id != widget.habitat.id &&
                                                h.dogs.length < 4 &&
                                                HabitatCatalog
                                                    .isHabitatCompatible(
                                                  habitatCatalogId: h.habitatId,
                                                  breedId: dog.breedId,
                                                  element: dog.element,
                                                ))
                                            .toList();

                                        if (compatibleOtherHabs.isEmpty) {
                                          final anyOtherPlaced = widget
                                              .game.placedHabitats
                                              .any((h) =>
                                                  h.type == 'habitat' &&
                                                  h.id != widget.habitat.id &&
                                                  HabitatCatalog
                                                      .isHabitatCompatible(
                                                    habitatCatalogId:
                                                        h.habitatId,
                                                    breedId: dog.breedId,
                                                    element: dog.element,
                                                  ));
                                          if (anyOtherPlaced) {
                                            _showToast(
                                                'Other compatible habitats are full (4/4 dogs)!');
                                          } else {
                                            _showToast(
                                                'No other compatible habitat placed! Build one first.');
                                          }
                                          return;
                                        }

                                        if (widget.onStartTransferDog != null) {
                                          widget.onStartTransferDog!(
                                              dog, widget.habitat.id);
                                        } else {
                                          widget.onBackToWorld();
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: compact ? 8 : 12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF38BDF8),
                                              Color(0xFF0284C7),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white, width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x400284C7),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.open_with_rounded,
                                                  size: 17, color: Colors.white),
                                              SizedBox(width: 6),
                                              Text(
                                                'TRANSFER HABITAT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // SELL DOG Button
                                  Expanded(
                                    child: HoverScale(
                                      scale: 1.05,
                                      onTap: _showSellConfirmModal,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: compact ? 8 : 12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFF59E0B),
                                              Color(0xFFD97706),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFFEF3C7),
                                              width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40D97706),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Image.asset(
                                                'assets/ui/coins.png',
                                                width: 18,
                                                height: 18,
                                                fit: BoxFit.contain,
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'SELL DOG',
                                                style: TextStyle(
                                                  color: Color(0xFF3B1404),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
  }

  Widget _buildWoodResourcePill({
    required String iconAsset,
    required String value,
    required VoidCallback onPlus,
    double pillW = 138.0,
    double pillH = 44.0,
  }) {
    final double iconSize = (pillH * 0.52).clamp(16.0, 24.0);
    final double plusSize = (pillH * 0.46).clamp(16.0, 22.0);
    final double fontSize = (pillH * 0.34).clamp(12.0, 15.0);

    return HoverScale(
      scale: 1.05,
      onTap: onPlus,
      child: SizedBox(
        width: pillW,
        height: pillH,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: pillW * 0.04,
              right: pillW * 0.04,
              top: pillH * 0.14,
              bottom: pillH * 0.06,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pillH * 0.45),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                'assets/ui/ResourcesPlaceHolder.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned(
              left: pillW * 0.18 - iconSize / 2,
              top: (pillH - iconSize) / 2,
              width: iconSize,
              height: iconSize,
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned(
              left: pillW * 0.28,
              right: pillW * 0.28,
              top: 0,
              bottom: 0,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                      fontFamily: 'Lilita One',
                      letterSpacing: 0.5,
                      shadows: const [
                        Shadow(
                          color: Color(0xFF3B1404),
                          offset: Offset(0, 1.5),
                          blurRadius: 1,
                        ),
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: pillW * 0.82 - plusSize / 2,
              top: (pillH - plusSize) / 2,
              width: plusSize,
              height: plusSize,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      offset: Offset(0, 1.5),
                      blurRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: plusSize * 0.72,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveDogSprite extends StatefulWidget {
  final String assetPath;
  final double height;
  final int petNonce;
  final int feedNonce;
  final int levelUpNonce;

  const _InteractiveDogSprite({
    required this.assetPath,
    required this.height,
    required this.petNonce,
    required this.feedNonce,
    required this.levelUpNonce,
  });

  @override
  State<_InteractiveDogSprite> createState() => _InteractiveDogSpriteState();
}

class _InteractiveDogSpriteState extends State<_InteractiveDogSprite>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _feedController;
  late final AnimationController _petController;
  late final AnimationController _levelUpController;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _feedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _petController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didUpdateWidget(covariant _InteractiveDogSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedNonce != oldWidget.feedNonce) {
      _feedController.forward(from: 0.0);
    }
    if (widget.petNonce != oldWidget.petNonce) {
      _petController.forward(from: 0.0);
    }
    if (widget.levelUpNonce != oldWidget.levelUpNonce) {
      _levelUpController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _feedController.dispose();
    _petController.dispose();
    _levelUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // ── Dog Artwork with Combined Idle + Feed + Pet + Level-Up Motion ──
        AnimatedBuilder(
          animation: Listenable.merge([
            _idleController,
            _feedController,
            _petController,
            _levelUpController,
          ]),
          builder: (_, child) {
            final breath = Curves.easeInOut.transform(_idleController.value);
            double scaleX = 1.0 - 0.008 * breath;
            double scaleY = 1.0 + 0.024 * breath;
            double translateY = 0.0;
            double rotateZ = sin(_idleController.value * pi) * 0.012;

            // Feed chomp/happy bounce (double munch + hop)
            if (_feedController.isAnimating) {
              final t = _feedController.value;
              final env = sin(t * pi);
              final chomp = sin(t * pi * 4.0);
              scaleX += chomp * 0.065 * env;
              scaleY -= chomp * 0.075 * env;
              translateY -= sin(t * pi * 2.0).abs() * 7.0 * env;
              rotateZ += sin(t * pi * 3.0) * 0.045 * env;
            }

            // Pet affectionate wiggle & nuzzle
            if (_petController.isAnimating) {
              final t = _petController.value;
              final env = sin(t * pi);
              rotateZ += sin(t * pi * 4.0) * 0.075 * env;
              scaleX += 0.04 * env;
              scaleY -= 0.035 * env;
            }

            // Level-up celebration jump
            if (_levelUpController.isAnimating) {
              final t = _levelUpController.value;
              final jump = sin(t * pi);
              translateY -= jump * 18.0;
              scaleX += 0.06 * jump;
              scaleY += 0.06 * jump;
            }

            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..translateByDouble(0.0, translateY, 0.0, 1.0)
                ..rotateZ(rotateZ)
                ..scaleByDouble(scaleX, scaleY, 1.0, 1.0),
              child: child,
            );
          },
          child: Image.asset(
            widget.assetPath,
            height: widget.height,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),

        // ── Floating Hearts Burst on Pet ──
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _petController,
              builder: (_, _) {
                if (!_petController.isAnimating) return const SizedBox.shrink();
                final t = _petController.value;
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    for (int i = 0; i < 3; i++)
                      Positioned(
                        bottom: widget.height * 0.55 + t * (48.0 + i * 14.0),
                        left: 0,
                        right: 0,
                        child: Transform.translate(
                          offset: Offset(
                            -26.0 + i * 26.0 + sin(t * pi * 2 + i) * 8.0,
                            0,
                          ),
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: 0.75 + 0.35 * sin(t * pi),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: i == 1
                                    ? const Color(0xFFF472B6)
                                    : const Color(0xFFEC4899),
                                size: i == 1 ? 26 : 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Flying Kibble & Sparkles on Feed ──
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _feedController,
              builder: (_, _) {
                if (!_feedController.isAnimating) {
                  return const SizedBox.shrink();
                }
                final t = _feedController.value;
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    for (int i = 0; i < 3; i++)
                      Positioned(
                        bottom: widget.height * 0.42 + t * (36.0 + i * 10.0),
                        left: 0,
                        right: 0,
                        child: Transform.translate(
                          offset: Offset(
                            -22.0 + i * 22.0 + cos(t * pi * 2 + i) * 6.0,
                            0,
                          ),
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.rotate(
                              angle: t * 4.0 + i,
                              child: Image.asset(
                                'assets/ui/dogfood.png',
                                width: 18,
                                height: 18,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),

        // ── Golden Star Burst on Level Up ──
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _levelUpController,
              builder: (_, _) {
                if (!_levelUpController.isAnimating) {
                  return const SizedBox.shrink();
                }
                final t = _levelUpController.value;
                final opacity = (1.0 - t).clamp(0.0, 1.0);
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    for (int i = 0; i < 6; i++)
                      Positioned(
                        bottom: widget.height * 0.45 +
                            sin(i * pi / 3) * t * 45.0 +
                            t * 25.0,
                        left: 0,
                        right: 0,
                        child: Transform.translate(
                          offset: Offset(cos(i * pi / 3) * t * 55.0, 0),
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.rotate(
                              angle: t * 5.0,
                              child: const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFDE047),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

enum _BathStage { none, scrubbing, rinsing }

class _DirtSpot {
  final Offset normPos;
  final double radius;
  final int seed;
  double progress = 0.0;

  _DirtSpot(this.normPos, this.radius, {this.seed = 0});
}

class _SoapBubble {
  Offset pos;
  final double radius;
  final double vx;
  final double vy;
  double life = 1.0;

  _SoapBubble({
    required this.pos,
    required this.radius,
    required this.vx,
    required this.vy,
  });
}

class _FoamPatch {
  final Offset normPos;
  final double radius;

  _FoamPatch(this.normPos, this.radius);
}

class _BathOverlayPainter extends CustomPainter {
  final _BathStage stage;
  final List<_DirtSpot> dirtSpots;
  final List<_FoamPatch> foamPatches;
  final List<_SoapBubble> bubbles;
  final Offset? pointer;
  final double rinseProgress;
  final double tick;

  _BathOverlayPainter({
    required this.stage,
    required this.dirtSpots,
    required this.foamPatches,
    required this.bubbles,
    required this.pointer,
    required this.rinseProgress,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Organic layered mud splatters (fade & shrink as scrubbed)
    for (final spot in dirtSpots) {
      final remaining = (1.0 - spot.progress).clamp(0.0, 1.0);
      if (remaining <= 0.01) continue;
      final center = Offset(
        spot.normPos.dx * size.width,
        spot.normPos.dy * size.height,
      );
      final r = spot.radius * (0.35 + 0.65 * remaining);
      final alpha = (0.92 * remaining).clamp(0.0, 1.0);
      final blobPath = _buildMudBlobPath(center, r, spot.seed);

      // Soft contact shadow around the mud splatter
      canvas.drawPath(
        blobPath.shift(const Offset(0.8, 1.4)),
        Paint()
          ..color = const Color(0xFF261407).withValues(alpha: 0.35 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );

      // Rich radial-gradient mud body
      final mudRect = Rect.fromCircle(center: center, radius: r * 1.25);
      final mudFill = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.3),
          radius: 1.05,
          colors: [
            const Color(0xFF855228).withValues(alpha: alpha),
            const Color(0xFF5C3618).withValues(alpha: alpha),
            const Color(0xFF3E210C).withValues(alpha: alpha),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(mudRect);
      canvas.drawPath(blobPath, mudFill);

      // Crisp dark mud outline
      canvas.drawPath(
        blobPath,
        Paint()
          ..color = const Color(0xFF2F1808).withValues(alpha: 0.55 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );

      // Glossy highlight & darker grit specks for depth
      canvas.drawOval(
        Rect.fromCenter(
          center: center + Offset(-r * 0.24, -r * 0.28),
          width: r * 0.52,
          height: r * 0.28,
        ),
        Paint()
          ..color = const Color(0xFFA97142).withValues(alpha: 0.45 * alpha),
      );
      final gritPaint = Paint()
        ..color = const Color(0xFF2F1808).withValues(alpha: 0.65 * alpha);
      canvas.drawCircle(
        center + Offset(r * 0.28, r * 0.18),
        r * 0.15,
        gritPaint,
      );
      canvas.drawCircle(
        center + Offset(-r * 0.22, r * 0.34),
        r * 0.11,
        gritPaint,
      );

      // Tiny flung mud droplets around the main splatter
      final dropPaint = Paint()
        ..color = const Color(0xFF543014).withValues(alpha: 0.82 * alpha);
      for (int i = 0; i < 3; i++) {
        final angle = (spot.seed * 1.7 + i * 2.15);
        final dist = r * (1.18 + ((spot.seed + i) % 3) * 0.22);
        final dropCenter = center + Offset(cos(angle) * dist, sin(angle) * dist);
        final dropR = r * (0.16 + ((spot.seed + i) % 2) * 0.08);
        canvas.drawCircle(dropCenter, dropR, dropPaint);
      }
    }

    // 2. Creamy white soap foam patches (washed away during rinse)
    final foamAlpha = stage == _BathStage.rinsing
        ? (1.0 - rinseProgress).clamp(0.0, 1.0)
        : 1.0;
    if (foamAlpha > 0.02) {
      final foamPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * foamAlpha);
      for (final f in foamPatches) {
        final c = Offset(f.normPos.dx * size.width, f.normPos.dy * size.height);
        canvas.drawCircle(c, f.radius, foamPaint);
      }
    }

    // 3. Floating soap bubbles with specular highlight
    for (final b in bubbles) {
      final alpha = b.life.clamp(0.0, 1.0);
      final fill = Paint()
        ..color = const Color(0xFFBAE6FD).withValues(alpha: 0.32 * alpha);
      final rim = Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final glint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9 * alpha);
      canvas.drawCircle(b.pos, b.radius, fill);
      canvas.drawCircle(b.pos, b.radius, rim);
      canvas.drawCircle(
        b.pos + Offset(-b.radius * 0.32, -b.radius * 0.32),
        b.radius * 0.24,
        glint,
      );
    }

    // 4. Active tool at pointer: Soap Sponge or Shower Water Stream
    if (pointer != null) {
      if (stage == _BathStage.scrubbing) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: pointer!, width: 36, height: 24),
          const Radius.circular(9),
        );
        canvas.drawRRect(
          rect.shift(const Offset(0, 2)),
          Paint()..color = const Color(0x33000000),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = const Color(0xFFFDE047),
        );
        // Sponge pores
        final porePaint = Paint()..color = const Color(0xFFEAB308);
        canvas.drawCircle(pointer! + const Offset(-8, -3), 2.1, porePaint);
        canvas.drawCircle(pointer! + const Offset(5, -4), 1.7, porePaint);
        canvas.drawCircle(pointer! + const Offset(0, 4), 2.3, porePaint);
        canvas.drawCircle(pointer! + const Offset(10, 3), 1.6, porePaint);
        canvas.drawRRect(
          rect,
          Paint()
            ..color = const Color(0xFFCA8A04)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      } else if (stage == _BathStage.rinsing) {
        // Showerhead & falling water droplets
        final headRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: pointer!, width: 28, height: 14),
          const Radius.circular(6),
        );
        canvas.drawRRect(headRect, Paint()..color = const Color(0xFF38BDF8));
        canvas.drawRRect(
          headRect,
          Paint()
            ..color = const Color(0xFF0369A1)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );

        final dropPaint = Paint()
          ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.85)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
        for (int i = -2; i <= 2; i++) {
          final phase = (tick * 3 + i * 0.23) % 1.0;
          final x = pointer!.dx + i * 6.0;
          final y = pointer!.dy + 10.0 + phase * 65.0;
          canvas.drawLine(Offset(x, y), Offset(x, y + 10.0), dropPaint);
        }
      }
    }
  }

  Path _buildMudBlobPath(Offset center, double r, int seed) {
    const lobes = 8;
    final points = <Offset>[];
    for (int i = 0; i < lobes; i++) {
      final angle = (i / lobes) * 2 * pi;
      final wave = 0.82 + 0.34 * ((sin(angle * 2 + seed * 1.3) + 1) * 0.5);
      final rad = r * wave;
      points.add(center + Offset(cos(angle) * rad, sin(angle) * rad));
    }
    final path = Path();
    final firstMid = Offset(
      (points.last.dx + points.first.dx) / 2,
      (points.last.dy + points.first.dy) / 2,
    );
    path.moveTo(firstMid.dx, firstMid.dy);
    for (int i = 0; i < points.length; i++) {
      final curr = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset((curr.dx + next.dx) / 2, (curr.dy + next.dy) / 2);
      path.quadraticBezierTo(curr.dx, curr.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _BathOverlayPainter oldDelegate) => true;
}
