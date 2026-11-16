import 'package:flutter/material.dart';

/// LoadingProgressBar
/// A Flutter CustomPainter reproduction of the game loading bar:
/// - Golden capsule frame with dark carved woodgrain track
/// - Left circular medallion with metallic gold rim and embossed paw print
/// - Glowing radiant gold energy fill that advances with [progress]
/// - Shimmer sweep animation and specular reflections
class LoadingProgressBar extends StatefulWidget {
  /// Progress value from 0.0 to 100.0
  final double progress;

  const LoadingProgressBar({super.key, this.progress = 0});

  @override
  State<LoadingProgressBar> createState() => _LoadingProgressBarState();
}

class _LoadingProgressBarState extends State<LoadingProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        return AspectRatio(
          aspectRatio: 540 / 68,
          child: CustomPaint(
            painter: _ProgressBarPainter(
              progress: widget.progress.clamp(0.0, 100.0),
              shimmerOffset: _shimmerController.value,
            ),
          ),
        );
      },
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  final double progress;
  final double shimmerOffset;

  _ProgressBarPainter({required this.progress, required this.shimmerOffset});

  // Scale from SVG viewBox (540x68) to canvas size
  double sx(double x, Size size) => x * size.width / 540;
  double sy(double y, Size size) => y * size.height / 68;

  @override
  void paint(Canvas canvas, Size size) {
    _drawTrackBackplate(canvas, size);
    _drawWoodGrainDetails(canvas, size);
    _drawProgressFill(canvas, size);
    _drawTrackFrameOverlay(canvas, size);
    _drawMedallion(canvas, size);
  }

  void _drawTrackBackplate(Canvas canvas, Size size) {
    // Outer gold capsule border
    final goldTrackGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFfef08a),
        Color(0xFFf59e0b),
        Color(0xFFd97706),
        Color(0xFF451a03),
      ],
      stops: const [0.0, 0.15, 0.85, 1.0],
    );

    final trackPath = Path()
      ..moveTo(sx(34, size), sy(11, size))
      ..lineTo(sx(507, size), sy(11, size))
      ..arcToPoint(
        Offset(sx(507, size), sy(57, size)),
        radius: Radius.elliptical(sx(23, size), sy(23, size)),
        clockwise: true,
      )
      ..lineTo(sx(34, size), sy(57, size))
      ..close();

    final goldPaint = Paint()
      ..shader = goldTrackGradient.createShader(
          Rect.fromLTWH(0, sy(11, size), size.width, sy(46, size)));
    canvas.drawPath(trackPath, goldPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF301202)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sx(2.5, size);
    canvas.drawPath(trackPath, borderPaint);

    // Inner wooden track bed
    final woodGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFF190701),
        Color(0xFF2d1306),
        Color(0xFF421a08),
        Color(0xFF4a1e0a),
        Color(0xFF3d1807),
        Color(0xFF260e04),
        Color(0xFF140501),
      ],
      stops: const [0.0, 0.08, 0.30, 0.50, 0.70, 0.92, 1.0],
    );

    final innerPath = Path()
      ..moveTo(sx(36, size), sy(14.5, size))
      ..lineTo(sx(507, size), sy(14.5, size))
      ..arcToPoint(
        Offset(sx(507, size), sy(53.5, size)),
        radius: Radius.elliptical(sx(19.5, size), sy(19.5, size)),
        clockwise: true,
      )
      ..lineTo(sx(36, size), sy(53.5, size))
      ..close();

    final woodPaint = Paint()
      ..shader = woodGradient.createShader(
          Rect.fromLTWH(0, sy(14.5, size), size.width, sy(39, size)));
    canvas.drawPath(innerPath, woodPaint);
  }

  void _drawWoodGrainDetails(Canvas canvas, Size size) {
    final clipPath = Path()
      ..moveTo(sx(44, size), sy(15, size))
      ..lineTo(sx(507, size), sy(15, size))
      ..arcToPoint(
        Offset(sx(507, size), sy(53, size)),
        radius: Radius.elliptical(sx(19, size), sy(19, size)),
        clockwise: true,
      )
      ..lineTo(sx(44, size), sy(53, size))
      ..close();

    canvas.save();
    canvas.clipPath(clipPath);

    final lines = [
      (20.0, const Color(0xFF5a270d), 1.2, 0.4),
      (26.0, const Color(0xFF1d0902), 1.5, 0.5),
      (34.0, const Color(0xFF52240c), 1.2, 0.35),
      (40.0, const Color(0xFF180701), 1.8, 0.6),
      (46.0, const Color(0xFF481e09), 1.2, 0.4),
    ];

    for (final (y, color, width, opacity) in lines) {
      canvas.drawLine(
        Offset(sx(40, size), sy(y, size)),
        Offset(sx(525, size), sy(y, size)),
        Paint()
          ..color = color.withOpacity(opacity)
          ..strokeWidth = sy(width, size),
      );
    }

    // Carved top recessed depth shadow
    canvas.drawRect(
      Rect.fromLTWH(sx(36, size), sy(14, size), sx(500, size), sy(9, size)),
      Paint()..color = Colors.black.withOpacity(0.75),
    );
    canvas.drawRect(
      Rect.fromLTWH(sx(36, size), sy(14, size), sx(500, size), sy(4, size)),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    // Bottom shadow
    canvas.drawRect(
      Rect.fromLTWH(sx(36, size), sy(49, size), sx(500, size), sy(5, size)),
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    canvas.restore();
  }

  void _drawProgressFill(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final clipPath = Path()
      ..moveTo(sx(44, size), sy(15, size))
      ..lineTo(sx(507, size), sy(15, size))
      ..arcToPoint(
        Offset(sx(507, size), sy(53, size)),
        radius: Radius.elliptical(sx(19, size), sy(19, size)),
        clockwise: true,
      )
      ..lineTo(sx(44, size), sy(53, size))
      ..close();

    canvas.save();
    canvas.clipPath(clipPath);

    final maxFillWidth = sx(468, size);
    final fillWidth = (progress / 100) * maxFillWidth;
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(sx(42, size), sy(16.5, size), fillWidth, sy(35, size)),
      Radius.circular(sy(17.5, size)),
    );

    // Glow effect
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..color = const Color(0xFFf59e0b).withOpacity(0.85);
    canvas.drawRRect(fillRect, glowPaint);

    // Main fill gradient
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFffffff),
        Color(0xFFfef08a),
        Color(0xFFfbbf24),
        Color(0xFFf59e0b),
        Color(0xFFb45309),
      ],
      stops: const [0.0, 0.12, 0.45, 0.75, 1.0],
    );
    canvas.drawRRect(
      fillRect,
      Paint()
        ..shader = fillGradient.createShader(
            Rect.fromLTWH(sx(42, size), sy(16.5, size), fillWidth, sy(35, size))),
    );

    // Top glossy highlight
    final highlightWidth = (fillWidth - sx(4, size)).clamp(0.0, double.infinity);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sx(44, size), sy(18, size), highlightWidth, sy(15, size)),
        Radius.circular(sy(7.5, size)),
      ),
      Paint()..color = Colors.white.withOpacity(0.4),
    );

    // Bottom tone shade
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(sx(44, size), sy(45, size), highlightWidth, sy(5, size)),
        Radius.circular(sy(2.5, size)),
      ),
      Paint()..color = const Color(0xFF78350f).withOpacity(0.4),
    );

    // Animated shimmer sweep
    final shimmerX = sx(42, size) + (shimmerOffset * 3 - 1) * fillWidth;
    final shimmerGradient = LinearGradient(
      colors: [
        Colors.white.withOpacity(0),
        Colors.white.withOpacity(0.45),
        Colors.white.withOpacity(0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawRRect(
      fillRect,
      Paint()
        ..shader = shimmerGradient.createShader(
            Rect.fromLTWH(shimmerX, sy(16.5, size), fillWidth * 0.5, sy(35, size))),
    );

    canvas.restore();
  }

  void _drawTrackFrameOverlay(Canvas canvas, Size size) {
    // Top gold highlight line
    canvas.drawLine(
      Offset(sx(34, size), sy(12.5, size)),
      Offset(sx(507, size), sy(12.5, size)),
      Paint()
        ..color = const Color(0xFFfffbeb).withOpacity(0.85)
        ..strokeWidth = sy(1.2, size)
        ..strokeCap = StrokeCap.round,
    );
    // Bottom dark shadow line
    canvas.drawLine(
      Offset(sx(34, size), sy(56, size)),
      Offset(sx(507, size), sy(56, size)),
      Paint()
        ..color = const Color(0xFF381503).withOpacity(0.9)
        ..strokeWidth = sy(1.5, size),
    );
  }

  void _drawMedallion(Canvas canvas, Size size) {
    final cx = sx(34, size);
    final cy = sy(34, size);

    // Outer shadow
    canvas.drawCircle(
      Offset(cx, cy),
      sx(31.5, size),
      Paint()..color = const Color(0xFF100401).withOpacity(0.55),
    );

    // Outer gold rim bevel
    final goldRimGradient = RadialGradient(
      center: const Alignment(-0.3, -0.4),
      radius: 1.0,
      colors: const [
        Color(0xFFfffbeb),
        Color(0xFFfef08a),
        Color(0xFFf59e0b),
        Color(0xFFb45309),
        Color(0xFF78350f),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    final rimRect = Rect.fromCircle(center: Offset(cx, cy), radius: sx(30, size));
    canvas.drawCircle(
      Offset(cx, cy),
      sx(30, size),
      Paint()..shader = goldRimGradient.createShader(rimRect),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      sx(30, size),
      Paint()
        ..color = const Color(0xFF381503)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sx(1.8, size),
    );

    // Dark recessed groove
    canvas.drawCircle(
      Offset(cx, cy),
      sx(24.5, size),
      Paint()
        ..color = const Color(0xFF240c02)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sx(2, size),
    );

    // Inner gold raised ring
    canvas.drawCircle(
      Offset(cx, cy),
      sx(22.5, size),
      Paint()
        ..shader = goldRimGradient.createShader(rimRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sx(2.5, size),
    );

    // Dark wood inlay face
    final woodMedallionGradient = RadialGradient(
      center: const Alignment(-0.24, -0.3),
      radius: 0.62,
      colors: const [
        Color(0xFF4d220b),
        Color(0xFF2d1205),
        Color(0xFF140501),
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final medallionRect =
        Rect.fromCircle(center: Offset(cx, cy), radius: sx(20, size));
    canvas.drawCircle(
      Offset(cx, cy),
      sx(20, size),
      Paint()..shader = woodMedallionGradient.createShader(medallionRect),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      sx(20, size),
      Paint()
        ..color = const Color(0xFF1a0802)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sx(1, size),
    );

    // Inner face shadow ring
    canvas.drawCircle(
      Offset(cx, cy),
      sx(19, size),
      Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sx(2, size),
    );

    // Paw print
    _drawPawPrint(canvas, size, cx, cy);

    // Specular glint on outer rim
    canvas.save();
    canvas.translate(sx(21, size), sy(17, size));
    canvas.rotate(-42 * 3.14159 / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: sx(9, size), height: sy(4.4, size)),
      Paint()..color = Colors.white.withOpacity(0.55),
    );
    canvas.restore();
  }

  void _drawPawPrint(Canvas canvas, Size size, double cx, double cy) {
    final pawGoldGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Color(0xFFfffbeb),
        Color(0xFFfef08a),
        Color(0xFFf59e0b),
        Color(0xFFd97706),
        Color(0xFF92400e),
      ],
      stops: const [0.0, 0.25, 0.60, 0.85, 1.0],
    );

    final pawRect = Rect.fromLTWH(sx(22, size), sy(22, size), sx(26, size), sy(24, size));

    // Shadow paint
    final shadowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
      ..color = const Color(0xFF120501).withOpacity(0.85);

    final strokePaint = Paint()
      ..color = const Color(0xFF92400e)
      ..style = PaintingStyle.stroke
      ..strokeWidth = sx(0.7, size);

    // Main center pad
    final padPath = Path()
      ..moveTo(sx(34, size), sy(31.8, size))
      ..cubicTo(sx(37.2, size), sy(30.5, size), sx(40.2, size), sy(32, size),
          sx(41, size), sy(35, size))
      ..cubicTo(sx(41.8, size), sy(37.8, size), sx(40, size), sy(41.4, size),
          sx(37.4, size), sy(43.2, size))
      ..cubicTo(sx(35.3, size), sy(44.6, size), sx(32.7, size), sy(44.6, size),
          sx(30.6, size), sy(43.2, size))
      ..cubicTo(sx(28, size), sy(41.4, size), sx(26.2, size), sy(37.8, size),
          sx(27, size), sy(35, size))
      ..cubicTo(sx(27.8, size), sy(32, size), sx(30.8, size), sy(30.5, size),
          sx(34, size), sy(31.8, size))
      ..close();

    canvas.drawPath(padPath, shadowPaint);
    canvas.drawPath(padPath, Paint()..shader = pawGoldGradient.createShader(pawRect));
    canvas.drawPath(padPath, strokePaint);

    // Main pad highlight
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(sx(34, size), sy(33.8, size)),
          width: sx(7, size),
          height: sy(3.6, size)),
      Paint()..color = Colors.white.withOpacity(0.4),
    );

    // Helper to draw a toe
    void drawToe(double ecx, double ecy, double erx, double ery, double angleDeg,
        double hlcx, double hlcy, double hlrx, double hlry) {
      final angle = angleDeg * 3.14159 / 180;
      canvas.save();
      canvas.translate(sx(ecx, size), sy(ecy, size));
      canvas.rotate(angle);
      final toeRect = Rect.fromCenter(
          center: Offset.zero, width: sx(erx * 2, size), height: sy(ery * 2, size));
      canvas.drawOval(toeRect,
          Paint()..shader = pawGoldGradient.createShader(pawRect));
      canvas.drawOval(toeRect, strokePaint..strokeWidth = sx(0.6, size));
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, sy(hlcy - ecy, size)),
              width: sx(hlrx * 2, size),
              height: sy(hlry * 2, size)),
          Paint()..color = Colors.white.withOpacity(0.4));
      canvas.restore();
    }

    drawToe(23, 30.5, 2.5, 3.8, -30, 23, 29.2, 1.2, 1.8);
    drawToe(29.5, 25, 2.8, 4.2, -12, 29.5, 23.5, 1.3, 2.0);
    drawToe(38.5, 25, 2.8, 4.2, 12, 38.5, 23.5, 1.3, 2.0);
    drawToe(45, 30.5, 2.5, 3.8, 30, 45, 29.2, 1.2, 1.8);
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.shimmerOffset != shimmerOffset;
  }
}
