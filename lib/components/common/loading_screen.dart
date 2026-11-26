import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'loading_progress_bar.dart';

/// LoadingScreen
/// Parameters:
///   [onFinish]  – called when the load reaches 100% and the fade-out ends
///   [duration]  – total loading duration (default 3 seconds)
class LoadingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  final Duration duration;

  const LoadingScreen({
    super.key,
    required this.onFinish,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  double _progress = 0; // 0–100
  bool _fadeOut = false;
  int _tipIndex = 0;
  bool _initialized = false;

  late final AnimationController _entryController;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _barOpacity;

  late final AnimationController _ambientController;
  late final AnimationController _rayController;

  Timer? _progressTimer;
  Timer? _tipTimer;

  final _random = Random();
  final List<String> _tips = const [
    'Breed two dogs to discover a rare hybrid!',
    'Complete daily quests to earn bonus gems.',
    'Level up your dogs to unlock new habitats.',
    'Visit friends to collect bonus gold.',
    'Bake tasty kibble in the Dogfood Factory!',
  ];

  static const String _bgAsset = 'assets/images/Loading_screen_bg.webp';
  static const String _logoAsset = 'assets/images/DogtopiaLogo_transparent.webp';

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _barOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _rayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startLoadingSequence();
    }
  }

  Future<void> _startLoadingSequence() async {
    _entryController.forward();
    _startProgressTicker();
    _startTipRotation();

    try {
      await Future.wait([
        precacheImage(const AssetImage(_bgAsset), context),
        precacheImage(const AssetImage(_logoAsset), context),
      ]);
    } catch (_) {
      // Ignore precache errors in headless/test environments.
    }
  }

  void _startProgressTicker() {
    const steps = 60;
    final intervalMs = max(16, widget.duration.inMilliseconds ~/ steps);
    double current = 0;

    _progressTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      current += (100 / steps) + (_random.nextDouble() * 1.4 - 0.5);
      current = current.clamp(0, 100);

      if (mounted) setState(() => _progress = current.floorToDouble());

      if (current >= 100) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _fadeOut = true);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) widget.onFinish();
          });
        });
      }
    });
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _tipTimer?.cancel();
    _entryController.dispose();
    _ambientController.dispose();
    _rayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _fadeOut ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 600),
      child: IgnorePointer(
        ignoring: _fadeOut,
        child: Container(
          color: const Color(0xFF1A0D04),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image with gentle slow zoom ──
              AnimatedBuilder(
                animation: _ambientController,
                builder: (_, child) {
                  final zoom =
                      1.0 + 0.035 * Curves.easeInOut.transform(_ambientController.value);
                  return Transform.scale(scale: zoom, child: child);
                },
                child: Image.asset(
                  _bgAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Soft sky & bottom vignette for clear foreground contrast ──
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x33071E3D),
                      Color(0x11000000),
                      Color(0xBB1E0E04),
                    ],
                    stops: [0.0, 0.48, 1.0],
                  ),
                ),
              ),

              // ── Rotating game-style sunburst rays ──
              AnimatedBuilder(
                animation: _rayController,
                builder: (_, _) {
                  final size = MediaQuery.sizeOf(context);
                  final diameter = max(size.width, size.height) * 1.1;
                  return Center(
                    child: Transform.translate(
                      offset: Offset(0, -size.height * 0.08),
                      child: Transform.rotate(
                        angle: _rayController.value * 2 * pi,
                        child: CustomPaint(
                          size: Size(diameter, diameter),
                          painter: const _SunburstPainter(),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Responsive Foreground Content ──
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;
                    final isCompact = h < 440;

                    final logoMaxW = min(w * 0.78, isCompact ? 300.0 : 460.0);
                    final logoMaxH = h * (isCompact ? 0.40 : 0.36);
                    final barMaxW = min(w * 0.84, 460.0);

                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: isCompact ? 10 : 24,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Floating Logo with Warm Glow ──
                            AnimatedBuilder(
                              animation: Listenable.merge(
                                [_entryController, _ambientController],
                              ),
                              builder: (_, child) {
                                final floatY = sin(
                                      _ambientController.value * pi,
                                    ) *
                                    -6.0;
                                return Opacity(
                                  opacity: _logoOpacity.value,
                                  child: Transform.translate(
                                    offset: Offset(0, floatY),
                                    child: Transform.scale(
                                      scale: _logoScale.value,
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: logoMaxW * 0.72,
                                    height: logoMaxH * 0.65,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFDE047)
                                              .withValues(alpha: 0.28),
                                          blurRadius: 64,
                                          spreadRadius: 12,
                                        ),
                                      ],
                                    ),
                                  ),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: logoMaxW,
                                      maxHeight: logoMaxH,
                                    ),
                                    child: Image.asset(
                                      _logoAsset,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                      isAntiAlias: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: isCompact ? 14 : 28),

                            // ── Progress Bar + Status Label ──
                            FadeTransition(
                              opacity: _barOpacity,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: barMaxW),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LoadingProgressBar(progress: _progress),
                                    SizedBox(height: isCompact ? 6 : 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xAA261105),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0x88FDE68A),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'LOADING ISLAND... ${_progress.toInt()}%',
                                        style: const TextStyle(
                                          fontFamily: 'Lilita One',
                                          color: Color(0xFFFDE68A),
                                          fontSize: 13,
                                          letterSpacing: 1.6,
                                          shadows: [
                                            Shadow(
                                              color: Color(0xCC000000),
                                              offset: Offset(0, 1.5),
                                              blurRadius: 3,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: isCompact ? 10 : 18),

                            // ── Rotating Tip Pill ──
                            FadeTransition(
                              opacity: _barOpacity,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 380),
                                transitionBuilder: (child, anim) {
                                  return FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0, 0.12),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  key: ValueKey(_tipIndex),
                                  constraints: BoxConstraints(
                                    maxWidth: min(w * 0.88, 420.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x991C0B03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0x44FDE68A),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.pets_rounded,
                                        color: Color(0xFFFBBF24),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _tips[_tipIndex],
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFFEF3C7),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws classic game-style conical sunburst rays that taper at the center
/// and fade smoothly outward.
class _SunburstPainter extends CustomPainter {
  const _SunburstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFEF08A).withValues(alpha: 0.24),
          const Color(0xFFFDE047).withValues(alpha: 0.09),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    const rayCount = 12;
    const step = (2 * pi) / rayCount;
    const halfSpread = step * 0.22;

    for (int i = 0; i < rayCount; i++) {
      final a = i * step;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + cos(a - halfSpread) * radius,
          center.dy + sin(a - halfSpread) * radius,
        )
        ..lineTo(
          center.dx + cos(a + halfSpread) * radius,
          center.dy + sin(a + halfSpread) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
