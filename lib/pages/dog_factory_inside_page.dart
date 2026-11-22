import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/habitat_model.dart';
import '../models/food_recipe_model.dart';
import '../models/walkthrough_step.dart';
import '../state/game_controller.dart';
import '../components/common/hover_scale.dart';

class DogFactoryInsidePage extends StatefulWidget {
  final GameController game;
  final HabitatModel habitat;
  final VoidCallback onBackToWorld;
  final Map<String, GlobalKey>? walkthroughKeys;

  const DogFactoryInsidePage({
    super.key,
    required this.game,
    required this.habitat,
    required this.onBackToWorld,
    this.walkthroughKeys,
  });

  @override
  State<DogFactoryInsidePage> createState() => _DogFactoryInsidePageState();
}

class _DogFactoryInsidePageState extends State<DogFactoryInsidePage> {
  Timer? _oneSecTimer;
  String? _toastMessage;
  bool _showRecipesWhileBaking = false;

  final ScrollController _recipeScrollController = ScrollController();
  bool _recipesAtBottom = false;

  @override
  void initState() {
    super.initState();
    _recipeScrollController.addListener(_onRecipesScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRecipesScroll());
    _oneSecTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _oneSecTimer?.cancel();
    _recipeScrollController.removeListener(_onRecipesScroll);
    _recipeScrollController.dispose();
    super.dispose();
  }

  void _onRecipesScroll() {
    if (!_recipeScrollController.hasClients) return;
    final atBottom = _recipeScrollController.position.extentAfter <= 8;
    if (atBottom != _recipesAtBottom && mounted) {
      setState(() => _recipesAtBottom = atBottom);
    }
  }

  /// Persistent "more recipes below" cue for the recipe grid.
  Widget _buildRecipeScrollHint() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          height: 56,
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xCC160702)],
            ),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xEE451A03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFBBF24), width: 1.2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MORE RECIPES BELOW',
                  style: TextStyle(
                    color: Color(0xFFFEF08A),
                    fontFamily: 'Lilita One',
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 14, color: Color(0xFFFBBF24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
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

  void _onStartBake(FoodRecipeModel recipe) {
    if (widget.game.coins < recipe.costCoins) {
      _showToast('Not enough Paw Coins! Need ${_fmt(recipe.costCoins)} coins.');
      return;
    }
    final success = widget.game.startBakingFood(widget.habitat.id, recipe);
    if (success) {
      _showToast('Baking ${recipe.name}! Ready in ${recipe.formattedDuration}.');
      setState(() => _showRecipesWhileBaking = false);
    }
  }

  void _onSpeedUp() {
    final hab = widget.habitat;
    final remainingSecs = hab.bakingRemainingSeconds;
    final diamondsNeeded = max(1, (remainingSecs / 900).ceil());

    if (widget.game.crystals < diamondsNeeded) {
      _showToast('Not enough Diamonds! Need $diamondsNeeded.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1205),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 2),
        ),
        title: const Text(
          'SPEED UP BAKING?',
          style: TextStyle(
            color: Color(0xFFFEF08A),
            fontFamily: 'Lilita One',
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Finish baking "${hab.bakingRecipeName ?? 'Kibble'}" instantly for $diamondsNeeded Diamonds?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFEF3C7),
                fontFamily: 'Fredoka',
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/ui/diamonds.png', width: 22, height: 22),
                const SizedBox(width: 6),
                Text(
                  '$diamondsNeeded Diamonds',
                  style: const TextStyle(
                    color: Color(0xFF67E8F9),
                    fontFamily: 'Lilita One',
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white70, fontFamily: 'Lilita One')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final ok = widget.game.speedUpBaking(widget.habitat.id);
              if (ok) {
                _showToast('Baking finished! Ready to collect!');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
            ),
            child: const Text('INSTANT FINISH',
                style: TextStyle(fontFamily: 'Lilita One', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onCollect() {
    final hab = widget.habitat;
    final foodAmt = hab.dogfoodAccumulated > 0
        ? hab.dogfoodAccumulated
        : (hab.bakingFoodAmount ?? 0);
    final ok = widget.game.collectDogfood(hab.id);
    if (ok) {
      _showToast('+$foodAmt Kibble Collected!');
      setState(() => _showRecipesWhileBaking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hab = widget.habitat;
    final isBaking = hab.isBaking;
    final isReadyToCollect = hab.readyToCollectDogfood &&
        (hab.dogfoodAccumulated > 0 || (hab.bakingFoodAmount ?? 0) > 0);

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final isCompact = screenW < 880;
    final pillW = isCompact
        ? ((screenW - 28 - 16) / 3).clamp(70.0, 138.0)
        : 138.0;
    final pillH = isCompact ? 36.0 : 44.0;

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. DogfoodFactoryInsideView Background ──
          Positioned.fill(
            child: Image.asset(
              'assets/itemsInShop/building/DogfoodFactoryInsideView.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          // Subtle dark vignette to ensure readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),

          // ── 2. Top Navigation & Resource Bar ──
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: isCompact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildBackButton(isCompact: true),
                          _buildTitlePlaque(isCompact: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/diamonds.png',
                            value: '${widget.game.crystals}',
                            pillW: pillW,
                            pillH: pillH,
                          ),
                          const SizedBox(width: 8),
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/coins.png',
                            value: _fmt(widget.game.coins),
                            pillW: pillW,
                            pillH: pillH,
                          ),
                          const SizedBox(width: 8),
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/dogfood.png',
                            value: _fmt(widget.game.kibble),
                            pillW: pillW,
                            pillH: pillH,
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildBackButton(isCompact: false),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildTitlePlaque(isCompact: false),
                            ),
                          ),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildWoodResourcePill(
                                iconAsset: 'assets/ui/diamonds.png',
                                value: '${widget.game.crystals}',
                              ),
                              const SizedBox(width: 8),
                              _buildWoodResourcePill(
                                iconAsset: 'assets/ui/coins.png',
                                value: _fmt(widget.game.coins),
                              ),
                              const SizedBox(width: 8),
                              _buildWoodResourcePill(
                                iconAsset: 'assets/ui/dogfood.png',
                                value: _fmt(widget.game.kibble),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // ── 3. Main Body Content (Center View) ──
          Positioned.fill(
            top: isCompact ? 104 : 68,
            bottom: 12,
            left: isCompact ? 12 : 20,
            right: isCompact ? 12 : 20,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _buildMainContent(hab, isBaking, isReadyToCollect),
              ),
            ),
          ),

          // ── 4. Toast Notification Overlay ──
          if (_toastMessage != null)
            Positioned(
              top: isCompact ? 108 : 72,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xEE1E0A02),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _toastMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFEF08A),
                      fontFamily: 'Lilita One',
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackButton({required bool isCompact}) {
    return HoverScale(
      key: widget.walkthroughKeys?[WalkthroughTargets.factoryBackButton],
      scale: 1.06,
      onTap: widget.onBackToWorld,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 10 : 14, vertical: isCompact ? 6 : 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF08A), Color(0xFFF59E0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD97706), width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66D97706),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_ios_new_rounded,
                size: 13, color: Color(0xFF3B1404)),
            const SizedBox(width: 5),
            Text(
              isCompact ? 'BACK' : 'BACK TO ISLAND',
              style: const TextStyle(
                color: Color(0xFF3B1404),
                fontFamily: 'Lilita One',
                fontSize: 12.0,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitlePlaque({required bool isCompact}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 22, vertical: isCompact ? 5 : 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF451A03), Color(0xFF200A02)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFBBF24), width: 2.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/ui/dogfood.png',
            width: isCompact ? 18 : 24,
            height: isCompact ? 18 : 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Text(
            isCompact ? 'KIBBLE BAKERY' : 'DOG FOOD FACTORY & BAKERY',
            style: TextStyle(
              color: const Color(0xFFFEF08A),
              fontFamily: 'Lilita One',
              fontSize: isCompact ? 13 : 16,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWoodResourcePill({
    required String iconAsset,
    required String value,
    double pillW = 140.0,
    double pillH = 38.0,
  }) {
    final double iconSize = (pillH * 0.55).clamp(16.0, 24.0);
    return SizedBox(
      width: pillW,
      height: pillH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/ui/ResourcesPlaceHolder.webp',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: pillW * 0.10,
            top: pillH * 0.50 - iconSize / 2,
            width: iconSize,
            height: iconSize,
            child: Image.asset(
              iconAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            left: pillW * 0.34,
            right: pillW * 0.08,
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
                  fontSize: 14.0,
                  fontFamily: 'Lilita One',
                  letterSpacing: 0.4,
                  shadows: [
                    Shadow(
                      color: Color(0xFF3B1404),
                      offset: Offset(0, 1.5),
                      blurRadius: 1,
                    ),
                    Shadow(
                      color: Colors.black,
                      offset: Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: pillH * 0.50 - 9,
            width: 18,
            height: 18,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFD97706),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(HabitatModel hab, bool isBaking, bool isReadyToCollect) {
    if (isReadyToCollect) {
      return _scrollableCenter(_buildReadyToCollectView(hab));
    }

    if (isBaking && !_showRecipesWhileBaking) {
      return _scrollableCenter(_buildBakingInProgressView(hab));
    }

    // Default or browsing mode: Show the 6 Food Recipes!
    return _buildRecipeSelectionView(hab, isBaking);
  }

  /// Centers a fixed-size panel and lets it scroll instead of overflowing
  /// when the window is short.
  Widget _scrollableCenter(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.of(context).size;
        final compact = size.width < 880 || size.height < 560;
        final panelWidth = constraints.maxWidth < 520 ? constraints.maxWidth : 520.0;
        final panel = compact
            ? SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(width: panelWidth, child: child),
                ),
              )
            : child;

        return Scrollbar(
          controller: _recipeScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _recipeScrollController,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: panel),
            ),
          ),
        );
      },
    );
  }

  // ── Mode 1: Ready to Collect ──
  Widget _buildReadyToCollectView(HabitatModel hab) {
    final foodAmt = hab.dogfoodAccumulated > 0
        ? hab.dogfoodAccumulated
        : (hab.bakingFoodAmount ?? 0);
    final xpAmt = hab.bakingXpReward ?? 100;
    final recipeName = hab.bakingRecipeName ?? 'Fresh Dog Food';

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF381504), Color(0xFF1E0A02)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFBBF24), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF047857)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6EE7B7), width: 1.5),
            ),
            child: const Text(
              'BAKING COMPLETE!',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 16,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Image.asset(
            'assets/ui/dogfood.png',
            width: 84,
            height: 84,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 14),
          Text(
            recipeName,
            style: const TextStyle(
              color: Color(0xFFFEF08A),
              fontFamily: 'Lilita One',
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x40000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/ui/dogfood.png', width: 22, height: 22),
                    const SizedBox(width: 6),
                    Text(
                      '+${_fmt(foodAmt)} Kibble',
                      style: const TextStyle(
                        color: Color(0xFFFEF3C7),
                        fontFamily: 'Lilita One',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x40000000),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/ui/icon_star.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, st) => const Icon(
                        Icons.star_rounded,
                        color: Color(0xFF34D399),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+$xpAmt XP',
                      style: const TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontFamily: 'Lilita One',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          HoverScale(
            key: widget.walkthroughKeys?[WalkthroughTargets.factoryCollectButton],
            scale: 1.06,
            onTap: _onCollect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF059669)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66059669),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/ui/dogfood.png', width: 26, height: 26),
                  const SizedBox(width: 10),
                  const Text(
                    'COLLECT KIBBLE',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode 2: Baking In Progress ──
  Widget _buildBakingInProgressView(HabitatModel hab) {
    final remainingSecs = hab.bakingRemainingSeconds;
    final progress = hab.bakingProgress;
    final diamondsNeeded = max(1, (remainingSecs / 900).ceil());
    final screen = MediaQuery.of(context).size;
    final compact = screen.width < 880 || screen.height < 560;
    final pad = compact ? 14.0 : 26.0;
    final gap = compact ? 10.0 : 18.0;
    final artSize = compact ? 44.0 : 72.0;

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3D1706), Color(0xFF200A02)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFBBF24), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 14,
                  vertical: compact ? 3 : 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFB45309)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: const Color(0xFFFEF08A),
                        size: compact ? 13 : 16),
                    SizedBox(width: compact ? 3 : 4),
                    Text(
                      'BAKING IN OVEN',
                      style: TextStyle(
                        color: const Color(0xFFFEF08A),
                        fontFamily: 'Lilita One',
                        fontSize: compact ? 11 : 13,
                        letterSpacing: compact ? 0.2 : 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              HoverScale(
                scale: 1.05,
                onTap: () => setState(() => _showRecipesWhileBaking = true),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 12,
                    vertical: compact ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x40000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFBBF24), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          color: const Color(0xFFFBBF24),
                          size: compact ? 12 : 14),
                      SizedBox(width: compact ? 3 : 4),
                      Text(
                        'View 6 Recipes',
                        style: TextStyle(
                          color: const Color(0xFFFEF3C7),
                          fontFamily: 'Fredoka',
                          fontSize: compact ? 10 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          Image.asset(
            'assets/ui/dogfood.png',
            width: artSize,
            height: artSize,
            fit: BoxFit.contain,
          ),
          SizedBox(height: compact ? 6 : 12),
          Text(
            hab.bakingRecipeName ?? 'Baking Kibble',
            style: TextStyle(
              color: const Color(0xFFFEF08A),
              fontFamily: 'Lilita One',
              fontSize: compact ? 16 : 22,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            'Yield: +${_fmt(hab.bakingFoodAmount ?? 0)} Kibble  |  +${hab.bakingXpReward ?? 0} XP',
            style: TextStyle(
              color: const Color(0xFFFCD34D),
              fontFamily: 'Fredoka',
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: gap),

          // Progress Bar & Timer Pill
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x44FBBF24)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            color: const Color(0xFFFBBF24),
                            size: compact ? 13 : 16),
                        SizedBox(width: compact ? 4 : 6),
                        Text(
                          'Time Remaining: ${_formatDuration(remainingSecs)}',
                          style: TextStyle(
                            color: const Color(0xFFFEF3C7),
                            fontFamily: 'Fredoka',
                            fontSize: compact ? 11 : 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        color: const Color(0xFFFEF08A),
                        fontFamily: 'Lilita One',
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 5 : 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: compact ? 10 : 14,
                    color: const Color(0xFF1E0A02),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: compact ? 12 : 22),

          // Speed-Up Button
          HoverScale(
            key: widget.walkthroughKeys?[WalkthroughTargets.factorySpeedUpButton],
            scale: 1.06,
            onTap: _onSpeedUp,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 24,
                vertical: compact ? 7 : 10,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF67E8F9), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x660891B2),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/ui/diamonds.png',
                      width: compact ? 17 : 22, height: compact ? 17 : 22),
                  SizedBox(width: compact ? 5 : 8),
                  Text(
                    'FINISH INSTANTLY',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: compact ? 11 : 14,
                      letterSpacing: compact ? 0.2 : 0.5,
                    ),
                  ),
                  SizedBox(width: compact ? 5 : 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF67E8F9), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/ui/diamonds.png',
                            width: compact ? 11 : 14,
                            height: compact ? 11 : 14),
                        SizedBox(width: compact ? 3 : 4),
                        Text(
                          '$diamondsNeeded',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Lilita One',
                            fontSize: compact ? 11 : 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode 3: 6 Food Recipes (Dragon City Apple Farm Style) ──
  Widget _buildRecipeSelectionView(HabitatModel hab, bool isBaking) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Header Plaque
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF381504), Color(0xFF200A02)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBaking) ...[
                  HoverScale(
                    scale: 1.05,
                    onTap: () => setState(() => _showRecipesWhileBaking = false),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back,
                            color: Color(0xFFFCD34D), size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Oven Status',
                          style: TextStyle(
                            color: Color(0xFFFCD34D),
                            fontFamily: 'Fredoka',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 14),
                      ],
                    ),
                  ),
                ],
                const Text(
                  'BAKE FOOD RECIPES (6 AVAILABLE)',
                  style: TextStyle(
                    color: Color(0xFFFEF08A),
                    fontFamily: 'Lilita One',
                    fontSize: 15,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 6 Food Recipe Cards in responsive grid
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isShort = constraints.maxHeight < 340;
              // Use three columns on short landscape windows too, so the six
              // recipes need far less scrolling to browse.
              final isWide = constraints.maxWidth > 750 ||
                  (isShort && constraints.maxWidth > 540);
              final isVeryNarrow = constraints.maxWidth < 450;
              final crossAxisCount = isWide ? 3 : (isVeryNarrow ? 1 : 2);
              final aspect = isWide
                  ? (isShort ? 1.4 : 1.48)
                  : (isVeryNarrow ? 2.4 : 1.15);

              return Stack(
                children: [
                  Positioned.fill(
                    child: Scrollbar(
                      controller: _recipeScrollController,
                      thumbVisibility: true,
                      child: GridView.builder(
                        controller: _recipeScrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: FoodRecipeModel.recipes.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: aspect,
                        ),
                        itemBuilder: (context, idx) {
                          final recipe = FoodRecipeModel.recipes[idx];
                          return _buildRecipeCard(recipe, hab, isBaking,
                              isFirstRecipe: idx == 0);
                        },
                      ),
                    ),
                  ),
                  if (!_recipesAtBottom) _buildRecipeScrollHint(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(
      FoodRecipeModel recipe, HabitatModel hab, bool isBaking,
      {bool isFirstRecipe = false}) {
    final canAfford = widget.game.coins >= recipe.costCoins;
    final isBakeBlocked = isBaking;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBakeBlocked
              ? [const Color(0xFF281105), const Color(0xFF190802)]
              : [const Color(0xFF451A03), const Color(0xFF250B02)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBakeBlocked
              ? const Color(0x66B45309)
              : (canAfford ? const Color(0xFFFBBF24) : const Color(0x889CA3AF)),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top: Icon + Name + Duration Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1002),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  recipe.iconAsset,
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/TrioUIKit_FreeSample_v2.2/png/1x/icons/${recipe.iconAsset.split('/').last}',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, st) => Image.asset(
                      'assets/ui/dogfood.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontFamily: 'Lilita One',
                        fontSize: 13.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      recipe.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFCD34D),
                        fontFamily: 'Fredoka',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0x55000000),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF93C5FD), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, color: Color(0xFF93C5FD), size: 11),
                    const SizedBox(width: 3),
                    Text(
                      recipe.formattedDuration,
                      style: const TextStyle(
                        color: Color(0xFFDBEAFE),
                        fontFamily: 'Fredoka',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Middle: Yield Preview (Kibble + XP)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset('assets/ui/dogfood.png',
                          width: 16, height: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '+${_fmt(recipe.foodAmount)} Kibble',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFEF3C7),
                            fontFamily: 'Lilita One',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Image.asset(
                        'assets/ui/icon_star.png',
                        width: 14,
                        height: 14,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, st) => const Icon(
                          Icons.star_rounded,
                          color: Color(0xFF34D399),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '+${recipe.xpReward} XP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontFamily: 'Fredoka',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action: Make Food / Bake Button with Cost
          HoverScale(
            key: isFirstRecipe
                ? (widget.walkthroughKeys?[WalkthroughTargets.factoryBakeButton])
                : null,
            scale: canAfford && !isBakeBlocked ? 1.04 : 1.0,
            onTap: () {
              if (isBakeBlocked) {
                _showToast('Oven is busy! Wait for current food to finish.');
                return;
              }
              _onStartBake(recipe);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                gradient: isBakeBlocked
                    ? const LinearGradient(
                        colors: [Color(0xFF4B5563), Color(0xFF374151)])
                    : (canAfford
                        ? const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFD97706)])
                        : const LinearGradient(
                            colors: [Color(0xFF6B7280), Color(0xFF4B5563)])),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isBakeBlocked
                      ? const Color(0xFF9CA3AF)
                      : (canAfford ? const Color(0xFFFEF3C7) : const Color(0xFF9CA3AF)),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/ui/coins.png', width: 16, height: 16),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(recipe.costCoins),
                      style: TextStyle(
                        color: canAfford && !isBakeBlocked
                            ? const Color(0xFF3B1404)
                            : Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBakeBlocked ? 'OVEN BUSY' : 'MAKE FOOD',
                      style: TextStyle(
                        color: canAfford && !isBakeBlocked
                            ? const Color(0xFF3B1404)
                            : Colors.white70,
                        fontFamily: 'Lilita One',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
