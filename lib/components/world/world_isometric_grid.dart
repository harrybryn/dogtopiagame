import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/habitat_model.dart';
import '../../models/habitat_catalog.dart';
import '../../models/dog_evolution.dart';
import '../../models/obstacle_model.dart';
import '../../services/audio_service.dart';
import '../common/hover_scale.dart';
import '../common/loading_progress_bar.dart';
import 'habitat_wandering_dog.dart';

const int gridCols = 26;
const int gridRows = 24;
const double tileW = 76.0;
const double tileH = 38.0;
const double originX = 1000.0;
const double originY = 110.0;
const double worldWidth = 2000.0;
const double worldHeight = 1125.0;

Offset gridToIso(int c, int r) {
  final x = originX + (c - r) * (tileW / 2);
  final y = originY + (c + r) * (tileH / 2);
  return Offset(x, y);
}

({int c, int r}) isoToGrid(double x, double y) {
  final dx = x - originX;
  final dy = y - originY;
  final c = ((dy / (tileH / 2) + dx / (tileW / 2)) / 2).round();
  final r = ((dy / (tileH / 2) - dx / (tileW / 2)) / 2).round();
  return (c: c, r: r);
}

bool isTileBuildable(int c, int r) {
  if (c < 0 || c >= gridCols || r < 0 || r >= gridRows) return false;
  // Match React WorldGrid.jsx buildable territory bounds
  if (c + r <= 2) return false;
  if (c + r >= 46) return false;
  if (r - c >= 21) return false;
  if (c - r >= 23) return false;
  return true;
}

({Offset pTop, Offset pRight, Offset pBottom, Offset pLeft, Offset center})
getHabitatCorners(int col, int row, int w, int h) {
  final pTop = Offset(
    originX + (col - row) * (tileW / 2),
    originY + (col + row) * (tileH / 2) - tileH / 2,
  );
  final pRight = Offset(
    originX + (col - row + w) * (tileW / 2),
    originY + (col + w + row - 1) * (tileH / 2),
  );
  final pBottom = Offset(
    originX + (col - row + w - h) * (tileW / 2),
    originY + (col + w + row + h - 2) * (tileH / 2) + tileH / 2,
  );
  final pLeft = Offset(
    originX + (col - row - h) * (tileW / 2),
    originY + (col + row + h - 1) * (tileH / 2),
  );
  final center = Offset((pTop.dx + pBottom.dx) / 2, (pTop.dy + pBottom.dy) / 2);
  return (
    pTop: pTop,
    pRight: pRight,
    pBottom: pBottom,
    pLeft: pLeft,
    center: center,
  );
}

class WorldIsometricGrid extends StatefulWidget {
  final List<HabitatModel> habitats;
  final String? selectedHabitatId;
  final bool gridVisible;
  final HabitatCatalogItem? placingItem;
  final String? movingHabitatId;
  final Function(HabitatModel) onSelectHabitat;
  final Function(String habitatId) onCollectCoins;
  final Function(String habitatId) onCollectDogfood;
  final Function(String habitatId)? onCompleteConstruction;
  final Function(String habitatId)? onSpeedUpConstruction;
  final String surfaceAsset;
  final bool isOverview;
  final Function(int col, int row)? onConfirmPlace;
  final VoidCallback? onCancelPlace;
  final Function(HabitatModel)? onStartMove;
  final Set<String>? highlightedHabitatIds;
  final bool isSelectingHabitat;
  final Function(HabitatModel)? onSelectTargetHabitat;

  // Obstacle & Locked Lot Extension properties (2 Lots: Lot 1 = Upper [c >= 13, r < 12], Lot 2 = Lower [c >= 13, r >= 12])
  final List<ObstacleModel> obstacles;
  final String? selectedObstacleId;
  final bool isLotExpansionUnlocked;
  final bool isLot1Unlocked;
  final bool isLot2Unlocked;
  final bool isIslandHydrated;
  final Function(ObstacleModel)? onSelectObstacle;
  final Function(String obstacleId)? onStartClearingObstacle;
  final Function(String obstacleId)? onCompleteClearingObstacle;
  final VoidCallback? onUnlockLotExpansion;
  final Function(int lotNumber)? onUnlockLot;

  const WorldIsometricGrid({
    super.key,
    required this.habitats,
    this.selectedHabitatId,
    this.gridVisible = false,
    this.placingItem,
    this.movingHabitatId,
    required this.onSelectHabitat,
    required this.onCollectCoins,
    required this.onCollectDogfood,
    this.onCompleteConstruction,
    this.onSpeedUpConstruction,
    this.surfaceAsset = 'assets/ui/LandSurface.png',
    this.isOverview = false,
    this.onConfirmPlace,
    this.onCancelPlace,
    this.onStartMove,
    this.highlightedHabitatIds,
    this.isSelectingHabitat = false,
    this.onSelectTargetHabitat,
    this.obstacles = const [],
    this.selectedObstacleId,
    this.isLotExpansionUnlocked = false,
    this.isLot1Unlocked = false,
    this.isLot2Unlocked = false,
    this.isIslandHydrated = true,
    this.onSelectObstacle,
    this.onStartClearingObstacle,
    this.onCompleteClearingObstacle,
    this.onUnlockLotExpansion,
    this.onUnlockLot,
  });

  @override
  State<WorldIsometricGrid> createState() => _WorldIsometricGridState();
}

class _WorldIsometricGridState extends State<WorldIsometricGrid>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _ambientController;
  Timer? _oneSecTimer;
  int _now = DateTime.now().millisecondsSinceEpoch;
  int _ghostCol = 11;
  int _ghostRow = 9;
  final List<ObstacleModel> _vanishingObstacles = [];

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();

    _oneSecTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final hasActiveTimers =
          widget.habitats.any((h) => h.underConstruction) ||
          widget.obstacles.any((o) => o.isClearing);
      if (!hasActiveTimers) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _now = now;
      });
      for (final hab in widget.habitats) {
        if (hab.underConstruction &&
            (hab.constructionEndsAt ?? 0) > 0 &&
            now >= hab.constructionEndsAt!) {
          widget.onCompleteConstruction?.call(hab.id);
        }
      }
      for (final obs in widget.obstacles) {
        if (obs.isClearing &&
            (obs.clearingEndsAt ?? 0) > 0 &&
            now >= obs.clearingEndsAt! &&
            !_vanishingObstacles.any((v) => v.id == obs.id)) {
          _triggerObstacleVanish(obs);
          widget.onCompleteClearingObstacle?.call(obs.id);
        }
      }
    });

    _syncGhostPos();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _ambientController.dispose();
    _oneSecTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WorldIsometricGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.movingHabitatId != oldWidget.movingHabitatId ||
        widget.placingItem != oldWidget.placingItem) {
      _syncGhostPos();
    }
    if (widget.habitats.any((h) => h.underConstruction) ||
        widget.obstacles.any((o) => o.isClearing)) {
      _now = DateTime.now().millisecondsSinceEpoch;
    }
    final currentIds = widget.obstacles.map((o) => o.id).toSet();
    for (final oldObs in oldWidget.obstacles) {
      if (oldObs.isClearing && !currentIds.contains(oldObs.id)) {
        _triggerObstacleVanish(oldObs);
      }
    }
  }

  void _triggerObstacleVanish(ObstacleModel obs) {
    if (_vanishingObstacles.any((v) => v.id == obs.id)) return;
    setState(() {
      _vanishingObstacles.add(obs);
    });
  }

  void _syncGhostPos() {
    if (widget.movingHabitatId != null) {
      final movingHab = widget.habitats.firstWhere(
        (h) => h.id == widget.movingHabitatId,
        orElse: () =>
            HabitatModel(id: '', habitatId: '', name: '', col: 11, row: 9),
      );
      _ghostCol = movingHab.col;
      _ghostRow = movingHab.row;
    } else if (widget.placingItem != null) {
      _ghostCol = 11;
      _ghostRow = 9;
    }
  }

  bool _isTileUnlocked(int c, int r) {
    if (r >= 11) return true; // Entire bottom strip always unlocked
    if (c < 13 && r < 11)
      return widget.isLot1Unlocked; // Expansion Lot 1 (Top-left / Bench)
    return widget.isLot2Unlocked; // Expansion Lot 2 (Top-right, locked)
  }

  bool _isFootprintValid(int col, int row, int w, int h) {
    for (int c = col; c < col + w; c++) {
      for (int r = row; r < row + h; r++) {
        if (!isTileBuildable(c, r)) return false;
        // Cannot place on locked lot expansion area
        if (!_isTileUnlocked(c, r)) return false;

        for (final hab in widget.habitats) {
          if (hab.id == widget.movingHabitatId) continue;
          if (c >= hab.col &&
              c < hab.col + hab.sizeW &&
              r >= hab.row &&
              r < hab.row + hab.sizeH) {
            return false;
          }
        }

        // Cannot place over uncleared obstacles
        for (final obs in widget.obstacles) {
          if (c >= obs.col &&
              c < obs.col + obs.sizeW &&
              r >= obs.row &&
              r < obs.row + obs.sizeH) {
            return false;
          }
        }
      }
    }
    return true;
  }

  void _snapGhostToOffset(Offset localPos, int w, int h) {
    final gridPos = isoToGrid(localPos.dx, localPos.dy);
    final targetC = gridPos.c - (w ~/ 2);
    final targetR = gridPos.r - (h ~/ 2);
    final nextC = targetC.clamp(0, gridCols - w);
    final nextR = targetR.clamp(0, gridRows - h);
    if (nextC != _ghostCol || nextR != _ghostRow) {
      setState(() {
        _ghostCol = nextC;
        _ghostRow = nextR;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allWorldEntities =
        <dynamic>[
          ...widget.habitats.where((h) => h.id != widget.movingHabitatId),
          ...widget.obstacles,
        ]..sort((a, b) {
          final colA = a is HabitatModel ? a.col : (a as ObstacleModel).col;
          final rowA = a is HabitatModel ? a.row : (a as ObstacleModel).row;
          final sizeA = a is HabitatModel
              ? (a.sizeW + a.sizeH) * 0.5
              : (a as ObstacleModel).sizeW * 0.5;

          final colB = b is HabitatModel ? b.col : (b as ObstacleModel).col;
          final rowB = b is HabitatModel ? b.row : (b as ObstacleModel).row;
          final sizeB = b is HabitatModel
              ? (b.sizeW + b.sizeH) * 0.5
              : (b as ObstacleModel).sizeW * 0.5;

          return (colA + rowA + sizeA).compareTo(colB + rowB + sizeB);
        });

    final isPlacing =
        widget.placingItem != null || widget.movingHabitatId != null;
    final movingHab = widget.movingHabitatId != null
        ? widget.habitats.firstWhere(
            (h) => h.id == widget.movingHabitatId,
            orElse: () => HabitatModel(
              id: '',
              habitatId: '',
              name: '',
              col: 0,
              row: 0,
            ),
          )
        : null;
    final itemW = widget.placingItem?.sizeW ?? movingHab?.sizeW ?? 3;
    final itemH = widget.placingItem?.sizeH ?? movingHab?.sizeH ?? 3;
    final canPlaceGhost = _isFootprintValid(_ghostCol, _ghostRow, itemW, itemH);

    final content = SizedBox(
      width: worldWidth,
      height: worldHeight,
      child: Stack(
        children: [
          // ── Background Island Surface + Locked Lot Overlay (cached on GPU) ──
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.surfaceAsset,
                    fit: BoxFit.cover,
                    cacheWidth: 2000,
                    filterQuality: FilterQuality.medium,
                  ),
                  if (!widget.isLot1Unlocked || !widget.isLot2Unlocked)
                    CustomPaint(
                      painter: _LockedLotTerritoryPainter(
                        isLot1Unlocked: widget.isLot1Unlocked,
                        isLot2Unlocked: widget.isLot2Unlocked,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Grid Lines Layer (if placing or gridVisible) ──
          if (widget.gridVisible || isPlacing)
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(
                  ghostCol: isPlacing ? _ghostCol : null,
                  ghostRow: isPlacing ? _ghostRow : null,
                  ghostW: itemW,
                  ghostH: itemH,
                  isGhostValid: canPlaceGhost,
                  isPlacing: isPlacing,
                  isLot1Unlocked: widget.isLot1Unlocked,
                  isLot2Unlocked: widget.isLot2Unlocked,
                ),
              ),
            ),

          // ── Selected Habitat Glowing Isometric Base (React #facc15 Gold Rhombus) ──
          if (widget.selectedHabitatId != null && !isPlacing)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bounceController,
                builder: (context, _) {
                  final selHab = widget.habitats
                      .cast<HabitatModel?>()
                      .firstWhere(
                        (h) => h?.id == widget.selectedHabitatId,
                        orElse: () => null,
                      );
                  if (selHab == null || selHab.id == widget.movingHabitatId) {
                    return const SizedBox.shrink();
                  }
                  return CustomPaint(
                    painter: _HabitatSelectionPainter(
                      habitat: selHab,
                      pulse: _bounceController.value,
                    ),
                  );
                },
              ),
            ),

          // ── Available Compatible Habitats Glowing Base during Adoption / Transfer ──
          if (widget.isSelectingHabitat && widget.highlightedHabitatIds != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _bounceController,
                builder: (context, _) {
                  final targetHabitats = widget.habitats
                      .where(
                        (h) => widget.highlightedHabitatIds!.contains(h.id),
                      )
                      .toList();
                  if (targetHabitats.isEmpty) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: _CompatibleHabitatsBasePainter(
                      habitats: targetHabitats,
                      pulse: _bounceController.value,
                    ),
                  );
                },
              ),
            ),

          // ── Placed Habitats & Obstacles Layer (isometrically depth-sorted) ──
          for (final entity in allWorldEntities)
            if (entity is HabitatModel)
              _buildHabitatWidget(entity, isPlacing)
            else if (entity is ObstacleModel)
              _buildObstacleWidget(entity, isPlacing),

          // ── Construction Progress Overlays (topmost for hit-testing) ──
          if (!isPlacing && !widget.isOverview)
            for (final hab in widget.habitats)
              if (hab.underConstruction && (hab.constructionEndsAt ?? 0) > _now)
                _buildConstructionOverlay(hab),

          // ── Vanishing Obstacle Animations (just cleared) ──
          for (final obs in _vanishingObstacles)
            _buildVanishingObstacleWidget(obs),

          // ── Floating Coin & Kibble Collection Bubbles (topmost for full hit-testing) ──
          if (!isPlacing && !widget.isSelectingHabitat && !widget.isOverview)
            for (final hab in widget.habitats)
              if (!(hab.underConstruction && (hab.constructionEndsAt ?? 0) > _now))
                ..._buildCollectionBubbles(hab),

          // ── 2 FOR SALE Wooden Signs on Locked Expansion Lots ──
          if (!widget.isLot1Unlocked && !isPlacing && !widget.isOverview)
            _buildForSaleSign(lotNumber: 1, col: 5, row: 4),
          if (!widget.isLot2Unlocked && !isPlacing && !widget.isOverview)
            _buildForSaleSign(lotNumber: 2, col: 18, row: 4),

          // ── Ghost Building Preview during Placement / Move ──
          if (isPlacing) _buildGhostPreview(itemW, itemH, canPlaceGhost),
        ],
      ),
    );

    if (isPlacing) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            _snapGhostToOffset(details.localPosition, itemW, itemH),
        onPanStart: (details) =>
            _snapGhostToOffset(details.localPosition, itemW, itemH),
        onPanUpdate: (details) =>
            _snapGhostToOffset(details.localPosition, itemW, itemH),
        child: content,
      );
    }

    return content;
  }

  Widget _buildHabitatWidget(HabitatModel hab, bool isPlacingMode) {
    final catItem = HabitatCatalog.findById(hab.habitatId);

    // Construction state
    final isUnderConstruction =
        hab.underConstruction && (hab.constructionEndsAt ?? 0) > _now;

    // Use UnderConstruction asset when under construction
    final imageAsset = isUnderConstruction
        ? 'assets/ui/UnderConstruction.png'
        : (catItem?.imageAsset ?? 'assets/habitats/GardenHabitat.png');

    final corners = getHabitatCorners(hab.col, hab.row, hab.sizeW, hab.sizeH);
    final footprintW = corners.pRight.dx - corners.pLeft.dx;
    final imgW = footprintW * 1.08;
    final imgH = imgW * 0.666;
    final imgX = corners.center.dx - imgW / 2;
    final imgY = corners.pBottom.dy - imgH * 0.90;

    final isSelected = hab.id == widget.selectedHabitatId;
    final isCompatible =
        widget.isSelectingHabitat &&
        (widget.highlightedHabitatIds?.contains(hab.id) ?? false);

    return Positioned(
      left: imgX,
      top: imgY,
      width: imgW,
      height: imgH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.isSelectingHabitat) {
            if (isCompatible) {
              widget.onSelectTargetHabitat?.call(hab);
            }
            return;
          }
          if (hab.dogs.isNotEmpty) {
            SoundManager.instance.playDogBark(isPuppy: hab.dogs.first.isPuppy);
          } else {
            SoundManager.instance.playClick();
          }
          widget.onSelectHabitat(hab);
        },
        onPanUpdate: (details) {
          // Direct drag-to-move detection (threshold > 6px)
          if (!isPlacingMode && details.delta.distanceSquared > 6) {
            widget.onStartMove?.call(hab);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // ── Green/Golden Glowing Highlighting for Available Compatible Habitat ──
            if (isCompatible)
              AnimatedBuilder(
                animation: _bounceController,
                builder: (context, _) {
                  final glowPulse =
                      0.65 + 0.30 * sin(_bounceController.value * 2 * pi);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer emerald aura
                      Image.asset(
                        imageAsset,
                        width: imgW * 1.12,
                        height: imgH * 1.12,
                        fit: BoxFit.contain,
                        color: const Color(
                          0xFF10B981,
                        ).withOpacity(glowPulse * 0.75),
                        colorBlendMode: BlendMode.srcIn,
                        filterQuality: FilterQuality.high,
                      ),
                      // Inner bright golden-white bloom
                      Image.asset(
                        imageAsset,
                        width: imgW * 1.05,
                        height: imgH * 1.05,
                        fit: BoxFit.contain,
                        color: const Color(
                          0xFFFEF08A,
                        ).withOpacity(glowPulse * 0.85),
                        colorBlendMode: BlendMode.srcIn,
                        filterQuality: FilterQuality.high,
                      ),
                    ],
                  );
                },
              ),

            // Clean white glow silhouette highlighting the entire habitat when selected
            if (isSelected && !widget.isSelectingHabitat)
              AnimatedBuilder(
                animation: _bounceController,
                builder: (context, _) {
                  final glowPulse =
                      0.55 + 0.20 * sin(_bounceController.value * 2 * pi);
                  return Image.asset(
                    imageAsset,
                    width: imgW * 1.03,
                    height: imgH * 1.03,
                    fit: BoxFit.contain,
                    color: Colors.white.withOpacity(glowPulse),
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.high,
                  );
                },
              ),

            // Habitat Artwork (or UnderConstruction asset, dimmed if not compatible in selection mode)
            Opacity(
              opacity: (widget.isSelectingHabitat && !isCompatible)
                  ? 0.38
                  : 1.0,
              child: _wrapAmbientMotion(
                hab: hab,
                child: Image.asset(
                  imageAsset,
                  width: imgW,
                  height: imgH,
                  fit: BoxFit.contain,
                  cacheWidth: 360,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),

            // ── Bouncing Arrow Pointing at Available Compatible Habitat ──
            if (isCompatible)
              Positioned(
                top: -72 + (sin(_bounceController.value * 2 * pi) * 10),
                child: _buildHabitatPointingArrow(hab),
              ),

            // Resident Dog(s) wander with separation & dynamic Y-depth sorting
            if (!isUnderConstruction && hab.dogs.isNotEmpty)
              Positioned.fill(
                child: HabitatPatrolGroup(
                  key: ValueKey('${hab.id}_patrol'),
                  habitatId: hab.id,
                  dogs: hab.dogs,
                  center: Offset(imgW / 2, corners.center.dy - imgY),
                  isThirsty: !widget.isIslandHydrated,
                  onTap: () => widget.onSelectHabitat(hab),
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget _wrapAmbientMotion({
    required HabitatModel hab,
    required Widget child,
  }) {
    if (hab.underConstruction) return child;

    final id = hab.habitatId.toLowerCase();
    final isSwayingDecor = id.contains('palm') ||
        id.contains('tree') ||
        id.contains('bush') ||
        id.contains('flower');
    final isFloating = id.contains('cloud') || id == 'legendary';
    final isBaking = hab.isBaking;

    if (!isSwayingDecor && !isFloating && !isBaking) return child;

    final phaseOffset = hab.col * 0.9 + hab.row * 0.7;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ambientController,
        builder: (_, inner) {
          final t = _ambientController.value * 2 * pi + phaseOffset;
          if (isSwayingDecor) {
            return Transform.rotate(
              alignment: Alignment.bottomCenter,
              angle: sin(t) * 0.03,
              child: inner,
            );
          }
          if (isFloating) {
            return Transform.translate(
              offset: Offset(0, sin(t) * 3.0),
              child: inner,
            );
          }
          // Dogfood Factory active baking pulse
          final pulse = sin(_ambientController.value * 6 * pi);
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..scaleByDouble(
                1.0 - 0.015 * pulse,
                1.0 + 0.02 * pulse,
                1.0,
                1.0,
              ),
            child: inner,
          );
        },
        child: child,
      ),
    );
  }

  List<Widget> _buildCollectionBubbles(HabitatModel hab) {
    final showCoins =
        hab.dogs.isNotEmpty && hab.readyToCollect && hab.coinsAccumulated > 0;
    final showFood =
        hab.readyToCollectDogfood && hab.dogfoodAccumulated > 0;
    if (!showCoins && !showFood) return const [];

    final corners = getHabitatCorners(hab.col, hab.row, hab.sizeW, hab.sizeH);
    final footprintW = corners.pRight.dx - corners.pLeft.dx;
    final imgW = footprintW * 1.08;
    final imgH = imgW * 0.666;
    final imgX = corners.center.dx - imgW / 2;
    final imgY = corners.pBottom.dy - imgH * 0.90;
    const double bubbleSize = 56.0;

    return [
      if (showCoins)
        _buildSingleCollectionBubble(
          left: imgX + (imgW - bubbleSize) / 2,
          baseTop: imgY - 36,
          bubbleSize: bubbleSize,
          iconAsset: 'assets/ui/coins.png',
          iconTop: 13,
          iconSize: 28,
          tooltip: 'Collect ${hab.coinsAccumulated} Paw Coins!',
          onTap: () => widget.onCollectCoins(hab.id),
        ),
      if (showFood)
        _buildSingleCollectionBubble(
          left: imgX + (imgW - bubbleSize) / 2,
          baseTop: imgY - 36,
          bubbleSize: bubbleSize,
          iconAsset: 'assets/ui/dogfood.png',
          iconTop: 14,
          iconSize: 26,
          tooltip: 'Collect ${hab.dogfoodAccumulated} Kibble!',
          onTap: () => widget.onCollectDogfood(hab.id),
        ),
    ];
  }

  Widget _buildSingleCollectionBubble({
    required double left,
    required double baseTop,
    required double bubbleSize,
    required String iconAsset,
    required double iconTop,
    required double iconSize,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _bounceController,
      builder: (_, __) {
        final floatY = _bounceController.value * 8;
        final pulseScale = 1.0 + 0.045 * sin(_bounceController.value * pi);
        return Positioned(
          top: baseTop - floatY,
          left: left,
          width: bubbleSize,
          height: bubbleSize,
          child: Transform.scale(
            scale: pulseScale,
            child: HoverScale(
            scale: 1.15,
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            tooltip: tooltip,
            child: SizedBox(
              width: bubbleSize,
              height: bubbleSize,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Image.asset(
                    'assets/ui/CollectPlaceHolder.png',
                    width: bubbleSize,
                    height: bubbleSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  Positioned(
                    top: iconTop,
                    child: Image.asset(
                      iconAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConstructionOverlay(HabitatModel hab) {
    final remainingSeconds = max(
      0,
      (((hab.constructionEndsAt ?? 0) - _now) / 1000).ceil(),
    );
    if (remainingSeconds == 0) {
      return const SizedBox.shrink();
    }

    final totalDuration = max(1, hab.constructionDuration);
    final hrs = remainingSeconds ~/ 3600;
    final mins = (remainingSeconds % 3600) ~/ 60;
    final secs = remainingSeconds % 60;
    final timeLabel = hrs > 0
        ? '${hrs}h ${mins.toString().padLeft(2, '0')}m'
        : (mins > 0
            ? '${mins}m ${secs.toString().padLeft(2, '0')}s'
            : '${remainingSeconds}s');
    final speedUpCost = remainingSeconds <= 120
        ? 2
        : (remainingSeconds <= 900
            ? 5
            : (remainingSeconds <= 7200 ? 10 : 20));

    final corners = getHabitatCorners(hab.col, hab.row, hab.sizeW, hab.sizeH);
    final footprintW = corners.pRight.dx - corners.pLeft.dx;
    final imgW = footprintW * 1.08;
    final imgH = imgW * 0.666;
    final imgX = corners.center.dx - imgW / 2;
    final imgY = corners.pBottom.dy - imgH * 0.90;

    return Positioned(
      top: imgY - 68,
      left: imgX + (imgW - 170) / 2,
      width: 170,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xEE2A1205),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: const Color(0xFFFBBF24), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.construction_rounded,
                        size: 12, color: Color(0xFFFEF08A)),
                    const SizedBox(width: 4),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontFamily: 'Lilita One',
                        fontSize: 11,
                        color: Color(0xFFFEF08A),
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              HoverScale(
                scale: 1.06,
                onTap: () => (widget.onSpeedUpConstruction ??
                        widget.onCompleteConstruction)
                    ?.call(hab.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFFEF3C7), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/ui/diamonds.png',
                        width: 12,
                        height: 12,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$speedUpCost SPEED UP',
                        style: const TextStyle(
                          fontFamily: 'Lilita One',
                          fontSize: 10,
                          color: Color(0xFF3B1404),
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 170,
            height: 16,
            child: LoadingProgressBar(
              progress: (((totalDuration - remainingSeconds) / totalDuration) *
                      100)
                  .clamp(0.0, 100.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGhostPreview(int w, int h, bool isValid) {
    final corners = getHabitatCorners(_ghostCol, _ghostRow, w, h);
    final footprintW = corners.pRight.dx - corners.pLeft.dx;
    final imgW = footprintW * 1.08;
    final imgH = imgW * 0.666;
    final imgX = corners.center.dx - imgW / 2;
    final imgY = corners.pBottom.dy - imgH * 0.90;

    final String imageAsset;
    if (widget.placingItem != null) {
      imageAsset = widget.placingItem!.assetImage;
    } else if (widget.movingHabitatId != null) {
      final movingHab = widget.habitats.firstWhere(
        (h) => h.id == widget.movingHabitatId,
        orElse: () =>
            HabitatModel(id: '', habitatId: '', name: '', col: 0, row: 0),
      );
      final cat = HabitatCatalog.findById(movingHab.habitatId);
      imageAsset = cat?.assetImage ?? 'assets/habitats/GardenHabitat.png';
    } else {
      imageAsset = 'assets/habitats/GardenHabitat.png';
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Ghost Building Graphic Preview (Pass-through pointer to canvas drag)
        Positioned(
          left: imgX,
          top: imgY,
          width: imgW,
          height: imgH,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.92,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  isValid
                      ? Colors.green.withOpacity(0.18)
                      : Colors.red.withOpacity(0.35),
                  BlendMode.srcATop,
                ),
                child: Image.asset(
                  imageAsset,
                  width: imgW,
                  height: imgH,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),

        // 2. Floating Action Buttons (Confirm ✓, Cancel ✕)
        Positioned(
          left: corners.center.dx - 80,
          top: corners.pTop.dy - 75,
          width: 160,
          height: 68,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // Prevent tap from falling through to canvas drag
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cancel Button (Red ✕)
                HoverScale(
                  scale: 1.1,
                  onTap: widget.onCancelPlace,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.3, -0.3),
                        radius: 0.8,
                        colors: [
                          Color(0xFFEF4444),
                          Color(0xFFB91C1C),
                          Color(0xFF7F1D1D),
                        ],
                      ),
                      border: Border.all(color: Colors.white, width: 3.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xCC000000),
                          offset: Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Confirm Button (Green ✓)
                HoverScale(
                  scale: isValid ? 1.1 : 1.0,
                  onTap: isValid
                      ? () => widget.onConfirmPlace?.call(_ghostCol, _ghostRow)
                      : null,
                  child: Opacity(
                    opacity: isValid ? 1.0 : 0.40,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.3),
                          radius: 0.8,
                          colors: [
                            Color(0xFF4ADE80),
                            Color(0xFF16A34A),
                            Color(0xFF14532D),
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: isValid
                            ? const [
                                BoxShadow(
                                  color: Color(0xCC16A34A),
                                  offset: Offset(0, 4),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitatPointingArrow(HabitatModel hab) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pill Badge with Habitat name & dog capacity
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFBBF24), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                color: Color(0xFFFDE047),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${hab.name.toUpperCase()} (${hab.dogs.length}/4)',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Lilita One',
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),

        // Glowing bouncing arrow circle pin
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF34D399), Color(0xFF059669)],
              center: Alignment(0, -0.3),
            ),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_downward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),

        // Sharp Arrow Tip pointing into the habitat
        CustomPaint(
          size: const Size(16, 9),
          painter: _TriangleArrowTipPainter(),
        ),
      ],
    );
  }

  Widget _buildObstacleWidget(ObstacleModel obs, bool isPlacingMode) {
    final corners = getHabitatCorners(obs.col, obs.row, obs.sizeW, obs.sizeH);
    final footprintW = corners.pRight.dx - corners.pLeft.dx;
    double scaleMultiplier = obs.sizeW == 1 ? 1.55 : 1.25;
    if (obs.imageAsset.contains('IcePineTree')) {
      scaleMultiplier = 2.05;
    } else if (obs.imageAsset.contains('IceSpikeRock')) {
      scaleMultiplier = 0.95;
    } else if (obs.imageAsset.contains('LegendaryPillar')) {
      scaleMultiplier = 1.95;
    }
    final double aspect = obs.type == 'tree'
        ? (1199.0 / 1312.0)
        : (obs.type == 'tree_rock' ? (1145.0 / 1374.0) : (1024.0 / 1536.0));
    final imgW = footprintW * scaleMultiplier;
    final imgH = imgW * aspect;
    final imgX = corners.center.dx - imgW / 2;
    final imgY = corners.pBottom.dy - imgH * 0.88;

    final isSelected = obs.id == widget.selectedObstacleId;
    final isClearing = obs.isClearing;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final remainingSeconds = isClearing
        ? max(0, (((obs.clearingEndsAt ?? 0) - nowMs) / 1000).ceil())
            .clamp(0, max(1, obs.clearDuration))
        : 0;
    final isClearingFinished =
        isClearing && (obs.clearingEndsAt ?? 0) <= nowMs;
    final progress = isClearing
        ? (1.0 - (remainingSeconds / max(1, obs.clearDuration))).clamp(0.0, 1.0)
        : 0.0;

    final isLockedLot =
        (obs.col < 13 && obs.row < 11 && !widget.isLot1Unlocked) ||
        (obs.col >= 13 &&
            obs.row < 11 &&
            !widget.isLot2Unlocked); // Top-right only

    return Positioned(
      left: imgX,
      top: imgY,
      width: imgW,
      height: imgH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isPlacingMode || widget.isSelectingHabitat) return;
          if (isClearingFinished) {
            widget.onCompleteClearingObstacle?.call(obs.id);
            return;
          }
          if (isClearing) return;
          widget.onSelectObstacle?.call(obs);
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // ── Glowing Effect when Selected OR while Removing ──
            if (isSelected || isClearing)
              AnimatedBuilder(
                animation: _bounceController,
                builder: (context, _) {
                  final glowPulse =
                      0.60 + 0.30 * sin(_bounceController.value * 2 * pi);
                  return Image.asset(
                    obs.imageAsset,
                    width: imgW * 1.08,
                    height: imgH * 1.08,
                    fit: BoxFit.contain,
                    color: (isClearing ? const Color(0xFFFBBF24) : Colors.white)
                        .withOpacity(glowPulse),
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.high,
                  );
                },
              ),

            // ── Obstacle Artwork ──
            Opacity(
              opacity: isLockedLot ? 0.55 : 1.0,
              child: ((obs.type == 'tree' || obs.type == 'tree_rock') &&
                      !obs.imageAsset.contains('Legendary'))
                  ? RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _ambientController,
                        builder: (_, inner) {
                          final angle = sin(
                                _ambientController.value * 2 * pi +
                                    obs.col * 0.9 +
                                    obs.row * 0.7,
                              ) *
                              0.026;
                          return Transform.rotate(
                            alignment: Alignment.bottomCenter,
                            angle: angle,
                            child: inner,
                          );
                        },
                        child: Image.asset(
                          obs.imageAsset,
                          width: imgW,
                          height: imgH,
                          fit: BoxFit.contain,
                          cacheWidth: 256,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    )
                  : Image.asset(
                      obs.imageAsset,
                      width: imgW,
                      height: imgH,
                      fit: BoxFit.contain,
                      cacheWidth: 256,
                      filterQuality: FilterQuality.medium,
                    ),
            ),

            // ── Clearing Timer & Progress Bar (Real-time countdown) ──
            if (isClearing && !isClearingFinished)
              Positioned(
                top: -55,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE2A1205),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFBBF24),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: Color(0xFFFBBF24),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '00:${remainingSeconds.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lilita One',
                              fontSize: 10.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Progress Bar (110px wide)
                    SizedBox(
                      width: 110,
                      height: 10,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Stack(
                          children: [
                            Container(color: const Color(0xCC000000)),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF34D399),
                                      Color(0xFF10B981),
                                      Color(0xFF059669),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Finished Clearing Indicator (Tap to collect XP & free tile) ──
            if (isClearingFinished)
              Positioned(
                top: -45,
                child: HoverScale(
                  scale: 1.15,
                  onTap: () => widget.onCompleteClearingObstacle?.call(obs.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'CLEARED!',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Lilita One',
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVanishingObstacleWidget(ObstacleModel obs) {
    final corners = getHabitatCorners(obs.col, obs.row, obs.sizeW, obs.sizeH);
    final footprintW = corners.pRight.dx - corners.pLeft.dx;
    double scaleMultiplier = obs.sizeW == 1 ? 1.55 : 1.25;
    if (obs.imageAsset.contains('IcePineTree')) {
      scaleMultiplier = 2.05;
    } else if (obs.imageAsset.contains('IceSpikeRock')) {
      scaleMultiplier = 0.95;
    } else if (obs.imageAsset.contains('LegendaryPillar')) {
      scaleMultiplier = 1.95;
    }
    final double aspect = obs.type == 'tree'
        ? (1199.0 / 1312.0)
        : (obs.type == 'tree_rock' ? (1145.0 / 1374.0) : (1024.0 / 1536.0));
    final imgW = footprintW * scaleMultiplier;
    final imgH = imgW * aspect;
    final imgX = corners.center.dx - imgW / 2;
    final imgY = corners.pBottom.dy - imgH * 0.88;

    return Positioned(
      key: ValueKey('vanish_${obs.id}'),
      left: imgX,
      top: imgY,
      width: imgW,
      height: imgH,
      child: IgnorePointer(
        child: _VanishingObstacleEffect(
          imageAsset: obs.imageAsset,
          width: imgW,
          height: imgH,
          onDone: () {
            if (mounted) {
              setState(() {
                _vanishingObstacles.removeWhere((v) => v.id == obs.id);
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildForSaleSign({
    required int lotNumber,
    required int col,
    required int row,
  }) {
    final corners = getHabitatCorners(col, row, 2, 2);
    const imgW = 140.0;
    const imgH = 112.0;
    final imgX = corners.center.dx - imgW / 2;
    final imgY = corners.center.dy - imgH * 0.78;

    return Positioned(
      left: imgX,
      top: imgY,
      width: imgW,
      height: imgH,
      child: HoverScale(
        scale: 1.08,
        behavior: HitTestBehavior.opaque,
        tooltip: 'Tap to unlock Expansion Lot $lotNumber!',
        onTap: () {
          if (widget.onUnlockLot != null) {
            widget.onUnlockLot!(lotNumber);
          } else {
            widget.onUnlockLotExpansion?.call();
          }
        },
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft ground shadow
            Positioned(
              bottom: 6,
              width: 72,
              height: 16,
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(
                    Radius.elliptical(72, 16),
                  ),
                  gradient: RadialGradient(
                    colors: [Color(0x77000000), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Static For Sale sign + Unlock pill
            Positioned(
              bottom: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/ui/LotForSale.png',
                    width: 124,
                    height: 82,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF451A03),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_open_rounded,
                            size: 11,
                            color: Color(0xFF451A03),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LOT $lotNumber',
                            style: const TextStyle(
                              fontFamily: 'Lilita One',
                              fontSize: 10.5,
                              color: Color(0xFF451A03),
                              letterSpacing: 0.6,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
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

class _GridPainter extends CustomPainter {
  final int? ghostCol;
  final int? ghostRow;
  final int ghostW;
  final int ghostH;
  final bool isGhostValid;
  final bool isPlacing;
  final bool isLot1Unlocked;
  final bool isLot2Unlocked;

  _GridPainter({
    this.ghostCol,
    this.ghostRow,
    this.ghostW = 3,
    this.ghostH = 3,
    this.isGhostValid = true,
    this.isPlacing = false,
    this.isLot1Unlocked = false,
    this.isLot2Unlocked = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Grid Lines (Dashed clean isometric diamond grid across buildable island)
    final gridLinePaint = Paint()
      ..color = const Color(0x35FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final lockedGridPaint = Paint()
      ..color = const Color(0x40EF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        if (!isTileBuildable(c, r)) continue;

        final isGhostTile =
            ghostCol != null &&
            ghostRow != null &&
            c >= ghostCol! &&
            c < ghostCol! + ghostW &&
            r >= ghostRow! &&
            r < ghostRow! + ghostH;

        if (isGhostTile) continue; // Drawn in footprint pass

        final cx = originX + (c - r) * (tileW / 2);
        final cy = originY + (c + r) * (tileH / 2);
        final pTop = Offset(cx, cy - tileH / 2);
        final pRight = Offset(cx + tileW / 2, cy);
        final pBottom = Offset(cx, cy + tileH / 2);
        final pLeft = Offset(cx - tileW / 2, cy);

        final tilePath = Path()
          ..moveTo(pTop.dx, pTop.dy)
          ..lineTo(pRight.dx, pRight.dy)
          ..lineTo(pBottom.dx, pBottom.dy)
          ..lineTo(pLeft.dx, pLeft.dy)
          ..close();

        final isTileLocked =
            (c < 13 && r < 11 && !isLot1Unlocked) ||
            (c >= 13 && !isLot2Unlocked);
        final paintToUse = isTileLocked ? lockedGridPaint : gridLinePaint;
        canvas.drawPath(tilePath, paintToUse);
      }
    }

    // 2. Ghost Footprint Tiles (Green for valid, Red for invalid)
    if (ghostCol != null && ghostRow != null) {
      final fillPaint = Paint()
        ..color = isGhostValid
            ? const Color(0x8522C55E) // 52% glowing emerald green
            : const Color(0x9EEF4444) // 62% crimson red
        ..style = PaintingStyle.fill;

      final strokePaint = Paint()
        ..color = isGhostValid
            ? const Color(0xFF22C55E)
            : const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      for (int dw = 0; dw < ghostW; dw++) {
        for (int dh = 0; dh < ghostH; dh++) {
          final tc = ghostCol! + dw;
          final tr = ghostRow! + dh;

          final cx = originX + (tc - tr) * (tileW / 2);
          final cy = originY + (tc + tr) * (tileH / 2);
          final pTop = Offset(cx, cy - tileH / 2);
          final pRight = Offset(cx + tileW / 2, cy);
          final pBottom = Offset(cx, cy + tileH / 2);
          final pLeft = Offset(cx - tileW / 2, cy);

          final tilePath = Path()
            ..moveTo(pTop.dx, pTop.dy)
            ..lineTo(pRight.dx, pRight.dy)
            ..lineTo(pBottom.dx, pBottom.dy)
            ..lineTo(pLeft.dx, pLeft.dy)
            ..close();

          canvas.drawPath(tilePath, fillPaint);
          canvas.drawPath(tilePath, strokePaint);

          // Center ✓ or ✕ mark
          final textPainter = TextPainter(
            text: TextSpan(
              text: isGhostValid ? '✓' : '✕',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
          );
        }
      }

      // 3. Green Square Indicator (Glowing Outer Perimeter Rhombus)
      final corners = getHabitatCorners(ghostCol!, ghostRow!, ghostW, ghostH);
      final perimeterPath = Path()
        ..moveTo(corners.pTop.dx, corners.pTop.dy)
        ..lineTo(corners.pRight.dx, corners.pRight.dy)
        ..lineTo(corners.pBottom.dx, corners.pBottom.dy)
        ..lineTo(corners.pLeft.dx, corners.pLeft.dy)
        ..close();

      // Outer Glow
      canvas.drawPath(
        perimeterPath,
        Paint()
          ..color =
              (isGhostValid ? const Color(0xFF4ADE80) : const Color(0xFFF87171))
                  .withOpacity(0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
      );

      // Solid Bold Perimeter
      canvas.drawPath(
        perimeterPath,
        Paint()
          ..color = isGhostValid
              ? const Color(0xFF22C55E)
              : const Color(0xFFEF4444)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.ghostCol != ghostCol ||
        oldDelegate.ghostRow != ghostRow ||
        oldDelegate.ghostW != ghostW ||
        oldDelegate.ghostH != ghostH ||
        oldDelegate.isGhostValid != isGhostValid ||
        oldDelegate.isPlacing != isPlacing;
  }
}

class _HabitatSelectionPainter extends CustomPainter {
  final HabitatModel habitat;
  final double pulse; // 0.0 to 1.0

  _HabitatSelectionPainter({required this.habitat, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final corners = getHabitatCorners(
      habitat.col,
      habitat.row,
      habitat.sizeW,
      habitat.sizeH,
    );
    final path = Path()
      ..moveTo(corners.pTop.dx, corners.pTop.dy)
      ..lineTo(corners.pRight.dx, corners.pRight.dy)
      ..lineTo(corners.pBottom.dx, corners.pBottom.dy)
      ..lineTo(corners.pLeft.dx, corners.pLeft.dy)
      ..close();

    // 1. Soft translucent white ground highlight
    final fillOpacity = 0.16 + 0.08 * sin(pulse * 2 * pi);
    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(fillOpacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 2. Soft white outer bloom / glow
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawPath(path, glowPaint);

    // 3. Crisp bright white isometric diamond border (matching reference)
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _HabitatSelectionPainter oldDelegate) {
    return oldDelegate.habitat.id != habitat.id ||
        oldDelegate.habitat.col != habitat.col ||
        oldDelegate.habitat.row != habitat.row ||
        oldDelegate.pulse != pulse;
  }
}

class _CompatibleHabitatsBasePainter extends CustomPainter {
  final List<HabitatModel> habitats;
  final double pulse;

  _CompatibleHabitatsBasePainter({required this.habitats, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    for (final habitat in habitats) {
      final corners = getHabitatCorners(
        habitat.col,
        habitat.row,
        habitat.sizeW,
        habitat.sizeH,
      );
      final path = Path()
        ..moveTo(corners.pTop.dx, corners.pTop.dy)
        ..lineTo(corners.pRight.dx, corners.pRight.dy)
        ..lineTo(corners.pBottom.dx, corners.pBottom.dy)
        ..lineTo(corners.pLeft.dx, corners.pLeft.dy)
        ..close();

      // Translucent emerald fill
      final fillOpacity = 0.22 + 0.10 * sin(pulse * 2 * pi);
      final fillPaint = Paint()
        ..color = const Color(0xFF10B981).withOpacity(fillOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Emerald bloom
      final glowPaint = Paint()
        ..color = const Color(0xFF34D399).withOpacity(0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawPath(path, glowPaint);

      // Bright white-gold isometric diamond border
      final strokePaint = Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompatibleHabitatsBasePainter oldDelegate) =>
      true;
}

class _TriangleArrowTipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF047857)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LockedLotTerritoryPainter extends CustomPainter {
  final bool isLot1Unlocked;
  final bool isLot2Unlocked;

  _LockedLotTerritoryPainter({
    this.isLot1Unlocked = false,
    this.isLot2Unlocked = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Soft dreamy mist veil instead of harsh dark blocking
    final mistPaint = Paint()
      ..color = const Color(0x36E0F2FE)
      ..style = PaintingStyle.fill;

    final fenceShadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;

    final chainOutlinePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6;

    final chainLinkPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final chainBridgePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;

    final postFillPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.fill;

    final postCapPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;

    // 1. Soft sunlit mist over locked tiles
    for (int c = 0; c < gridCols; c++) {
      for (int r = 0; r < gridRows; r++) {
        if (!isTileBuildable(c, r)) continue;

        final isLocked =
            (c < 13 && r < 11 && !isLot1Unlocked) ||
            (c >= 13 && r < 11 && !isLot2Unlocked);
        if (!isLocked) continue;

        final cx = originX + (c - r) * (tileW / 2);
        final cy = originY + (c + r) * (tileH / 2);
        final pTop = Offset(cx, cy - tileH / 2);
        final pRight = Offset(cx + tileW / 2, cy);
        final pBottom = Offset(cx, cy + tileH / 2);
        final pLeft = Offset(cx - tileW / 2, cy);

        final tilePath = Path()
          ..moveTo(pTop.dx, pTop.dy)
          ..lineTo(pRight.dx, pRight.dy)
          ..lineTo(pBottom.dx, pBottom.dy)
          ..lineTo(pLeft.dx, pLeft.dy)
          ..close();

        canvas.drawPath(tilePath, mistPaint);
      }
    }

    void drawChainSegment(Offset a, Offset b, bool drawPost) {
      final delta = b - a;
      final angle = atan2(delta.dy, delta.dx);
      const linkCount = 4;

      for (int i = 0; i < linkCount; i++) {
        final t = (i + 0.5) / linkCount;
        final center = Offset.lerp(a, b, t)!;

        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);

        if (i.isEven) {
          // Flat oval chain link
          final rect = Rect.fromCenter(
            center: Offset.zero,
            width: 8.5,
            height: 4.4,
          );
          final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2.2));
          canvas.drawRRect(rrect.shift(const Offset(0, 1.2)), fenceShadowPaint);
          canvas.drawRRect(rrect, chainOutlinePaint);
          canvas.drawRRect(rrect, chainLinkPaint);
        } else {
          // Edge-on interlocking link
          const p1 = Offset(-3.6, 0);
          const p2 = Offset(3.6, 0);
          canvas.drawLine(
            p1.translate(0, 1.2),
            p2.translate(0, 1.2),
            fenceShadowPaint,
          );
          canvas.drawLine(p1, p2, chainOutlinePaint);
          canvas.drawLine(p1, p2, chainBridgePaint);
        }
        canvas.restore();
      }

      if (drawPost) {
        canvas.drawCircle(a.translate(0, 1.2), 3.8, fenceShadowPaint);
        canvas.drawCircle(a, 3.3, postFillPaint);
        canvas.drawCircle(a, 1.5, postCapPaint);
      }
    }

    // 2. Chain-and-post boundary along row = 11
    if (!isLot1Unlocked || !isLot2Unlocked) {
      for (int c = 0; c < gridCols; c++) {
        final segmentLocked =
            (c < 13 && !isLot1Unlocked) || (c >= 13 && !isLot2Unlocked);
        if (segmentLocked && isTileBuildable(c, 11)) {
          final cx = originX + (c - 11) * (tileW / 2);
          final cy = originY + (c + 11) * (tileH / 2);
          final pTop = Offset(cx, cy - tileH / 2);
          final pRight = Offset(cx + tileW / 2, cy);
          drawChainSegment(pTop, pRight, c % 2 == 0);
        }
      }
    }

    // 3. Dividing chain-and-post boundary along col = 13 (r < 11)
    if (!isLot1Unlocked || !isLot2Unlocked) {
      for (int r = 0; r < 11; r++) {
        if (isTileBuildable(13, r)) {
          final cx = originX + (13 - r) * (tileW / 2);
          final cy = originY + (13 + r) * (tileH / 2);
          final pTop = Offset(cx, cy - tileH / 2);
          final pLeft = Offset(cx - tileW / 2, cy);
          drawChainSegment(pTop, pLeft, r % 2 == 0);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LockedLotTerritoryPainter oldDelegate) =>
      oldDelegate.isLot1Unlocked != isLot1Unlocked ||
      oldDelegate.isLot2Unlocked != isLot2Unlocked;
}

class _VanishingObstacleEffect extends StatefulWidget {
  final String imageAsset;
  final double width;
  final double height;
  final VoidCallback onDone;

  const _VanishingObstacleEffect({
    required this.imageAsset,
    required this.width,
    required this.height,
    required this.onDone,
  });

  @override
  State<_VanishingObstacleEffect> createState() =>
      _VanishingObstacleEffectState();
}

class _VanishingObstacleEffectState extends State<_VanishingObstacleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDone();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final t = _controller.value;
        // Brief pop-up then shrink to 0
        final scale = t < 0.2
            ? 1.0 + (t / 0.2) * 0.14
            : (1.14 * (1.0 - ((t - 0.2) / 0.8))).clamp(0.0, 1.2);
        final opacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Shrinking & fading obstacle
            Opacity(
              opacity: opacity,
              child: Transform.scale(
                alignment: Alignment.bottomCenter,
                scale: scale,
                child: child,
              ),
            ),

            // Dust poof puffs
            for (int i = 0; i < 4; i++)
              Transform.translate(
                offset: Offset(
                  cos(i * pi / 2 + 0.4) * t * 34.0,
                  sin(i * pi / 2 + 0.4) * t * 18.0 - t * 14.0,
                ),
                child: Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0) * 0.7,
                  child: Container(
                    width: 18 * (1.0 - t * 0.5),
                    height: 18 * (1.0 - t * 0.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),

            // Sparkle stars
            for (int i = 0; i < 6; i++)
              Transform.translate(
                offset: Offset(
                  cos(i * pi / 3) * t * 42.0,
                  sin(i * pi / 3) * t * 28.0 - t * 22.0,
                ),
                child: Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: t * 4.5,
                    child: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFDE047),
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: Image.asset(
        widget.imageAsset,
        width: widget.width,
        height: widget.height,
        fit: BoxFit.contain,
        cacheWidth: 256,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
