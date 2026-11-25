import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../components/common/hover_scale.dart';
import '../components/common/sky_background.dart';
import '../components/world/world_isometric_grid.dart';
import '../models/friend_visit_model.dart';
import '../models/habitat_model.dart';
import '../models/island_model.dart';
import '../services/audio_service.dart';
import '../state/game_controller.dart';

/// Mock "visit a friend" screen. The friend island is a separate simulation:
/// the visitor can switch between the friend's unlocked islands via the
/// World Islands landsurface overview, and pet/feed their dogs, with no
/// ownership actions (selling, collecting, building, etc.).
class FriendVisitPage extends StatefulWidget {
  final GameController game;
  final MockFriend friend;
  final String? initialIslandId;
  final bool initialShowOverview;
  final VoidCallback onBackToWorld;
  final Function(HabitatModel habitat) onOpenHabitat;

  const FriendVisitPage({
    super.key,
    required this.game,
    required this.friend,
    this.initialIslandId,
    this.initialShowOverview = false,
    required this.onBackToWorld,
    required this.onOpenHabitat,
  });

  @override
  State<FriendVisitPage> createState() => _FriendVisitPageState();
}

class _FriendVisitPageState extends State<FriendVisitPage> {
  late MockFriend _friend;
  late String _currentIslandId;
  late bool _isIslandOverviewOpen;
  bool _openedOverviewFromIsland = false;
  String? _selectedHabitatId;
  String? _toastMessage;
  Timer? _toastTimer;
  double _camX = 0;
  double _camY = 0;
  double _zoom = 1.05;
  double _startCamX = 0;
  double _startCamY = 0;
  double _startZoom = 1.05;
  bool _isDragging = false;
  bool _needsCenter = true;

  // Overview pan/zoom state (matches WorldViewPage)
  double _overviewCamX = 0;
  double _overviewCamY = 0;
  double _overviewZoom = 1.0;
  double _overviewStartZoom = 1.0;
  bool _overviewDragging = false;

  @override
  void initState() {
    super.initState();
    _friend = widget.friend;
    _isIslandOverviewOpen = widget.initialShowOverview;
    final requested = widget.initialIslandId;
    if (requested != null && _friend.isIslandUnlocked(requested)) {
      _currentIslandId = requested;
    } else {
      _currentIslandId = _friend.unlockedIslandIds.contains(
        IslandCatalog.starterIslandId,
      )
          ? IslandCatalog.starterIslandId
          : _friend.unlockedIslandIds.first;
    }
    _syncSelectedHabitatForCurrentIsland();
  }

  List<HabitatModel> get _islandHabitats =>
      _friend.habitatsForIsland(_currentIslandId);

  HabitatModel? get _selectedHabitat {
    final list = _islandHabitats;
    if (list.isEmpty) return null;
    return list.firstWhere(
      (h) => h.id == _selectedHabitatId,
      orElse: () => list.first,
    );
  }

  void _syncSelectedHabitatForCurrentIsland() {
    final list = _islandHabitats;
    if (list.isEmpty) {
      _selectedHabitatId = null;
      return;
    }
    final firstWithDogs = list.firstWhere(
      (h) => h.dogs.isNotEmpty,
      orElse: () => list.first,
    );
    _selectedHabitatId = firstWithDogs.id;
  }

  void _openIslandOverview() {
    SoundManager.instance.playClick();
    setState(() {
      _openedOverviewFromIsland = true;
      _isIslandOverviewOpen = true;
      _overviewCamX = 0;
      _overviewCamY = 0;
      _overviewZoom = 1.0;
    });
  }

  void _closeIslandOverview() {
    SoundManager.instance.playClick();
    if (!_openedOverviewFromIsland) {
      widget.onBackToWorld();
      return;
    }
    setState(() {
      _isIslandOverviewOpen = false;
    });
  }

  void _selectFriendIsland(IslandDefinition island) {
    if (!_friend.isIslandUnlocked(island.id)) {
      SoundManager.instance.playClick();
      _showToast("${_friend.name} hasn't unlocked ${island.name} yet!");
      return;
    }
    SoundManager.instance.playClick();
    setState(() {
      _currentIslandId = island.id;
      _syncSelectedHabitatForCurrentIsland();
      _needsCenter = true;
      _isIslandOverviewOpen = false;
      _openedOverviewFromIsland = true;
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)} K';
    return n.toString();
  }

  void _showToast(String message) {
    setState(() => _toastMessage = message);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final compact = media.width < 880 || media.height < 560;
    final currentIsland = IslandCatalog.findById(_currentIslandId);
    final lot1Unlocked = _friend.isLotUnlockedForIsland(_currentIslandId, 1);
    final lot2Unlocked = _friend.isLotUnlockedForIsland(_currentIslandId, 2);

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: SkyBackground(
        showLand: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            if (_isIslandOverviewOpen) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  _buildFriendIslandOverview(w, h, compact),
                  if (_toastMessage != null)
                    Positioned(
                      bottom: compact ? 52 : 66,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildToast(compact)),
                    ),
                ],
              );
            }

            final baseScale = max(w / worldWidth, h / worldHeight);
            final totalScale = baseScale * _zoom;
            final scaledW = worldWidth * totalScale;
            final scaledH = worldHeight * totalScale;
            final maxPanX = max(0.0, (scaledW - w) / 2);
            final maxPanY = max(0.0, (scaledH - h) / 2);

            if (_needsCenter) {
              _needsCenter = false;
              final target = _selectedHabitat;
              if (target != null) {
                final corners = getHabitatCorners(
                  target.col,
                  target.row,
                  target.sizeW,
                  target.sizeH,
                );
                _camX = (scaledW / 2) - corners.center.dx * totalScale;
                _camY = (h * 0.46 - (corners.center.dy - 24) * totalScale) -
                    (h - scaledH) / 2;
              } else {
                _camX = 0;
                _camY = 0;
              }
            }

            _camX = _camX.clamp(-maxPanX, maxPanX);
            _camY = _camY.clamp(-maxPanY, maxPanY);
            final leftPos = (w - scaledW) / 2 + _camX;
            final topPos = (h - scaledH) / 2 + _camY;

            return Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent) {
                      setState(() {
                        final delta =
                            signal.scrollDelta.dy < 0 ? 1.12 : 0.89;
                        _zoom = (_zoom * delta).clamp(0.75, 2.4);
                      });
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (_) {
                      _startCamX = _camX;
                      _startCamY = _camY;
                      _startZoom = _zoom;
                      setState(() => _isDragging = true);
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        if (details.scale != 1.0) {
                          _zoom = (_startZoom * details.scale).clamp(0.75, 2.4);
                        }
                        _camX = _startCamX + details.focalPointDelta.dx;
                        _camY = _startCamY + details.focalPointDelta.dy;
                      });
                    },
                    onScaleEnd: (_) => setState(() => _isDragging = false),
                    child: MouseRegion(
                      cursor: _isDragging
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
                                width: worldWidth,
                                height: worldHeight,
                                child: WorldIsometricGrid(
                                  habitats: _islandHabitats,
                                  surfaceAsset: currentIsland.surfaceAsset,
                                  selectedHabitatId: _selectedHabitatId,
                                  obstacles: _friend
                                      .obstaclesForIsland(_currentIslandId),
                                  isLotExpansionUnlocked:
                                      lot1Unlocked && lot2Unlocked,
                                  isLot1Unlocked: lot1Unlocked,
                                  isLot2Unlocked: lot2Unlocked,
                                  onSelectHabitat: (hab) {
                                    if (hab.isFactory) {
                                      _showToast(
                                        'Only ${_friend.name} can manage ${hab.name}.',
                                      );
                                      return;
                                    }
                                    setState(() => _selectedHabitatId = hab.id);
                                    widget.onOpenHabitat(hab);
                                  },
                                  onSelectObstacle: (_) => _showToast(
                                    'Only ${_friend.name} can clear obstacles.',
                                  ),
                                  onUnlockLot: (_) => _showToast(
                                    'Only ${_friend.name} can expand territory.',
                                  ),
                                  onCollectCoins: (_) => _showToast(
                                    'Only ${_friend.name} can collect coins.',
                                  ),
                                  onCollectDogfood: (_) => _showToast(
                                    'Only ${_friend.name} can collect kibble.',
                                  ),
                                  onCompleteConstruction: (_) => _showToast(
                                    'Only ${_friend.name} can finish building.',
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

                // Top Visitor HUD
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 18,
                      vertical: compact ? 8 : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(compact, currentIsland),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // Bottom-left Islands badge button (matches player's WorldHud)
                Positioned(
                  bottom: compact ? 10 : 16,
                  left: compact ? 10 : 14,
                  child: _buildIslandsBadgeButton(compact),
                ),

                // Bottom-center Guest Mode pill
                Positioned(
                  bottom: compact ? 14 : 20,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 16,
                          vertical: compact ? 5 : 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC1E0A02),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0x99FBBF24),
                            width: 1.4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.pets_rounded,
                              color: const Color(0xFFFDE047),
                              size: compact ? 13 : 15,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap any habitat to pet & feed dogs',
                              style: TextStyle(
                                color: const Color(0xFFFEF3C7),
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w700,
                                fontSize: compact ? 10.5 : 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (_toastMessage != null)
                  Positioned(
                    bottom: compact ? 50 : 62,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildToast(compact),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIslandsBadgeButton(bool compact) {
    final badgeScale = compact ? 0.72 : 0.88;
    final badgeW = 118.0 * badgeScale;
    final badgeH = 124.0 * badgeScale;

    return Tooltip(
      message: "Switch ${_friend.name}'s Islands",
      child: HoverScale(
        scale: 1.07,
        onTap: _openIslandOverview,
        child: SizedBox(
          width: badgeW,
          height: badgeH,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/ui/IslandIcon.png',
                width: badgeW,
                height: badgeH,
                fit: BoxFit.contain,
              ),
              Positioned(
                left: badgeW * (0.49 - 0.56 / 2),
                top: badgeH * 0.535,
                width: badgeW * 0.56,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'ISLANDS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF3B1404),
                      fontFamily: 'Lilita One',
                      fontSize: 15.0 * badgeScale,
                      letterSpacing: 0.4,
                      shadows: const [
                        Shadow(
                          color: Color(0xCCFFFFFF),
                          offset: Offset(0, 1),
                          blurRadius: 1,
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

  Widget _buildFriendIslandOverview(double w, double h, bool compact) {
    const double mapW = 3060;
    const double mapH = 1850;
    final baseScale = min(w / mapW, h / mapH) * 0.94;
    final totalScale = baseScale * _overviewZoom;
    final scaledW = mapW * totalScale;
    final scaledH = mapH * totalScale;
    final maxPanX = max(140.0, (scaledW - w) / 2 + 120.0);
    final maxPanY = max(100.0, (scaledH - h) / 2 + 90.0);
    final leftPos = (w - scaledW) / 2 + _overviewCamX.clamp(-maxPanX, maxPanX);
    final topPos = (h - scaledH) / 2 + _overviewCamY.clamp(-maxPanY, maxPanY);

    return Stack(
      fit: StackFit.expand,
      children: [
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
                  _overviewZoom =
                      (_overviewStartZoom * details.scale).clamp(0.75, 2.4);
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

        // Floating Top Controls (Back on Left, Friend World Banner Centered, Count Pill on Right)
        Positioned(
          top: compact ? 12 : 18,
          left: compact ? 14 : 24,
          right: compact ? 14 : 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 14 : 24,
                    vertical: compact ? 6 : 9,
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
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_friend.name.toUpperCase()}'S ISLANDS",
                            style: TextStyle(
                              color: const Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: compact ? 13 : 17,
                              letterSpacing: 0.7,
                            ),
                          ),
                          Text(
                            'Level ${_friend.level} · ${_friend.unlockedIslandCount}/${IslandCatalog.islands.length} Islands Unlocked',
                            style: TextStyle(
                              color: const Color(0xFF92400E),
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 9.5 : 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
                        colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
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
                          _openedOverviewFromIsland ? 'BACK' : 'HOME',
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

        // Bottom Hint Pill
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
                  'Drag & scroll to explore · Tap an island to visit it',
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
    );
  }

  Widget _buildFloatingIslandNode({
    required IslandDefinition island,
    required double left,
    required double top,
    required double width,
    required double height,
  }) {
    final isUnlocked = _friend.isIslandUnlocked(island.id);
    final isCurrent = _openedOverviewFromIsland && _currentIslandId == island.id;
    final islandHabitats = _friend.habitatsForIsland(island.id);
    final dogCount =
        islandHabitats.fold<int>(0, (sum, h) => sum + h.dogs.length);
    final lot1Unlocked = _friend.isLotUnlockedForIsland(island.id, 1);
    final lot2Unlocked = _friend.isLotUnlockedForIsland(island.id, 2);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: HoverScale(
        key: ValueKey('friend_island_node_${island.id}'),
        scale: 1.04,
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectFriendIsland(island),
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
                        obstacles: _friend.obstaclesForIsland(island.id),
                        isLot1Unlocked: lot1Unlocked,
                        isLot2Unlocked: lot2Unlocked,
                        isLotExpansionUnlocked: lot1Unlocked && lot2Unlocked,
                      ),
                    ),
                  ),
                ),
              ),
              if (isUnlocked)
                Positioned(
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCurrent
                            ? const [Color(0xFF10B981), Color(0xFF047857)]
                            : const [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFFA7F3D0)
                            : island.themeColor,
                        width: 2.6,
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          island.name,
                          style: TextStyle(
                            color: isCurrent
                                ? Colors.white
                                : const Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: 19,
                            letterSpacing: 0.4,
                          ),
                        ),
                        if (dogCount > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Colors.black26
                                  : const Color(0x2278350F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$dogCount🐾',
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xFFFEF08A)
                                    : const Color(0xFF78350F),
                                fontFamily: 'Lilita One',
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (!isUnlocked)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4B1E06), Color(0xFF260D02)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFBBF24),
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '${island.name} · Locked',
                        style: const TextStyle(
                          color: Color(0xFFFEF3C7),
                          fontFamily: 'Lilita One',
                          fontSize: 18,
                          letterSpacing: 0.4,
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

  Widget _buildTopBar(bool compact, IslandDefinition currentIsland) {
    return Row(
      children: [
        // Tactile Home / Return pill
        HoverScale(
          scale: 1.07,
          onTap: widget.onBackToWorld,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 13,
              vertical: compact ? 6 : 8,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
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
                    Icons.home_rounded,
                    color: const Color(0xFFFEF08A),
                    size: compact ? 13 : 15,
                  ),
                ),
                SizedBox(width: compact ? 5 : 7),
                Text(
                  'HOME',
                  style: TextStyle(
                    color: const Color(0xFF3B1404),
                    fontFamily: 'Lilita One',
                    fontSize: compact ? 11 : 13.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 12),

        // Friend Passport Banner
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 14,
                  vertical: compact ? 5 : 7,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xEE3B1404), Color(0xEE1E0A02)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFFBBF24),
                    width: 2,
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
                    Stack(
                      children: [
                        Container(
                          width: compact ? 28 : 34,
                          height: compact ? 28 : 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFDE047), Color(0xFFD97706)],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFFBEB),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.pets_rounded,
                            color: const Color(0xFF3B1404),
                            size: compact ? 16 : 19,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _friend.status == 'Online'
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'VISITING ${_friend.islandName.toUpperCase()}',
                          style: TextStyle(
                            color: const Color(0xFFFEF08A),
                            fontFamily: 'Lilita One',
                            fontSize: compact ? 14 : 17,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: currentIsland.themeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_friend.name} · ${currentIsland.name} · Lv ${_friend.level}',
                              style: TextStyle(
                                color: const Color(0xFFFCD34D),
                                fontFamily: 'Fredoka',
                                fontWeight: FontWeight.w600,
                                fontSize: compact ? 10 : 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_friend.helpCount > 0) ...[
                      SizedBox(width: compact ? 8 : 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF065F46),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6EE7B7),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFFCA5A5),
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_friend.helpCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Lilita One',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: compact ? 6 : 12),
        _buildKibblePill(compact),
      ],
    );
  }

  Widget _buildKibblePill(bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 13,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xEE3B1404), Color(0xEE1E0A02)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBBF24), width: 2),
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
          Image.asset('assets/ui/dogfood.png',
              width: compact ? 18 : 22, height: compact ? 18 : 22),
          SizedBox(width: compact ? 5 : 7),
          Text(
            _fmt(widget.game.kibble),
            style: TextStyle(
              color: const Color(0xFFFEF08A),
              fontFamily: 'Lilita One',
              fontSize: compact ? 13 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToast(bool compact) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xEE1E0A02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFBBF24), width: 2),
      ),
      child: Text(
        _toastMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFFEF3C7),
          fontFamily: 'Fredoka',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
