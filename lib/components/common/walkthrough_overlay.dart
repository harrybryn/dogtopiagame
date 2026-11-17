import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/walkthrough_step.dart';
import '../../state/game_controller.dart';
import 'hover_scale.dart';

class WalkthroughOverlay extends StatefulWidget {
  final GameController game;
  final String currentRoute;
  final Map<String, GlobalKey> targetKeys;
  final ValueNotifier<Rect?> worldTargetRectNotifier;
  final VoidCallback onReturnToWorld;

  const WalkthroughOverlay({
    super.key,
    required this.game,
    required this.currentRoute,
    required this.targetKeys,
    required this.worldTargetRectNotifier,
    required this.onReturnToWorld,
  });

  @override
  State<WalkthroughOverlay> createState() => _WalkthroughOverlayState();
}

class _WalkthroughOverlayState extends State<WalkthroughOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _bobController;
  late final AnimationController _spotlightTransitionController;
  Rect? _measuredKeyRect;
  Rect? _measuredHighlightRect;
  Rect? _fromSpotlightRect;
  Rect? _toSpotlightRect;
  WalkthroughStepId? _lastStepId;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _spotlightTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1.0,
    );

    widget.worldTargetRectNotifier.addListener(_onWorldRectChanged);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant WalkthroughOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worldTargetRectNotifier != widget.worldTargetRectNotifier) {
      oldWidget.worldTargetRectNotifier.removeListener(_onWorldRectChanged);
      widget.worldTargetRectNotifier.addListener(_onWorldRectChanged);
    }
    _scheduleMeasure();
  }

  void _onWorldRectChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.worldTargetRectNotifier.removeListener(_onWorldRectChanged);
    _bobController.dispose();
    _spotlightTransitionController.dispose();
    super.dispose();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureTargetKey();
    });
  }

  Rect? _measureKey(String? keyId) {
    if (keyId == null) return null;
    final key = widget.targetKeys[keyId];
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final renderObj = ctx.findRenderObject();
    if (renderObj is RenderBox && renderObj.hasSize) {
      return renderObj.localToGlobal(Offset.zero) & renderObj.size;
    }
    return null;
  }

  bool _rectsDiffer(Rect? a, Rect? b) {
    if ((a == null) != (b == null)) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() > 0.5 ||
        (a.top - b.top).abs() > 0.5 ||
        (a.width - b.width).abs() > 0.5 ||
        (a.height - b.height).abs() > 0.5;
  }

  void _measureTargetKey() {
    final step = widget.game.currentWalkthroughStep;
    if (step == null ||
        (step.targetKeyId == null && step.highlightAreaKeyId == null)) {
      if (_measuredKeyRect != null || _measuredHighlightRect != null) {
        setState(() {
          _measuredKeyRect = null;
          _measuredHighlightRect = null;
        });
      }
      return;
    }

    final targetRect = _measureKey(step.targetKeyId);
    final highlightRect = step.highlightAreaKeyId != null
        ? _measureKey(step.highlightAreaKeyId)
        : targetRect;

    if ((step.targetKeyId != null && targetRect == null) ||
        (step.highlightAreaKeyId != null && highlightRect == null)) {
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) _measureTargetKey();
      });
    }

    if (_rectsDiffer(_measuredKeyRect, targetRect) ||
        _rectsDiffer(_measuredHighlightRect, highlightRect)) {
      setState(() {
        _measuredKeyRect = targetRect;
        _measuredHighlightRect = highlightRect;
      });
    }
  }

  Rect? _padRect(Rect? raw, Size screenSize, {double pad = 12.0}) {
    if (raw == null || raw.isEmpty) return null;
    return Rect.fromLTRB(
      (raw.left - pad).clamp(0.0, screenSize.width),
      (raw.top - pad).clamp(0.0, screenSize.height),
      (raw.right + pad).clamp(0.0, screenSize.width),
      (raw.bottom + pad).clamp(0.0, screenSize.height),
    );
  }

  Rect? _resolveActionRect(WalkthroughStep step, Size screenSize) {
    if (step.worldTargetHabitatId != null) {
      return _padRect(widget.worldTargetRectNotifier.value, screenSize);
    }
    return _padRect(_measuredKeyRect, screenSize);
  }

  Rect? _resolveSpotlightRect(WalkthroughStep step, Size screenSize) {
    if (step.worldTargetHabitatId != null) {
      return _padRect(widget.worldTargetRectNotifier.value, screenSize);
    }
    if (step.highlightAreaKeyId != null) {
      return _padRect(_measuredHighlightRect ?? _measuredKeyRect, screenSize,
          pad: 16.0);
    }
    return _padRect(_measuredKeyRect, screenSize);
  }

  void _syncSpotlightAnimation(WalkthroughStep step, Rect? targetRect) {
    final stepChanged = _lastStepId != step.id;
    final rectChanged = _toSpotlightRect != targetRect;
    if (!stepChanged && !rectChanged) return;

    final currentAnimated = _currentAnimatedSpotlightRect();
    _lastStepId = step.id;
    _fromSpotlightRect = currentAnimated ?? targetRect;
    _toSpotlightRect = targetRect;

    if (targetRect != null && _fromSpotlightRect != null) {
      _spotlightTransitionController
        ..reset()
        ..forward();
    } else {
      _spotlightTransitionController.value = 1.0;
    }
  }

  Rect? _currentAnimatedSpotlightRect() {
    if (_toSpotlightRect == null) return null;
    if (_fromSpotlightRect == null) return _toSpotlightRect;
    final t = Curves.easeOutCubic.transform(_spotlightTransitionController.value);
    return Rect.lerp(_fromSpotlightRect, _toSpotlightRect, t);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.game.currentWalkthroughStep;
    if (step == null) return const SizedBox.shrink();

    final screenSize = MediaQuery.sizeOf(context);
    _scheduleMeasure();

    // Wrap in transparent Material so Text never gets yellow fallback underlines
    return Material(
      type: MaterialType.transparency,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 340),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: step.isCenterModal
            ? KeyedSubtree(
                key: ValueKey('modal_${step.id.name}'),
                child: _buildCenterModal(context, step, screenSize),
              )
            : (widget.currentRoute != step.requiredRoute
                ? KeyedSubtree(
                    key: ValueKey('mismatch_${step.id.name}'),
                    child: _buildRouteMismatchBanner(step),
                  )
                : KeyedSubtree(
                    key: const ValueKey('guided_spotlight_stage'),
                    child: _buildGuidedStage(step, screenSize),
                  )),
      ),
    );
  }

  Widget _buildGuidedStage(WalkthroughStep step, Size screenSize) {
    final spotlightRect = _resolveSpotlightRect(step, screenSize);
    final actionRect = _resolveActionRect(step, screenSize) ?? spotlightRect;
    _syncSpotlightAnimation(step, spotlightRect);

    final allowPassthrough = step.requireAction && actionRect != null;
    final showNextFallback =
        !step.requireAction || widget.game.canBypassCurrentWalkthroughStep;

    // Dock the Dog Wizard banner beside a tall left-side spotlight (e.g. Dog + Feed station),
    // otherwise place it on whichever vertical side (top or bottom) has more clearance.
    final bool isTallLeftSpotlight = spotlightRect != null &&
        spotlightRect.height > screenSize.height * 0.48 &&
        spotlightRect.center.dx < screenSize.width * 0.5 &&
        screenSize.width - spotlightRect.right > 340;

    final Alignment bannerAlignment;
    final double bannerMaxWidth;
    if (isTallLeftSpotlight) {
      bannerAlignment = Alignment.bottomRight;
      bannerMaxWidth =
          min(560.0, max(320.0, screenSize.width - spotlightRect.right - 36.0));
    } else if (spotlightRect == null) {
      bannerAlignment = Alignment.bottomCenter;
      bannerMaxWidth = 780.0;
    } else {
      final topSpace = spotlightRect.top;
      final bottomSpace = screenSize.height - spotlightRect.bottom;
      bannerAlignment =
          topSpace > bottomSpace ? Alignment.topCenter : Alignment.bottomCenter;
      bannerMaxWidth = 780.0;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Natural-color spotlight cutout (dark outside, 100% clear natural color inside)
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _spotlightTransitionController,
            builder: (context, _) {
              return CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  spotlightRect: _currentAnimatedSpotlightRect(),
                ),
              );
            },
          ),
        ),

        // 2. Tap blockers outside the clickable action target (or full screen if info-only step)
        if (allowPassthrough)
          ..._buildPassthroughBlockers(actionRect, screenSize)
        else
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
            ),
          ),

        // 3. Smoothly gliding, bouncing GenericArrow pointing directly at the action target
        if (actionRect != null &&
            step.arrowDirection != WalkthroughArrowDirection.none)
          _buildBouncingArrow(actionRect, step.arrowDirection, screenSize),

        // 4. Smoothly positioned Dog Wizard Dialogue Bar
        AnimatedAlign(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: bannerAlignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bannerMaxWidth),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('dialogue_${step.id.name}'),
                  child: _buildWizardDialogueBar(
                    step: step,
                    showNextButton: showNextFallback,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPassthroughBlockers(Rect hole, Size screen) {
    return [
      if (hole.top > 0)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: hole.top,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
        ),
      if (hole.bottom < screen.height)
        Positioned(
          left: 0,
          right: 0,
          top: hole.bottom,
          bottom: 0,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
        ),
      if (hole.left > 0)
        Positioned(
          left: 0,
          width: hole.left,
          top: hole.top,
          height: hole.height,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
        ),
      if (hole.right < screen.width)
        Positioned(
          left: hole.right,
          right: 0,
          top: hole.top,
          height: hole.height,
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
        ),
    ];
  }

  Widget _buildBouncingArrow(
    Rect target,
    WalkthroughArrowDirection direction,
    Size screen,
  ) {
    const double arrowSize = 82.0;
    const double gap = 10.0;

    double rotation = 0.0; // GenericArrow.png naturally points DOWN
    double baseLeft = target.center.dx - arrowSize / 2;
    double baseTop = target.top - arrowSize - gap;
    Offset bobAxis = const Offset(0, -14);

    switch (direction) {
      case WalkthroughArrowDirection.down:
        rotation = 0.0;
        baseLeft = target.center.dx - arrowSize / 2;
        baseTop = target.top - arrowSize - gap;
        bobAxis = const Offset(0, -14);
        if (baseTop < 12) {
          rotation = pi;
          baseTop = target.bottom + gap;
          bobAxis = const Offset(0, 14);
        }
        break;
      case WalkthroughArrowDirection.up:
        rotation = pi;
        baseLeft = target.center.dx - arrowSize / 2;
        baseTop = target.bottom + gap;
        bobAxis = const Offset(0, 14);
        if (baseTop + arrowSize > screen.height - 12) {
          rotation = 0.0;
          baseTop = target.top - arrowSize - gap;
          bobAxis = const Offset(0, -14);
        }
        break;
      case WalkthroughArrowDirection.left:
        rotation = pi / 2;
        baseLeft = target.right + gap;
        baseTop = target.center.dy - arrowSize / 2;
        bobAxis = const Offset(14, 0);
        break;
      case WalkthroughArrowDirection.right:
        rotation = -pi / 2;
        baseLeft = target.left - arrowSize - gap;
        baseTop = target.center.dy - arrowSize / 2;
        bobAxis = const Offset(-14, 0);
        break;
      case WalkthroughArrowDirection.none:
        return const SizedBox.shrink();
    }

    final clampedLeft =
        baseLeft.clamp(10.0, max(10.0, screen.width - arrowSize - 10)).toDouble();
    final clampedTop =
        baseTop.clamp(10.0, max(10.0, screen.height - arrowSize - 10)).toDouble();

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      left: clampedLeft,
      top: clampedTop,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _bobController,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_bobController.value);
            return Transform.translate(
              offset: Offset(bobAxis.dx * t, bobAxis.dy * t),
              child: child,
            );
          },
          child: Transform.rotate(
            angle: rotation,
            child: Image.asset(
              'assets/ui/GenericArrow.png',
              width: arrowSize,
              height: arrowSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizardDialogueBar({
    required WalkthroughStep step,
    required bool showNextButton,
  }) {
    final stepNum = widget.game.walkthroughStepIndex + 1;
    final total = widget.game.walkthroughTotalSteps;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomLeft,
      children: [
        // Main Wooden/Parchment Speech Card
        Container(
          margin: const EdgeInsets.only(left: 72, top: 20),
          padding: const EdgeInsets.fromLTRB(96, 18, 22, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7), Color(0xFFFDE68A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF78350F), width: 4.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x66FBBF24),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title + Step Counter + Skip
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFFBBF24), width: 1.8),
                    ),
                    child: Text(
                      step.title,
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontFamily: 'Lilita One',
                        fontSize: 16,
                        letterSpacing: 0.7,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x26B45309),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'STEP $stepNum / $total',
                      style: const TextStyle(
                        color: Color(0xFF78350F),
                        fontFamily: 'Lilita One',
                        fontSize: 12.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const Spacer(),
                  HoverScale(
                    scale: 1.08,
                    onTap: widget.game.skipWalkthrough,
                    tooltip: 'Skip Tutorial',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x2678350F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0x8078350F), width: 1.3),
                      ),
                      child: const Text(
                        'SKIP',
                        style: TextStyle(
                          color: Color(0xFF78350F),
                          fontFamily: 'Lilita One',
                          fontSize: 12.5,
                          letterSpacing: 0.7,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Dialogue Message + Action CTA
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      step.message,
                      style: const TextStyle(
                        color: Color(0xFF3B1404),
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        height: 1.35,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (showNextButton) ...[
                    const SizedBox(width: 16),
                    _buildPrimaryCtaButton(
                      label: step.ctaLabel ?? 'NEXT',
                      onTap: widget.game.advanceWalkthrough,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // Merlin the Dog Wizard Mascot overlapping left side of the card
        Positioned(
          left: -4,
          bottom: -8,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _bobController,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_bobController.value);
                return Transform.translate(
                  offset: Offset(0, -5 * t),
                  child: child,
                );
              },
              child: Transform.flip(
                flipX: true,
                child: Image.asset(
                  'assets/ui/DogWizard.png',
                  width: 158,
                  height: 174,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _personalizedMessage(WalkthroughStep step) {
    final name = widget.game.playerUsername;
    if (name.isEmpty) return step.message;
    if (step.id == WalkthroughStepId.welcome) {
      return step.message.replaceFirst('Keeper', name);
    }
    return step.message;
  }

  Widget _buildCenterModal(
    BuildContext context,
    WalkthroughStep step,
    Size screenSize,
  ) {
    final isGraduation = step.id == WalkthroughStepId.graduation;
    final showGiftPreview =
        isGraduation && !widget.game.walkthroughRewardClaimed;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.92, end: 1.0),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Modal Card
                Container(
                  margin: const EdgeInsets.only(top: 86),
                  padding: const EdgeInsets.fromLTRB(32, 102, 32, 28),
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
                    borderRadius: BorderRadius.circular(30),
                    border:
                        Border.all(color: const Color(0xFF78350F), width: 4.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xCC000000),
                        blurRadius: 36,
                        offset: Offset(0, 16),
                      ),
                      BoxShadow(
                        color: Color(0x66FBBF24),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title ribbon
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: const Color(0xFFFBBF24), width: 2.2),
                        ),
                        child: Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFEF08A),
                            fontFamily: 'Lilita One',
                            fontSize: 23,
                            letterSpacing: 0.9,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Message
                      Text(
                        _personalizedMessage(step),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF3B1404),
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w700,
                          fontSize: 17.5,
                          height: 1.42,
                          decoration: TextDecoration.none,
                        ),
                      ),

                      // Starter Gift Rewards on Graduation step
                      if (showGiftPreview) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0x24B45309),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFD97706), width: 1.6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildRewardChip(
                                  'assets/ui/coins.png', '+500 Coins'),
                              const SizedBox(width: 16),
                              _buildRewardChip(
                                  'assets/ui/diamonds.png', '+5 Crystals'),
                              const SizedBox(width: 16),
                              _buildRewardChip(
                                  'assets/ui/icon_star.png', '+100 XP'),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isGraduation) ...[
                            HoverScale(
                              scale: 1.05,
                              onTap: widget.game.skipWalkthrough,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0x2678350F),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFF92400E),
                                      width: 1.5),
                                ),
                                child: const Text(
                                  'SKIP TUTORIAL',
                                  style: TextStyle(
                                    color: Color(0xFF78350F),
                                    fontFamily: 'Lilita One',
                                    fontSize: 14.5,
                                    letterSpacing: 0.6,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                          ],
                          _buildPrimaryCtaButton(
                            label: isGraduation && !showGiftPreview
                                ? 'FINISH TOUR'
                                : (step.ctaLabel ?? 'CONTINUE'),
                            large: true,
                            onTap: widget.game.advanceWalkthrough,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Floating Merlin the Dog Wizard on top of the modal
                Positioned(
                  top: -22,
                  child: AnimatedBuilder(
                    animation: _bobController,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_bobController.value);
                      return Transform.translate(
                        offset: Offset(0, -7 * t),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/ui/DogWizard.png',
                      width: 196,
                      height: 200,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),

                // Top-right close/skip button
                if (!isGraduation)
                  Positioned(
                    top: 74,
                    right: -10,
                    child: HoverScale(
                      scale: 1.12,
                      onTap: widget.game.skipWalkthrough,
                      tooltip: 'Skip Tutorial',
                      child: Image.asset(
                        'assets/TrioUIKit_FreeSample_v2.2/png/1x/cozy/close_button.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardChip(String assetPath, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(assetPath, width: 24, height: 24, fit: BoxFit.contain),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3B1404),
            fontFamily: 'Lilita One',
            fontSize: 14.5,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryCtaButton({
    required String label,
    required VoidCallback onTap,
    bool large = false,
  }) {
    return HoverScale(
      scale: 1.06,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 28 : 20,
          vertical: large ? 13 : 10,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34D399), Color(0xFF059669)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFEF08A), width: 2.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66064E3B),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Lilita One',
            fontSize: large ? 17.5 : 15.5,
            letterSpacing: 0.8,
            decoration: TextDecoration.none,
            shadows: const [
              Shadow(
                color: Color(0x80000000),
                offset: Offset(0, 1.5),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteMismatchBanner(WalkthroughStep step) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xEE2A1205),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFBBF24), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/ui/DogWizard.png', width: 44, height: 44),
              const SizedBox(width: 12),
              const Text(
                'Return to the island to continue your Dog Wizard tour!',
                style: TextStyle(
                  color: Color(0xFFFEF3C7),
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(width: 14),
              _buildPrimaryCtaButton(
                label: 'GO BACK',
                onTap: widget.onReturnToWorld,
              ),
              const SizedBox(width: 10),
              HoverScale(
                scale: 1.08,
                onTap: widget.game.skipWalkthrough,
                child: const Text(
                  'SKIP',
                  style: TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Lilita One',
                    fontSize: 13,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? spotlightRect;

  _SpotlightPainter({required this.spotlightRect});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.72)
      ..style = PaintingStyle.fill;

    if (spotlightRect == null) {
      canvas.drawRect(fullRect, overlayPaint);
      return;
    }

    final holeRRect = RRect.fromRectAndRadius(
      spotlightRect!,
      const Radius.circular(24),
    );

    // PathFillType.evenOdd reliably punches a 100% transparent natural-color hole
    // across all Flutter renderers (Web CanvasKit/HTML, Windows, Android, iOS)
    final cutoutPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(fullRect)
      ..addRRect(holeRRect);

    canvas.drawPath(cutoutPath, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect;
  }
}
