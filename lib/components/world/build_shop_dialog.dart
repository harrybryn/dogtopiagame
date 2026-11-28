import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/dog_evolution.dart';
import '../../models/habitat_catalog.dart';
import '../../models/island_model.dart';
import '../../models/progression_models.dart';
import '../../models/walkthrough_step.dart';
import '../../state/game_controller.dart';
import '../common/hover_scale.dart';

class BuildShopDialog extends StatefulWidget {
  final GameController game;
  final Function(HabitatCatalogItem) onSelectBuildingToPlace;
  final Function(DogCatalogItem)? onSelectHabitatForDog;
  final Function(DogCatalogItem, String habitatId)? onAdoptDog;
  final String initialTab;

  const BuildShopDialog({
    super.key,
    required this.game,
    required this.onSelectBuildingToPlace,
    this.onSelectHabitatForDog,
    this.onAdoptDog,
    this.initialTab = 'categories',
  });

  @override
  State<BuildShopDialog> createState() => _BuildShopDialogState();
}

class _BuildShopDialogState extends State<BuildShopDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowBobController;
  Timer? _cooldownTimer;
  late String _activeTab; // 'categories' | 'diamonds' | 'habitats' | 'dogs' | 'buildings' | 'decor' | 'packs'
  String _dogFilter = 'all'; // 'all' | 'garden' | 'desert' | 'snow' | 'forest' | 'beach' | 'legendary'
  String _currencyTab = 'diamonds'; // 'diamonds' | 'coins'
  String? _toastMessage;

  @override
  void initState() {
    super.initState();
    _arrowBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _activeTab = widget.initialTab;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (_activeTab == 'diamonds' || _activeTab == 'packs')) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _arrowBobController.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _confirmShopOfferPurchase({
    required String offerId,
    required String title,
    required String rewardText,
    required String priceText,
    required VoidCallback onConfirm,
  }) {
    final rule = ShopOfferRule.findById(offerId);
    final remStock = widget.game.getShopOfferRemainingStock(offerId);
    final cooldownText = rule != null
        ? DogStageInfo.formatDuration(rule.cooldownSeconds)
        : '';
    final String cooldownNote;
    if (rule == null) {
      cooldownNote = '';
    } else if (remStock <= 1) {
      cooldownNote =
          'This offer has a $cooldownText cooldown after purchase before it becomes available again.';
    } else {
      cooldownNote =
          'Stock: $remStock/${rule.maxPurchasesPerWindow} remaining. Once all stock is purchased, it enters a $cooldownText cooldown.';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF260D02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFBBF24), width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0xCC000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CONFIRM PURCHASE?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFEF08A),
                  fontFamily: 'Lilita One',
                  fontSize: 21,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to buy $title\nfor $priceText?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFEF3C7),
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                rewardText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontFamily: 'Lilita One',
                  fontSize: 16,
                ),
              ),
              if (cooldownNote.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B1404),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x66FBBF24),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Color(0xFFFDE047),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cooldownNote,
                          style: const TextStyle(
                            color: Color(0xFFFEF3C7),
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w500,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontFamily: 'Lilita One',
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  HoverScale(
                    scale: 1.05,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onConfirm();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text(
                        'CONFIRM BUY',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getBannerTitle() {
    switch (_activeTab) {
      case 'categories':
        return 'SHOP CATEGORIES';
      case 'diamonds':
        if (_currencyTab == 'diamonds') {
          return 'BUY DIAMONDS (PHP ₱)';
        } else if (_currencyTab == 'coins_real') {
          return 'BUY GOLD COINS (PHP ₱)';
        } else {
          return 'CONVERT DIAMONDS TO COINS';
        }
      case 'habitats':
        return 'ISLAND HABITATS';
      case 'dogs':
        return 'DOG ADOPTIONS';
      case 'buildings':
        return 'ISLAND BUILDINGS';
      case 'decor':
        return 'ISLAND DECOR';
      case 'packs':
        return 'FOOD & KIBBLE';
      default:
        return 'DOGTOPIA STORE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final compact = _isCompact(screenSize);
    // Keep the original 3:2 frame on large screens, but let small landscape
    // windows use the full available height so the cards have room for art
    // and details.
    final double maxModalW =
        (screenSize.width - (compact ? 12.0 : 32.0)).clamp(320.0, 1024.0);
    final double maxModalH =
        (screenSize.height * (compact ? 0.96 : 0.92)).clamp(240.0, 682.0);
    double modalW = maxModalW;
    double modalH = maxModalH;
    if (!compact) {
      modalH = modalW * (2.0 / 3.0);
      if (modalH > maxModalH) {
        modalH = maxModalH;
        modalW = modalH * (3.0 / 2.0);
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 16,
        vertical: compact ? 4 : 12,
      ),
      child: Center(
        child: SizedBox(
          width: modalW,
          height: modalH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── 1. Handcrafted ShopModal.webp Background (Aspect 3:2) ──
              Positioned.fill(
                child: Image.asset(
                  'assets/ui/ShopModal.webp',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),

              // ── 2. Top Title Carved in Wooden Banner (Matching React left/right 32%, top 4.5%, height 12%) ──
              Positioned(
                left: modalW * 0.32,
                right: modalW * 0.32,
                top: modalH * 0.045,
                height: modalH * 0.12,
                child: Center(
                  child: Text(
                    _getBannerTitle(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Lilita One',
                      fontSize: (modalW * 0.024).clamp(14.0, 22.0),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF3B1404),
                      letterSpacing: 0.8,
                      shadows: const [
                        Shadow(
                          color: Color(0xE6FFFFFF),
                          offset: Offset(0, 1.5),
                          blurRadius: 1,
                        ),
                        Shadow(
                          color: Color(0x40000000),
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 3. Top-Right Red (X) Close Button Overlay (Matching React right 5.5%, top 11.5%) ──
              Positioned(
                right: modalW * 0.055,
                top: modalH * 0.115,
                width: modalW * 0.08,
                height: modalW * 0.08,
                child: HoverScale(
                  scale: 1.1,
                  onTap: () => Navigator.of(context).pop(),
                  tooltip: 'Close Shop',
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),

              if (widget.game.walkthroughActive &&
                  widget.game.currentWalkthroughStep?.id ==
                      WalkthroughStepId.shopAndGoals) ...[
                if ((screenSize.width - modalW) / 2 >= 50)
                  Positioned(
                    left: modalW * (1.0 - 0.055) + 6,
                    top: modalH * 0.115 + (modalW * 0.08 - 72) / 2,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _arrowBobController,
                        builder: (context, child) {
                          final t = Curves.easeInOut
                              .transform(_arrowBobController.value);
                          return Transform.translate(
                            offset: Offset(12 * t, 0),
                            child: child,
                          );
                        },
                        child: Transform.rotate(
                          angle: pi / 2,
                          child: Image.asset(
                            'assets/ui/GenericArrow.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    right: modalW * 0.055 + (modalW * 0.08 - 72) / 2,
                    top: modalH * 0.115 - 72 - 4,
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _arrowBobController,
                        builder: (context, child) {
                          final t = Curves.easeInOut
                              .transform(_arrowBobController.value);
                          return Transform.translate(
                            offset: Offset(0, -12 * t),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/ui/GenericArrow.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
              ],

              // ── 4. Main Parchment Board Area (Padded to fit perfectly inside wooden frame) ──
              Positioned(
                // Keep the content inside the wooden frame's parchment area.
                left: modalW * 0.12,
                right: modalW * 0.12,
                top: modalH * 0.245,
                bottom: modalH * 0.14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      // Subcategory Top Bar (Back button + Habitat tabs)
                      if (_activeTab != 'categories') ...[
                        Padding(
                          padding: EdgeInsets.only(bottom: compact ? 4 : 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              HoverScale(
                                scale: 1.05,
                                onTap: () => setState(() => _activeTab = 'categories'),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: compact ? 8 : 12,
                                      vertical: compact ? 3 : 5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFEF08A), Color(0xFFF59E0B)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFD97706), width: 1.5),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33000000),
                                        offset: Offset(0, 2),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.arrow_back,
                                          size: 14, color: Color(0xFF3B1404)),
                                      SizedBox(width: compact ? 2 : 4),
                                      Text(
                                        'CATEGORIES',
                                        style: TextStyle(
                                          color: const Color(0xFF3B1404),
                                          fontFamily: 'Lilita One',
                                          fontSize: compact ? 10 : 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Currency tabs when in diamonds category
                              if (_activeTab == 'diamonds')
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildCurrencyFilterTab('diamonds', 'DIAMONDS (₱)'),
                                        _buildCurrencyFilterTab('coins_real', 'GOLD (₱)'),
                                        _buildCurrencyFilterTab('coins', 'CONVERT'),
                                      ],
                                    ),
                                  ),
                                ),

                              // Dog Habitat tabs
                              if (_activeTab == 'dogs')
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildFilterTab('all', 'ALL'),
                                        _buildFilterTab('garden', 'GARDEN'),
                                        _buildFilterTab('desert', 'DESERT'),
                                        _buildFilterTab('snow', 'SNOW'),
                                        _buildFilterTab('forest', 'FOREST'),
                                        _buildFilterTab('beach', 'BEACH'),
                                        _buildFilterTab('legendary', 'LEGEND'),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Matching height spacer so Categories panel is the exact same size as other panels
                        SizedBox(height: compact ? 10 : 36),
                      ],

                      // Toast notification
                      if (_toastMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF047857),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _toastMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Fredoka',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // Content Views
                      Expanded(
                        child: _buildCurrentView(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isCompact(Size size) => size.width < 880 || size.height < 560;

  double _shopGridSpacing(bool compact) => compact ? 8.0 : 10.0;
  double _shopGridPadding(bool compact) => compact ? 4.0 : 8.0;

  /// Card ratio must account for the grid's padding, otherwise hover scaling
  /// pushes the cards past the parchment area of the shop background.
  double _shopGridRatio(BoxConstraints constraints, bool compact) {
    final spacing = _shopGridSpacing(compact);
    final padding = _shopGridPadding(compact);
    final cardW = (constraints.maxWidth - padding * 2 - spacing * 2) / 3;
    final cardH = (constraints.maxHeight - padding * 2 - spacing) / 2;
    return cardW / cardH;
  }

  Widget _buildCurrencyFilterTab(String id, String label) {
    final isSelected = _currencyTab == id;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: HoverScale(
        scale: 1.05,
        onTap: () => setState(() => _currencyTab = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB45309) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF78350F) : const Color(0xFFF59E0B),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                id == 'diamonds' ? 'assets/ui/diamonds.png' : 'assets/ui/coins.png',
                width: 13,
                height: 13,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF78350F),
                  fontFamily: 'Lilita One',
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String id, String label) {
    final isSelected = _dogFilter == id;
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: HoverScale(
        scale: 1.05,
        onTap: () => setState(() => _dogFilter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB45309) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF78350F) : const Color(0xFFF59E0B),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF78350F),
              fontFamily: 'Lilita One',
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_activeTab) {
      case 'categories':
        return _buildCategoriesView();
      case 'diamonds':
        return _buildDiamondsView();
      case 'habitats':
        return _buildHabitatsView();
      case 'dogs':
        return _buildDogsView();
      case 'buildings':
        return _buildBuildingsView();
      case 'decor':
        return _buildDecorView();
      case 'packs':
        return _buildPacksView();
      default:
        return _buildCategoriesView();
    }
  }

  bool _isBuildingFirstTime(
    HabitatCatalogItem item, {
    required bool isUnlocked,
  }) {
    if (!isUnlocked) return false;
    return !widget.game.placedHabitats.any((h) => h.habitatId == item.id);
  }

  bool _isDogFirstTime(DogCatalogItem dog, {required bool isUnlocked}) {
    if (!isUnlocked) return false;
    return !widget.game.placedHabitats
        .any((h) => h.dogs.any((d) => d.breedId == dog.id));
  }

  bool _categoryHasNew(String categoryId) {
    switch (categoryId) {
      case 'habitats':
        return HabitatCatalog.habitats.any((hab) {
          final isUnlocked = widget.game.level >= hab.requiredLevel &&
              IslandCatalog.isItemAllowedOnIsland(
                  hab, widget.game.currentIslandId);
          return _isBuildingFirstTime(hab, isUnlocked: isUnlocked);
        });
      case 'dogs':
        return HabitatCatalog.dogs.any((dog) {
          final isUnlocked =
              widget.game.level >= dog.requiredLevel && !dog.isLocked;
          return _isDogFirstTime(dog, isUnlocked: isUnlocked);
        });
      case 'buildings':
        return HabitatCatalog.facilities.any((item) {
          final isUnlocked = widget.game.level >= item.requiredLevel;
          return _isBuildingFirstTime(item, isUnlocked: isUnlocked);
        });
      case 'decor':
        return HabitatCatalog.decor.any((item) {
          final isUnlocked = widget.game.level >= item.requiredLevel;
          return _isBuildingFirstTime(item, isUnlocked: isUnlocked);
        });
      default:
        return false;
    }
  }

  Widget _buildNewBadge(bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 1.5 : 2.5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFEF08A), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        'NEW!',
        style: TextStyle(
          color: const Color(0xFFFEF08A),
          fontFamily: 'Lilita One',
          fontSize: compact ? 7.5 : 9.5,
          letterSpacing: 0.5,
          height: 1.0,
        ),
      ),
    );
  }

  // ── 1. Main Category Grid (Clean 3x2, perfectly fitted without scrolling) ──
  Widget _buildCategoriesView() {
    final categories = [
      {
        'id': 'diamonds',
        'name': 'BUY DIAMONDS & COINS',
        'image': 'assets/ui/CoinAndDiamondsShopICon.webp',
        'desc': 'Star Crystals & Paw Coins',
      },
      {
        'id': 'habitats',
        'name': 'HABITATS',
        'image': 'assets/ui/HabitatShopIcon.png',
        'desc': '6 Elemental Sanctuaries',
      },
      {
        'id': 'dogs',
        'name': 'DOG ADOPTIONS',
        'image': 'assets/ui/AnimalShopIcon.png',
        'desc': 'Breed by Habitat Element',
      },
      {
        'id': 'buildings',
        'name': 'BUILDINGS',
        'image': 'assets/ui/BuildingShopIcon.webp',
        'desc': 'Training & Care Facilities',
      },
      {
        'id': 'decor',
        'name': 'ISLAND DECOR',
        'image': 'assets/itemsInShop/building/GoldenPalm.webp',
        'desc': 'Ornaments, Trees & Paths',
      },
      {
        'id': 'packs',
        'name': 'FOOD & KIBBLE',
        'image': 'assets/ui/dogfood.png',
        'desc': 'Gourmet Dog Food Packs',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);
        final cardW =
            (constraints.maxWidth - padding * 2 - spacing * 2) / 3;
        final titleSize = compact ? (cardW < 120 ? 8.5 : 9.5) : 13.5;
        final descSize = compact ? (cardW < 120 ? 7.5 : 8.5) : 10.5;

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];

            return HoverScale(
              scale: 1.04,
              onTap: () => setState(() => _activeTab = cat['id'] as String),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 5 : 10,
                  vertical: compact ? 3 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 0.85,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFEF8EB),
                      Color(0xFFFDE6BA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(compact ? 12 : 18),
                  border: Border.all(color: const Color(0xFFD97706), width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3378350F),
                      offset: Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Representative Game Asset
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: compact ? 0 : 3),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: Image.asset(
                                cat['image'] as String,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                            if (_categoryHasNew(cat['id'] as String))
                              Positioned(
                                top: 2,
                                left: 2,
                                child: _buildNewBadge(compact),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 1 : 4),

                    // Title
                    Text(
                      cat['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF451A03),
                        fontFamily: 'Lilita One',
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: compact ? 0 : 0.3,
                      ),
                    ),

                    // Description Subtitle
                    Text(
                      cat['desc'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF78350F),
                        fontFamily: 'Fredoka',
                        fontSize: descSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 2 : 6),

                    // Action Pill: "EXPLORE"
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 14,
                        vertical: compact ? 1 : 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            offset: Offset(0, 2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Text(
                        'EXPLORE',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: compact ? 8 : 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: compact ? 0 : 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 2. Habitats View ──
  Widget _buildHabitatsView() {
    final habitats = HabitatCatalog.habitats;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: habitats.length > 6
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: habitats.length,
          itemBuilder: (context, index) {
            final hab = habitats[index];
            final canAfford = widget.game.coins >= hab.costCoins &&
                widget.game.crystals >= hab.costDiamonds;
            final levelUnlocked = widget.game.level >= hab.requiredLevel;
            final allowedOnIsland = IslandCatalog.isItemAllowedOnIsland(
                hab, widget.game.currentIslandId);
            final requiredIslandId =
                IslandCatalog.requiredIslandIdForItem(hab);
            final requiredIslandName =
                IslandCatalog.requiredIslandNameForItem(hab);
            final requiredIslandUnlocked =
                widget.game.isIslandUnlocked(requiredIslandId);
            final owned = widget.game.getBuildingOwnedCount(hab.id);
            final limit = widget.game.getBuildingLimit(hab.id);
            final atLimit = owned >= limit;
            final nextSlotLvl =
                widget.game.nextBuildingSlotUnlockLevel(hab.id);
            final isUnlocked = levelUnlocked && allowedOnIsland && !atLimit;
            final isIslandLock = levelUnlocked && !allowedOnIsland;

            String? lockLabel;
            if (levelUnlocked) {
              if (!allowedOnIsland) {
                lockLabel = requiredIslandUnlocked
                    ? 'GO TO ${requiredIslandName.toUpperCase()}'
                    : 'UNLOCK ${requiredIslandName.toUpperCase()}';
              } else if (atLimit) {
                lockLabel = nextSlotLvl != null
                    ? 'LIMIT $owned/$limit · LVL $nextSlotLvl'
                    : 'MAXED $owned/$limit';
              }
            }

            return _buildItemCard(
              name: hab.name,
              image: hab.assetImage,
              element: hab.element,
              subtitle: '${hab.sizeW}×${hab.sizeH} Plot · +${hab.coinRate}',
              buildTime: hab.formattedBuildTime,
              ownershipText: '$owned/$limit',
              costCoins: hab.costCoins,
              costDiamonds: hab.costDiamonds,
              requiredLevel: hab.requiredLevel,
              isUnlocked: isUnlocked,
              canAfford: canAfford,
              isNew: _isBuildingFirstTime(hab, isUnlocked: isUnlocked),
              lockLabelOverride: lockLabel,
              isIslandLock: isIslandLock,
              onTapLocked: () {
                if (!levelUnlocked) {
                  _showToast(
                      '${hab.name} unlocks at Level ${hab.requiredLevel}!');
                } else if (!allowedOnIsland) {
                  _showToast(
                    requiredIslandUnlocked
                        ? 'Switch to $requiredIslandName to build ${hab.name}!'
                        : 'Unlock the $requiredIslandName island to purchase ${hab.name}!',
                  );
                } else if (atLimit) {
                  _showToast(
                    nextSlotLvl != null
                        ? '${hab.name} limit reached ($owned/$limit)! Reach Level $nextSlotLvl for +1 slot.'
                        : 'Maximum ${hab.name} limit reached ($owned/$limit)!',
                  );
                }
              },
              onBuy: () {
                Navigator.of(context).pop();
                widget.onSelectBuildingToPlace(hab);
              },
            );
          },
        );
      },
    );
  }

  // ── 3. Dogs View ──
  Widget _buildDogsView() {
    final dogs = HabitatCatalog.dogs.where((d) {
      if (_dogFilter == 'all') return true;
      if (_dogFilter == 'garden') return d.habitatType == 'garden';
      if (_dogFilter == 'desert') return d.habitatType == 'desert';
      if (_dogFilter == 'snow') return d.habitatType == 'snow';
      if (_dogFilter == 'forest') return d.habitatType == 'forest';
      if (_dogFilter == 'beach') return d.habitatType == 'beach';
      if (_dogFilter == 'legendary') return d.habitatType == 'legendary';
      return true;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: dogs.length > 6
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: dogs.length,
          itemBuilder: (context, index) {
            final dog = dogs[index];
            final canAfford = widget.game.coins >= dog.costCoins &&
                widget.game.crystals >= dog.costDiamonds;
            final isUnlocked = widget.game.level >= dog.requiredLevel && !dog.isLocked;

            // Check if player has an available compatible habitat with open slot (<4 dogs)
            final compatibleHabs = widget.game.placedHabitats
                .where((h) =>
                    h.type == 'habitat' &&
                    !h.underConstruction &&
                    h.dogs.length < 4 &&
                    HabitatCatalog.isHabitatCompatible(
                      habitatCatalogId: h.habitatId,
                      breedId: dog.id,
                      element: dog.element,
                      preferredHabitatId: dog.habitatId,
                    ))
                .toList();

            return _buildItemCard(
              name: dog.name,
              image: dog.assetImage,
              element: '${dog.habitatType.toUpperCase()} ELEMENT',
              subtitle: 'Adoptable Companion',
              costCoins: dog.costCoins,
              costDiamonds: dog.costDiamonds,
              requiredLevel: dog.requiredLevel,
              isUnlocked: isUnlocked,
              canAfford: canAfford,
              isNew: _isDogFirstTime(dog, isUnlocked: isUnlocked),
              onTapLocked: () {
                _showToast(
                    '${dog.name} is locked! Reach Level ${dog.requiredLevel} to unlock.');
              },
              onBuy: () {
                if (compatibleHabs.isEmpty) {
                  final anyPlaced = widget.game.placedHabitats.any((h) =>
                      h.type == 'habitat' &&
                      HabitatCatalog.isHabitatCompatible(
                        habitatCatalogId: h.habitatId,
                        breedId: dog.id,
                        element: dog.element,
                        preferredHabitatId: dog.habitatId,
                      ));
                  if (anyPlaced) {
                    _showToast('All compatible habitats are full (4/4 dogs)!');
                  } else {
                    _showToast(
                        'Build a ${dog.habitatType.toUpperCase()} Habitat first!');
                  }
                  return;
                }

                Navigator.of(context).pop();
                if (widget.onSelectHabitatForDog != null) {
                  widget.onSelectHabitatForDog!(dog);
                } else {
                  widget.onAdoptDog?.call(dog, compatibleHabs.first.id);
                }
              },
            );
          },
        );
      },
    );
  }

  // ── 4. Buildings View ──
  Widget _buildBuildingsView() {
    final facilities = HabitatCatalog.facilities;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: facilities.length > 6
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: facilities.length,
          itemBuilder: (context, index) {
            final item = facilities[index];
            final canAfford = widget.game.coins >= item.costCoins &&
                widget.game.crystals >= item.costDiamonds;
            final levelUnlocked = widget.game.level >= item.requiredLevel;
            final owned = widget.game.getBuildingOwnedCount(item.id);
            final limit = widget.game.getBuildingLimit(item.id);
            final atLimit = owned >= limit;
            final nextSlotLvl =
                widget.game.nextBuildingSlotUnlockLevel(item.id);
            final isUnlocked = levelUnlocked && !atLimit;

            String? lockLabel;
            if (levelUnlocked && atLimit) {
              if (item.isUnique) {
                lockLabel = 'OWNED $owned/$limit';
              } else if (nextSlotLvl != null) {
                lockLabel = 'LIMIT $owned/$limit · LVL $nextSlotLvl';
              } else {
                lockLabel = 'MAXED $owned/$limit';
              }
            }

            return _buildItemCard(
              name: item.name,
              image: item.assetImage,
              element: item.isUnique ? 'Unique Facility' : 'Care Facility',
              subtitle: '${item.sizeW}×${item.sizeH} Plot · ${item.description}',
              buildTime: item.formattedBuildTime,
              ownershipText: '$owned/$limit',
              costCoins: item.costCoins,
              costDiamonds: item.costDiamonds,
              requiredLevel: item.requiredLevel,
              isUnlocked: isUnlocked,
              canAfford: canAfford,
              isNew: _isBuildingFirstTime(item, isUnlocked: isUnlocked),
              lockLabelOverride: lockLabel,
              onTapLocked: () {
                if (!levelUnlocked) {
                  _showToast(
                      '${item.name} unlocks at Level ${item.requiredLevel}!');
                } else if (atLimit) {
                  _showToast(
                    item.isUnique
                        ? '${item.name} is unique ($owned/$limit)! You already own it.'
                        : (nextSlotLvl != null
                            ? '${item.name} limit reached ($owned/$limit)! Reach Level $nextSlotLvl for +1 slot.'
                            : 'Maximum ${item.name} limit reached ($owned/$limit)!'),
                  );
                }
              },
              onBuy: () {
                Navigator.of(context).pop();
                widget.onSelectBuildingToPlace(item);
              },
            );
          },
        );
      },
    );
  }

  // ── 5. Decor View ──
  Widget _buildDecorView() {
    final decor = HabitatCatalog.decor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: decor.length > 6
              ? const BouncingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: decor.length,
          itemBuilder: (context, index) {
            final item = decor[index];
            final canAfford = widget.game.coins >= item.costCoins &&
                widget.game.crystals >= item.costDiamonds;
            final levelUnlocked = widget.game.level >= item.requiredLevel;
            final owned = widget.game.getBuildingOwnedCount(item.id);
            final limit = widget.game.getBuildingLimit(item.id);
            final atLimit = owned >= limit;
            final nextSlotLvl =
                widget.game.nextBuildingSlotUnlockLevel(item.id);
            final isUnlocked = levelUnlocked && !atLimit;

            return _buildItemCard(
              name: item.name,
              image: item.assetImage,
              element: 'Island Decor',
              subtitle: '${item.sizeW}×${item.sizeH} · Ornaments',
              buildTime: item.formattedBuildTime,
              ownershipText: '$owned/$limit',
              costCoins: item.costCoins,
              costDiamonds: item.costDiamonds,
              requiredLevel: item.requiredLevel,
              isUnlocked: isUnlocked,
              canAfford: canAfford,
              isNew: _isBuildingFirstTime(item, isUnlocked: isUnlocked),
              lockLabelOverride: (levelUnlocked && atLimit)
                  ? (nextSlotLvl != null
                      ? 'LIMIT $owned/$limit · LVL $nextSlotLvl'
                      : 'MAXED $owned/$limit')
                  : null,
              onTapLocked: () {
                if (!levelUnlocked) {
                  _showToast(
                      '${item.name} unlocks at Level ${item.requiredLevel}!');
                } else if (atLimit) {
                  _showToast(
                    nextSlotLvl != null
                        ? '${item.name} limit reached ($owned/$limit)! Reach Level $nextSlotLvl for more.'
                        : 'Maximum ${item.name} limit reached ($owned/$limit)!',
                  );
                }
              },
              onBuy: () {
                Navigator.of(context).pop();
                widget.onSelectBuildingToPlace(item);
              },
            );
          },
        );
      },
    );
  }

  // ── 6. Packs View (Pure Food & Kibble) ──
  Widget _buildPacksView() {
    final packs = [
      {
        'id': 'kibble_treat',
        'name': 'Handful of Kibble',
        'element': '+500 Kibble',
        'image': 'assets/ui/dogfood.png',
        'costCoins': 350,
        'costDiamonds': 0,
        'kibble': 500,
        'coins': 0,
      },
      {
        'id': 'kibble_snack',
        'name': 'Bowl of Kibble',
        'element': '+1,500 Kibble',
        'image': 'assets/ui/dogfood.png',
        'costCoins': 1000,
        'costDiamonds': 0,
        'kibble': 1500,
        'coins': 0,
      },
      {
        'id': 'kibble_sack',
        'name': 'Sack of Kibble',
        'element': '+5,000 Kibble',
        'image': 'assets/ui/dogfood.png',
        'costCoins': 3000,
        'costDiamonds': 0,
        'kibble': 5000,
        'coins': 0,
      },
      {
        'id': 'kibble_crate',
        'name': 'Crate of Kibble',
        'element': '+10,000 Kibble',
        'image': 'assets/ui/dogfood.png',
        'costCoins': 5500,
        'costDiamonds': 0,
        'kibble': 10000,
        'coins': 0,
      },
      {
        'id': 'kibble_banquet',
        'name': 'Grand Feast',
        'element': '+20,000 Kibble',
        'image': 'assets/ui/dogfood.png',
        'costCoins': 10000,
        'costDiamonds': 0,
        'kibble': 20000,
        'coins': 0,
      },
      {
        'id': 'kibble_royal',
        'name': 'Royal Feast',
        'element': '+50,000 Kibble',
        'image': 'assets/ui/dogfood.png',
        'costCoins': 22000,
        'costDiamonds': 0,
        'kibble': 50000,
        'coins': 0,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: packs.length,
          itemBuilder: (context, index) {
            final pack = packs[index];
            final offerId = pack['id'] as String;
            final rule = ShopOfferRule.findById(offerId);
            final reqLevel = rule?.requiredLevel ?? 1;
            final costCoins = pack['costCoins'] as int;
            final costDiamonds = pack['costDiamonds'] as int;
            final canAfford = widget.game.coins >= costCoins &&
                widget.game.crystals >= costDiamonds;
            final levelOk = widget.game.level >= reqLevel;
            final cooldownSec = widget.game.getShopOfferCooldownSeconds(offerId);
            final remStock = widget.game.getShopOfferRemainingStock(offerId);
            final maxStock = rule?.maxPurchasesPerWindow ?? 1;
            final isAvailable = levelOk && cooldownSec == 0 && remStock > 0;

            String? lockLabel;
            if (levelOk && cooldownSec > 0) {
              lockLabel = DogStageInfo.formatDuration(cooldownSec);
            }

            return _buildItemCard(
              name: pack['name'] as String,
              image: pack['image'] as String,
              element: pack['element'] as String,
              subtitle: 'Instant Resource Pack',
              ownershipText: rule != null ? '$remStock/$maxStock' : null,
              costCoins: costCoins,
              costDiamonds: costDiamonds,
              requiredLevel: reqLevel,
              isUnlocked: isAvailable,
              canAfford: canAfford,
              lockLabelOverride: lockLabel,
              onTapLocked: () {
                if (!levelOk) {
                  _showToast('Unlocks at Level $reqLevel!');
                } else if (cooldownSec > 0) {
                  _showToast(
                      'Offer refreshes in ${DogStageInfo.formatDuration(cooldownSec)}!');
                }
              },
              onBuy: () {
                _confirmShopOfferPurchase(
                  offerId: offerId,
                  title: pack['name'] as String,
                  rewardText: pack['element'] as String,
                  priceText: '${_fmt(costCoins)} Coins',
                  onConfirm: () {
                    if (widget.game.purchaseShopOffer(
                      offerId,
                      costCoins: costCoins,
                      costCrystals: costDiamonds,
                      addKibble: pack['kibble'] as int,
                      addCoins: pack['coins'] as int,
                    )) {
                      setState(() {});
                      _showToast('Purchased ${pack['name']}!');
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLockedOfferButton({
    required bool levelOk,
    required int reqLevel,
    required int cooldownSec,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 11,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF573B26), Color(0xFF3B2313)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFBBF24),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
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
            Icon(
              levelOk ? Icons.schedule_rounded : Icons.lock_rounded,
              size: compact ? 9 : 11,
              color: const Color(0xFFFDE047),
            ),
            SizedBox(width: compact ? 3 : 4),
            Text(
              !levelOk
                  ? 'LVL $reqLevel REQUIRED'
                  : DogStageInfo.formatDuration(cooldownSec),
              style: TextStyle(
                color: const Color(0xFFFEF3C7),
                fontFamily: 'Lilita One',
                fontSize: compact ? 8 : 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 7. Diamonds / Currency View ──
  Widget _buildDiamondsView() {
    if (_currencyTab == 'coins_real') {
      return _buildCoinsRealMoneyView();
    }
    if (_currencyTab == 'coins') {
      return _buildCoinsCurrencyView();
    }
    final tiers = [
      {'id': 'diam_pile', 'name': 'Pile of Diamonds', 'amount': 50, 'bonusCoins': 10000, 'price': '₱49.00', 'badge': ''},
      {'id': 'diam_bag', 'name': 'Bag of Diamonds', 'amount': 150, 'bonusCoins': 35000, 'price': '₱129.00', 'badge': ''},
      {'id': 'diam_chest', 'name': 'Chest of Diamonds', 'amount': 500, 'bonusCoins': 120000, 'price': '₱399.00', 'badge': 'POPULAR'},
      {'id': 'diam_vault', 'name': 'Vault of Diamonds', 'amount': 1200, 'bonusCoins': 300000, 'price': '₱799.00', 'badge': 'BEST VALUE'},
      {'id': 'diam_treasury', 'name': 'Treasury of Diamonds', 'amount': 2800, 'bonusCoins': 800000, 'price': '₱1,499.00', 'badge': '+60% EXTRA'},
      {'id': 'diam_mountain', 'name': 'Mountain of Diamonds', 'amount': 6500, 'bonusCoins': 2000000, 'price': '₱2,999.00', 'badge': 'MEGA HOARD'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: tiers.length,
          itemBuilder: (context, index) {
            final t = tiers[index];
            final offerId = t['id'] as String;
            final rule = ShopOfferRule.findById(offerId);
            final reqLevel = rule?.requiredLevel ?? 1;
            final levelOk = widget.game.level >= reqLevel;
            final cooldownSec = widget.game.getShopOfferCooldownSeconds(offerId);
            final isAvailable = levelOk && cooldownSec == 0;
            final badge = t['badge'] as String;

            return HoverScale(
              scale: isAvailable ? 1.04 : 1.0,
              onTap: () {
                if (!levelOk) {
                  _showToast('${t['name']} unlocks at Level $reqLevel!');
                  return;
                }
                if (cooldownSec > 0) {
                  _showToast(
                      '${t['name']} available again in ${DogStageInfo.formatDuration(cooldownSec)}!');
                  return;
                }
                final amount = t['amount'] as int;
                final bonusCoins = t['bonusCoins'] as int;
                _confirmShopOfferPurchase(
                  offerId: offerId,
                  title: t['name'] as String,
                  rewardText: '+$amount Diamonds & +${_fmt(bonusCoins)} Gold',
                  priceText: t['price'] as String,
                  onConfirm: () {
                    if (widget.game.purchaseShopOffer(
                      offerId,
                      addCrystals: amount,
                      addCoins: bonusCoins,
                    )) {
                      setState(() {});
                      _showToast(
                          '+$amount Diamonds & +${_fmt(bonusCoins)} Bonus Gold added!');
                    }
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 0.9,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFEF9EE),
                      Color(0xFFFAE8C8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD97706), width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2978350F),
                      offset: Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Column(
                        children: [
                          // Graphic Image
                          Expanded(
                            child: Center(
                              child: Image.asset(
                                'assets/ui/diamonds.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Diamonds Count
                          Text(
                            '${t['amount']} Diamonds',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF451A03),
                              fontFamily: 'Lilita One',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),

                          // Bonus Gold Portion
                          Text(
                            '+${_fmt(t['bonusCoins'] as int)} Gold Bonus',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontFamily: 'Fredoka',
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Buy Button
                          if (!isAvailable)
                            _buildLockedOfferButton(
                              levelOk: levelOk,
                              reqLevel: reqLevel,
                              cooldownSec: cooldownSec,
                              compact: compact,
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 7 : 12,
                                vertical: compact ? 2 : 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFEF3C7),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Text(
                                t['price'] as String,
                                style: TextStyle(
                                  color: const Color(0xFF3B1404),
                                  fontFamily: 'Lilita One',
                                  fontSize: compact ? 9.5 : 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Badge Pill if present (e.g. POPULAR, BEST VALUE)
                    if (badge.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lilita One',
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 7B. Gold Coins Real Money View (PHP ₱) ──
  Widget _buildCoinsRealMoneyView() {
    final goldTiers = [
      {'id': 'gold_pouch', 'name': 'Pouch of Gold', 'amount': 50000, 'price': '₱49.00', 'badge': ''},
      {'id': 'gold_sack', 'name': 'Sack of Gold', 'amount': 160000, 'price': '₱129.00', 'badge': ''},
      {'id': 'gold_chest', 'name': 'Chest of Gold', 'amount': 550000, 'price': '₱399.00', 'badge': 'POPULAR'},
      {'id': 'gold_vault', 'name': 'Vault of Gold', 'amount': 1350000, 'price': '₱799.00', 'badge': 'BEST VALUE'},
      {'id': 'gold_treasury', 'name': 'Treasury of Gold', 'amount': 3200000, 'price': '₱1,499.00', 'badge': '+60% EXTRA'},
      {'id': 'gold_mountain', 'name': 'Mountain of Gold', 'amount': 8500000, 'price': '₱2,999.00', 'badge': 'MEGA HOARD'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: goldTiers.length,
          itemBuilder: (context, index) {
            final t = goldTiers[index];
            final offerId = t['id'] as String;
            final rule = ShopOfferRule.findById(offerId);
            final reqLevel = rule?.requiredLevel ?? 1;
            final levelOk = widget.game.level >= reqLevel;
            final cooldownSec = widget.game.getShopOfferCooldownSeconds(offerId);
            final isAvailable = levelOk && cooldownSec == 0;
            final badge = t['badge'] as String;
            final amount = t['amount'] as int;

            return HoverScale(
              scale: isAvailable ? 1.04 : 1.0,
              onTap: () {
                if (!levelOk) {
                  _showToast('${t['name']} unlocks at Level $reqLevel!');
                  return;
                }
                if (cooldownSec > 0) {
                  _showToast(
                      '${t['name']} available again in ${DogStageInfo.formatDuration(cooldownSec)}!');
                  return;
                }
                _confirmShopOfferPurchase(
                  offerId: offerId,
                  title: t['name'] as String,
                  rewardText: '+${_fmt(amount)} Paw Coins',
                  priceText: t['price'] as String,
                  onConfirm: () {
                    if (widget.game.purchaseShopOffer(offerId, addCoins: amount)) {
                      setState(() {});
                      _showToast('+${_fmt(amount)} Paw Coins added!');
                    }
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 0.9,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFEF9EE),
                      Color(0xFFFAE8C8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD97706), width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2978350F),
                      offset: Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Column(
                        children: [
                          // Graphic Image
                          Expanded(
                            child: Center(
                              child: Image.asset(
                                'assets/ui/coins.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Coins Count
                          Text(
                            '${_fmt(amount)} Gold',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF451A03),
                              fontFamily: 'Lilita One',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),

                          // Package Name
                          Text(
                            t['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontFamily: 'Fredoka',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Buy Button
                          if (!isAvailable)
                            _buildLockedOfferButton(
                              levelOk: levelOk,
                              reqLevel: reqLevel,
                              cooldownSec: cooldownSec,
                              compact: compact,
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 7 : 12,
                                vertical: compact ? 2 : 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFEF3C7),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Text(
                                t['price'] as String,
                                style: TextStyle(
                                  color: const Color(0xFF3B1404),
                                  fontFamily: 'Lilita One',
                                  fontSize: compact ? 9.5 : 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Badge Pill if present (e.g. POPULAR, BEST VALUE)
                    if (badge.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lilita One',
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 8. Coins / Money Currency View (Moved from Packs to Currency) ──
  Widget _buildCoinsCurrencyView() {
    final coinTiers = [
      {'id': 'conv_pouch', 'name': 'Pouch of Coins', 'amount': 15000, 'costDiamonds': 25, 'badge': ''},
      {'id': 'conv_sack', 'name': 'Sack of Coins', 'amount': 60000, 'costDiamonds': 80, 'badge': ''},
      {'id': 'conv_chest', 'name': 'Chest of Coins', 'amount': 150000, 'costDiamonds': 160, 'badge': 'POPULAR'},
      {'id': 'conv_mountain', 'name': 'Mountain of Coins', 'amount': 250000, 'costDiamonds': 250, 'badge': 'BEST VALUE'},
      {'id': 'conv_treasury', 'name': 'Treasury of Coins', 'amount': 600000, 'costDiamonds': 550, 'badge': '+40% BONUS'},
      {'id': 'conv_royal', 'name': 'Royal Vault of Coins', 'amount': 1500000, 'costDiamonds': 1200, 'badge': 'MEGA HOARD'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _isCompact(MediaQuery.of(context).size);
        final spacing = _shopGridSpacing(compact);
        final padding = _shopGridPadding(compact);
        final ratio = _shopGridRatio(constraints, compact);

        return GridView.builder(
          padding: EdgeInsets.all(padding),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: ratio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: coinTiers.length,
          itemBuilder: (context, index) {
            final t = coinTiers[index];
            final offerId = t['id'] as String;
            final rule = ShopOfferRule.findById(offerId);
            final reqLevel = rule?.requiredLevel ?? 1;
            final levelOk = widget.game.level >= reqLevel;
            final cooldownSec = widget.game.getShopOfferCooldownSeconds(offerId);
            final isAvailable = levelOk && cooldownSec == 0;
            final badge = t['badge'] as String;
            final costDiamonds = t['costDiamonds'] as int;
            final coinsAmount = t['amount'] as int;
            final canAfford = widget.game.crystals >= costDiamonds && isAvailable;

            return HoverScale(
              scale: isAvailable ? 1.04 : 1.0,
              onTap: () {
                if (!levelOk) {
                  _showToast('${t['name']} unlocks at Level $reqLevel!');
                  return;
                }
                if (cooldownSec > 0) {
                  _showToast(
                      '${t['name']} available again in ${DogStageInfo.formatDuration(cooldownSec)}!');
                  return;
                }
                if (widget.game.crystals < costDiamonds) {
                  _showToast('Not enough Diamonds!');
                  return;
                }
                _confirmShopOfferPurchase(
                  offerId: offerId,
                  title: t['name'] as String,
                  rewardText: '+${_fmt(coinsAmount)} Paw Coins',
                  priceText: '$costDiamonds Diamonds',
                  onConfirm: () {
                    if (widget.game.purchaseShopOffer(
                      offerId,
                      costCrystals: costDiamonds,
                      addCoins: coinsAmount,
                    )) {
                      setState(() {});
                      _showToast('+${_fmt(coinsAmount)} Paw Coins added!');
                    } else {
                      _showToast('Not enough Diamonds!');
                    }
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(0, -0.4),
                    radius: 0.9,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFEF9EE),
                      Color(0xFFFAE8C8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD97706), width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2978350F),
                      offset: Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Column(
                        children: [
                          // Graphic Image
                          Expanded(
                            child: Center(
                              child: Image.asset(
                                'assets/ui/coins.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Coins Count
                          Text(
                            '+${_fmt(coinsAmount)} Coins',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF451A03),
                              fontFamily: 'Lilita One',
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),

                          // Package Name
                          Text(
                            t['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontFamily: 'Fredoka',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),

                          // Buy Button (Diamonds Price)
                          if (!isAvailable)
                            _buildLockedOfferButton(
                              levelOk: levelOk,
                              reqLevel: reqLevel,
                              cooldownSec: cooldownSec,
                              compact: compact,
                            )
                          else
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 7 : 12,
                                vertical: compact ? 2 : 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: canAfford
                                    ? const LinearGradient(
                                        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: canAfford
                                      ? const Color(0xFFFEF3C7)
                                      : Colors.white24,
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/ui/diamonds.png',
                                    width: compact ? 11 : 13,
                                    height: compact ? 11 : 13,
                                  ),
                                  SizedBox(width: compact ? 3 : 4),
                                  Text(
                                    '$costDiamonds',
                                    style: TextStyle(
                                      color: const Color(0xFF3B1404),
                                      fontFamily: 'Lilita One',
                                      fontSize: compact ? 9.5 : 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Badge Pill if present (e.g. POPULAR, BEST VALUE)
                    if (badge.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                offset: Offset(0, 1.5),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lilita One',
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Reusable Shop Item Card ──
  Widget _buildItemCard({
    required String name,
    required String image,
    required String element,
    required String subtitle,
    String? buildTime,
    String? ownershipText,
    required int costCoins,
    required int costDiamonds,
    required int requiredLevel,
    required bool isUnlocked,
    required bool canAfford,
    required VoidCallback onBuy,
    VoidCallback? onTapLocked,
    String? lockLabelOverride,
    bool isIslandLock = false,
    bool isNew = false,
  }) {
    final compact = _isCompact(MediaQuery.of(context).size);
    return Container(
      decoration: BoxDecoration(
        gradient: isUnlocked
            ? const RadialGradient(
                center: Alignment(0, -0.4),
                radius: 0.9,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFEF9EE),
                  Color(0xFFFAE8C8),
                ],
              )
            : const RadialGradient(
                center: Alignment(0, -0.4),
                radius: 0.9,
                colors: [
                  Color(0xFFEFE7DC),
                  Color(0xFFDBCFBE),
                  Color(0xFFBAA894),
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked ? const Color(0xFFD97706) : const Color(0xFF786C5F),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked
                ? const Color(0x2978350F)
                : const Color(0x22000000),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 8,
          vertical: compact ? 3 : 6,
        ),
        child: Column(
          children: [
            // Graphic Image with subtle lock overlay when locked
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(compact ? 0 : 4),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: Opacity(
                        opacity: isUnlocked ? 1.0 : 0.65,
                        child: Image.asset(
                          image,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    if (isNew)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: _buildNewBadge(compact),
                      ),
                    if (ownershipText != null)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 5 : 7,
                            vertical: compact ? 1.5 : 2,
                          ),
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? const Color(0xDD1E3A8A)
                                : const Color(0xDD7F1D1D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFEF08A),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            ownershipText,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lilita One',
                              fontSize: compact ? 8 : 9.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    if (buildTime != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 4 : 6,
                            vertical: compact ? 1.5 : 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xDD3B1404),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFBBF24),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: compact ? 8 : 10,
                                color: const Color(0xFFFDE047),
                              ),
                              SizedBox(width: compact ? 2 : 3),
                              Text(
                                buildTime,
                                style: TextStyle(
                                  color: const Color(0xFFFEF3C7),
                                  fontFamily: 'Lilita One',
                                  fontSize: compact ? 7.5 : 9.5,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!isUnlocked)
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          width: compact ? 20 : 26,
                          height: compact ? 20 : 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFEF08A), Color(0xFFD97706)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: const Color(0xFF3B1404),
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
                          child: Icon(
                            Icons.lock_rounded,
                            size: compact ? 11 : 14,
                            color: const Color(0xFF3B1404),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: compact ? 1 : 2),

            // Item Name
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isUnlocked
                    ? const Color(0xFF451A03)
                    : const Color(0xFF5A4D3E),
                fontFamily: 'Lilita One',
                fontSize: compact ? 9 : 13,
                fontWeight: FontWeight.w900,
                letterSpacing: compact ? 0 : 0.2,
              ),
            ),

            // Element or Subtitle
            Text(
              element,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isUnlocked
                    ? const Color(0xFFB45309)
                    : const Color(0xFF786C5F),
                fontFamily: 'Fredoka',
                fontSize: compact ? 7 : 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: compact ? 2 : 5),

            // Button or Level/Island Lock
            if (!isUnlocked)
              HoverScale(
                scale: 1.05,
                onTap: onTapLocked,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 7 : 11,
                    vertical: compact ? 3 : 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isIslandLock
                          ? const [Color(0xFF0F766E), Color(0xFF115E59)]
                          : const [Color(0xFF573B26), Color(0xFF3B2313)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFBBF24),
                      width: 1.3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
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
                        Icon(
                          isIslandLock
                              ? Icons.public_rounded
                              : Icons.lock_rounded,
                          size: compact ? 9 : 11,
                          color: const Color(0xFFFDE047),
                        ),
                        SizedBox(width: compact ? 3 : 4),
                        Text(
                          lockLabelOverride ?? 'LVL $requiredLevel REQUIRED',
                          style: TextStyle(
                            color: const Color(0xFFFEF3C7),
                            fontFamily: 'Lilita One',
                            fontSize: compact ? 8 : 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              HoverScale(
                scale: 1.06,
                onTap: canAfford ? onBuy : null,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 7 : 12,
                    vertical: compact ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: canAfford
                        ? const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: canAfford ? const Color(0xFFFEF3C7) : Colors.white24,
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (costCoins > 0) ...[
                        Image.asset('assets/ui/coins.png',
                            width: compact ? 11 : 13,
                            height: compact ? 11 : 13),
                        SizedBox(width: compact ? 3 : 4),
                        Text(
                          _fmt(costCoins),
                          style: TextStyle(
                            color: const Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: compact ? 9.5 : 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (costDiamonds > 0) ...[
                        if (costCoins > 0) const SizedBox(width: 5),
                        Image.asset('assets/ui/diamonds.png',
                            width: compact ? 11 : 13,
                            height: compact ? 11 : 13),
                        SizedBox(width: compact ? 3 : 4),
                        Text(
                          '$costDiamonds',
                          style: TextStyle(
                            color: const Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: compact ? 9.5 : 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (costCoins == 0 && costDiamonds == 0)
                        Text(
                          'FREE',
                          style: TextStyle(
                            color: const Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: compact ? 9.5 : 11,
                            fontWeight: FontWeight.w900,
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

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}
