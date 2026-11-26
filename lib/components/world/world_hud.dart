import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../state/game_controller.dart';
import '../../models/habitat_model.dart';
import '../../models/habitat_catalog.dart';
import '../../models/dog_model.dart';
import '../../models/dog_evolution.dart';
import '../common/hover_scale.dart';
import '../../models/walkthrough_step.dart';
import '../../services/social_service.dart';

class WorldHUD extends StatelessWidget {
  final GameController game;
  final Map<String, GlobalKey>? walkthroughKeys;
  final VoidCallback onOpenBuild;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenSocial;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenInbox;
  final VoidCallback onOpenBreeding;
  final VoidCallback onOpenCollection;
  final void Function(HabitatModel hab, [int dogIndex]) onOpenHabitatCare;
  final Function(HabitatModel) onStartMoveHabitat;
  final Function(HabitatModel) onOpenHabitatInfo;
  final VoidCallback onDeselectHabitat;
  final VoidCallback? onOpenIslands;

  const WorldHUD({
    super.key,
    required this.game,
    this.walkthroughKeys,
    required this.onOpenBuild,
    required this.onOpenGoals,
    required this.onOpenProgress,
    required this.onOpenSocial,
    required this.onOpenRanking,
    required this.onOpenSettings,
    this.onOpenInbox,
    required this.onOpenBreeding,
    required this.onOpenCollection,
    required this.onOpenHabitatCare,
    required this.onStartMoveHabitat,
    required this.onOpenHabitatInfo,
    required this.onDeselectHabitat,
    this.onOpenIslands,
  });

  String _fmt(int n) => GameController.formatCoins(n);

  String _fmtXp(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 10000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final selectedHab = game.selectedHabitat;
    final xpPercent = ((game.xp / game.maxXp) * 100).clamp(4.0, 100.0);

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final screenH = media.size.height;
    final isCompact = screenW < 880;
    final isShort = screenH < 620;

    final scale = (screenW / 1100).clamp(0.65, 1.0);
    // Shrink the top bar a little on short windows so the side badges keep room.
    final heightScale = (screenH / 620).clamp(0.72, 1.0);
    final xpBarH = isCompact
        ? ((screenW < 400 ? 44.0 : 52.0) * heightScale).clamp(38.0, 52.0)
        : (78.0 * scale * heightScale).clamp(52.0, 78.0);
    final xpBarW = xpBarH * (866.0 / 288.0);

    final pillW = isCompact
        ? 112.0
        : (174.0 * scale).clamp(105.0, 174.0);
    final pillH = pillW * (56.0 / 174.0);

    final settingsSize = isCompact
        ? (screenW < 400 ? 40.0 : 46.0)
        : (56.0 * scale).clamp(44.0, 56.0);

    // The Goals/Progress/Social stack must always fit between the top bar and
    // the bottom edge, no matter how short the window is.
    final badgeTop = isCompact ? (xpBarH + 18) : 104.0;
    final availableBadgeH = screenH - badgeTop - 16;
    final fitBadgeScale = ((availableBadgeH - 16) / (3 * 124)).clamp(0.38, 1.0);
    final preferredBadgeScale = isCompact
        ? (screenW < 450 ? 0.54 : 0.58)
        : (isShort ? 0.75 : scale.clamp(0.80, 1.0));
    final badgeScale =
        preferredBadgeScale < fitBadgeScale ? preferredBadgeScale : fitBadgeScale;

    final preferredBuildScale = isCompact ? 0.64 : (isShort ? 0.80 : 1.0);
    final buildScale = (preferredBuildScale * heightScale).clamp(0.48, 1.0);

    return Stack(
      children: [
        // ── TOP BAR (Level & XP Bar on left, Resources & Settings on right) ──
        Positioned(
          top: isCompact ? 10 : 14,
          left: 14,
          right: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── 1. LEVEL & XP BAR + USERNAME BESIDE LEVEL ──
              Flexible(
                flex: isCompact ? 5 : 0,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildXpBarWidget(xpBarW, xpBarH, xpPercent),
                      if (game.hasUsername && (!isCompact || screenW >= 540)) ...[
                        SizedBox(width: isCompact ? 8 : 10),
                        _buildUsernamePlaqueWidget(isCompact: isCompact),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),

              // ── 2. Top-Right Resources + Settings Row ──
              Expanded(
                flex: isCompact ? 6 : 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      key: walkthroughKeys?[WalkthroughTargets.hudResources],
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildWoodResourcePill(
                          iconAsset: 'assets/ui/diamonds.png',
                          value: '${game.crystals}',
                          label: 'Star Crystals',
                          onPlus: onOpenBuild,
                          pillW: pillW,
                          pillH: pillH,
                        ),
                        SizedBox(width: isCompact ? 6 : 10),
                        _buildWoodResourcePill(
                          iconAsset: 'assets/ui/coins.png',
                          value: _fmt(game.coins),
                          label: 'Paw Coins',
                          onPlus: onOpenBuild,
                          pillW: pillW,
                          pillH: pillH,
                        ),
                        SizedBox(width: isCompact ? 6 : 10),
                        _buildWoodResourcePill(
                          iconAsset: 'assets/ui/dogfood.png',
                          value: _fmt(game.kibble),
                          label: 'Kibble',
                          onPlus: onOpenBuild,
                          pillW: pillW,
                          pillH: pillH,
                        ),
                        if (onOpenInbox != null) ...[
                          SizedBox(width: isCompact ? 6 : 10),
                          HoverInboxButton(
                            onTap: onOpenInbox!,
                            size: settingsSize,
                          ),
                        ],
                        SizedBox(width: isCompact ? 6 : 10),
                        HoverSettingsButton(
                          onTap: onOpenSettings,
                          size: settingsSize,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── LEFT COLUMN BADGES (GOALS, PROGRESS, SOCIAL) Enlarged with Hover ──
        Positioned(
          top: badgeTop,
          left: 14,
          child: Column(
            children: [
              _buildBadgeButton(
                asset: 'assets/ui/GoalsIcon.png',
                label: 'GOALS',
                textLeftPercent: 0.52,
                textTopPercent: 0.275,
                textWidthPercent: 0.66,
                fontSize: 15.0,
                tooltip: 'Open Daily Goals & Quests',
                onTap: onOpenGoals,
                badgeW: 118.0 * badgeScale,
                badgeH: 124.0 * badgeScale,
              ),
              SizedBox(height: isCompact ? 6 : 10),

              _buildBadgeButton(
                asset: 'assets/ui/ProressIcon.png',
                label: 'PROGRESS',
                textLeftPercent: 0.51,
                textTopPercent: 0.526,
                textWidthPercent: 0.80,
                fontSize: 14.0,
                tooltip: 'View Season Progress & Milestones',
                onTap: onOpenProgress,
                badgeW: 118.0 * badgeScale,
                badgeH: 124.0 * badgeScale,
              ),
              SizedBox(height: isCompact ? 6 : 10),

              KeyedSubtree(
                key: walkthroughKeys?[WalkthroughTargets.hudSocial],
                child: _buildBadgeButton(
                  asset: 'assets/ui/SocialIcon.png',
                  label: 'SOCIAL',
                  textLeftPercent: 0.50,
                  textTopPercent: 0.630,
                  textWidthPercent: 0.70,
                  fontSize: 15.0,
                  tooltip: 'Friends & Social Island Visits',
                  onTap: onOpenSocial,
                  badgeW: 118.0 * badgeScale,
                  badgeH: 124.0 * badgeScale,
                ),
              ),
            ],
          ),
        ),

        // ── BOTTOM-RIGHT 3D BUILD BUTTON (shop.png) Enlarged with Hover ──
        Positioned(
          bottom: 16,
          right: 16,
          child: HoverScale(
            key: walkthroughKeys?[WalkthroughTargets.hudBuild],
            scale: 1.08,
            onTap: onOpenBuild,
            tooltip: 'Open Habitat & Building Store',
            child: SizedBox(
              width: 152.0 * buildScale,
              height: 174.0 * buildScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(0, 5),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
                      child: Image.asset(
                        'assets/ui/shop.png',
                        width: 152.0 * buildScale,
                        height: 174.0 * buildScale,
                        fit: BoxFit.contain,
                        color: const Color(0x66000000),
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/ui/shop.png',
                    width: 152.0 * buildScale,
                    height: 174.0 * buildScale,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  // "BUILD" carved title on the ivory bone sign
                  Positioned(
                    top: (174.0 * buildScale) * 0.725 - (13.5 * buildScale * 0.65),
                    child: Text(
                      'BUILD',
                      style: TextStyle(
                        color: Color(0xFF3B1404),
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5 * buildScale,
                        fontFamily: 'Lilita One',
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            color: Color(0xE6FFFFFF),
                            offset: Offset(0, 1),
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
                ],
              ),
            ),
          ),
        ),

        // ── BOTTOM-LEFT ISLANDS BADGE BUTTON (IslandIcon.png) ──
        if (onOpenIslands != null &&
            (selectedHab == null || selectedHab.underConstruction))
          Positioned(
            bottom: 16,
            left: 14,
            child: KeyedSubtree(
              key: walkthroughKeys?[WalkthroughTargets.hudIslands],
              child: _buildBadgeButton(
                asset: 'assets/ui/IslandIcon.png',
                label: 'ISLANDS',
                textLeftPercent: 0.49,
                textTopPercent: 0.535,
                textWidthPercent: 0.56,
                fontSize: 15.0,
                tooltip: 'Explore World Islands (${game.currentIsland.name})',
                onTap: onOpenIslands!,
                badgeW: 118.0 * badgeScale,
                badgeH: 124.0 * badgeScale,
              ),
            ),
          ),

        // ── HABITAT ACTION CONTROLS BAR (When a completed habitat is tapped) ──
        if (selectedHab != null && !selectedHab.underConstruction)
          Positioned(
            bottom: 16,
            // Leave the bottom-right corner free for the Build button so the
            // action bar never sits underneath it.
            left: 12,
            right: 152.0 * buildScale + 28,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _buildHabitatActionBar(context, selectedHab),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildXpBarWidget(double xpBarW, double xpBarH, double xpPercent) {
    final double circleSize = (xpBarH * (60.0 / 114.0)).clamp(28.0, 60.0);
    return HoverScale(
      scale: 1.04,
      onTap: onOpenProgress,
      tooltip:
          'Level ${game.level} (${game.xp}/${game.maxXp} XP) · Tap for Milestone Rewards',
      child: SizedBox(
        width: xpBarW,
        height: xpBarH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: const Offset(0, 4),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Image.asset(
                    'assets/ui/progress-bar.webp',
                    fit: BoxFit.fill,
                    color: const Color(0x66000000),
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Image.asset(
                'assets/ui/progress-bar.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
            Positioned(
              left: xpBarW * 0.272 - circleSize / 2,
              top: xpBarH * 0.485 - circleSize / 2,
              width: circleSize,
              height: circleSize,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${game.level}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38 * (xpBarH / 114.0),
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Lilita One',
                      shadows: const [
                        Shadow(
                          color: Color(0xFF3B1404),
                          offset: Offset(0, 2.5),
                          blurRadius: 1,
                        ),
                        Shadow(
                          color: Color(0xFF1F0A02),
                          offset: Offset(0, 4),
                          blurRadius: 1,
                        ),
                        Shadow(
                          color: Color(0xCC000000),
                          offset: Offset(0, 5),
                          blurRadius: 7,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: xpBarW * 0.40,
              right: xpBarW * 0.065,
              top: xpBarH * 0.27,
              bottom: xpBarH * 0.30,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    FractionallySizedBox(
                      widthFactor: xpPercent / 100.0,
                      heightFactor: 1.0,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFF59E0B),
                              Color(0xFFB45309),
                              Color(0xFF78350F),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${_fmtXp(game.xp)} / ${_fmtXp(game.maxXp)} XP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize:
                                    (15.5 * (xpBarH / 114.0)).clamp(9.0, 15.5),
                                fontFamily: 'Lilita One',
                                letterSpacing: 0.5,
                                shadows: const [
                                  Shadow(
                                    color: Color(0xFF3B1404),
                                    offset: Offset(0, 2),
                                    blurRadius: 1,
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    offset: Offset(0, 3),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (game.unclaimedMilestoneCount > 0)
              Positioned(
                right: -4,
                top: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.card_giftcard_rounded,
                          color: Color(0xFFFEF08A), size: 10),
                      const SizedBox(width: 3),
                      Text(
                        '${game.unclaimedMilestoneCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernamePlaqueWidget({required bool isCompact}) {
    return HoverScale(
      scale: 1.05,
      onTap: onOpenSettings,
      tooltip: 'Keeper Profile (${game.playerUsername})',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: isCompact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xD92A1205),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0x99FBBF24),
            width: 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pets_rounded,
              color: const Color(0xFFFDE047),
              size: isCompact ? 14 : 16,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? 96 : 136,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  game.playerUsername,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: isCompact ? 12.5 : 14.0,
                    height: 1.1,
                    shadows: const [
                      Shadow(
                        color: Color(0x88000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
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
  }

  Widget _buildWoodResourcePill({
    required String iconAsset,
    required String value,
    required String label,
    required VoidCallback onPlus,
    double pillH = 56.0,
    double pillW = 174.0,
  }) {
    final double iconSize = (pillH * 0.52).clamp(16.0, 28.0);
    final double plusSize = (pillH * 0.46).clamp(16.0, 24.0);
    final double fontSize = (pillH * 0.34).clamp(12.5, 18.0);

    return HoverScale(
      scale: 1.05,
      onTap: onPlus,
      tooltip: '$label: $value (Click to open store)',
      child: SizedBox(
        width: pillW,
        height: pillH,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Soft floating drop shadow behind the wooden plank
            Positioned(
              left: pillW * 0.04,
              right: pillW * 0.04,
              top: pillH * 0.14,
              bottom: pillH * 0.06,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(pillH * 0.45),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),

            // Handcrafted wooden plank frame
            Positioned.fill(
              child: Image.asset(
                'assets/ui/ResourcesPlaceHolder.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),

            // 1. Resource Icon (Diamond, Gold Coins, Kibble)
            Positioned(
              left: pillW * 0.18 - iconSize / 2,
              top: (pillH - iconSize) / 2,
              width: iconSize,
              height: iconSize,
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),

            // 2. Center Value text ("25", "5 K", "1 K")
            Positioned(
              left: pillW * 0.28,
              right: pillW * 0.28,
              top: 0,
              bottom: 0,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                      fontFamily: 'Lilita One',
                      letterSpacing: 0.5,
                      shadows: const [
                        Shadow(
                          color: Color(0xFF3B1404),
                          offset: Offset(0, 1.5),
                          blurRadius: 1,
                        ),
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Tactile Green (+) Round Button
            Positioned(
              left: pillW * 0.82 - plusSize / 2,
              top: (pillH - plusSize) / 2,
              width: plusSize,
              height: plusSize,
              child: HoverScale(
                scale: 1.15,
                onTap: onPlus,
                tooltip: 'Add $label',
                child: Container(
                  width: plusSize,
                  height: plusSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4ADE80), Color(0xFF16A34A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        offset: Offset(0, 1.5),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: plusSize * 0.72,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double computeBadgeScale(double screenW, double screenH) {
    final isCompact = screenW < 700;
    final isShort = screenH < 560;
    final scale = (screenW / 1100).clamp(0.65, 1.0);
    final heightScale = (screenH / 620).clamp(0.72, 1.0);
    final xpBarH = isCompact
        ? ((screenW < 400 ? 44.0 : 52.0) * heightScale).clamp(38.0, 52.0)
        : (78.0 * scale * heightScale).clamp(52.0, 78.0);
    final badgeTop = isCompact ? (xpBarH + 18) : 104.0;
    final availableBadgeH = screenH - badgeTop - 16;
    final fitBadgeScale = ((availableBadgeH - 16) / (3 * 124)).clamp(0.38, 1.0);
    final preferredBadgeScale = isCompact
        ? (screenW < 450 ? 0.54 : 0.58)
        : (isShort ? 0.75 : scale.clamp(0.80, 1.0));
    return preferredBadgeScale < fitBadgeScale
        ? preferredBadgeScale
        : fitBadgeScale;
  }

  static Widget buildBadgeButton({
    required String asset,
    required String label,
    required double textLeftPercent,
    required double textTopPercent,
    required double textWidthPercent,
    required double fontSize,
    required String tooltip,
    required VoidCallback onTap,
    double badgeW = 118.0,
    double badgeH = 124.0,
  }) {
    final scaledFontSize = fontSize * (badgeH / 124.0);

    return HoverScale(
      scale: 1.08,
      onTap: onTap,
      tooltip: tooltip,
      child: SizedBox(
        width: badgeW,
        height: badgeH,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: const Offset(0, 4),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Image.asset(
                  asset,
                  width: badgeW,
                  height: badgeH,
                  fit: BoxFit.contain,
                  color: const Color(0x66000000),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
            Image.asset(
              asset,
              width: badgeW,
              height: badgeH,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
            Positioned(
              left: badgeW * textLeftPercent - (badgeW * textWidthPercent / 2),
              width: badgeW * textWidthPercent,
              top: badgeH * textTopPercent - (scaledFontSize * 0.7),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF3B1404),
                    fontWeight: FontWeight.w900,
                    fontSize: scaledFontSize,
                    fontFamily: 'Lilita One',
                    letterSpacing: 0.8,
                    shadows: const [
                      Shadow(
                        color: Color(0xE6FFFFFF),
                        offset: Offset(0, 1),
                        blurRadius: 1,
                      ),
                      Shadow(
                        color: Color(0x33000000),
                        offset: Offset(0, -0.5),
                        blurRadius: 1,
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
  }

  Widget _buildBadgeButton({
    required String asset,
    required String label,
    required double textLeftPercent,
    required double textTopPercent,
    required double textWidthPercent,
    required double fontSize,
    required String tooltip,
    required VoidCallback onTap,
    double badgeW = 118.0,
    double badgeH = 124.0,
  }) =>
      WorldHUD.buildBadgeButton(
        asset: asset,
        label: label,
        textLeftPercent: textLeftPercent,
        textTopPercent: textTopPercent,
        textWidthPercent: textWidthPercent,
        fontSize: fontSize,
        tooltip: tooltip,
        onTap: onTap,
        badgeW: badgeW,
        badgeH: badgeH,
      );

  String _formatNumber(int n) => GameController.formatCoins(n);

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildHabitatActionBar(BuildContext context, HabitatModel hab) {
    final isFactory = hab.isFactory;
    final isHabitat = hab.type == 'habitat';
    final isWaterStation = hab.isWaterStation;
    final isBreedingDen = hab.habitatId.toLowerCase().contains('breeding');
    final showCollectCoins = isHabitat;
    final catItem = HabitatCatalog.findById(hab.habitatId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Habitat Title Tab on Top Right ──
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF451A03), Color(0xFF290E02)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                top: BorderSide(color: Color(0xFFFBBF24), width: 2),
                left: BorderSide(color: Color(0xFFFBBF24), width: 2),
                right: BorderSide(color: Color(0xFFFBBF24), width: 2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Text(
              isHabitat
                  ? '${hab.name.toUpperCase()} LEVEL ${hab.level}'
                  : hab.name.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: 11,
                letterSpacing: 0.8,
                height: 1.0,
              ),
            ),
          ),
        ),

        // ── Main Action Bar Plaque ──
        Transform.translate(
          offset: const Offset(0, -2),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3D1706), Color(0xFF200A02)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFBBF24), width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xE6000000),
                      blurRadius: 26,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── 1. Left Section: Resident Dogs (habitats), Factory Info, or Building/Decor Info ──
                    if (isFactory) ...[
                      HoverScale(
                        scale: 1.05,
                        onTap: () => onOpenHabitatInfo(hab),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: const Color(0xFF290E02),
                                border: Border.all(
                                    color: const Color(0xFFFCD34D), width: 2),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                'assets/itemsInShop/building/DogfoodFactory.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'KIBBLE BAKERY',
                                  style: TextStyle(
                                    color: Color(0xFFFEF08A),
                                    fontFamily: 'Lilita One',
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  'Rate: +25 / min',
                                  style: TextStyle(
                                    color: Color(0xFFFBBF24),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  'Stored: ${hab.dogfoodAccumulated} / ${hab.maxDogfood}',
                                  style: const TextStyle(
                                    color: Color(0xFFFEF3C7),
                                    fontFamily: 'Fredoka',
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else if (isHabitat) ...[
                      if (hab.dogs.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < hab.dogs.length && i < 4; i++) ...[
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _buildResidentDogAvatar(hab.dogs[i], hab, i),
                              ),
                            ],
                          ],
                        ),
                      ] else ...[
                        HoverScale(
                          scale: 1.08,
                          onTap: onOpenBuild,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0x40290E02),
                                  border: Border.all(
                                      color: const Color(0xFFFCD34D), width: 2),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.add,
                                    color: Color(0xFFFCD34D), size: 26),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'ADD DOG',
                                style: TextStyle(
                                  fontFamily: 'Lilita One',
                                  fontSize: 9,
                                  color: Color(0xFFFEF08A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else if (catItem != null) ...[
                      HoverScale(
                        scale: 1.05,
                        onTap: () => onOpenHabitatInfo(hab),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: const Color(0xFF290E02),
                                border: Border.all(
                                    color: const Color(0xFFFCD34D), width: 1.8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Image.asset(
                                catItem.imageAsset,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  hab.type == 'decor'
                                      ? 'ISLAND DECOR'
                                      : (isWaterStation
                                          ? (game.isHydrationRushActive
                                              ? '2X RUSH (${game.hydrationRushRemainingSeconds}s)'
                                              : (game.isIslandHydrated
                                                  ? 'HYDRATED (+15%)'
                                                  : 'DOGS THIRSTY! (-50%)'))
                                          : 'FACILITY'),
                                  style: TextStyle(
                                    color: isWaterStation
                                        ? (game.isHydrationRushActive
                                              ? const Color(0xFF38BDF8)
                                              : (game.isIslandHydrated
                                                  ? const Color(0xFF6EE7B7)
                                                  : const Color(0xFFFCA5A5)))
                                        : const Color(0xFFFEF08A),
                                    fontFamily: 'Lilita One',
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  catItem.tagline,
                                  style: const TextStyle(
                                    color: Color(0xFFFEF3C7),
                                    fontFamily: 'Fredoka',
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Vertical Divider ──
                    Container(
                      width: 1.5,
                      height: 50,
                      color: const Color(0x66B45309),
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                    ),

                    // ── 2. Right Section: Action Buttons ──
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // MAKE FOOD (factory) or COLLECT (habitat / water station only)
                        if (isFactory || showCollectCoins) ...[
                        HoverScale(
                          key: isFactory
                              ? (walkthroughKeys?[WalkthroughTargets.hudMakeFood])
                              : null,
                          scale: 1.08,
                          onTap: () {
                            if (isFactory) {
                              onOpenHabitatCare(hab);
                            } else {
                              if ((hab.dogs.isNotEmpty || hab.isWaterStation) &&
                                  hab.coinsAccumulated > 0) {
                                game.collectCoins(hab.id);
                              }
                            }
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.topCenter,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: isFactory
                                            ? const [Color(0xFF10B981), Color(0xFF047857)]
                                            : const [Color(0xFFFBBF24), Color(0xFFD97706)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: isFactory
                                              ? const Color(0xFFA7F3D0)
                                              : const Color(0xFFFEF3C7),
                                          width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x66000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: isFactory
                                        ? const Icon(Icons.outdoor_grill_rounded,
                                            color: Colors.white, size: 26)
                                        : Image.asset(
                                            'assets/ui/coins.png',
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                          ),
                                  ),
                                  if (!isFactory)
                                    Positioned(
                                      top: -9,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFBBF24),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFFFEF3C7),
                                              width: 1.2),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x55000000),
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          _formatNumber(
                                            (hab.dogs.isEmpty &&
                                                    !isWaterStation)
                                                ? 0
                                                : hab.coinsAccumulated,
                                          ),
                                          style: const TextStyle(
                                            fontFamily: 'Lilita One',
                                            fontSize: 10,
                                            color: Color(0xFF3B1404),
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isFactory ? 'MAKE FOOD' : 'COLLECT',
                                style: TextStyle(
                                  fontFamily: 'Lilita One',
                                  fontSize: 10,
                                  color: isFactory
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFFFEF08A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ],

                        // BREED Button (Breeding Den only)
                        if (isBreedingDen) ...[
                          HoverScale(
                            scale: 1.08,
                            onTap: onOpenBreeding,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFF472B6),
                                        Color(0xFFDB2777),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFFBCFE8),
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x66000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.favorite_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'BREED',
                                  style: TextStyle(
                                    fontFamily: 'Lilita One',
                                    fontSize: 10,
                                    color: Color(0xFFF9A8D4),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // HYDRATE Button (Water Station only)
                        if (isWaterStation) ...[
                          HoverScale(
                            scale: game.canHydratePark ? 1.08 : 1.0,
                            onTap: game.canHydratePark
                                ? () => game.hydratePark()
                                : null,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: game.canHydratePark
                                          ? const [
                                              Color(0xFF38BDF8),
                                              Color(0xFF0284C7),
                                            ]
                                          : const [
                                              Color(0xFF64748B),
                                              Color(0xFF475569),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: game.canHydratePark
                                          ? const Color(0xFFBAE6FD)
                                          : const Color(0xFF94A3B8),
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x66000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.water_drop_rounded,
                                    color: game.canHydratePark
                                        ? Colors.white
                                        : const Color(0xFFCBD5E1),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  game.canHydratePark
                                      ? 'HYDRATE'
                                      : '${game.hydrationCooldownRemainingSeconds}s',
                                  style: TextStyle(
                                    fontFamily: 'Lilita One',
                                    fontSize: 10,
                                    color: game.canHydratePark
                                        ? const Color(0xFF7DD3FC)
                                        : const Color(0xFFCBD5E1),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // INFO Button
                        HoverScale(
                          scale: 1.08,
                          onTap: () => onOpenHabitatInfo(hab),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF38BDF8),
                                      Color(0xFF1D4ED8)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFF7DD3FC),
                                      width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [Color(0xFFE0F2FE), Color(0xFF7DD3FC)],
                                    ),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.question_mark_rounded,
                                    color: Color(0xFF0284C7),
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'INFO',
                                style: TextStyle(
                                  fontFamily: 'Lilita One',
                                  fontSize: 10,
                                  color: Color(0xFFBAE6FD),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // MOVE Button
                        HoverScale(
                          scale: 1.08,
                          onTap: () => onStartMoveHabitat(hab),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFD97706),
                                      Color(0xFF78350F)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFFDE68A),
                                      width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.open_with_rounded,
                                  color: Color(0xFFFEF08A),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'MOVE',
                                style: TextStyle(
                                  fontFamily: 'Lilita One',
                                  fontSize: 10,
                                  color: Color(0xFFFEF08A),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Top-Left Red Close Button ──
              Positioned(
                top: -8,
                left: -8,
                child: HoverScale(
                  scale: 1.15,
                  onTap: onDeselectHabitat,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFDC2626),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResidentDogAvatar(DogModel dog, HabitatModel hab, int dogIndex) {
    final stageInfo = DogStageInfo.getInfo(dog);
    final dogName = dog.name.trim().isEmpty ? 'Bulldog' : dog.name;

    return HoverScale(
      key: dogIndex == 0
          ? (walkthroughKeys?[WalkthroughTargets.hudCareDog])
          : null,
      scale: 1.08,
      onTap: () => onOpenHabitatCare(hab, dogIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF290E02),
                  border:
                      Border.all(color: const Color(0xFFFCD34D), width: 2.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: Image.asset(
                      stageInfo.sitImg,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Level Badge in Top-Right
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                        color: const Color(0xFFF59E0B), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${dog.level}',
                    style: const TextStyle(
                      color: Color(0xFF18181B),
                      fontFamily: 'Lilita One',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 58,
            child: Text(
              dogName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFEF08A),
                fontFamily: 'Lilita One',
                fontSize: 10,
                letterSpacing: 0.3,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HoverSettingsButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  const HoverSettingsButton({super.key, required this.onTap, this.size = 56.0});

  @override
  State<HoverSettingsButton> createState() => _HoverSettingsButtonState();
}

class _HoverSettingsButtonState extends State<HoverSettingsButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : (_hovered ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size * 0.86,
                  height: widget.size * 0.86,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/ui/SettingPlaceHolder.webp',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                AnimatedRotation(
                  turns: _hovered ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: widget.size * 0.50,
                    shadows: [
                      Shadow(
                        color: Color(0xCC000000),
                        offset: Offset(0, 2),
                        blurRadius: 4,
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
  }
}

class HoverInboxButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  const HoverInboxButton({super.key, required this.onTap, this.size = 56.0});

  @override
  State<HoverInboxButton> createState() => _HoverInboxButtonState();
}

class _HoverInboxButtonState extends State<HoverInboxButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: SocialService.instance.onSocialChanged,
      builder: (context, _) {
        final unclaimed = SocialService.instance.unclaimedGiftCount;
        return Tooltip(
          message: unclaimed > 0
              ? 'Gift Inbox ($unclaimed unclaimed)'
              : 'Gift Inbox',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: AnimatedScale(
                scale: _pressed ? 0.92 : (_hovered ? 1.08 : 1.0),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: widget.size * 0.86,
                        height: widget.size * 0.86,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      Image.asset(
                        'assets/ui/SettingPlaceHolder.webp',
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                      Icon(
                        unclaimed > 0
                            ? Icons.mark_email_unread_rounded
                            : Icons.mail_rounded,
                        color: Colors.white,
                        size: widget.size * 0.48,
                        shadows: const [
                          Shadow(
                            color: Color(0xCC000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      if (unclaimed > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              '$unclaimed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Lilita One',
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
