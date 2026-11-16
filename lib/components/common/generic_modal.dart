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
    this.maxWidth = 660,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final availableW = (screenSize.width - 32).clamp(280.0, maxWidth);
    final targetH = availableW * (447.0 / 558.0);
    final maxH = screenSize.height * 0.92;
    final modalH = targetH > maxH ? maxH : targetH;
    final modalW = modalH * (558.0 / 447.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: SizedBox(
          width: modalW,
          height: modalH,
          child: Stack(
            children: [
              // Handcrafted GenericModal.png Frame
              Positioned.fill(
                child: Image.asset(
                  'assets/ui/GenericModal.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),

              // Title placed directly inside the top wooden banner
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

              // Top-Right Red (X) Close Button Overlay (over illustrated button on asset)
              Positioned(
                left: modalW * 0.825,
                top: modalH * 0.125,
                width: modalW * 0.085,
                height: modalH * 0.11,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
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

              // Inner Parchment Scrollable Content Area (Accurately bounded to avoid frame overlap)
              Positioned(
                left: modalW * 0.145,
                right: modalW * 0.145,
                top: modalH * 0.255,
                bottom: modalH * 0.125,
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
