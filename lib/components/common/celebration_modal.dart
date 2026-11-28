import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/celebration_event.dart';
import '../../services/audio_service.dart';
import 'hover_scale.dart';

class CelebrationModal extends StatefulWidget {
  final CelebrationEvent event;
  final VoidCallback onDismiss;

  const CelebrationModal({
    super.key,
    required this.event,
    required this.onDismiss,
  });

  @override
  State<CelebrationModal> createState() => _CelebrationModalState();
}

class _CelebrationModalState extends State<CelebrationModal>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _raysController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
    _raysController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CelebrationModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event != widget.event) {
      _entryController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _raysController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    SoundManager.instance.playClick();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.height < 520 || screenSize.width < 560;
    final cardMaxW = isCompact ? min(440.0, screenSize.width - 28) : 500.0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Dark radial backdrop
          GestureDetector(
            onTap: _handleDismiss,
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xB31E0B02), Color(0xE6090301)],
                  radius: 1.0,
                ),
              ),
            ),
          ),

          // Rotating golden sunburst + floating sparkles behind the card
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_raysController, _entryController]),
                builder: (context, _) {
                  final entry =
                      Curves.easeOut.transform(_entryController.value);
                  return Opacity(
                    opacity: entry,
                    child: CustomPaint(
                      size: Size(
                        min(screenSize.width, 640),
                        min(screenSize.height, 640),
                      ),
                      painter: _SunburstAndSparklesPainter(
                        rotation: _raysController.value * 2 * pi,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Main celebration card
          Center(
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (context, child) {
                final scale =
                    Curves.easeOutBack.transform(_entryController.value);
                final opacity =
                    Curves.easeOut.transform(_entryController.value).clamp(0.0, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cardMaxW,
                  maxHeight: screenSize.height * 0.90,
                ),
                child: switch (widget.event) {
                  DogEvolutionCelebration evo =>
                    _buildEvolutionCard(evo, isCompact),
                  PlayerLevelUpCelebration lvl =>
                    _buildLevelUpCard(lvl, isCompact),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardShell({
    required String bannerTitle,
    required Color bannerStart,
    required Color bannerEnd,
    required Widget body,
    required bool isCompact,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: isCompact ? 18 : 24),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 24,
            isCompact ? 34 : 42,
            isCompact ? 16 : 24,
            isCompact ? 16 : 22,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF78350F), width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 32,
                offset: Offset(0, 14),
              ),
              BoxShadow(
                color: Color(0x88FBBF24),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: isCompact ? 250 : 350),
                  child: Center(child: body),
                ),
                SizedBox(height: isCompact ? 14 : 18),
                HoverScale(
                  scale: 1.06,
                  onTap: _handleDismiss,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 32 : 42,
                      vertical: isCompact ? 10 : 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF047857)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFFEF08A),
                        width: 2.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'AWESOME!',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: isCompact ? 16 : 19,
                        letterSpacing: 1.0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top Celebration Ribbon
        Positioned(
          top: 0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 22 : 30,
              vertical: isCompact ? 7 : 9,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bannerStart, bannerEnd],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFEF08A), width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              bannerTitle,
              style: TextStyle(
                color: const Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: isCompact ? 18 : 22,
                letterSpacing: 1.2,
                decoration: TextDecoration.none,
                shadows: const [
                  Shadow(
                    color: Color(0xAA000000),
                    offset: Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvolutionCard(DogEvolutionCelebration evo, bool isCompact) {
    final artSize = isCompact ? 116.0 : 156.0;
    return _buildCardShell(
      bannerTitle: 'EVOLUTION!',
      bannerStart: const Color(0xFFD97706),
      bannerEnd: const Color(0xFF92400E),
      isCompact: isCompact,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF3B1404),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
            ),
            child: Text(
              '${evo.previousStage.toUpperCase()}  \u2192  ${evo.newStageLabel.toUpperCase()}',
              style: TextStyle(
                color: const Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: isCompact ? 12 : 13.5,
                letterSpacing: 0.8,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          SizedBox(height: isCompact ? 10 : 14),

          // Glowing floating evolved dog sprite
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_floatController.value);
              return Transform.translate(
                offset: Offset(0, -7 * t),
                child: child,
              );
            },
            child: Container(
              width: artSize + 24,
              height: artSize + 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFFFDE047),
                    Color(0x66F59E0B),
                    Color(0x00F59E0B),
                  ],
                ),
              ),
              child: Center(
                child: Image.asset(
                  evo.sitImg,
                  width: artSize,
                  height: artSize,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 6 : 10),

          Text(
            evo.dogName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF3B1404),
              fontFamily: 'Lilita One',
              fontSize: isCompact ? 20 : 24,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'Lv. ${evo.level} ${evo.newStageLabel} ${evo.breedName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF92400E),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w800,
              fontSize: isCompact ? 13 : 14.5,
              decoration: TextDecoration.none,
            ),
          ),
          if (evo.lore.isNotEmpty) ...[
            SizedBox(height: isCompact ? 8 : 10),
            Text(
              evo.lore,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF451A03),
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
                fontSize: isCompact ? 12.5 : 13.5,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          SizedBox(height: isCompact ? 10 : 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD97706), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 6),
                Text(
                  '+${evo.coinRatePerMin} Coins / min',
                  style: const TextStyle(
                    color: Color(0xFF78350F),
                    fontFamily: 'Lilita One',
                    fontSize: 13.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelUpCard(PlayerLevelUpCelebration lvl, bool isCompact) {
    return _buildCardShell(
      bannerTitle: 'LEVEL UP!',
      bannerStart: const Color(0xFF0F766E),
      bannerEnd: const Color(0xFF115E59),
      isCompact: isCompact,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Big Star Level Badge
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_floatController.value);
              return Transform.translate(
                offset: Offset(0, -5 * t),
                child: child,
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 18 : 24,
                vertical: isCompact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF78350F), width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFFEF08A), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'KEEPER LEVEL ${lvl.newLevel}',
                    style: TextStyle(
                      color: const Color(0xFF3B1404),
                      fontFamily: 'Lilita One',
                      fontSize: isCompact ? 18 : 22,
                      letterSpacing: 0.8,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isCompact ? 10 : 14),

          if (lvl.milestone != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981), width: 1.8),
              ),
              child: Column(
                children: [
                  Text(
                    'MILESTONE REACHED: ${lvl.milestone!.title.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF065F46),
                      fontFamily: 'Lilita One',
                      fontSize: 13,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Claim your bonus reward in the Progress menu!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (lvl.unlockedItems.isNotEmpty) ...[
            Text(
              'NEW ITEMS UNLOCKED IN SHOP!',
              style: TextStyle(
                color: const Color(0xFF78350F),
                fontFamily: 'Lilita One',
                fontSize: isCompact ? 13.5 : 15,
                letterSpacing: 0.6,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: isCompact ? 8 : 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: lvl.unlockedItems
                  .map((item) => _buildUnlockTile(item, isCompact))
                  .toList(),
            ),
          ] else
            Text(
              'Your sanctuary is growing stronger! Keep feeding, caring, and building to unlock new breeds and islands.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF451A03),
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
                fontSize: isCompact ? 13 : 14,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnlockTile(CelebrationUnlockItem item, bool isCompact) {
    final tileW = isCompact ? 112.0 : 126.0;
    return Container(
      width: tileW,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.accentColor, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: item.accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.category,
              style: TextStyle(
                color: item.accentColor,
                fontFamily: 'Lilita One',
                fontSize: 9.5,
                letterSpacing: 0.4,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Image.asset(
            item.imageAsset,
            width: isCompact ? 48 : 58,
            height: isCompact ? 48 : 58,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Icon(
              Icons.auto_awesome_rounded,
              color: item.accentColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF3B1404),
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
              height: 1.15,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _SunburstAndSparklesPainter extends CustomPainter {
  final double rotation;

  _SunburstAndSparklesPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.52;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    const rayCount = 14;
    final rayPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0x66FEF08A),
          Color(0x1AFBBF24),
          Color(0x00FBBF24),
        ],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));

    for (int i = 0; i < rayCount; i++) {
      final startAngle = (i * 2 * pi) / rayCount;
      const sweep = pi / rayCount;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(cos(startAngle) * radius, sin(startAngle) * radius)
        ..lineTo(
          cos(startAngle + sweep) * radius,
          sin(startAngle + sweep) * radius,
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }
    canvas.restore();

    // Floating celebratory stars around the sunburst
    final starColors = [
      const Color(0xFFFEF08A),
      const Color(0xFF34D399),
      const Color(0xFF38BDF8),
      const Color(0xFFF472B6),
    ];
    for (int i = 0; i < 16; i++) {
      final angle = rotation * (i.isEven ? 1.3 : -0.9) + (i * pi / 8);
      final dist = radius * (0.58 + 0.25 * sin(rotation * 2 + i));
      final pos = Offset(
        center.dx + cos(angle) * dist,
        center.dy + sin(angle) * dist,
      );
      final paint = Paint()
        ..color = starColors[i % starColors.length].withValues(alpha: 0.78);
      canvas.drawCircle(pos, 3.0 + (i % 3) * 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunburstAndSparklesPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}
