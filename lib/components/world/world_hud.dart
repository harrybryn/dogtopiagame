import 'package:flutter/material.dart';
import '../../state/game_controller.dart';
import '../../models/habitat_model.dart';
import '../../models/dog_model.dart';
import '../../models/dog_evolution.dart';
import '../common/hover_scale.dart';
import '../../models/walkthrough_step.dart';

class WorldHUD extends StatelessWidget {
  final GameController game;
  final Map<String, GlobalKey>? walkthroughKeys;
  final VoidCallback onOpenBuild;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenProgress;
  final VoidCallback onOpenSocial;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenBreeding;
  final VoidCallback onOpenCollection;
  final void Function(HabitatModel hab, [int dogIndex]) onOpenHabitatCare;
  final Function(HabitatModel) onStartMoveHabitat;
  final Function(HabitatModel) onOpenHabitatInfo;
  final VoidCallback onDeselectHabitat;

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
    required this.onOpenBreeding,
    required this.onOpenCollection,
    required this.onOpenHabitatCare,
    required this.onStartMoveHabitat,
    required this.onOpenHabitatInfo,
    required this.onDeselectHabitat,
  });

  String _fmt(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)} M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(0)} K';
    }
    return n.toString();
  }

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

    // Enlarged XP bar dimensions (ratio 866/288 ~3.007) matching React & Shop scale
    const double xpBarH = 114.0;
    const double xpBarW = xpBarH * (866.0 / 288.0); // ~342.8px

    return Stack(
      children: [
        // ── TOP BAR (Level & XP Bar on left, Resources & Settings on right) ──
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ── 1. LEVEL & XP BAR + USERNAME BESIDE LEVEL ──
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HoverScale(
                    scale: 1.04,
                    onTap: onOpenProgress,
                    tooltip:
                        'Level ${game.level} (${game.xp}/${game.maxXp} XP) · Tap for 5-Level Milestone Rewards',
                    child: SizedBox(
                      width: xpBarW,
                      height: xpBarH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Handcrafted progress-bar.webp asset
                          Positioned.fill(
                            child: Image.asset(
                              'assets/ui/progress-bar.webp',
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),

                          // Level Number in golden circle (centered at 27.2% horizontal, 48.5% vertical)
                          Positioned(
                            left: xpBarW * 0.272 - 30,
                            top: xpBarH * 0.485 - 30,
                            width: 60,
                            height: 60,
                            child: Center(
                              child: Text(
                                '${game.level}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Lilita One',
                                  shadows: [
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

                          // Liquid Gold XP Fill & Current / Required XP (e.g. "500 / 1000 XP")
                          Positioned(
                            left: xpBarW * 0.40,
                            right: xpBarW * 0.065,
                            top: xpBarH * 0.27,
                            bottom: xpBarH * 0.30,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // Liquid Gold Progress Fill
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

                                  // Current / Required XP Label (e.g. "500 / 1000 XP")
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '${_fmtXp(game.xp)} / ${_fmtXp(game.maxXp)} XP',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15.5,
                                              fontFamily: 'Lilita One',
                                              letterSpacing: 0.5,
                                              shadows: [
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

                          // Unclaimed 5-Level Milestone Reward Badge
                          if (game.unclaimedMilestoneCount > 0)
                            Positioned(
                              right: -4,
                              top: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEF4444),
                                      Color(0xFFB91C1C),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFFEF08A),
                                      width: 1.8),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x99000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.card_giftcard_rounded,
                                        color: Color(0xFFFEF08A), size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${game.unclaimedMilestoneCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Lilita One',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Player Username Plaque Displayed Right Beside the Level Bar
                  if (game.hasUsername) ...[
                    const SizedBox(width: 10),
                    HoverScale(
                      scale: 1.05,
                      onTap: onOpenSettings,
                      tooltip: 'Keeper Profile (${game.playerUsername})',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4B1E06), Color(0xFF260D02)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFFBBF24), width: 2.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xAA000000),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFDE047),
                                    Color(0xFFD97706),
                                  ],
                                ),
                                border: Border.all(
                                    color: const Color(0xFFFFFBEB), width: 1.4),
                              ),
                              child: const Icon(Icons.pets_rounded,
                                  color: Color(0xFF3B1404), size: 15),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'KEEPER',
                                  style: TextStyle(
                                    color: Color(0xFFFCD34D),
                                    fontFamily: 'Lilita One',
                                    fontSize: 9.5,
                                    letterSpacing: 1.0,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  game.playerUsername,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Lilita One',
                                    fontSize: 16,
                                    letterSpacing: 0.4,
                                    height: 1.05,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xCC000000),
                                        offset: Offset(0, 2),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // ── 2. Top-Right Resources Row (Enlarged with Hover Effects) ──
              Row(
                key: walkthroughKeys?[WalkthroughTargets.hudResources],
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Star Crystals (Diamonds)
                  _buildWoodResourcePill(
                    iconAsset: 'assets/ui/diamonds.png',
                    value: '${game.crystals}',
                    label: 'Star Crystals',
                    onPlus: onOpenBuild,
                  ),
                  const SizedBox(width: 10),

                  // Paw Coins
                  _buildWoodResourcePill(
                    iconAsset: 'assets/ui/coins.png',
                    value: _fmt(game.coins),
                    label: 'Paw Coins',
                    onPlus: onOpenBuild,
                  ),
                  const SizedBox(width: 10),

                  // Kibble
                  _buildWoodResourcePill(
                    iconAsset: 'assets/ui/dogfood.png',
                    value: _fmt(game.kibble),
                    label: 'Kibble',
                    onPlus: onOpenBuild,
                  ),
                  const SizedBox(width: 10),

                  // Settings Gear Button with Hover Scale & Gear Rotation
                  HoverSettingsButton(onTap: onOpenSettings),
                ],
              ),
            ],
          ),
        ),

        // ── LEFT COLUMN BADGES (GOALS, PROGRESS, SOCIAL) Enlarged with Hover ──
        Positioned(
          top: 138,
          left: 14,
          child: Column(
            children: [
              _buildBadgeButton(
                asset: 'assets/ui/GoalsIcon.png',
                label: 'GOALS',
                textLeftPercent: 0.52,
                textTopPercent: 0.256,
                textWidthPercent: 0.66,
                fontSize: 15.0,
                tooltip: 'Open Daily Goals & Quests',
                onTap: onOpenGoals,
              ),
              const SizedBox(height: 10),

              _buildBadgeButton(
                asset: 'assets/ui/ProressIcon.png',
                label: 'PROGRESS',
                textLeftPercent: 0.51,
                textTopPercent: 0.526,
                textWidthPercent: 0.80,
                fontSize: 14.0,
                tooltip: 'View Season Progress & Milestones',
                onTap: onOpenProgress,
              ),
              const SizedBox(height: 10),

              _buildBadgeButton(
                asset: 'assets/ui/SocialIcon.png',
                label: 'SOCIAL',
                textLeftPercent: 0.50,
                textTopPercent: 0.655,
                textWidthPercent: 0.70,
                fontSize: 15.0,
                tooltip: 'Friends & Social Island Visits',
                onTap: onOpenSocial,
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
              width: 152,
              height: 174,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/ui/shop.png',
                    width: 152,
                    height: 174,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  // "BUILD" carved title on the ivory bone sign
                  Positioned(
                    top: 174 * 0.725 - 9,
                    child: const Text(
                      'BUILD',
                      style: TextStyle(
                        color: Color(0xFF3B1404),
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
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

        // ── HABITAT ACTION CONTROLS BAR (When a completed habitat is tapped) ──
        if (selectedHab != null && !selectedHab.underConstruction)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: _buildHabitatActionBar(context, selectedHab),
            ),
          ),
      ],
    );
  }

  Widget _buildWoodResourcePill({
    required String iconAsset,
    required String value,
    required String label,
    required VoidCallback onPlus,
  }) {
    // Enlarged natural aspect ratio: 174w x 56h
    const double pillH = 56.0;
    const double pillW = 174.0;

    return HoverScale(
      scale: 1.05,
      onTap: onPlus,
      tooltip: '$label: $value (Click to open store)',
      child: SizedBox(
        width: pillW,
        height: pillH,
        child: Stack(
          alignment: Alignment.center,
          children: [
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
              left: pillW * 0.19 - 14,
              top: pillH * 0.50 - 14,
              width: 28,
              height: 28,
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
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.0,
                    fontFamily: 'Lilita One',
                    letterSpacing: 0.5,
                    shadows: [
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

            // 3. Tactile Green (+) Round Button
            Positioned(
              left: pillW * 0.82 - 12,
              top: pillH * 0.50 - 12,
              width: 24,
              height: 24,
              child: HoverScale(
                scale: 1.15,
                onTap: onPlus,
                tooltip: 'Add $label',
                child: Container(
                  width: 24,
                  height: 24,
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
                  child: const Text(
                    '+',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      height: 1.0,
                    ),
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
  }) {
    // Enlarged Badge dimensions matching React & Shop size: 118w x 124h
    const double badgeW = 118.0;
    const double badgeH = 124.0;

    return HoverScale(
      scale: 1.08,
      onTap: onTap,
      tooltip: tooltip,
      child: SizedBox(
        width: badgeW,
        height: badgeH,
        child: Stack(
          alignment: Alignment.center,
          children: [
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
              top: badgeH * textTopPercent - (fontSize * 0.7),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF3B1404),
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
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

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

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
    final isBaking = hab.isBaking;
    final isReadyToCollectFood = isFactory &&
        hab.readyToCollectDogfood &&
        (hab.dogfoodAccumulated > 0 || (hab.bakingFoodAmount ?? 0) > 0);
    final foodReadyAmount = hab.dogfoodAccumulated > 0
        ? hab.dogfoodAccumulated
        : (hab.bakingFoodAmount ?? 0);

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
              '${hab.name.toUpperCase()} LEVEL ${hab.level}',
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
                    // ── 1. Left Section: Resident Dogs or Factory Info ──
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
                    ] else ...[
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
                        // MAKE FOOD (factory) or COLLECT (habitat) Button
                        HoverScale(
                          key: isFactory
                              ? (walkthroughKeys?[WalkthroughTargets.hudMakeFood])
                              : null,
                          scale: 1.08,
                          onTap: () {
                            if (isFactory) {
                              onOpenHabitatCare(hab);
                            } else {
                              if (hab.coinsAccumulated > 0) {
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
                                          _formatNumber(hab.coinsAccumulated > 0
                                              ? hab.coinsAccumulated
                                              : 1000),
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
  const HoverSettingsButton({super.key, required this.onTap});

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
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/ui/SettingPlaceHolder.webp',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                AnimatedRotation(
                  turns: _hovered ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: const Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 28,
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
