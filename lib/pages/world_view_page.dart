import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../state/game_controller.dart';
import '../models/habitat_model.dart';
import '../models/habitat_catalog.dart';
import '../models/dog_model.dart';
import '../models/dog_evolution.dart';
import '../components/common/hover_scale.dart';
import '../components/world/world_isometric_grid.dart';
import '../components/world/world_hud.dart';
import '../components/world/build_shop_dialog.dart';
import '../components/world/goals_dialog.dart';
import '../components/world/progress_dialog.dart';
import '../components/world/ranking_dialog.dart';
import '../components/world/social_dialog.dart';
import '../components/world/settings_dialog.dart';
import '../components/world/habitat_info_dialog.dart';
import '../components/common/generic_modal.dart';
import '../models/obstacle_model.dart';

class WorldViewPage extends StatefulWidget {
  final GameController game;
  final Function(String route, {Map<String, dynamic>? args}) onNavigate;
  final Map<String, dynamic>? initialArgs;
  final Map<String, GlobalKey>? walkthroughKeys;
  final ValueNotifier<Rect?>? worldTargetRectNotifier;

  const WorldViewPage({
    super.key,
    required this.game,
    required this.onNavigate,
    this.initialArgs,
    this.walkthroughKeys,
    this.worldTargetRectNotifier,
  });

  @override
  State<WorldViewPage> createState() => _WorldViewPageState();
}

class _WorldViewPageState extends State<WorldViewPage> {
  // Camera Pan and Zoom state
  double _camX = 0.0;
  double _camY = 0.0;
  double _zoom = 1.05;

  double _startCamX = 0.0;
  double _startCamY = 0.0;
  double _startZoom = 1.0;
  bool _isDragging = false;

  HabitatCatalogItem? _placingItem;
  String? _movingHabitatId;

  // Habitat selection mode for Dog Adoption or Transfer
  DogCatalogItem? _adoptingDogItem;
  DogModel? _transferringDog;
  String? _transferFromHabitatId;
  String? _hudToast;
  String? _lastWalkthroughCenteredHabId;

  @override
  void initState() {
    super.initState();
    _handleInitialArgs(widget.initialArgs);
  }

  @override
  void didUpdateWidget(covariant WorldViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialArgs != oldWidget.initialArgs) {
      _handleInitialArgs(widget.initialArgs);
    }
  }

  void _handleInitialArgs(Map<String, dynamic>? args) {
    if (args != null && args.containsKey('transferDog')) {
      final dog = args['transferDog'] as DogModel?;
      final fromHabId = args['fromHabitatId'] as String?;
      if (dog != null && fromHabId != null) {
        setState(() {
          _transferringDog = dog;
          _transferFromHabitatId = fromHabId;
          _adoptingDogItem = null;
          _placingItem = null;
          _movingHabitatId = null;
        });
      }
    }
  }

  Set<String> _getCompatibleHabitatIds() {
    if (_adoptingDogItem != null) {
      final dog = _adoptingDogItem!;
      return widget.game.placedHabitats
          .where((h) =>
              h.type == 'habitat' &&
              h.dogs.length < 4 &&
              HabitatCatalog.isHabitatCompatible(
                habitatCatalogId: h.habitatId,
                breedId: dog.id,
                element: dog.element,
                preferredHabitatId: dog.habitatId,
              ))
          .map((h) => h.id)
          .toSet();
    } else if (_transferringDog != null) {
      final dog = _transferringDog!;
      return widget.game.placedHabitats
          .where((h) =>
              h.type == 'habitat' &&
              h.id != _transferFromHabitatId &&
              h.dogs.length < 4 &&
              HabitatCatalog.isHabitatCompatible(
                habitatCatalogId: h.habitatId,
                breedId: dog.breedId,
                element: dog.element,
              ))
          .map((h) => h.id)
          .toSet();
    }
    return {};
  }

  void _handleTargetHabitatSelected(HabitatModel hab) {
    if (_adoptingDogItem != null) {
      final dogItem = _adoptingDogItem!;
      final success = widget.game.adoptDog(dogItem, hab.id);
      if (success) {
        _showHudToast('${dogItem.name} adopted into ${hab.name}!');
      }
      setState(() {
        _adoptingDogItem = null;
      });
    } else if (_transferringDog != null) {
      final dog = _transferringDog!;
      final success = widget.game.transferDog(
        _transferFromHabitatId!,
        hab.id,
        dog.id,
      );
      if (success) {
        _showHudToast('${dog.name} transferred to ${hab.name}!');
      }
      setState(() {
        _transferringDog = null;
        _transferFromHabitatId = null;
      });
    }
  }

  void _showHudToast(String msg) {
    setState(() => _hudToast = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hudToast = null);
    });
  }

  void _startPlacing(HabitatCatalogItem item) {
    setState(() {
      _placingItem = item;
      _movingHabitatId = null;
      _adoptingDogItem = null;
      _transferringDog = null;
      _transferFromHabitatId = null;
    });
    widget.game.setGridVisible(true);
  }

  void _startMoving(HabitatModel hab) {
    setState(() {
      _movingHabitatId = hab.id;
      _placingItem = null;
      _adoptingDogItem = null;
      _transferringDog = null;
      _transferFromHabitatId = null;
    });
    widget.game.setGridVisible(true);
  }

  void _confirmPlacement(int col, int row) {
    if (_placingItem != null) {
      widget.game.placeHabitat(_placingItem!, col, row);
    } else if (_movingHabitatId != null) {
      widget.game.moveHabitat(_movingHabitatId!, col, row);
    }
    _cancelPlacement();
  }

  void _cancelPlacement() {
    setState(() {
      _placingItem = null;
      _movingHabitatId = null;
    });
    widget.game.setGridVisible(false);
  }

  @override
  Widget build(BuildContext context) {
    final isPlacing = _placingItem != null || _movingHabitatId != null;
    final isSelectingHabitat =
        _adoptingDogItem != null || _transferringDog != null;
    final compatibleHabitatIds =
        isSelectingHabitat ? _getCompatibleHabitatIds() : <String>{};

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final W = constraints.maxWidth;
          final H = constraints.maxHeight;

          // Base scale ensures the 2000x1125 island completely covers the viewport
          final baseScale = max(W / worldWidth, H / worldHeight);
          final totalScale = baseScale * _zoom;
          final scaledW = worldWidth * totalScale;
          final scaledH = worldHeight * totalScale;

          // Maximum pan limits so edges never enter the screen
          final maxPanX = max(0.0, (scaledW - W) / 2);
          final maxPanY = max(0.0, (scaledH - H) / 2);

          // Auto-center camera on targeted walkthrough building when step activates
          final wtTargetHabId =
              widget.game.currentWalkthroughStep?.worldTargetHabitatId;
          HabitatModel? wtTargetHab;
          if (wtTargetHabId != null) {
            for (final h in widget.game.placedHabitats) {
              if (h.id == wtTargetHabId) {
                wtTargetHab = h;
                break;
              }
            }
          }

          if (wtTargetHab != null &&
              _lastWalkthroughCenteredHabId != wtTargetHab.id) {
            _lastWalkthroughCenteredHabId = wtTargetHab.id;
            final corners = getHabitatCorners(
              wtTargetHab.col,
              wtTargetHab.row,
              wtTargetHab.sizeW,
              wtTargetHab.sizeH,
            );
            _camX = (scaledW / 2) - corners.center.dx * totalScale;
            _camY = (H * 0.44 - (corners.center.dy - 24.0) * totalScale) -
                (H - scaledH) / 2;
          } else if (wtTargetHabId == null &&
              _lastWalkthroughCenteredHabId != null) {
            _lastWalkthroughCenteredHabId = null;
          }

          // Clamped camera offsets
          _camX = _camX.clamp(-maxPanX, maxPanX);
          _camY = _camY.clamp(-maxPanY, maxPanY);

          final leftPos = (W - scaledW) / 2 + _camX;
          final topPos = (H - scaledH) / 2 + _camY;

          // Sync projected screen rect of targeted building to WalkthroughOverlay
          if (widget.worldTargetRectNotifier != null) {
            Rect? projectedRect;
            if (wtTargetHab != null) {
              final corners = getHabitatCorners(
                wtTargetHab.col,
                wtTargetHab.row,
                wtTargetHab.sizeW,
                wtTargetHab.sizeH,
              );
              projectedRect = Rect.fromLTRB(
                leftPos + corners.pLeft.dx * totalScale,
                topPos + (corners.pTop.dy - 24.0) * totalScale,
                leftPos + corners.pRight.dx * totalScale,
                topPos + (corners.pBottom.dy + 10.0) * totalScale,
              );
            }
            final prev = widget.worldTargetRectNotifier!.value;
            final changed = (prev == null) != (projectedRect == null) ||
                (prev != null &&
                    projectedRect != null &&
                    ((prev.left - projectedRect.left).abs() > 0.5 ||
                        (prev.top - projectedRect.top).abs() > 0.5 ||
                        (prev.width - projectedRect.width).abs() > 0.5 ||
                        (prev.height - projectedRect.height).abs() > 0.5));
            if (changed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  widget.worldTargetRectNotifier!.value = projectedRect;
                }
              });
            }
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── 1. DRAGGABLE & MOVABLE ISLAND VIEW ──
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final zoomDelta = pointerSignal.scrollDelta.dy < 0 ? 1.12 : 0.89;
                    setState(() {
                      _zoom = (_zoom * zoomDelta).clamp(1.0, 2.8);
                      final nextScaledW = worldWidth * baseScale * _zoom;
                      final nextScaledH = worldHeight * baseScale * _zoom;
                      final nextMaxX = max(0.0, (nextScaledW - W) / 2);
                      final nextMaxY = max(0.0, (nextScaledH - H) / 2);
                      _camX = _camX.clamp(-nextMaxX, nextMaxX);
                      _camY = _camY.clamp(-nextMaxY, nextMaxY);
                    });
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: isPlacing
                      ? null
                      : (details) {
                          _startCamX = _camX;
                          _startCamY = _camY;
                          _startZoom = _zoom;
                          setState(() => _isDragging = true);
                        },
                  onScaleUpdate: isPlacing
                      ? null
                      : (details) {
                          setState(() {
                            // Multi-touch pinch zoom
                            if (details.scale != 1.0) {
                              _zoom =
                                  (_startZoom * details.scale).clamp(1.0, 2.8);
                            }
                            // Mouse or finger pan
                            _camX += details.focalPointDelta.dx;
                            _camY += details.focalPointDelta.dy;

                            final currScaledW = worldWidth * baseScale * _zoom;
                            final currScaledH = worldHeight * baseScale * _zoom;
                            final currMaxX = max(0.0, (currScaledW - W) / 2);
                            final currMaxY = max(0.0, (currScaledH - H) / 2);
                            _camX = _camX.clamp(-currMaxX, currMaxX);
                            _camY = _camY.clamp(-currMaxY, currMaxY);
                          });
                        },
                  onScaleEnd: isPlacing
                      ? null
                      : (_) {
                          setState(() => _isDragging = false);
                        },
                  child: MouseRegion(
                    cursor: _isDragging
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                    child: Stack(
                      children: [
                        // The movable Island Canvas
                        Positioned(
                          left: leftPos,
                          top: topPos,
                          width: scaledW,
                          height: scaledH,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: worldWidth,
                              height: worldHeight,
                              child: WorldIsometricGrid(
                                habitats: widget.game.placedHabitats,
                                selectedHabitatId:
                                    widget.game.selectedHabitatId,
                                gridVisible: widget.game.gridVisible,
                                placingItem: _placingItem,
                                movingHabitatId: _movingHabitatId,
                                isSelectingHabitat: isSelectingHabitat,
                                highlightedHabitatIds: compatibleHabitatIds,
                                onSelectTargetHabitat:
                                    _handleTargetHabitatSelected,
                                onSelectHabitat: (hab) {
                                  if (!isPlacing && !isSelectingHabitat) {
                                    widget.game.selectHabitat(hab.id);
                                  }
                                },
                                onCollectCoins: (id) =>
                                    widget.game.collectCoins(id),
                                onCollectDogfood: (id) =>
                                    widget.game.collectDogfood(id),
                                onCompleteConstruction: (id) =>
                                    widget.game.completeConstruction(id),
                                onConfirmPlace: _confirmPlacement,
                                onCancelPlace: _cancelPlacement,
                                onStartMove: _startMoving,
                                obstacles: widget.game.obstacles,
                                selectedObstacleId:
                                    widget.game.selectedObstacleId,
                                isLotExpansionUnlocked:
                                    widget.game.isLotExpansionUnlocked,
                                isLot1Unlocked: widget.game.isLot1Unlocked,
                                isLot2Unlocked: widget.game.isLot2Unlocked,
                                onSelectObstacle: _handleSelectObstacle,
                                onStartClearingObstacle: (id) =>
                                    widget.game.startClearingObstacle(id),
                                onCompleteClearingObstacle:
                                    _handleCompleteClearingObstacle,
                                onUnlockLotExpansion: () =>
                                    _showExpandLotDialogForLot(
                                        widget.game.isLot1Unlocked ? 2 : 1),
                                onUnlockLot: _showExpandLotDialogForLot,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 2. FIXED UI & HUD OVERLAY (Always anchored to the screen) ──
              if (!isPlacing && !isSelectingHabitat)
                WorldHUD(
                  game: widget.game,
                  walkthroughKeys: widget.walkthroughKeys,
                  onOpenBuild: () {
                    showDialog(
                      context: context,
                      builder: (_) => BuildShopDialog(
                        game: widget.game,
                        onSelectBuildingToPlace: (item) => _startPlacing(item),
                        onSelectHabitatForDog: (dog) {
                          setState(() {
                            _adoptingDogItem = dog;
                            _transferringDog = null;
                            _transferFromHabitatId = null;
                            _placingItem = null;
                            _movingHabitatId = null;
                          });
                        },
                        onAdoptDog: (dog, habId) =>
                            widget.game.adoptDog(dog, habId),
                      ),
                    );
                  },
                  onOpenGoals: () {
                    showDialog(
                      context: context,
                      builder: (_) => GoalsDialog(game: widget.game),
                    );
                  },
                  onOpenProgress: () {
                    showDialog(
                      context: context,
                      builder: (_) => ProgressDialog(game: widget.game),
                    );
                  },
                  onOpenSocial: () {
                    showDialog(
                      context: context,
                      builder: (_) => const SocialDialog(),
                    );
                  },
                  onOpenRanking: () {
                    showDialog(
                      context: context,
                      builder: (_) => const RankingDialog(),
                    );
                  },
                  onOpenSettings: () {
                    showDialog(
                      context: context,
                      builder: (_) => SettingsDialog(game: widget.game),
                    );
                  },
                  onOpenBreeding: () => widget.onNavigate('breeding'),
                  onOpenCollection: () => widget.onNavigate('collection'),
                  onOpenHabitatCare: (hab, [dogIndex = 0]) {
                    if (hab.isFactory) {
                      widget.onNavigate('factory', args: {'habitat': hab});
                    } else {
                      widget.onNavigate('habitat', args: {
                        'habitat': hab,
                        'initialDogIndex': dogIndex,
                      });
                    }
                  },
                  onStartMoveHabitat: (hab) => _startMoving(hab),
                  onOpenHabitatInfo: (hab) {
                    if (hab.isFactory) {
                      widget.onNavigate('factory', args: {'habitat': hab});
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (_) => HabitatInfoDialog(
                        habitat: hab,
                        onOpenCare: (h) =>
                            widget.onNavigate('habitat', args: {'habitat': h}),
                      ),
                    );
                  },
                  onDeselectHabitat: () => widget.game.selectHabitat(null),
                ),

              // ── 3. Habitat Selection Header Bar (Adoption & Transfer) ──
              if (isSelectingHabitat)
                _buildHabitatSelectionPromptHeader(),

              // ── 4. HUD Toast Notification Overlay ──
              if (_hudToast != null)
                Positioned(
                  top: isSelectingHabitat ? 95 : 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xEE1E0A02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFFBBF24), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        _hudToast!,
                        style: const TextStyle(
                          color: Color(0xFFFEF3C7),
                          fontFamily: 'Lilita One',
                          fontSize: 14,
                          letterSpacing: 0.3,
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

  Widget _buildHabitatSelectionPromptHeader() {
    final isAdopting = _adoptingDogItem != null;
    final dogName =
        isAdopting ? _adoptingDogItem!.name : _transferringDog!.name;
    final dogThumb = isAdopting
        ? _adoptingDogItem!.assetImage
        : DogStageInfo.getInfo(_transferringDog!).portraitImg;

    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xF02A1205), Color(0xF0451A03)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFFBBF24), width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0xB3000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dog Portrait Avatar
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF3C7),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                ),
                child: ClipOval(
                  child: Image.asset(
                    dogThumb,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Instruction
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isAdopting
                        ? 'SELECT HABITAT FOR ${dogName.toUpperCase()}'
                        : 'TRANSFER ${dogName.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Text(
                    'Tap any highlighted habitat with a pointing arrow',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontFamily: 'Fredoka',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),

              // Cancel Button
              HoverScale(
                scale: 1.06,
                onTap: () {
                  setState(() {
                    _adoptingDogItem = null;
                    _transferringDog = null;
                    _transferFromHabitatId = null;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66B91C1C),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'CANCEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Obstacle & Island Expansion Handlers ──

  void _handleSelectObstacle(ObstacleModel obs) {
    if (obs.col < 13 && obs.row < 11 && !widget.game.isLot1Unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unlock Expansion Lot 1 first to clear this obstacle!',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (obs.col >= 13 && obs.row < 11 && !widget.game.isLot2Unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unlock Expansion Lot 2 first to clear this obstacle!',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    widget.game.selectObstacle(obs.id);

    if (obs.isClearing) {
      final remainingMs =
          (obs.clearingEndsAt ?? 0) - DateTime.now().millisecondsSinceEpoch;
      if (remainingMs <= 0) {
        _handleCompleteClearingObstacle(obs.id);
      } else {
        _showObstacleClearingProgressDialog(obs);
      }
    } else {
      _showClearObstacleDialog(obs);
    }
  }

  void _handleCompleteClearingObstacle(String id) {
    final success = widget.game.completeClearingObstacle(id);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Obstacle cleared! Space is now ready for building! 🎉',
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showExpandLotDialog() {
    _showExpandLotDialogForLot(widget.game.isLot1Unlocked ? 2 : 1);
  }

  void _showExpandLotDialogForLot(int lotNumber) {
    final cost = 2500;
    final canAfford = widget.game.coins >= cost;
    final lotTitle = lotNumber == 1 ? 'EXPANSION LOT 1 (PARK BENCH)' : 'EXPANSION LOT 2 (MEADOW)';
    final lotSubtitle = lotNumber == 1
        ? 'Unlock the upper park lot under the oak tree and bench! Obstacles will remain on the lot for you to clear for XP and coins.'
        : 'Unlock the large east meadow expansion territory! Obstacles will remain on the lot for you to clear for XP and coins.';

    showDialog(
      context: context,
      builder: (ctx) => GenericModal(
        title: 'ISLAND EXPANSION',
        maxWidth: 500,
        onClose: () => Navigator.of(ctx).pop(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Illustration Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/ui/LotForSale.png',
                      width: 120,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lotTitle,
                      style: const TextStyle(
                        fontFamily: 'Lilita One',
                        fontSize: 18,
                        color: Color(0xFF78350F),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        lotSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cost and Expand Button
              HoverScale(
                scale: 1.03,
                child: GestureDetector(
                  onTap: () {
                    if (!canAfford) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Not enough Paw Coins! Earn more coins from your habitats.',
                            style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Color(0xFFEF4444),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    final ok = lotNumber == 1
                        ? widget.game.unlockLot1()
                        : widget.game.unlockLot2();
                    Navigator.of(ctx).pop();
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.celebration_rounded,
                                  color: Colors.amber, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  lotNumber == 1
                                      ? '🎉 Expansion Lot 1 unlocked! The remaining 1/4 lot is still locked.'
                                      : '🎉 Expansion Lot 2 unlocked! The entire island paradise is now unlocked!',
                                  style: const TextStyle(
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF0F172A),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: canAfford
                            ? [
                                const Color(0xFF10B981),
                                const Color(0xFF059669)
                              ]
                            : [
                                const Color(0xFF9CA3AF),
                                const Color(0xFF6B7280)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: canAfford
                              ? const Color(0x55059669)
                              : Colors.transparent,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_open_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          canAfford
                              ? 'UNLOCK LOT $lotNumber (🪙 ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')})'
                              : 'NEED 🪙 ${cost.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} (Have: ${widget.game.coins})',
                          style: const TextStyle(
                            fontFamily: 'Lilita One',
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 0.5,
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
      ),
    );
  }

  void _showClearObstacleDialog(ObstacleModel obs) {
    final canAfford = widget.game.coins >= obs.clearCost;

    showDialog(
      context: context,
      builder: (ctx) => GenericModal(
        title: 'CLEAR OBSTACLE',
        maxWidth: 460,
        onClose: () => Navigator.of(ctx).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Obstacle Showcase
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22F59E0B),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        obs.imageAsset,
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    obs.name.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Lilita One',
                      fontSize: 17,
                      color: Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Clear this obstacle to free up ground space for new habitats!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Cost & Reward Pills
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFBBF24)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CLEAR COST',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🪙 ',
                                style: TextStyle(fontSize: 13)),
                            Text(
                              '${obs.clearCost}',
                              style: TextStyle(
                                fontFamily: 'Lilita One',
                                fontSize: 15,
                                color: canAfford
                                    ? const Color(0xFF78350F)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF34D399)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TIME & REWARD',
                          style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '⏱ ${obs.clearDuration}s  •  ⭐ +${obs.xpReward} XP',
                          style: const TextStyle(
                            fontFamily: 'Lilita One',
                            fontSize: 13,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Clear Button
            HoverScale(
              scale: 1.03,
              child: GestureDetector(
                onTap: () {
                  if (!canAfford) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Not enough Paw Coins! Earn more coins from your habitats.',
                          style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  final ok = widget.game.startClearingObstacle(obs.id);
                  Navigator.of(ctx).pop();
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '🧹 Clearing ${obs.name}... Timer started!',
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: const Color(0xFF0F172A),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canAfford
                          ? [
                              const Color(0xFFF59E0B),
                              const Color(0xFFD97706)
                            ]
                          : [
                              const Color(0xFF9CA3AF),
                              const Color(0xFF6B7280)
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: canAfford
                            ? const Color(0x55D97706)
                            : Colors.transparent,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cleaning_services_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        canAfford ? 'CLEAR OBSTACLE' : 'NOT ENOUGH COINS',
                        style: const TextStyle(
                          fontFamily: 'Lilita One',
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 0.5,
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

  void _showObstacleClearingProgressDialog(ObstacleModel obs) {
    const speedUpGems = 2;
    final canSpeedUp = widget.game.crystals >= speedUpGems;

    showDialog(
      context: context,
      builder: (ctx) => GenericModal(
        title: 'CLEARING IN PROGRESS',
        maxWidth: 440,
        onClose: () => Navigator.of(ctx).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(obs.imageAsset,
                width: 80, height: 80, fit: BoxFit.contain),
            const SizedBox(height: 8),
            Text(
              obs.name,
              style: const TextStyle(
                fontFamily: 'Lilita One',
                fontSize: 17,
                color: Color(0xFF78350F),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your workers are busy clearing this obstacle. You can wait or speed it up with Diamonds!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Fredoka',
                fontSize: 12,
                color: Color(0xFF92400E),
              ),
            ),
            const SizedBox(height: 16),
            HoverScale(
              scale: 1.03,
              child: GestureDetector(
                onTap: () {
                  if (!canSpeedUp) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Not enough Diamonds to speed up!',
                          style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  widget.game.speedUpClearingObstacle(obs.id, speedUpGems);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '⚡ Obstacle cleared instantly! Space ready!',
                        style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Color(0xFF0F172A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: Colors.amber, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'SPEED UP (💎 2)',
                        style: TextStyle(
                          fontFamily: 'Lilita One',
                          fontSize: 15,
                          color: Colors.white,
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
}
