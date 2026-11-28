import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/dog_model.dart';
import '../../models/dog_evolution.dart';
import '../../services/audio_service.dart';

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

/// Renders up to 4 dogs in a habitat with shared separation steering (so they
/// never overlap while walking or sitting) and real-time Y-depth sorting (so
/// dogs lower on the patio render in front of dogs behind them).
class HabitatPatrolGroup extends StatefulWidget {
  final String? habitatId;
  final List<DogModel> dogs;
  final Offset center;
  final bool isThirsty;
  final VoidCallback? onTap;

  const HabitatPatrolGroup({
    super.key,
    this.habitatId,
    required this.dogs,
    required this.center,
    this.isThirsty = false,
    this.onTap,
  });

  @override
  State<HabitatPatrolGroup> createState() => _HabitatPatrolGroupState();
}

class _DogAgent {
  DogModel dog;
  Offset pos;
  Offset target;
  String mode = 'sitting';
  bool flipH = false;
  int sitStartTime;
  int sitDuration;
  double walkCycleTime = 0.0;
  double breathCycleTime = 0.0;

  _DogAgent({
    required this.dog,
    required this.pos,
    required this.sitStartTime,
    required this.sitDuration,
  }) : target = pos;
}

class _HabitatPatrolGroupState extends State<HabitatPatrolGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<_DogAgent> _agents = [];
  final Random _rnd = Random();
  DateTime? _lastTick;

  @override
  void initState() {
    super.initState();
    _syncAgents();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _ticker.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant HabitatPatrolGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAgents();
  }

  void _syncAgents() {
    final activeDogs = widget.dogs.take(4).toList();
    final byId = {for (final a in _agents) a.dog.id: a};
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = <_DogAgent>[];
    for (int i = 0; i < activeDogs.length; i++) {
      final d = activeDogs[i];
      final existing = byId[d.id];
      if (existing != null) {
        existing.dog = d;
        next.add(existing);
      } else {
        final startIdx = (i * 2) % _patrolWaypoints.length;
        next.add(
          _DogAgent(
            dog: d,
            pos: _patrolWaypoints[startIdx],
            sitStartTime: now + (i * 1200),
            sitDuration: 3800 + (i * 900),
          ),
        );
      }
    }
    _agents
      ..clear()
      ..addAll(next);
  }

  @override
  void dispose() {
    _ticker.removeListener(_onTick);
    _ticker.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted || _agents.isEmpty) return;

    final nowTime = DateTime.now();
    if (_lastTick == null) {
      _lastTick = nowTime;
      return;
    }
    final dt = min(
      nowTime.difference(_lastTick!).inMicroseconds / 1000000.0,
      0.1,
    );
    _lastTick = nowTime;

    final nowMs = nowTime.millisecondsSinceEpoch;
    final speed = widget.isThirsty ? 13.0 : 22.0;
    const minSeparation = 24.0;

    for (final agent in _agents) {
      if (agent.mode == 'sitting') {
        agent.breathCycleTime += dt;
        if (nowMs - agent.sitStartTime >= agent.sitDuration) {
          // Pick a waypoint away from self AND away from other dogs
          final candidates = _patrolWaypoints.where((pt) {
            if ((pt - agent.pos).distance < 22) return false;
            for (final other in _agents) {
              if (identical(other, agent)) continue;
              if ((pt - other.pos).distance < minSeparation) return false;
              if ((pt - other.target).distance < minSeparation) return false;
            }
            return true;
          }).toList();

          final pool = candidates.isNotEmpty
              ? candidates
              : _patrolWaypoints
                  .where((pt) => (pt - agent.pos).distance >= 18)
                  .toList();
          final nextTarget = pool.isNotEmpty
              ? pool[_rnd.nextInt(pool.length)]
              : _patrolWaypoints[_rnd.nextInt(_patrolWaypoints.length)];

          agent.target = nextTarget;
          agent.mode = 'walking';
          agent.flipH = (nextTarget.dx - agent.pos.dx) < 0;
          agent.walkCycleTime = 0.0;
        }
      } else {
        agent.walkCycleTime += dt;
        final diff = agent.target - agent.pos;
        final dist = diff.distance;

        if (dist <= 2.5) {
          agent.pos = agent.target;
          agent.mode = 'sitting';
          agent.sitStartTime = nowMs;
          agent.sitDuration = 4200 + _rnd.nextInt(1800);
          agent.breathCycleTime = 0.0;
        } else {
          // If another dog is occupying our destination and we're close, sit here cleanly
          final targetBlocked = _agents.any(
            (other) =>
                !identical(other, agent) &&
                (other.pos - agent.target).distance < 18.0 &&
                (other.pos - agent.pos).distance < 22.0,
          );
          if (targetBlocked) {
            agent.mode = 'sitting';
            agent.sitStartTime = nowMs;
            agent.sitDuration = 3500 + _rnd.nextInt(1800);
            agent.breathCycleTime = 0.0;
            continue;
          }

          final dir = diff / dist;
          // Gentle tangential steering so walking dogs curve smoothly around
          // dogs ahead of them without ever oscillating backwards.
          Offset steer = Offset.zero;
          for (final other in _agents) {
            if (identical(other, agent)) continue;
            final toOther = other.pos - agent.pos;
            final d = toOther.distance;
            if (d > 0.01 && d < minSeparation) {
              final ahead = dir.dx * toOther.dx + dir.dy * toOther.dy;
              if (ahead > 0) {
                final cross = dir.dx * toOther.dy - dir.dy * toOther.dx;
                final perp = cross >= 0
                    ? Offset(dir.dy, -dir.dx)
                    : Offset(-dir.dy, dir.dx);
                steer += perp * ((minSeparation - d) / minSeparation) * 0.65;
              }
            }
          }
          final combined = dir + steer;
          final moveDir =
              combined.distance > 0.01 ? combined / combined.distance : dir;
          final step = min(dist, speed * dt);
          final nextPos = agent.pos + moveDir * step;
          agent.pos = Offset(
            nextPos.dx.clamp(-36.0, 36.0),
            nextPos.dy.clamp(-2.0, 30.0),
          );
          if (diff.dx.abs() > 3.0 && moveDir.dx.abs() > 0.25) {
            agent.flipH = moveDir.dx < 0;
          }
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Depth-sort dogs by Y so dogs lower on screen render in front
    final sorted = [..._agents]..sort((a, b) {
        final dyCmp = a.pos.dy.compareTo(b.pos.dy);
        return dyCmp != 0 ? dyCmp : a.dog.id.compareTo(b.dog.id);
      });
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final agent in sorted) _buildDogWidget(agent),
      ],
    );
  }

  Widget _buildDogWidget(_DogAgent agent) {
    final info = DogStageInfo.getInfo(agent.dog);
    final cfg = _spriteConfigs[info.stage] ?? _spriteConfigs['Adult']!;
    final currentPos = widget.center + agent.pos;

    double scale = 1.0;
    double rotateZ = 0.0;
    if (agent.mode == 'sitting') {
      scale = 1.0 + 0.025 * sin(agent.breathCycleTime * (2 * pi / 2.4));
    } else {
      rotateZ = sin(agent.walkCycleTime * 9.0) * 0.015;
    }

    final spriteSize = agent.mode == 'walking' ? cfg.walkSize : cfg.sitSize;
    final spriteOffset =
        agent.mode == 'walking' ? cfg.walkOffset : cfg.sitOffset;
    final spriteAsset = agent.mode == 'walking' ? info.walkImg : info.sitImg;

    return Positioned(
      key: ValueKey('patrol_${agent.dog.id}'),
      left: currentPos.dx,
      top: currentPos.dy,
      width: 0,
      height: 0,
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -cfg.shadowRx,
              top: 2 - cfg.shadowRy,
              child: Transform.scale(
                scaleX: agent.mode == 'walking'
                    ? 1.0 + 0.05 * sin(agent.walkCycleTime * 18.0).abs()
                    : 1.0,
                scaleY: 1.0,
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
            ),
            Positioned(
              left: spriteOffset.dx,
              top: spriteOffset.dy,
              child: GestureDetector(
                key: widget.habitatId != null
                    ? ValueKey(
                        '${widget.habitatId}_dog_${agent.dog.id}_${widget.dogs.indexOf(agent.dog)}',
                      )
                    : null,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  SoundManager.instance.playDogBark(
                    isPuppy: agent.dog.isPuppy,
                    force: true,
                  );
                  widget.onTap?.call();
                },
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..scaleByDouble(
                      agent.flipH ? -scale : scale,
                      scale,
                      1.0,
                      1.0,
                    )
                    ..rotateZ(agent.flipH ? -rotateZ : rotateZ),
                  child: SizedBox(
                    width: spriteSize.width,
                    height: spriteSize.height,
                    child: agent.mode == 'walking'
                        ? _WalkingStrideSprite(
                            assetPath: spriteAsset,
                            size: spriteSize,
                            walkCycleTime: agent.walkCycleTime,
                          )
                        : Image.asset(
                            spriteAsset,
                            fit: BoxFit.contain,
                            cacheWidth: 160,
                            filterQuality: FilterQuality.medium,
                          ),
                  ),
                ),
              ),
            ),
            if (widget.isThirsty && agent.mode == 'sitting')
              Positioned(
                left: -10,
                top: spriteOffset.dy - 14,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xDD0F172A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF38BDF8),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF38BDF8),
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HabitatWanderingDog extends StatefulWidget {
  final DogModel dog;
  final Offset center;
  final int dogIndex;
  final bool isThirsty;
  final VoidCallback? onTap;

  const HabitatWanderingDog({
    super.key,
    required this.dog,
    required this.center,
    this.dogIndex = 0,
    this.isThirsty = false,
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
    final speed = widget.isThirsty ? 13.0 : 22.0; // Sluggish when thirsty

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

    // Breathing effect when sitting; grounded stride when walking (no jumping).
    double scale = 1.0;
    double rotateZ = 0.0;

    if (_mode == 'sitting') {
      scale = 1.0 + 0.025 * sin(_breathCycleTime * (2 * pi / 2.4));
    } else {
      // Gentle forward-walking sway without vertical hopping
      final phase = _walkCycleTime * 9.0;
      rotateZ = sin(phase) * 0.015; // subtle ~0.8 deg stride lean
    }

    final spriteSize = _mode == 'walking' ? cfg.walkSize : cfg.sitSize;
    final spriteOffset = _mode == 'walking' ? cfg.walkOffset : cfg.sitOffset;
    final spriteAsset = _mode == 'walking' ? info.walkImg : info.sitImg;

    return Positioned(
      left: currentPos.dx,
      top: currentPos.dy,
      width: 0,
      height: 0,
      child: RepaintBoundary(
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Soft ground contact shadow ellipse
          Positioned(
            left: -cfg.shadowRx,
            top: 2 - cfg.shadowRy,
            child: Transform.scale(
              scaleX: _mode == 'walking'
                  ? 1.0 + 0.05 * sin(_walkCycleTime * 18.0).abs()
                  : 1.0,
              scaleY: 1.0,
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
          ),

          // 2. Dog Sprite with Horizontal Flip & Grounded Walking Stride / Breath
          Positioned(
            left: spriteOffset.dx,
            top: spriteOffset.dy,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                SoundManager.instance.playDogBark(
                  isPuppy: widget.dog.isPuppy,
                  force: true,
                );
                widget.onTap?.call();
              },
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.identity()
                  ..scaleByDouble(_flipH ? -scale : scale, scale, 1.0, 1.0)
                  ..rotateZ(_flipH ? -rotateZ : rotateZ),
                child: SizedBox(
                  width: spriteSize.width,
                  height: spriteSize.height,
                  child: _mode == 'walking'
                      ? _WalkingStrideSprite(
                          assetPath: spriteAsset,
                          size: spriteSize,
                          walkCycleTime: _walkCycleTime,
                        )
                      : Image.asset(
                          spriteAsset,
                          fit: BoxFit.contain,
                          cacheWidth: 160,
                          filterQuality: FilterQuality.medium,
                        ),
                ),
              ),
            ),
          ),

          // 3. Thirsty indicator when island is not hydrated
          if (widget.isThirsty && _mode == 'sitting')
            Positioned(
              left: -10,
              top: spriteOffset.dy - 14,
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: const Color(0xDD0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF38BDF8),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF38BDF8),
                  size: 10,
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

/// Renders a single static walking-pose dog image with procedural alternating
/// front/back leg stride and paw lift so the dog walks without jumping.
class _WalkingStrideSprite extends StatelessWidget {
  final String assetPath;
  final Size size;
  final double walkCycleTime;

  const _WalkingStrideSprite({
    required this.assetPath,
    required this.size,
    required this.walkCycleTime,
  });

  static const double _hipSplitY = 0.72;
  static const double _midSplitX = 0.50;
  // Alignment Y corresponding to _hipSplitY: 0.72 * 2 - 1 = 0.44
  static const double _hipAlignY = _hipSplitY * 2.0 - 1.0;

  @override
  Widget build(BuildContext context) {
    final phase = walkCycleTime * 9.0;
    final swing = sin(phase);
    final lift = cos(phase);

    // Opposite-phase stride between back legs and front legs
    final backSkew = swing * 0.22;
    final backScaleY = 1.0 - max(0.0, lift) * 0.14;

    final frontSkew = -swing * 0.22;
    final frontScaleY = 1.0 - max(0.0, -lift) * 0.14;

    // Subtle chest/head stride squash-and-stretch (kept grounded)
    final torsoScaleY = 1.0 - 0.015 * cos(phase * 2.0);

    final baseImage = Image.asset(
      assetPath,
      width: size.width,
      height: size.height,
      fit: BoxFit.contain,
      cacheWidth: 160,
      filterQuality: FilterQuality.medium,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Upper body (head, ears, torso, tail)
        Transform(
          alignment: const Alignment(0.0, _hipAlignY),
          transform: Matrix4.identity()
            ..scaleByDouble(1.0, torsoScaleY, 1.0, 1.0),
          child: ClipRect(
            clipper: const _FractionClipper(0.0, 0.0, 1.0, _hipSplitY),
            child: baseImage,
          ),
        ),
        // Back legs (left half below hip line)
        Transform(
          alignment: const Alignment(-0.5, _hipAlignY),
          transform: Matrix4.skewX(backSkew)
            ..scaleByDouble(1.0, backScaleY, 1.0, 1.0),
          child: ClipRect(
            clipper: const _FractionClipper(0.0, _hipSplitY, _midSplitX, 1.0),
            child: baseImage,
          ),
        ),
        // Front legs (right half below shoulder line)
        Transform(
          alignment: const Alignment(0.5, _hipAlignY),
          transform: Matrix4.skewX(frontSkew)
            ..scaleByDouble(1.0, frontScaleY, 1.0, 1.0),
          child: ClipRect(
            clipper: const _FractionClipper(_midSplitX, _hipSplitY, 1.0, 1.0),
            child: baseImage,
          ),
        ),
      ],
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _FractionClipper(this.left, this.top, this.right, this.bottom);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    size.width * left,
    size.height * top,
    size.width * right,
    size.height * bottom,
  );

  @override
  bool shouldReclip(_FractionClipper oldClipper) =>
      oldClipper.left != left ||
      oldClipper.top != top ||
      oldClipper.right != right ||
      oldClipper.bottom != bottom;
}
