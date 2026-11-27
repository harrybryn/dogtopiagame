import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/audio_service.dart';

class GenericModal extends StatelessWidget {
  final String title;
  final Widget? titleExtra;
  final Widget child;
  final VoidCallback onClose;
  final double maxWidth;
  final bool highlightClose;

  /// Wrap the body in a vertical scroll view. Use this for fixed-height
  /// content that could overflow on short screens.
  final bool scrollable;

  const GenericModal({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.titleExtra,
    this.maxWidth = 720,
    this.highlightClose = false,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final maxAllowedW = (screenSize.width - 32).clamp(280.0, maxWidth);
    final maxAllowedH = screenSize.height * 0.92;

    // Maintain native GenericModal.png aspect ratio (1402 : 1122 ≈ 1.25 : 1)
    double modalW = maxAllowedW;
    double modalH = modalW * (1122.0 / 1402.0);
    if (modalH > maxAllowedH) {
      modalH = maxAllowedH;
      modalW = modalH * (1402.0 / 1122.0);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: SizedBox(
          width: modalW,
          height: modalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Background frame (Handcrafted GenericModal.png) ──
              Positioned.fill(
                child: Image.asset(
                  'assets/ui/GenericModal.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),

              // Title placed inside the top wooden banner
              Positioned(
                left: modalW * 0.20,
                right: modalW * 0.20,
                top: modalH * 0.065,
                height: modalH * 0.145,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Lilita One',
                            fontSize: (modalW * 0.038).clamp(15.0, 24.0),
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF3B1404),
                            letterSpacing: 0.8,
                            shadows: const [
                              Shadow(
                                color: Color(0xF2FFFFFF),
                                offset: Offset(0, 1.5),
                                blurRadius: 1,
                              ),
                              Shadow(
                                color: Color(0x40000000),
                                offset: Offset(0, -0.5),
                                blurRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (titleExtra != null) ...[
                        const SizedBox(width: 8),
                        titleExtra!,
                      ],
                    ],
                  ),
                ),
              ),

              // Inner content area inside the parchment frame — bounded for ListViews and scrolls
              Positioned(
                left: modalW * 0.12,
                right: modalW * 0.12,
                top: modalH * 0.225,
                bottom: modalH * 0.12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: scrollable
                        ? SingleChildScrollView(child: child)
                        : child,
                  ),
                ),
              ),

              // Close (X) Button placed last in Stack so it is always on top of content
              Positioned(
                left: modalW * 0.815,
                top: modalH * 0.068,
                width: modalW * 0.11,
                height: modalW * 0.11,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => SoundManager.instance.playHover(),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        SoundManager.instance.playClick();
                        onClose();
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),

              if (highlightClose) ...[
                if ((screenSize.width - modalW) / 2 >= 50)
                  Positioned(
                    left: modalW * (0.815 + 0.11) + 6,
                    top: modalH * 0.068 + (modalW * 0.11 - 72) / 2,
                    child: const _BouncingExitArrow(horizontal: true),
                  )
                else
                  Positioned(
                    left: modalW * 0.815 + (modalW * 0.11 - 72) / 2,
                    top: modalH * 0.068 - 72 - 4,
                    child: const _BouncingExitArrow(horizontal: false),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BouncingExitArrow extends StatefulWidget {
  final bool horizontal;

  const _BouncingExitArrow({required this.horizontal});

  @override
  State<_BouncingExitArrow> createState() => _BouncingExitArrowState();
}

class _BouncingExitArrowState extends State<_BouncingExitArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Transform.translate(
            offset: widget.horizontal ? Offset(12 * t, 0) : Offset(0, -12 * t),
            child: child,
          );
        },
        child: Transform.rotate(
          angle: widget.horizontal ? pi / 2 : 0.0,
          child: Image.asset(
            'assets/ui/GenericArrow.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
