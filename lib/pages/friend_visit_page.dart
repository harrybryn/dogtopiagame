import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../components/common/hover_scale.dart';
import '../components/common/sky_background.dart';
import '../components/world/world_isometric_grid.dart';
import '../models/friend_visit_model.dart';
import '../models/habitat_model.dart';
import '../state/game_controller.dart';

/// Mock "visit a friend" screen. The friend island is a separate simulation:
/// the visitor can pet and feed its dogs, but has no ownership actions such as
/// selling, transferring, renaming, collecting, building, or baking.
class FriendVisitPage extends StatefulWidget {
  final GameController game;
  final MockFriend friend;
  final VoidCallback onBackToWorld;
  final Function(HabitatModel habitat) onOpenHabitat;

  const FriendVisitPage({
    super.key,
    required this.game,
    required this.friend,
    required this.onBackToWorld,
    required this.onOpenHabitat,
  });

  @override
  State<FriendVisitPage> createState() => _FriendVisitPageState();
}

class _FriendVisitPageState extends State<FriendVisitPage> {
  late MockFriend _friend;
  late String _selectedHabitatId;
  String? _toastMessage;
  Timer? _toastTimer;
  double _camX = 0;
  double _camY = 0;
  double _zoom = 1.05;
  double _startCamX = 0;
  double _startCamY = 0;
  double _startZoom = 1.05;
  bool _isDragging = false;
  String? _centeredHabitatId;

  @override
  void initState() {
    super.initState();
    _friend = widget.friend;
    final firstWithDogs = _friend.habitats.firstWhere(
      (h) => h.dogs.isNotEmpty,
      orElse: () => _friend.habitats.first,
    );
    _selectedHabitatId = firstWithDogs.id;
  }

  HabitatModel get _selectedHabitat =>
      _friend.habitats.firstWhere((h) => h.id == _selectedHabitatId);

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

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: SkyBackground(
        showLand: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final baseScale = max(w / worldWidth, h / worldHeight);
            final totalScale = baseScale * _zoom;
            final scaledW = worldWidth * totalScale;
            final scaledH = worldHeight * totalScale;
            final maxPanX = max(0.0, (scaledW - w) / 2);
            final maxPanY = max(0.0, (scaledH - h) / 2);

            if (_centeredHabitatId == null) {
              _centeredHabitatId = _selectedHabitatId;
              final corners = getHabitatCorners(
                _selectedHabitat.col,
                _selectedHabitat.row,
                _selectedHabitat.sizeW,
                _selectedHabitat.sizeH,
              );
              _camX = (scaledW / 2) - corners.center.dx * totalScale;
              _camY = (h * 0.46 - (corners.center.dy - 24) * totalScale) -
                  (h - scaledH) / 2;
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
                                  habitats: _friend.habitats,
                                  selectedHabitatId: _selectedHabitatId,
                                  obstacles: widget.game.obstacles,
                                  isLotExpansionUnlocked:
                                      widget.game.isLotExpansionUnlocked,
                                  isLot1Unlocked: widget.game.isLot1Unlocked,
                                  isLot2Unlocked: widget.game.isLot2Unlocked,
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
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 20,
                      vertical: compact ? 6 : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopBar(compact),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                if (_toastMessage != null)
                  Positioned(
                    bottom: compact ? 18 : 24,
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

  Widget _buildTopBar(bool compact) {
    return Row(
      children: [
        HoverScale(
          scale: 1.06,
          onTap: widget.onBackToWorld,
          child: Container(
            width: compact ? 34 : 42,
            height: compact ? 34 : 42,
            decoration: BoxDecoration(
              color: const Color(0xDD451A03),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFBBF24), width: 2),
            ),
            child: const Icon(Icons.arrow_back,
                color: Color(0xFFFEF08A), size: 20),
          ),
        ),
        SizedBox(width: compact ? 8 : 14),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VISITING ${_friend.islandName.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFFFEF08A),
                    fontFamily: 'Lilita One',
                    fontSize: 20,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${_friend.name} · Level ${_friend.level} · ${_friend.status}',
                  style: const TextStyle(
                    color: Color(0xFFFCD34D),
                    fontFamily: 'Fredoka',
                    fontSize: 11,
                  ),
                ),
              ],
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
        horizontal: compact ? 8 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xDD1E0A02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ui/dogfood.png',
              width: compact ? 16 : 20, height: compact ? 16 : 20),
          SizedBox(width: compact ? 4 : 6),
          Text(
            _fmt(widget.game.kibble),
            style: TextStyle(
              color: const Color(0xFFFEF08A),
              fontFamily: 'Lilita One',
              fontSize: compact ? 12 : 15,
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
