import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../components/common/hover_scale.dart';
import '../models/dog_evolution.dart';
import '../models/dog_model.dart';
import '../models/habitat_catalog.dart';
import '../models/habitat_model.dart';
import '../services/audio_service.dart';
import '../state/game_controller.dart';

/// Minimum dog level required for breeding (Adult stage).
const int minBreedingLevel = 12;
const int _breedingCostCoins = 500;
const int _puppySellCoins = 250;

class BreedingDialog extends StatelessWidget {
  final GameController game;
  final VoidCallback? onClose;

  const BreedingDialog({super.key, required this.game, this.onClose});

  @override
  Widget build(BuildContext context) {
    return BreedingPage(
      game: game,
      onBackToWorld: onClose ?? () => Navigator.of(context).pop(),
    );
  }
}

class BreedingPage extends StatefulWidget {
  final GameController game;
  final VoidCallback onBackToWorld;
  final void Function(String breedId, String breedName, String element, String sitImg)?
      onStartPlaceBredPuppy;

  const BreedingPage({
    super.key,
    required this.game,
    required this.onBackToWorld,
    this.onStartPlaceBredPuppy,
  });

  @override
  State<BreedingPage> createState() => _BreedingPageState();
}

class _BreedingPageState extends State<BreedingPage>
    with SingleTickerProviderStateMixin {
  String? _parent1Id;
  String? _parent2Id;
  Timer? _countdownTimer;
  String? _toastMessage;
  late final AnimationController _pulseController;

  List<DogModel> get _allOwnedDogs =>
      widget.game.placedHabitats.expand((h) => h.dogs).toList();

  List<DogModel> get _eligibleDogs => _allOwnedDogs
      .where((d) => d.isAdult && d.level >= minBreedingLevel)
      .toList();

  String get _breedingState {
    final session = widget.game.activeBreeding;
    if (session == null) return 'idle';
    return session.isReady ? 'hatched' : 'breeding';
  }

  _HatchedPuppyResult? get _hatchedPup {
    final session = widget.game.activeBreeding;
    if (session == null || !session.isReady) return null;
    final breedName = DogStageInfo.getBreedDisplayName(session.resultBreedId);
    final previewPup = DogModel(
      id: 'preview',
      breedId: session.resultBreedId,
      name: breedName,
      level: 1,
      feedProgress: 0,
      stage: 'Puppy',
      element: session.resultElement,
      habitatId: '',
      habitatName: '',
    );
    return _HatchedPuppyResult(
      breedId: session.resultBreedId,
      breedName: breedName,
      element: session.resultElement,
      sitImg: DogStageInfo.getInfo(previewPup).sitImg,
    );
  }

  DogModel? _findDogById(String? id) {
    if (id == null) return null;
    for (final d in _eligibleDogs) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    final session = widget.game.activeBreeding;
    if (session != null) {
      _parent1Id = session.parent1Id;
      _parent2Id = session.parent2Id;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final active = widget.game.activeBreeding;
      if (active != null) {
        if (active.isReady && !active.readyNotified) {
          widget.game.tickIncome();
          SoundManager.instance.playDogBark(isPuppy: true, force: true);
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    setState(() => _toastMessage = message);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && _toastMessage == message) {
        setState(() => _toastMessage = null);
      }
    });
  }

  void _openDogPickerForBed(int bedIndex) {
    if (_breedingState != 'idle') return;
    SoundManager.instance.playClick();

    final otherId = bedIndex == 1 ? _parent2Id : _parent1Id;
    final otherDog = _findDogById(otherId);
    final otherPrefix =
        otherDog != null ? DogStageInfo.getBreedPrefix(otherDog.breedId) : null;

    final eligible = _eligibleDogs.where((d) => d.id != otherId).toList();

    showDialog(
      context: context,
      builder: (ctx) => _DogBedPickerDialog(
        bedIndex: bedIndex,
        eligibleDogs: eligible,
        requiredBreedPrefix: otherPrefix,
        onSelectDog: (dog) {
          Navigator.of(ctx).pop();
          setState(() {
            if (bedIndex == 1) {
              _parent1Id = dog.id;
            } else {
              _parent2Id = dog.id;
            }
          });
        },
      ),
    );
  }

  void _startBreeding(DogModel? p1, DogModel? p2) {
    if (p1 == null || p2 == null) {
      SoundManager.instance.playSadWhimper();
      _showToast('Add an Adult (Lv.$minBreedingLevel+) dog to both beds first!');
      return;
    }
    if (p1.isOnBreedingCooldown) {
      SoundManager.instance.playSadWhimper();
      _showToast(
        '${p1.name} is recovering (${DogStageInfo.formatDuration(p1.breedingCooldownRemainingSeconds)})!',
      );
      return;
    }
    if (p2.isOnBreedingCooldown) {
      SoundManager.instance.playSadWhimper();
      _showToast(
        '${p2.name} is recovering (${DogStageInfo.formatDuration(p2.breedingCooldownRemainingSeconds)})!',
      );
      return;
    }
    if (DogStageInfo.getBreedPrefix(p1.breedId) !=
        DogStageInfo.getBreedPrefix(p2.breedId)) {
      SoundManager.instance.playSadWhimper();
      _showToast('Both dogs must be the same breed!');
      return;
    }
    if (widget.game.coins < _breedingCostCoins) {
      SoundManager.instance.playSadWhimper();
      _showToast('You need $_breedingCostCoins Paw Coins to breed!');
      return;
    }

    final ok = widget.game.startBreeding(p1, p2, costCoins: _breedingCostCoins);
    if (!ok) {
      _showToast('Unable to start breeding right now.');
      return;
    }
    setState(() {});
  }

  void _sellHatchedPuppy() {
    final pup = _hatchedPup;
    if (pup == null) return;
    if (!widget.game.sellBredPuppy(_puppySellCoins)) return;
    setState(() {
      _parent1Id = null;
      _parent2Id = null;
    });
    _showToast('Sold ${pup.breedName} Pup for +$_puppySellCoins Paw Coins!');
  }

  void _openPlaceHabitatDialog() {
    final pup = _hatchedPup;
    if (pup == null) return;
    SoundManager.instance.playClick();

    final openHabitats = widget.game.placedHabitats
        .where(
          (h) =>
              h.type == 'habitat' &&
              !h.underConstruction &&
              h.dogs.length < 4 &&
              HabitatCatalog.isHabitatCompatible(
                habitatCatalogId: h.habitatId,
                breedId: pup.breedId,
                element: pup.element,
              ),
        )
        .toList();

    if (openHabitats.isEmpty) {
      final reqHab = HabitatCatalog.requiredHabitatNameForDog(
        breedId: pup.breedId,
        element: pup.element,
      );
      SoundManager.instance.playSadWhimper();
      _showToast('Need an open $reqHab habitat (<4 dogs) or sell pup!');
      return;
    }

    if (widget.onStartPlaceBredPuppy != null) {
      widget.onStartPlaceBredPuppy!(
        pup.breedId,
        pup.breedName,
        pup.element,
        pup.sitImg,
      );
      return;
    }

    if (openHabitats.length == 1) {
      _placePuppyInHabitat(openHabitats.first);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PlaceHabitatPickerDialog(
        puppyName: 'Purebred ${pup.breedName} Pup',
        habitats: openHabitats,
        onSelectHabitat: (hab) {
          Navigator.of(ctx).pop();
          _placePuppyInHabitat(hab);
        },
      ),
    );
  }

  void _placePuppyInHabitat(HabitatModel hab) {
    final pup = _hatchedPup;
    if (pup == null) return;
    final placedName = widget.game.claimBredPuppyToHabitat(hab.id);
    if (placedName == null) {
      SoundManager.instance.playSadWhimper();
      _showToast('Could not place puppy in ${hab.name}.');
      return;
    }
    SoundManager.instance.playQuestReward();
    setState(() {
      _parent1Id = null;
      _parent2Id = null;
    });
    _showToast('${pup.breedName} Pup placed in $placedName!');
  }

  @override
  Widget build(BuildContext context) {
    final p1 = _findDogById(_parent1Id);
    final p2 = _findDogById(_parent2Id);
    final bool canBreed = p1 != null &&
        p2 != null &&
        DogStageInfo.getBreedPrefix(p1.breedId) ==
            DogStageInfo.getBreedPrefix(p2.breedId);

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;
          final isCompact = screenW < 880;

          // Match BoxFit.cover geometry of BreedingDenInsideView.png (16:9)
          const imgAspect = 16.0 / 9.0;
          double imgW = screenW;
          double imgH = screenW / imgAspect;
          if (imgH < screenH) {
            imgH = screenH;
            imgW = screenH * imgAspect;
          }
          final offsetX = (screenW - imgW) / 2;
          final offsetY = (screenH - imgH) / 2;

          Offset mapPoint(double nx, double ny) =>
              Offset(offsetX + nx * imgW, offsetY + ny * imgH);

          final leftBedPos = mapPoint(0.355, 0.515);
          final rightBedPos = mapPoint(0.645, 0.515);
          final carpetPos = mapPoint(0.50, 0.805);
          final midHeartPos = mapPoint(0.50, 0.46);

          final bedSlotW = (imgW * 0.16).clamp(112.0, 210.0);
          final bedSlotH = (imgH * 0.22).clamp(100.0, 185.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. Breeding Den Inside View Background ──
              Positioned(
                left: offsetX,
                top: offsetY,
                width: imgW,
                height: imgH,
                child: Image.asset(
                  'assets/itemsInShop/building/BreedingDenInsideView.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),

              // ── 2. Top Bar (Back Button + Title + Coins) ──
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    HoverScale(
                      scale: 1.05,
                      onTap: widget.onBackToWorld,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF92400E), Color(0xFF451A03)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFBBF24),
                            width: 1.8,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              color: Color(0xFFFEF08A),
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'BACK TO ISLAND',
                              style: TextStyle(
                                color: Color(0xFFFEF08A),
                                fontFamily: 'Lilita One',
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9F1239), Color(0xFF4C0519)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFDA4AF),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFFDA4AF),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'BREEDING DEN',
                            style: TextStyle(
                              color: const Color(0xFFFFF1F2),
                              fontFamily: 'Lilita One',
                              fontSize: isCompact ? 14 : 17,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC290E02),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFBBF24),
                          width: 1.6,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/ui/coins.png',
                            width: 18,
                            height: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            GameController.formatCoins(widget.game.coins),
                            style: const TextStyle(
                              color: Color(0xFFFEF08A),
                              fontFamily: 'Lilita One',
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── 3. Left Bed Slot ──
              Positioned(
                left: leftBedPos.dx - bedSlotW / 2,
                top: leftBedPos.dy - bedSlotH / 2,
                width: bedSlotW,
                height: bedSlotH,
                child: _buildBedSlot(
                  bedIndex: 1,
                  dog: p1,
                  isCompact: isCompact,
                ),
              ),

              // ── 4. Right Bed Slot ──
              Positioned(
                left: rightBedPos.dx - bedSlotW / 2,
                top: rightBedPos.dy - bedSlotH / 2,
                width: bedSlotW,
                height: bedSlotH,
                child: _buildBedSlot(
                  bedIndex: 2,
                  dog: p2,
                  isCompact: isCompact,
                ),
              ),

              // ── 5. Breeding Heart & Rising Sparkles Animation Between Beds ──
              if (_breedingState == 'breeding')
                Positioned(
                  left: midHeartPos.dx - 110,
                  top: midHeartPos.dy - 95,
                  width: 220,
                  height: 170,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        final t = _pulseController.value;
                        final scale = 0.92 + 0.24 * sin(t * pi);

                        Widget floatingHeart(
                          double baseX,
                          double phase,
                          double size,
                          Color color,
                        ) {
                          final p = (t + phase) % 1.0;
                          final dy = 110 - p * 95;
                          final dx = baseX + sin(p * 2 * pi) * 12;
                          final op = p < 0.2
                              ? p / 0.2
                              : (p > 0.75 ? (1.0 - p) / 0.25 : 1.0);
                          return Positioned(
                            left: dx,
                            top: dy,
                            child: Opacity(
                              opacity: op.clamp(0.0, 1.0),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: color,
                                size: size,
                              ),
                            ),
                          );
                        }

                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            floatingHeart(42, 0.0, 16, const Color(0xFFFDA4AF)),
                            floatingHeart(158, 0.25, 18, const Color(0xFFF472B6)),
                            floatingHeart(72, 0.50, 14, const Color(0xFFFDE047)),
                            floatingHeart(132, 0.75, 16, const Color(0xFFFFE4E6)),
                            Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Color(0xDDF43F5E),
                                      Color(0x55FB7185),
                                      Color(0x00F43F5E),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: Color(0xFFFFE4E6),
                                  size: 48,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

              // ── 6. Center Carpet Area (Start Breeding / Progress / Hatched Puppy + Sell or Place) ──
              Positioned(
                left: max(12.0, carpetPos.dx - 230),
                right: max(12.0, screenW - (carpetPos.dx + 230)),
                top: max(100.0, carpetPos.dy - (isCompact ? 92 : 112)),
                bottom: 10,
                child: Center(
                  child: _buildCarpetContent(p1, p2, canBreed, isCompact),
                ),
              ),

              // ── 7. Toast Notification ──
              if (_toastMessage != null)
                Positioned(
                  top: 66,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE6290E02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFBBF24),
                            width: 1.8,
                          ),
                        ),
                        child: Text(
                          _toastMessage!,
                          style: const TextStyle(
                            color: Color(0xFFFEF08A),
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBedSlot({
    required int bedIndex,
    required DogModel? dog,
    required bool isCompact,
  }) {
    if (dog == null) {
      return Center(
        child: HoverScale(
          scale: 1.07,
          onTap: _breedingState == 'idle'
              ? () => _openDogPickerForBed(bedIndex)
              : null,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: isCompact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFEF3C7), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_circle_rounded,
                  color: Color(0xFF3B1404),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'ADD DOG',
                  style: TextStyle(
                    color: const Color(0xFF3B1404),
                    fontFamily: 'Lilita One',
                    fontSize: isCompact ? 12 : 13.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final info = DogStageInfo.getInfo(dog);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _breedingState == 'idle'
              ? () => _openDogPickerForBed(bedIndex)
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: _breedingState == 'breeding'
                    ? AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final wave = sin(_pulseController.value * pi);
                          final dir = bedIndex == 1 ? 1.0 : -1.0;
                          final dx = dir * 10.0 * wave;
                          final dy = -7.0 * wave.abs();
                          final tilt = dir * 0.07 * wave;
                          final sx = (bedIndex == 2 ? -1.0 : 1.0) *
                              (1.0 + 0.05 * wave);
                          final sy = 1.0 - 0.04 * wave;
                          return Transform.translate(
                            offset: Offset(dx, dy),
                            child: Transform.rotate(
                              angle: tilt,
                              child: Transform.scale(
                                scaleX: sx,
                                scaleY: sy,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: Image.asset(
                          info.sitImg,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      )
                    : Transform.scale(
                        scaleX: bedIndex == 2 ? -1.0 : 1.0,
                        child: Image.asset(
                          info.sitImg,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xDD290E02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFBBF24),
                    width: 1.3,
                  ),
                ),
                child: Text(
                  '${dog.name} • Lv.${dog.level}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFFEF08A),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 10.5 : 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_breedingState == 'idle')
          Positioned(
            top: 0,
            right: 4,
            child: HoverScale(
              scale: 1.12,
              onTap: () {
                SoundManager.instance.playClick();
                setState(() {
                  if (bedIndex == 1) {
                    _parent1Id = null;
                  } else {
                    _parent2Id = null;
                  }
                });
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDC2626),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCarpetContent(
    DogModel? p1,
    DogModel? p2,
    bool canBreed,
    bool isCompact,
  ) {
    if (_breedingState == 'breeding') {
      final session = widget.game.activeBreeding!;
      final remSec = session.remainingSeconds;
      final skipCost = GameController.speedUpCostForSeconds(remSec);
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 20,
          vertical: isCompact ? 8 : 11,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9F1239), Color(0xFF4C0519)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFDA4AF), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFDE047)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'BREEDING · ${DogStageInfo.formatDuration(remSec)}',
                  style: TextStyle(
                    color: const Color(0xFFFFF1F2),
                    fontFamily: 'Lilita One',
                    fontSize: isCompact ? 13 : 15,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: isCompact ? 180 : 230,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: session.progress,
                  minHeight: 7,
                  backgroundColor: const Color(0x66000000),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFBBF24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            HoverScale(
              scale: 1.06,
              onTap: () {
                if (!widget.game.speedUpBreeding()) {
                  _showToast('Need $skipCost Diamonds to speed up!');
                } else {
                  setState(() {});
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/ui/diamonds.png', width: 13, height: 13),
                    const SizedBox(width: 4),
                    Text(
                      'FINISH NOW · $skipCost',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_breedingState == 'hatched' && _hatchedPup != null) {
      final pup = _hatchedPup!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final dy = -6.0 * Curves.easeInOut.transform(_pulseController.value);
              return Transform.translate(
                offset: Offset(0, dy),
                child: child,
              );
            },
            child: Image.asset(
              pup.sitImg,
              width: isCompact ? 78 : 104,
              height: isCompact ? 78 : 104,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xDD290E02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
            ),
            child: Text(
              'NEW ${pup.breedName.toUpperCase()} PUP!',
              style: TextStyle(
                color: const Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: isCompact ? 12 : 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HoverScale(
                scale: 1.06,
                onTap: _sellHatchedPuppy,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 14 : 18,
                    vertical: isCompact ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFEF3C7), width: 1.8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/ui/coins.png', width: 16, height: 16),
                      const SizedBox(width: 5),
                      Text(
                        'SELL +$_puppySellCoins',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: isCompact ? 12.5 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              HoverScale(
                scale: 1.06,
                onTap: _openPlaceHabitatDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 14 : 20,
                    vertical: isCompact ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF047857)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFEF08A), width: 1.8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'PLACE IN HABITAT',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: isCompact ? 12.5 : 14,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Idle state
    if (!canBreed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xCC290E02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x88FBBF24), width: 1.5),
        ),
        child: Text(
          'Add two Adult (Lv.$minBreedingLevel+) dogs of the same breed to the beds above!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFFEF3C7),
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 12 : 13.5,
          ),
        ),
      );
    }

    return HoverScale(
      scale: 1.06,
      onTap: () => _startBreeding(p1, p2),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20 : 28,
          vertical: isCompact ? 10 : 13,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFEF08A), width: 2.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'START BREEDING',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: isCompact ? 15 : 17,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x44000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/ui/coins.png', width: 14, height: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$_breedingCostCoins',
                    style: const TextStyle(
                      color: Color(0xFFFEF08A),
                      fontFamily: 'Lilita One',
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HatchedPuppyResult {
  final String breedId;
  final String breedName;
  final String element;
  final String sitImg;

  const _HatchedPuppyResult({
    required this.breedId,
    required this.breedName,
    required this.element,
    required this.sitImg,
  });
}

class _DogBedPickerDialog extends StatelessWidget {
  final int bedIndex;
  final List<DogModel> eligibleDogs;
  final String? requiredBreedPrefix;
  final ValueChanged<DogModel> onSelectDog;

  const _DogBedPickerDialog({
    required this.bedIndex,
    required this.eligibleDogs,
    required this.requiredBreedPrefix,
    required this.onSelectDog,
  });

  @override
  Widget build(BuildContext context) {
    final matchingDogs = requiredBreedPrefix == null
        ? eligibleDogs
        : eligibleDogs
            .where(
              (d) => DogStageInfo.getBreedPrefix(d.breedId) == requiredBreedPrefix,
            )
            .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 460),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF78350F), width: 3.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0xCC000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'SELECT DOG FOR BED $bedIndex',
                  style: const TextStyle(
                    color: Color(0xFF3B1404),
                    fontFamily: 'Lilita One',
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                HoverScale(
                  scale: 1.1,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF78350F),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              requiredBreedPrefix == null
                  ? 'Only Adult (Lv.$minBreedingLevel+) dogs can breed.'
                  : 'Showing compatible Adult (Lv.$minBreedingLevel+) $requiredBreedPrefix dogs.',
              style: const TextStyle(
                color: Color(0xFF78350F),
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            if (matchingDogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'No eligible Adult dogs available!\nLevel up two dogs of the same breed to Lv.$minBreedingLevel+.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: matchingDogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final dog = matchingDogs[index];
                    final info = DogStageInfo.getInfo(dog);
                    final rarity = DogStageInfo.getRarityForBreed(dog.breedId);
                    final onCooldown = dog.isOnBreedingCooldown;
                    return HoverScale(
                      scale: onCooldown ? 1.0 : 1.02,
                      onTap: onCooldown ? null : () => onSelectDog(dog),
                      child: Opacity(
                        opacity: onCooldown ? 0.6 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: onCooldown
                                ? const Color(0xFFF3E8D8)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: onCooldown
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFFD97706),
                              width: 1.6,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                info.sitImg,
                                width: 46,
                                height: 46,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dog.name,
                                      style: const TextStyle(
                                        color: Color(0xFF3B1404),
                                        fontFamily: 'Lilita One',
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '${info.breedName} • Lv.${dog.level} • ${rarity.label}',
                                      style: const TextStyle(
                                        color: Color(0xFF92400E),
                                        fontFamily: 'Fredoka',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      onCooldown
                                          ? 'Recovering: ${DogStageInfo.formatDuration(dog.breedingCooldownRemainingSeconds)}'
                                          : 'Recovery after breed: ${rarity.formattedRecovery}',
                                      style: TextStyle(
                                        color: onCooldown
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF059669),
                                        fontFamily: 'Fredoka',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: onCooldown
                                      ? const Color(0xFF6B7280)
                                      : const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  onCooldown ? 'COOLDOWN' : 'SELECT',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Lilita One',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlaceHabitatPickerDialog extends StatelessWidget {
  final String puppyName;
  final List<HabitatModel> habitats;
  final ValueChanged<HabitatModel> onSelectHabitat;

  const _PlaceHabitatPickerDialog({
    required this.puppyName,
    required this.habitats,
    required this.onSelectHabitat,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF78350F), width: 3.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CHOOSE A HABITAT',
                    style: TextStyle(
                      color: Color(0xFF3B1404),
                      fontFamily: 'Lilita One',
                      fontSize: 18,
                    ),
                  ),
                ),
                HoverScale(
                  scale: 1.1,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF78350F),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select a home for your $puppyName:',
              style: const TextStyle(
                color: Color(0xFF78350F),
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: habitats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final hab = habitats[index];
                  return HoverScale(
                    scale: 1.02,
                    onTap: () => onSelectHabitat(hab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981),
                          width: 1.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hab.name,
                                  style: const TextStyle(
                                    color: Color(0xFF3B1404),
                                    fontFamily: 'Lilita One',
                                    fontSize: 14.5,
                                  ),
                                ),
                                Text(
                                  '${hab.dogs.length} / 4 Dogs',
                                  style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'PLACE',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Lilita One',
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
