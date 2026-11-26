import 'package:flutter/material.dart';

/// A layered animated background with sky gradient, sliding mirrored clouds,
/// and a land surface at the bottom.
///
/// Layers (back to front):
///  1. Clear Blue Sky Gradient (fills screen)
///  2. Cartoon Cloud Sprite Sheet – mirrored & looped, sliding left
///  3. Land Surface – anchored at bottom
class SkyBackground extends StatefulWidget {
  /// Child widget rendered on top of all background layers.
  final Widget? child;

  /// Duration for one full cloud scroll cycle. Defaults to 110 seconds.
  final Duration cloudCycleDuration;

  /// Whether to show the land surface layer. Defaults to true.
  final bool showLand;

  /// How much of the screen height the land surface occupies (0.0–1.0).
  /// Defaults to 0.45.
  final double landHeightFraction;

  /// How much of the screen height the cloud band occupies (0.0–1.0).
  /// Defaults to 0.80.
  final double cloudHeightFraction;

  /// Vertical position of the cloud band's top edge as a fraction of screen
  /// height (0.0 = top, 1.0 = bottom). Defaults to -0.05.
  final double cloudTopFraction;

  /// Optional scale applied to the animated cloud layer (e.g. when zooming
  /// the world map). Defaults to 1.0.
  final double cloudScale;

  /// Optional translation offset applied to the animated cloud layer.
  final Offset cloudOffset;

  const SkyBackground({
    super.key,
    this.child,
    this.cloudCycleDuration = const Duration(seconds: 110),
    this.showLand = true,
    this.landHeightFraction = 0.45,
    this.cloudHeightFraction = 0.80,
    this.cloudTopFraction = -0.05,
    this.cloudScale = 1.0,
    this.cloudOffset = Offset.zero,
  });

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _cloudController;

  @override
  void initState() {
    super.initState();
    _cloudController = AnimationController(
      vsync: this,
      duration: widget.cloudCycleDuration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant SkyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cloudCycleDuration != widget.cloudCycleDuration) {
      _cloudController.duration = widget.cloudCycleDuration;
    }
  }

  @override
  void dispose() {
    _cloudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Sky gradient ──
        Positioned.fill(
          child: Image.asset(
            'assets/ui/Clear Blue Sky Gradient.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),

        // ── Layer 2: Sliding mirrored clouds (overscanned so zoom/pan never crops edges) ──
        Positioned(
          left: -800,
          right: -800,
          top: MediaQuery.of(context).size.height * widget.cloudTopFraction,
          height: MediaQuery.of(context).size.height * widget.cloudHeightFraction,
          child: RepaintBoundary(
            child: Transform.translate(
              offset: widget.cloudOffset,
              child: Transform.scale(
                scale: widget.cloudScale,
                child: AnimatedBuilder(
                  animation: _cloudController,
                  builder: (context, child) {
                    return _SlidingClouds(
                      progress: _cloudController.value,
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // ── Layer 3: Land surface at bottom ──
        if (widget.showLand)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height:
                MediaQuery.of(context).size.height * widget.landHeightFraction,
            child: Image.asset(
              'assets/ui/LandSurface.png',
              fit: BoxFit.contain,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),

        // ── Child content on top ──
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Renders the cloud sprite sheet as a seamless mirrored horizontal loop.
///
/// Pairs of original and horizontally-mirrored cloud images are placed side by side.
/// As the strip scrolls left, it loops continuously and seamlessly.
class _SlidingClouds extends StatelessWidget {
  /// 0.0 → 1.0 representing scroll progress through one full cycle.
  final double progress;

  const _SlidingClouds({required this.progress});

  // Original cloud sprite sheet aspect ratio: 2172 / 724 ≈ 3.0
  static const double _spriteAspect = 2172.0 / 724.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bandHeight = constraints.maxHeight;
        // Width of one sprite at this height
        final spriteWidth = bandHeight * _spriteAspect;
        if (spriteWidth <= 0) return const SizedBox.shrink();

        // One repeating strip is original + mirrored copy
        final stripWidth = spriteWidth * 2;

        // Ensure we have enough mirrored pairs to span across the overscanned width without gaps
        final pairCount = (constraints.maxWidth / stripWidth).ceil() + 4;

        // Scroll offset: move left by one full strip width over the cycle
        final offset = -progress * stripWidth;

        return OverflowBox(
          maxWidth: double.infinity,
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: Offset(offset, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < pairCount; i++) ...[
                  _cloudImage(spriteWidth, bandHeight, mirrored: false),
                  _cloudImage(spriteWidth, bandHeight, mirrored: true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cloudImage(double width, double height, {bool mirrored = false}) {
    final image = Image.asset(
      'assets/ui/Cartoon Cloud Sprite Sheet.png',
      fit: BoxFit.fill,
      cacheWidth: 1086,
      filterQuality: FilterQuality.medium,
    );
    return SizedBox(
      width: width,
      height: height,
      child: mirrored ? Transform.flip(flipX: true, child: image) : image,
    );
  }
}
