import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../state/game_controller.dart';
import '../models/habitat_model.dart';
import '../models/habitat_catalog.dart';
import '../models/island_model.dart';
import '../models/dog_model.dart';
import '../models/dog_evolution.dart';
import '../components/common/hover_scale.dart';
import '../components/common/sky_background.dart';
import '../components/world/world_isometric_grid.dart';
import '../components/world/world_hud.dart';
import '../components/world/build_shop_dialog.dart';
import '../components/world/goals_dialog.dart';
import '../components/world/inbox_dialog.dart';
import '../components/world/progress_dialog.dart';
import '../components/world/ranking_dialog.dart';
import '../components/world/social_dialog.dart';
import '../components/world/settings_dialog.dart';
import '../components/world/habitat_info_dialog.dart';
import '../components/common/generic_modal.dart';
import '../models/obstacle_model.dart';
import '../services/audio_service.dart';
import 'breeding_page.dart';

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

class _WorldViewPageState extends State<WorldViewPage>
    with SingleTickerProviderStateMixin {
  // Camera Pan and Zoom state
  double _camX = 0.0;
  double _camY = 0.0;
  double _zoom = 1.05;

  double _startCamX = 0.0;
  double _startCamY = 0.0;
  double _startZoom = 1.0;
  bool _isDragging = false;
  final ValueNotifier<int> _cameraNotifier = ValueNotifier<int>(0);

  AnimationController? _islandOverviewController;
  bool _isIslandOverview = false;
  double _overviewCamX = 0.0;
  double _overviewCamY = 0.0;
  double _overviewZoom = 1.0;
  double _overviewStartZoom = 1.0;
  bool _overviewDragging = false;

  AnimationController get _overviewController =>
      _islandOverviewController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );

  HabitatCatalogItem? _placingItem;
  String? _movingHabitatId;

  // Habitat selection mode for Dog Adoption or Transfer
  DogCatalogItem? _adoptingDogItem;
  DogModel? _transferringDog;
  String? _transferFromHabitatId;
  Map<String, String>? _placingBredPuppy;
  String? _hudToast;
  String? _lastWalkthroughCenteredHabId;

  @override
  void initState() {
    super.initState();
    _overviewController;
    _handleInitialArgs(widget.initialArgs);
  }

  @override
  void dispose() {
    _cameraNotifier.dispose();
    _islandOverviewController?.dispose();
    super.dispose();
  }

  void _openIslandOverview() {
    setState(() {
      _isIslandOverview = true;
      _overviewCamX = 0.0;
      _overviewCamY = 0.0;
      _overviewZoom = 1.0;
    });
    widget.game.setIslandOverviewOpen(true);
    _overviewController.forward();
  }

  Future<void> _closeIslandOverview() async {
    await _overviewController.reverse();
    if (mounted) {
      setState(() => _isIslandOverview = false);
      widget.game.setIslandOverviewOpen(false);
    }
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
          _placingBredPuppy = null;
          _placingItem = null;
          _movingHabitatId = null;
        });
      }
    } else if (args != null && args.containsKey('placeBredPuppy')) {
      final raw = args['placeBredPuppy'];
      if (raw is Map) {
        final pup = Map<String, String>.from(raw);
        final breedId = pup['breedId'] ?? '';
        final element = pup['element'] ?? '';
        // If no compatible open habitat is on the current island, switch to an unlocked island that has one
        final hasOnCurrent = widget.game.placedHabitats.any(
          (h) =>
              h.islandId == widget.game.currentIslandId &&
              h.type == 'habitat' &&
              !h.underConstruction &&
              h.dogs.length < 4 &&
              HabitatCatalog.isHabitatCompatible(
                habitatCatalogId: h.habitatId,
                breedId: breedId,
                element: element,
              ),
        );
        if (!hasOnCurrent) {
          final targetHab = widget.game.placedHabitats.firstWhere(
            (h) =>
                h.type == 'habitat' &&
                !h.underConstruction &&
                h.dogs.length < 4 &&
                HabitatCatalog.isHabitatCompatible(
                  habitatCatalogId: h.habitatId,
                  breedId: breedId,
                  element: element,
                ),
            orElse: () => HabitatModel(
              id: '',
              habitatId: '',
              name: '',
              col: 0,
              row: 0,
            ),
          );
          if (targetHab.id.isNotEmpty) {
            widget.game.switchIsland(targetHab.islandId);
          }
        }
        setState(() {
          _placingBredPuppy = pup;
          _adoptingDogItem = null;
          _transferringDog = null;
          _transferFromHabitatId = null;
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
          .where(
            (h) =>
                h.islandId == widget.game.currentIslandId &&
                h.type == 'habitat' &&
                !h.underConstruction &&
                h.dogs.length < 4 &&
                HabitatCatalog.isHabitatCompatible(
                  habitatCatalogId: h.habitatId,
                  breedId: dog.id,
                  element: dog.element,
                  preferredHabitatId: dog.habitatId,
                ),
          )
          .map((h) => h.id)
          .toSet();
    } else if (_transferringDog != null) {
      final dog = _transferringDog!;
      return widget.game.placedHabitats
          .where(
            (h) =>
                h.islandId == widget.game.currentIslandId &&
                h.type == 'habitat' &&
                !h.underConstruction &&
                h.id != _transferFromHabitatId &&
                h.dogs.length < 4 &&
                HabitatCatalog.isHabitatCompatible(
                  habitatCatalogId: h.habitatId,
                  breedId: dog.breedId,
                  element: dog.element,
                ),
          )
          .map((h) => h.id)
          .toSet();
    } else if (_placingBredPuppy != null) {
      final pup = _placingBredPuppy!;
      return widget.game.placedHabitats
          .where(
            (h) =>
                h.islandId == widget.game.currentIslandId &&
                h.type == 'habitat' &&
                !h.underConstruction &&
                h.dogs.length < 4 &&
                HabitatCatalog.isHabitatCompatible(
                  habitatCatalogId: h.habitatId,
                  breedId: pup['breedId'],
                  element: pup['element'],
                ),
          )
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
    } else if (_placingBredPuppy != null) {
      final pup = _placingBredPuppy!;
      final placedName = widget.game.claimBredPuppyToHabitat(hab.id);
      if (placedName != null) {
        SoundManager.instance.playQuestReward();
        _showHudToast('${pup['breedName'] ?? 'Bred'} Pup placed in $placedName!');
      }
      setState(() {
        _placingBredPuppy = null;
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
        _adoptingDogItem != null ||
        _transferringDog != null ||
        _placingBredPuppy != null;
    final compatibleHabitatIds = isSelectingHabitat
        ? _getCompatibleHabitatIds()
        : <String>{};
    final isCompactHud = MediaQuery.sizeOf(context).width < 880;

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: AnimatedBuilder(
        animation: _overviewController,
        builder: (context, _) {
          final overviewT =
              Curves.easeInOutCubic.transform(_overviewController.value);
          final skyCloudScale = (1.0 - 0.28 * overviewT) *
              (1.0 + (_overviewZoom - 1.0) * 0.45 * overviewT);
          final skyCloudOffset = Offset(
            _overviewCamX * 0.25 * overviewT,
            _overviewCamY * 0.25 * overviewT,
          );

          return SkyBackground(
            showLand: false,
            cloudScale: skyCloudScale,
            cloudOffset: skyCloudOffset,
            child: LayoutBuilder(
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
              _camY =
                  (H * 0.44 - (corners.center.dy - 24.0) * totalScale) -
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
              final changed =
                  (prev == null) != (projectedRect == null) ||
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

            return AnimatedBuilder(
              animation: _overviewController,
              builder: (context, _) {
                final t = Curves.easeInOutCubic.transform(
                  _overviewController.value,
                );
                final islandScale = 1.0 - (0.62 * t);
                final islandOpacity = (1.0 - t * 1.45).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (islandOpacity > 0.01)
                      IgnorePointer(
                        ignoring: _isIslandOverview,
                        child: Opacity(
                          opacity: islandOpacity,
                          child: Transform.scale(
                            scale: islandScale,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // ── 1. DRAGGABLE & MOVABLE ISLAND VIEW ──
                                Listener(
                                  onPointerSignal: (pointerSignal) {
                                    if (pointerSignal is PointerScrollEvent) {
                                      final zoomDelta =
                                          pointerSignal.scrollDelta.dy < 0
                                          ? 1.12
                                          : 0.89;
                                      final minZoom = W < 600
                                          ? 0.60
                                          : (W < 900 ? 0.80 : 1.0);
                                      _zoom = (_zoom * zoomDelta).clamp(
                                        minZoom,
                                        2.8,
                                      );
                                      final nextScaledW =
                                          worldWidth * baseScale * _zoom;
                                      final nextScaledH =
                                          worldHeight * baseScale * _zoom;
                                      final nextMaxX = max(
                                        0.0,
                                        (nextScaledW - W) / 2,
                                      );
                                      final nextMaxY = max(
                                        0.0,
                                        (nextScaledH - H) / 2,
                                      );
                                      _camX = _camX.clamp(-nextMaxX, nextMaxX);
                                      _camY = _camY.clamp(-nextMaxY, nextMaxY);
                                      _cameraNotifier.value++;
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
                                            // Multi-touch pinch zoom
                                            if (details.scale != 1.0) {
                                              _zoom =
                                                  (_startZoom * details.scale)
                                                      .clamp(
                                                        W < 600
                                                            ? 0.60
                                                            : (W < 900
                                                                  ? 0.80
                                                                  : 1.0),
                                                        2.8,
                                                      );
                                            }
                                            // Mouse or finger pan
                                            _camX += details.focalPointDelta.dx;
                                            _camY += details.focalPointDelta.dy;

                                            final currScaledW =
                                                worldWidth * baseScale * _zoom;
                                            final currScaledH =
                                                worldHeight * baseScale * _zoom;
                                            final currMaxX = max(
                                              0.0,
                                              (currScaledW - W) / 2,
                                            );
                                            final currMaxY = max(
                                              0.0,
                                              (currScaledH - H) / 2,
                                            );
                                            _camX = _camX.clamp(
                                              -currMaxX,
                                              currMaxX,
                                            );
                                            _camY = _camY.clamp(
                                              -currMaxY,
                                              currMaxY,
                                            );
                                            _cameraNotifier.value++;
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
                                          // The movable Island Canvas (GPU-transformed without rebuilding)
                                          ValueListenableBuilder<int>(
                                            valueListenable: _cameraNotifier,
                                            builder: (context, _, islandChild) {
                                              final curTotalScale =
                                                  baseScale * _zoom;
                                              final curScaledW =
                                                  worldWidth * curTotalScale;
                                              final curScaledH =
                                                  worldHeight * curTotalScale;
                                              final curMaxX = max(
                                                0.0,
                                                (curScaledW - W) / 2,
                                              );
                                              final curMaxY = max(
                                                0.0,
                                                (curScaledH - H) / 2,
                                              );
                                              final clampedX = _camX.clamp(
                                                -curMaxX,
                                                curMaxX,
                                              );
                                              final clampedY = _camY.clamp(
                                                -curMaxY,
                                                curMaxY,
                                              );
                                              final curLeft =
                                                  (W - curScaledW) / 2 +
                                                  clampedX;
                                              final curTop =
                                                  (H - curScaledH) / 2 +
                                                  clampedY;

                                              return Positioned(
                                                left: 0,
                                                top: 0,
                                                width: worldWidth,
                                                height: worldHeight,
                                                child: Transform(
                                                  alignment: Alignment.topLeft,
                                                  transform: Matrix4.identity()
                                                    ..translateByDouble(
                                                      curLeft,
                                                      curTop,
                                                      0.0,
                                                      1.0,
                                                    )
                                                    ..scaleByDouble(
                                                      curTotalScale,
                                                      curTotalScale,
                                                      1.0,
                                                      1.0,
                                                    ),
                                                  child: islandChild,
                                                ),
                                              );
                                            },
                                            child: RepaintBoundary(
                                              child: SizedBox(
                                                width: worldWidth,
                                                height: worldHeight,
                                                child: WorldIsometricGrid(
                                                  habitats: widget
                                                      .game
                                                      .currentIslandHabitats,
                                                  surfaceAsset: widget
                                                      .game
                                                      .currentIsland
                                                      .surfaceAsset,
                                                  selectedHabitatId: widget
                                                      .game
                                                      .selectedHabitatId,
                                                  gridVisible:
                                                      widget.game.gridVisible,
                                                  placingItem: _placingItem,
                                                  movingHabitatId:
                                                      _movingHabitatId,
                                                  isSelectingHabitat:
                                                      isSelectingHabitat,
                                                  highlightedHabitatIds:
                                                      compatibleHabitatIds,
                                                  activeBreeding: widget
                                                      .game
                                                      .activeBreeding,
                                                  onOpenBreeding: () =>
                                                      widget.onNavigate(
                                                        'breeding',
                                                      ),
                                                  onSelectTargetHabitat:
                                                      _handleTargetHabitatSelected,
                                                  onTapIncompatibleHabitat: (hab) {
                                                    if (hab.underConstruction) {
                                                      _showLotToast(
                                                        message:
                                                            '${hab.name} is still under construction!',
                                                        isError: true,
                                                      );
                                                    } else if (hab.dogs.length >= 4) {
                                                      _showLotToast(
                                                        message:
                                                            '${hab.name} is full (4/4 dogs)!',
                                                        isError: true,
                                                      );
                                                    } else {
                                                      final breedId =
                                                          _adoptingDogItem?.id ??
                                                              _transferringDog
                                                                  ?.breedId ??
                                                              _placingBredPuppy?[
                                                                  'breedId'];
                                                      final element =
                                                          _adoptingDogItem
                                                                  ?.element ??
                                                              _transferringDog
                                                                  ?.element ??
                                                              _placingBredPuppy?[
                                                                  'element'];
                                                      final reqHab = HabitatCatalog
                                                          .requiredHabitatNameForDog(
                                                        breedId: breedId,
                                                        element: element,
                                                      );
                                                      _showLotToast(
                                                        message:
                                                            'Incompatible! Requires a $reqHab habitat.',
                                                        isError: true,
                                                      );
                                                    }
                                                  },
                                                  onSelectHabitat: (hab) {
                                                    if (!isPlacing &&
                                                        !isSelectingHabitat) {
                                                      widget.game.selectHabitat(
                                                        hab.id,
                                                      );
                                                    }
                                                  },
                                                  onCollectCoins: (id) => widget
                                                      .game
                                                      .collectCoins(id),
                                                  onCollectDogfood: (id) =>
                                                      widget.game
                                                          .collectDogfood(id),
                                                  onCompleteConstruction:
                                                      (id) => widget.game
                                                          .completeConstruction(
                                                            id,
                                                          ),
                                                  onSpeedUpConstruction: (id) {
                                                    final hab = widget
                                                        .game
                                                        .placedHabitats
                                                        .firstWhere(
                                                          (h) => h.id == id,
                                                          orElse: () =>
                                                              HabitatModel(
                                                                id: '',
                                                                habitatId: '',
                                                                name: '',
                                                                col: 0,
                                                                row: 0,
                                                              ),
                                                        );
                                                    final remSec =
                                                        hab.id.isEmpty
                                                        ? 0
                                                        : ((hab.constructionEndsAt ??
                                                                      0) -
                                                                  DateTime.now()
                                                                      .millisecondsSinceEpoch) ~/
                                                              1000;
                                                    final cost =
                                                        GameController.speedUpCostForSeconds(
                                                          remSec,
                                                        );
                                                    final ok = widget.game
                                                        .speedUpConstruction(
                                                          id,
                                                        );
                                                    if (!ok) {
                                                      _showLotToast(
                                                        message:
                                                            'Not enough Diamonds! Need $cost Diamonds to speed up.',
                                                        isError: true,
                                                      );
                                                    } else {
                                                      _showLotToast(
                                                        message:
                                                            'Construction sped up! Building ready!',
                                                        isError: false,
                                                      );
                                                    }
                                                  },
                                                  onConfirmPlace:
                                                      _confirmPlacement,
                                                  onCancelPlace:
                                                      _cancelPlacement,
                                                  onStartMove: _startMoving,
                                                  obstacles: widget
                                                      .game
                                                      .currentIslandObstacles,
                                                  selectedObstacleId: widget
                                                      .game
                                                      .selectedObstacleId,
                                                  isLotExpansionUnlocked: widget
                                                      .game
                                                      .isLotExpansionUnlocked,
                                                  isLot1Unlocked: widget
                                                      .game
                                                      .isLot1Unlocked,
                                                  isLot2Unlocked: widget
                                                      .game
                                                      .isLot2Unlocked,
                                                  isIslandHydrated: widget
                                                      .game
                                                      .isIslandHydrated,
                                                  onSelectObstacle:
                                                      _handleSelectObstacle,
                                                  onStartClearingObstacle:
                                                      (id) => widget.game
                                                          .startClearingObstacle(
                                                            id,
                                                          ),
                                                  onCompleteClearingObstacle:
                                                      _handleCompleteClearingObstacle,
                                                  onUnlockLotExpansion: () =>
                                                      _showExpandLotDialogForLot(
                                                        widget
                                                                .game
                                                                .isLot1Unlocked
                                                            ? 2
                                                            : 1,
                                                      ),
                                                  onUnlockLot:
                                                      _showExpandLotDialogForLot,
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
                                      widget.game.setShopDialogOpen(true);
                                      showDialog(
                                        context: context,
                                        builder: (_) => BuildShopDialog(
                                          game: widget.game,
                                          onSelectBuildingToPlace: (item) =>
                                              _startPlacing(item),
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
                                      ).then((_) {
                                        widget.game.setShopDialogOpen(false);
                                        widget.game
                                            .markWalkthroughShopVisited();
                                      });
                                    },
                                    onOpenGoals: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) =>
                                            GoalsDialog(game: widget.game),
                                      );
                                    },
                                    onOpenProgress: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) =>
                                            ProgressDialog(game: widget.game),
                                      );
                                    },
                                    onOpenSocial: () {
                                      widget.game.setSocialDialogOpen(true);
                                      showDialog(
                                        context: context,
                                        builder: (_) => SocialDialog(
                                          game: widget.game,
                                          senderUsername:
                                              widget.game.playerUsername,
                                          onVisitFriend: (friend) {
                                            Navigator.of(context).pop();
                                            widget.onNavigate(
                                              'friend_visit',
                                              args: {
                                                'friend': friend,
                                                'showOverview': true,
                                              },
                                            );
                                          },
                                          onOpenSettings: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => SettingsDialog(
                                                game: widget.game,
                                              ),
                                            );
                                          },
                                        ),
                                      ).then((_) {
                                        widget.game.setSocialDialogOpen(false);
                                        widget.game
                                            .markWalkthroughSocialVisited();
                                      });
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
                                        builder: (_) =>
                                            SettingsDialog(game: widget.game),
                                      );
                                    },
                                    onOpenInbox: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) =>
                                            InboxDialog(game: widget.game),
                                      );
                                    },
                                    onOpenBreeding: () =>
                                        widget.onNavigate('breeding'),
                                    onOpenCollection: () =>
                                        widget.onNavigate('collection'),
                                    onOpenIslands: _openIslandOverview,
                                    onOpenHabitatCare: (hab, [dogIndex = 0]) {
                                      if (hab.isFactory) {
                                        widget.onNavigate(
                                          'factory',
                                          args: {'habitat': hab},
                                        );
                                      } else if (hab.habitatId
                                          .toLowerCase()
                                          .contains('breeding')) {
                                        widget.onNavigate('breeding');
                                      } else {
                                        widget.onNavigate(
                                          'habitat',
                                          args: {
                                            'habitat': hab,
                                            'initialDogIndex': dogIndex,
                                          },
                                        );
                                      }
                                    },
                                    onStartMoveHabitat: (hab) =>
                                        _startMoving(hab),
                                    onOpenHabitatInfo: (hab) {
                                      if (hab.isFactory) {
                                        widget.onNavigate(
                                          'factory',
                                          args: {'habitat': hab},
                                        );
                                        return;
                                      }
                                      showDialog(
                                        context: context,
                                        builder: (_) => HabitatInfoDialog(
                                          habitat: hab,
                                          onOpenCare: (h) => widget.onNavigate(
                                            'habitat',
                                            args: {'habitat': h},
                                          ),
                                        ),
                                      );
                                    },
                                    onDeselectHabitat: () =>
                                        widget.game.selectHabitat(null),
                                  ),

                                // ── 3. Habitat Selection Header Bar (Adoption & Transfer) ──
                                if (isSelectingHabitat)
                                  _buildHabitatSelectionPromptHeader(),

                                // ── 4. HUD Toast Notification Overlay ──
                                if (_hudToast != null)
                                  Positioned(
                                    top: isSelectingHabitat
                                        ? (isCompactHud ? 130 : 95)
                                        : (isCompactHud ? 140 : 80),
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xEE1E0A02),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFFBBF24),
                                            width: 1.5,
                                          ),
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
                            ),
                          ),
                        ),
                      ),
                    if (t > 0.01) _buildIslandsOverview(W, H, t),
                  ],
                );
              },
            );
          },
        ),
          );
        },
      ),
    );
  }

  Widget _buildIslandsOverview(double w, double h, double t) {
    final compact = w < 720 || h < 480;
    final overviewScale = 1.16 - (0.16 * t);

    const double mapW = 3020.0;
    const double mapH = 1860.0;
    final baseScale = min(w / mapW, h / mapH) * 0.94;
    final scaledW = mapW * baseScale * _overviewZoom;
    final scaledH = mapH * baseScale * _overviewZoom;
    final maxPanX = max(140.0, (scaledW - w) / 2 + 120.0);
    final maxPanY = max(100.0, (scaledH - h) / 2 + 90.0);
    final leftPos = (w - scaledW) / 2 + _overviewCamX.clamp(-maxPanX, maxPanX);
    final topPos = (h - scaledH) / 2 + _overviewCamY.clamp(-maxPanY, maxPanY);

    return Opacity(
      opacity: t,
      child: Transform.scale(
        scale: overviewScale,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Draggable & Zoomable Floating Sky Map ──
            Listener(
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  final delta = pointerSignal.scrollDelta.dy < 0 ? 1.12 : 0.89;
                  setState(() {
                    _overviewZoom = (_overviewZoom * delta).clamp(0.75, 2.4);
                  });
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) {
                  _overviewStartZoom = _overviewZoom;
                  setState(() => _overviewDragging = true);
                },
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.scale != 1.0) {
                      _overviewZoom = (_overviewStartZoom * details.scale)
                          .clamp(0.75, 2.4);
                    }
                    _overviewCamX = (_overviewCamX + details.focalPointDelta.dx)
                        .clamp(-maxPanX, maxPanX);
                    _overviewCamY = (_overviewCamY + details.focalPointDelta.dy)
                        .clamp(-maxPanY, maxPanY);
                  });
                },
                onScaleEnd: (_) => setState(() => _overviewDragging = false),
                child: MouseRegion(
                  cursor: _overviewDragging
                      ? SystemMouseCursors.grabbing
                      : SystemMouseCursors.grab,
                  child: Stack(
                    children: [
                      Positioned(
                        left: leftPos,
                        top: topPos,
                        width: scaledW,
                        height: scaledH,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: mapW,
                            height: mapH,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Row 1: Meadow, Desert, Ice
                                _buildFloatingIslandNode(
                                  island: IslandCatalog.islands[0],
                                  left: 120,
                                  top: 150,
                                  width: 860,
                                  height: 660,
                                ),
                                _buildFloatingIslandNode(
                                  island: IslandCatalog.islands[1],
                                  left: 1080,
                                  top: 230,
                                  width: 860,
                                  height: 660,
                                ),
                                _buildFloatingIslandNode(
                                  island: IslandCatalog.islands[2],
                                  left: 2040,
                                  top: 150,
                                  width: 860,
                                  height: 660,
                                ),
                                // Row 2: Forest, Beach, Legendary
                                _buildFloatingIslandNode(
                                  island: IslandCatalog.islands[3],
                                  left: 140,
                                  top: 960,
                                  width: 860,
                                  height: 660,
                                ),
                                _buildFloatingIslandNode(
                                  island: IslandCatalog.islands[4],
                                  left: 1100,
                                  top: 1040,
                                  width: 860,
                                  height: 660,
                                ),
                                _buildFloatingIslandNode(
                                  island: IslandCatalog.islands[5],
                                  left: 2060,
                                  top: 960,
                                  width: 860,
                                  height: 660,
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
            ),

            // ── Floating Top Controls (Back on Left, World Islands Banner Centered) ──
            Positioned(
              top: compact ? 12 : 18,
              left: compact ? 14 : 24,
              right: compact ? 14 : 24,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Centered Carved Parchment World Islands Banner
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 16 : 26,
                        vertical: compact ? 7 : 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFFBEB),
                            Color(0xFFFEF3C7),
                            Color(0xFFFDE68A),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFFB45309),
                          width: 2.4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: compact ? 22 : 28,
                            height: compact ? 22 : 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFDE047), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: const Color(0xFF78350F),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.explore_rounded,
                              color: const Color(0xFF3B1404),
                              size: compact ? 14 : 18,
                            ),
                          ),
                          SizedBox(width: compact ? 7 : 10),
                          Text(
                            'WORLD ISLANDS',
                            style: TextStyle(
                              color: const Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: compact ? 14 : 19,
                              letterSpacing: 1.0,
                              shadows: const [
                                Shadow(
                                  color: Color(0xE6FFFFFF),
                                  offset: Offset(0, 1.5),
                                  blurRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Left Tactile Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: HoverScale(
                      scale: 1.07,
                      onTap: _closeIslandOverview,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 14,
                          vertical: compact ? 7 : 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFFBEB),
                              Color(0xFFFDE68A),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFB45309),
                            width: 2.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: compact ? 20 : 24,
                              height: compact ? 20 : 24,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF78350F),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: const Color(0xFFFEF08A),
                                size: compact ? 13 : 16,
                              ),
                            ),
                            SizedBox(width: compact ? 5 : 7),
                            Text(
                              'BACK',
                              style: TextStyle(
                                color: const Color(0xFF3B1404),
                                fontFamily: 'Lilita One',
                                fontSize: compact ? 11.5 : 14,
                                letterSpacing: 0.6,
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

            // ── Bottom Hint Pill ──
            Positioned(
              bottom: compact ? 14 : 20,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC260D02),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0x99FBBF24),
                        width: 1.4,
                      ),
                    ),
                    child: Text(
                      'Drag & scroll to explore · Tap an island to fly there',
                      style: TextStyle(
                        color: const Color(0xFFFEF3C7),
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 11.5 : 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingIslandNode({
    required IslandDefinition island,
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final isUnlocked = widget.game.isIslandUnlocked(island.id);
    final isCurrent = widget.game.currentIslandId == island.id;
    final islandHabitats = widget.game.placedHabitats
        .where((h) => h.islandId == island.id)
        .toList();
    final habCount = islandHabitats.length;
    final canAfford = widget.game.canAfford(
      island.costCoins,
      island.costCrystals,
    );
    final meetsLevel = widget.game.level >= island.requiredLevel;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: HoverScale(
        scale: 1.04,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isUnlocked) {
            widget.game.switchIsland(island.id);
            _closeIslandOverview();
            return;
          }
          if (!meetsLevel) {
            _showLotToast(
              message:
                  'Reach Level ${island.requiredLevel} to unlock ${island.name}!',
              isError: true,
            );
            return;
          }
          if (!canAfford) {
            _showLotToast(
              message:
                  'Not enough Paw Coins! Need ${island.costCoins} to unlock ${island.name}.',
              isError: true,
            );
            return;
          }
          final ok = widget.game.unlockIsland(island.id);
          if (ok) {
            _showLotToast(
              message: '${island.name} unlocked! Welcome to your new island!',
              isError: false,
            );
            _closeIslandOverview();
          }
        },
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: isUnlocked ? 1.0 : 0.60,
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: worldWidth,
                      height: worldHeight,
                      child: WorldIsometricGrid(
                        habitats: islandHabitats,
                        surfaceAsset: island.surfaceAsset,
                        isOverview: true,
                        selectedHabitatId: null,
                        gridVisible: false,
                        onSelectHabitat: (_) {},
                        onCollectCoins: (_) {},
                        onCollectDogfood: (_) {},
                        obstacles:
                            widget.game.obstaclesForIsland(island.id),
                        isLot1Unlocked:
                            widget.game.isLotUnlockedForIsland(island.id, 1),
                        isLot2Unlocked:
                            widget.game.isLotUnlockedForIsland(island.id, 2),
                        isLotExpansionUnlocked:
                            widget.game.isLotUnlockedForIsland(island.id, 1) &&
                                widget.game.isLotUnlockedForIsland(island.id, 2),
                      ),
                    ),
                  ),
                ),
              ),
              if (!isUnlocked)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Raised Golden Lock Medallion
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFEF08A),
                            Color(0xFFF59E0B),
                            Color(0xFFB45309),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                            color: const Color(0xFFFFFBEB), width: 3.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 18,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF2A1205),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Color(0xFFFDE047),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Sleek Unlock Cost / Level Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: meetsLevel && canAfford
                              ? const [Color(0xFF10B981), Color(0xFF047857)]
                              : const [Color(0xFF4B1E06), Color(0xFF260D02)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: meetsLevel && canAfford
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFFBBF24),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 14,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Text(
                        !meetsLevel
                            ? 'UNLOCK AT LVL ${island.requiredLevel}'
                            : 'UNLOCK · 🪙 ${island.costCoins}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: 22,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitatSelectionPromptHeader() {
    final isAdopting = _adoptingDogItem != null;
    final isPlacingBred = _placingBredPuppy != null;
    final dogName = isAdopting
        ? _adoptingDogItem!.name
        : (isPlacingBred
            ? '${_placingBredPuppy!['breedName'] ?? 'Bred'} Pup'
            : _transferringDog!.name);
    final dogThumb = isAdopting
        ? _adoptingDogItem!.assetImage
        : (isPlacingBred
            ? (_placingBredPuppy!['sitImg'] ??
                'assets/itemsInShop/dogs/BulldogPuppySit.png')
            : DogStageInfo.getInfo(_transferringDog!).portraitImg);

    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(dogThumb, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and Instruction
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (isAdopting || isPlacingBred)
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
                        _placingBredPuppy = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
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
                          Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
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
        ),
      ),
    );
  }

  // ── Obstacle & Island Expansion Handlers ──

  void _handleSelectObstacle(ObstacleModel obs) {
    if (obs.col < 13 && obs.row < 11 && !widget.game.isLot1Unlocked) {
      _showLotToast(
        message: 'Unlock Expansion Lot 1 first to clear this obstacle!',
        isError: true,
      );
      return;
    }

    if (obs.col >= 13 && obs.row < 11 && !widget.game.isLot2Unlocked) {
      _showLotToast(
        message: 'Unlock Expansion Lot 2 first to clear this obstacle!',
        isError: true,
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
      _showLotToast(
        message: 'Obstacle cleared! Space is now ready for building!',
        isError: false,
      );
    }
  }

  void _showExpandLotDialog() {
    _showExpandLotDialogForLot(widget.game.isLot1Unlocked ? 2 : 1);
  }

  void _showLotToast({required String message, required bool isError}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: EdgeInsets.zero,
        duration: Duration(seconds: isError ? 3 : 3),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isError
                  ? const [Color(0xFFB91C1C), Color(0xFF7F1D1D)]
                  : const [Color(0xFF4B1E06), Color(0xFF260D02)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isError
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFFBBF24),
              width: 1.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isError
                      ? const Color(0x33FFFFFF)
                      : const Color(0x33FBBF24),
                ),
                child: Icon(
                  isError
                      ? Icons.warning_amber_rounded
                      : Icons.celebration_rounded,
                  color: isError
                      ? const Color(0xFFFEF08A)
                      : const Color(0xFFFDE047),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    height: 1.25,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
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

  void _showExpandLotDialogForLot(int lotNumber) {
    final cost = 2500;
    final canAfford = widget.game.coins >= cost;
    final lotTitle = lotNumber == 1
        ? 'EXPANSION LOT 1 (PARK BENCH)'
        : 'EXPANSION LOT 2 (MEADOW)';
    final lotSubtitle = lotNumber == 1
        ? 'Unlock the upper park lot under the oak tree and bench! Obstacles will remain on the lot for you to clear for XP and coins.'
        : 'Unlock the large east meadow expansion territory! Obstacles will remain on the lot for you to clear for XP and coins.';

    final formattedCost = cost.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        final content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Illustration & Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFEF3C7),
                      Color(0xFFFDE68A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD97706),
                    width: 2.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2478350F),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 1.4,
                        ),
                      ),
                      child: Image.asset(
                        'assets/ui/LotForSale.png',
                        width: 108,
                        height: 82,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              lotTitle,
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Lilita One',
                                fontSize: 17.5,
                                color: Color(0xFF78350F),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lotSubtitle,
                            style: const TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 13,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cost and Expand Button
              HoverScale(
                scale: 1.03,
                onTap: () {
                  if (!canAfford) {
                    Navigator.of(ctx).pop();
                    _showLotToast(
                      message:
                          'Not enough Paw Coins! Earn more coins from your habitats.',
                      isError: true,
                    );
                    return;
                  }
                  final ok = lotNumber == 1
                      ? widget.game.unlockLot1()
                      : widget.game.unlockLot2();
                  Navigator.of(ctx).pop();
                  if (ok) {
                    _showLotToast(
                      message: lotNumber == 1
                          ? 'Expansion Lot 1 unlocked! The remaining 1/4 lot is still locked.'
                          : 'Expansion Lot 2 unlocked! The entire island paradise is now unlocked!',
                      isError: false,
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canAfford
                          ? [const Color(0xFF10B981), const Color(0xFF059669)]
                          : [const Color(0xFF9CA3AF), const Color(0xFF6B7280)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: canAfford
                            ? const Color(0x55059669)
                            : const Color(0x33000000),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canAfford
                                ? 'UNLOCK LOT $lotNumber (🪙 $formattedCost)'
                                : 'NEED 🪙 $formattedCost (Have: ${GameController.formatCoins(widget.game.coins)})',
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Lilita One',
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 0.5,
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
        );

        return GenericModal(
          title: 'ISLAND EXPANSION',
          maxWidth: 680,
          scrollable: false,
          onClose: () => Navigator.of(ctx).pop(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final needsScale =
                  constraints.maxWidth < 460 || constraints.maxHeight < 230;
              if (needsScale) {
                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(width: 480, child: content),
                  ),
                );
              }
              return Center(child: content);
            },
          ),
        );
      },
    );
  }

  void _showClearObstacleDialog(ObstacleModel obs) {
    final canAfford = widget.game.coins >= obs.clearCost;

    showDialog(
      context: context,
      builder: (ctx) {
        final content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Horizontal Obstacle Showcase Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFEF3C7),
                      Color(0xFFFDE68A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD97706),
                    width: 2.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2478350F),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 1.4,
                        ),
                      ),
                      child: Image.asset(
                        obs.imageAsset,
                        width: 84,
                        height: 68,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              obs.name.toUpperCase(),
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Lilita One',
                                fontSize: 17.5,
                                color: Color(0xFF78350F),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Clear this obstacle to free up ground space for new habitats!',
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontSize: 13,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Cost & Reward Pills
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
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
                              const Text('🪙 ', style: TextStyle(fontSize: 13)),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 10,
                      ),
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '⏱ ${obs.clearDuration}s  •  ⭐ +${obs.xpReward} XP',
                              maxLines: 1,
                              style: const TextStyle(
                                fontFamily: 'Lilita One',
                                fontSize: 13,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Clear Button
              HoverScale(
                scale: 1.03,
                onTap: () {
                  if (!canAfford) {
                    Navigator.of(ctx).pop();
                    _showLotToast(
                      message:
                          'Not enough Paw Coins! Earn more coins from your habitats.',
                      isError: true,
                    );
                    return;
                  }
                  final ok = widget.game.startClearingObstacle(obs.id);
                  Navigator.of(ctx).pop();
                  if (ok) {
                    _showLotToast(
                      message: 'Clearing ${obs.name}... Timer started!',
                      isError: false,
                    );
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: canAfford
                          ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                          : [const Color(0xFF9CA3AF), const Color(0xFF6B7280)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: canAfford
                            ? const Color(0x55D97706)
                            : const Color(0x33000000),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cleaning_services_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canAfford ? 'CLEAR OBSTACLE' : 'NOT ENOUGH COINS',
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Lilita One',
                              fontSize: 16,
                              color: Colors.white,
                              letterSpacing: 0.5,
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
        );

        return GenericModal(
          title: 'CLEAR OBSTACLE',
          maxWidth: 680,
          scrollable: false,
          onClose: () => Navigator.of(ctx).pop(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final needsScale =
                  constraints.maxWidth < 460 || constraints.maxHeight < 275;
              if (needsScale) {
                return Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(width: 480, child: content),
                  ),
                );
              }
              return Center(child: content);
            },
          ),
        );
      },
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
        scrollable: true,
        onClose: () => Navigator.of(ctx).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              obs.imageAsset,
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
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
                    Navigator.of(ctx).pop();
                    _showLotToast(
                      message: 'Not enough Diamonds to speed up!',
                      isError: true,
                    );
                    return;
                  }
                  widget.game.speedUpClearingObstacle(obs.id, speedUpGems);
                  Navigator.of(ctx).pop();
                  _showLotToast(
                    message: 'Obstacle cleared instantly! Space ready!',
                    isError: false,
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
                      Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
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
