import 'package:flutter/material.dart';

class GenericModal extends StatelessWidget {
  final String title;
  final Widget? titleExtra;
  final Widget child;
  final VoidCallback onClose;
  final double maxWidth;

  const GenericModal({
    super.key,
    required this.title,
    required this.onClose,
    required this.child,
    this.titleExtra,
    this.maxWidth = 720,
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

              // Close (X) Button positioned exactly over the red 'X' in GenericModal.png
              Positioned(
                left: modalW * 0.825,
                top: modalH * 0.08,
                width: modalW * 0.09,
                height: modalW * 0.09,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onClose,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),

              // Inner content area inside the parchment frame — bounded for ListViews and scrolls
              Positioned(
                left: modalW * 0.145,
                right: modalW * 0.145,
                top: modalH * 0.235,
                bottom: modalH * 0.085,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: child,
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
