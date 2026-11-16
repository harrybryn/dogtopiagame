import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'loading_progress_bar.dart';

/// LoadingScreen
/// Parameters:
///   [onFinish]  – called when the fake-load reaches 100% and the fade-out ends
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
  bool _isAssetsLoaded = false;
  bool _initialized = false;

  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _logoScale;

  late AnimationController _fadeUpController;
  late Animation<double> _fadeUpOpacity;
  late Animation<Offset> _fadeUpSlide;

  late AnimationController _rayController;
  late AnimationController _pawController;

  Timer? _progressTimer;
  Timer? _tipTimer;

  final _random = Random();
  final List<String> _tips = const [
    'Breed two dogs to discover a rare hybrid!',
    'Complete daily quests to earn bonus gems.',
    'Level up your dogs to unlock new habitats.',
    'Visit friends to collect bonus gold.',
    'Some breeds only appear during special events.',
  ];

  static const String _bgAsset = 'assets/images/Loading_screen_bg.webp';
  static const String _logoAsset = 'assets/ui/logo.webp';

  @override
  void initState() {
    super.initState();

    // Logo drop-in animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoSlide = Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoScale = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Fade-up for progress bar
    _fadeUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeUpOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeUpController, curve: Curves.easeOut),
    );
    _fadeUpSlide = Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _fadeUpController, curve: Curves.easeOut),
    );

    // Spinning light rays
    _rayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Paw float animation
    _pawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _preloadImages();
    }
  }

  Future<void> _preloadImages() async {
    try {
      await Future.wait([
        precacheImage(const AssetImage(_bgAsset), context),
        precacheImage(const AssetImage(_logoAsset), context),
      ]);
    } catch (_) {
      // Fallback if loading screen bg isn't found
      try {
        await precacheImage(const AssetImage('assets/ui/splash-bg.webp'), context);
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _isAssetsLoaded = true;
    });

    // Start entry animations now that the image is guaranteed to be ready
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeUpController.forward();
    });

    _startProgressTicker();
    _startTipRotation();
  }

  void _startProgressTicker() {
    const steps = 60;
    final intervalMs = widget.duration.inMilliseconds ~/ steps;
    double current = 0;

    _progressTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      current += (100 / steps) + (_random.nextDouble() * 2 - 1);
      current = current.clamp(0, 100);

      if (mounted) setState(() => _progress = current.floorToDouble());

      if (current >= 100) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _fadeOut = true);
          Future.delayed(const Duration(milliseconds: 700), () {
            widget.onFinish();
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
    _logoController.dispose();
    _fadeUpController.dispose();
    _rayController.dispose();
    _pawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _fadeOut ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 700),
      child: IgnorePointer(
        ignoring: _fadeOut,
        child: Container(
          color: const Color(0xFF120601),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image (High Quality & Pre-cached) ──
              Image.asset(
                _bgAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/ui/splash-bg.webp',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                  );
                },
              ),

              // ── Sky gradient overlay (bottom softener) ──
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x990c4a6e),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // ── Animated golden light rays ──
              AnimatedBuilder(
                animation: _rayController,
                builder: (_, __) {
                  return Stack(
                    alignment: Alignment.center,
                    children: List.generate(8, (i) {
                      return Opacity(
                        opacity: 0.2,
                        child: Transform.rotate(
                          angle: (i * 45 * pi / 180) +
                              (_rayController.value * 2 * pi),
                          child: Container(
                            width: 3,
                            height: MediaQuery.of(context).size.height * 0.55,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.transparent, Color(0xFFfde68a)],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),

              // ── Floating paw prints ──
              AnimatedBuilder(
                animation: _pawController,
                builder: (_, __) {
                  return Stack(
                    children: List.generate(6, (i) {
                      final floatOffset = (_pawController.value * 2 - 1) * 9;
                      final rotateAngle = (_pawController.value * 2 - 1) *
                          10 *
                          pi /
                          180;
                      return Positioned(
                        left: MediaQuery.of(context).size.width *
                            (0.10 + i * 0.15),
                        bottom: MediaQuery.of(context).size.height *
                            (0.15 + (i % 3) * 0.12) +
                            floatOffset,
                        child: Opacity(
                          opacity: 0.6,
                          child: Transform.rotate(
                            angle: rotateAngle,
                            child: const Text('🐾',
                                style: TextStyle(fontSize: 24)),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),

              // ── Centered content (only shows after assets preloaded) ──
              if (_isAssetsLoaded)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo drop-in
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (_, __) {
                        return FadeTransition(
                          opacity: _logoOpacity,
                          child: SlideTransition(
                            position: _logoSlide,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 480),
                                width: MediaQuery.of(context).size.width * 0.75,
                                child: Image.asset(
                                  _logoAsset,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                  isAntiAlias: true,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // Progress bar + percentage
                    AnimatedBuilder(
                      animation: _fadeUpController,
                      builder: (_, __) {
                        return FadeTransition(
                          opacity: _fadeUpOpacity,
                          child: SlideTransition(
                            position: _fadeUpSlide,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 480),
                                child: Column(
                                  children: [
                                    LoadingProgressBar(progress: _progress),
                                    const SizedBox(height: 8),
                                    // Percentage label
                                    Text(
                                      '${_progress.toInt()}%',
                                      style: TextStyle(
                                        color: const Color(0xFFfde68a),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                        shadows: [
                                          const Shadow(
                                            color: Color(0xFF78350f),
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                          Shadow(
                                            color: const Color(0xFFf59e0b)
                                                .withOpacity(0.7),
                                            blurRadius: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Rotating tip text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.1),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        key: ValueKey(_tipIndex),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Text(
                            _tips[_tipIndex],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFfef3c7).withOpacity(0.9),
                              fontSize: 13,
                              shadows: const [
                                Shadow(
                                  color: Color(0x99000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 4,
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
        ),
      ),
    );
  }
}
