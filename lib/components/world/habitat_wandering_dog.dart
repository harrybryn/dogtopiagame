import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/dog_model.dart';
import '../../models/dog_evolution.dart';

/// Waypoints on the habitat patio lawn (relative to habitat footprint center).
const List<Offset> _patrolWaypoints = [
  Offset(0, 14), // Center patio
  Offset(-32, 10), // Left patio
  Offset(32, 10), // Right patio
  Offset(-18, 24), // Front-left
  Offset(18, 24), // Front-right
  Offset(-14, 2), // Mid-left
  Offset(14, 2), // Mid-right
  Offset(0, 28), // Front-center apex
];

class _SpriteCfg {
  final double shadowRx;
  final double shadowRy;
  final Size sitSize;
  final Offset sitOffset;
  final Size walkSize;
  final Offset walkOffset;

  const _SpriteCfg({
    required this.shadowRx,
    required this.shadowRy,
    required this.sitSize,
    required this.sitOffset,
    required this.walkSize,
    required this.walkOffset,
  });
}

const Map<String, _SpriteCfg> _spriteConfigs = {
  'Puppy': _SpriteCfg(
    shadowRx: 12,
    shadowRy: 4,
    sitSize: Size(42, 44),
    sitOffset: Offset(-21, -37),
    walkSize: Size(35, 31),
    walkOffset: Offset(-17, -30),
  ),
  'Young': _SpriteCfg(
    shadowRx: 14,
    shadowRy: 4.5,
    sitSize: Size(37, 39),
    sitOffset: Offset(-18, -37),
    walkSize: Size(48, 38),
    walkOffset: Offset(-24, -37),
  ),
  'Adult': _SpriteCfg(
    shadowRx: 15,
    shadowRy: 5,
    sitSize: Size(42, 44),
    sitOffset: Offset(-21, -41),
    walkSize: Size(47, 49),
    walkOffset: Offset(-23, -43),
  ),
};

class HabitatWanderingDog extends StatefulWidget {
  final DogModel dog;
  final Offset center;
  final int dogIndex;
  final VoidCallback? onTap;

  const HabitatWanderingDog({
    super.key,
    required this.dog,
    required this.center,
    this.dogIndex = 0,
    this.onTap,
  });

  @override
  State<HabitatWanderingDog> createState() => _HabitatWanderingDogState();
}

class _HabitatWanderingDogState extends State<HabitatWanderingDog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tickerController;

  late Offset _pos;
  late Offset _target;
  String _mode = 'sitting'; // 'sitting' | 'walking'
  bool _flipH = false;

  late int _sitStartTime;
  late int _sitDuration;
  double _walkCycleTime = 0.0;
  double _breathCycleTime = 0.0;
  DateTime? _lastTick;

  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();

    final startIdx = (widget.dogIndex * 2) % _patrolWaypoints.length;
    _pos = _patrolWaypoints[startIdx];
    _target = _pos;

    final now = DateTime.now().millisecondsSinceEpoch;
    _sitStartTime = now + (widget.dogIndex * 1200);
    _sitDuration = 4000 + (widget.dogIndex * 1000);

    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _tickerController.addListener(_onTick);
  }

  @override
  void dispose() {
    _tickerController.removeListener(_onTick);
    _tickerController.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;

    final nowTime = DateTime.now();
    if (_lastTick == null) {
      _lastTick = nowTime;
      return;
    }

    final dt = min(
      (nowTime.difference(_lastTick!).inMicroseconds) / 1000000.0,
      0.1,
    );
    _lastTick = nowTime;

    final nowMs = nowTime.millisecondsSinceEpoch;
    const speed = 22.0; // Same 22 px/s stroll from React

    if (_mode == 'sitting') {
      _breathCycleTime += dt;
      final elapsed = nowMs - _sitStartTime;

      if (elapsed >= _sitDuration) {
        // Find candidates at least 26px away
        final candidates = _patrolWaypoints.where((pt) {
          final d = (pt - _pos).distance;
          return d >= 26;
        }).toList();

        final nextTarget = candidates.isNotEmpty
            ? candidates[_rnd.nextInt(candidates.length)]
            : _patrolWaypoints[_rnd.nextInt(_patrolWaypoints.length)];

        final dx = nextTarget.dx - _pos.dx;

        setState(() {
          _target = nextTarget;
          _mode = 'walking';
          _flipH = dx < 0;
          _walkCycleTime = 0.0;
        });
      } else {
        setState(() {}); // For breath animation
      }
    } else if (_mode == 'walking') {
      _walkCycleTime += dt;
      final diff = _target - _pos;
      final dist = diff.distance;

      if (dist <= 1.5) {
        setState(() {
          _pos = _target;
          _mode = 'sitting';
          _sitStartTime = nowMs;
          _sitDuration = 4500 + _rnd.nextInt(1500);
          _breathCycleTime = 0.0;
        });
      } else {
        final step = speed * dt;
        final moveDist = min(dist, step);
        final dir = diff / dist;
        final nextPos = _pos + dir * moveDist;
        final nextFlip = diff.dx < 0;

        setState(() {
          _pos = nextPos;
          _flipH = nextFlip;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = DogStageInfo.getInfo(widget.dog);
    final cfg = _spriteConfigs[info.stage] ?? _spriteConfigs['Adult']!;

    // Position relative to habitat center
    final currentPos = widget.center + _pos;

    // Breathing effect when sitting: 1.0 to 1.03 scale
    double scale = 1.0;
    double translateY = 0.0;
    double rotateZ = 0.0;

    if (_mode == 'sitting') {
      scale = 1.0 + 0.025 * sin(_breathCycleTime * (2 * pi / 2.4));
    } else {
      // Waddle animation when walking (rotation and slight bobbing)
      final waddleProgress = sin(_walkCycleTime * 15.0);
      rotateZ = waddleProgress * 0.05; // ~3 degrees
      translateY = -waddleProgress.abs() * 2.0; // 0 to -2px
    }

    final spriteSize = _mode == 'walking' ? cfg.walkSize : cfg.sitSize;
    final spriteOffset = _mode == 'walking' ? cfg.walkOffset : cfg.sitOffset;
    final spriteAsset = _mode == 'walking' ? info.walkImg : info.sitImg;

    return Positioned(
      left: currentPos.dx,
      top: currentPos.dy,
      width: 0,
      height: 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Soft ground contact shadow ellipse
          Positioned(
            left: -cfg.shadowRx,
            top: 2 - cfg.shadowRy,
            child: Container(
              width: cfg.shadowRx * 2,
              height: cfg.shadowRy * 2,
              decoration: BoxDecoration(
                color: const Color(0x55000000),
                borderRadius: BorderRadius.all(
                  Radius.elliptical(cfg.shadowRx, cfg.shadowRy),
                ),
              ),
            ),
          ),

          // 2. Dog Sprite with Horizontal Flip & Waddle/Breath
          Positioned(
            left: spriteOffset.dx,
            top: spriteOffset.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..scale(_flipH ? -scale : scale, scale, 1.0)
                  ..translate(0.0, translateY)
                  ..rotateZ(_flipH ? -rotateZ : rotateZ),
                child: SizedBox(
                  width: spriteSize.width,
                  height: spriteSize.height,
                  child: Image.asset(
                    spriteAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
