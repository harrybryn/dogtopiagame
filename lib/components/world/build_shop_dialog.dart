import 'package:flutter/material.dart';
import '../../models/habitat_catalog.dart';
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

class _BuildShopDialogState extends State<BuildShopDialog> {
  late String _activeTab; // 'categories' | 'diamonds' | 'habitats' | 'dogs' | 'buildings' | 'decor' | 'packs'
  String _dogFilter = 'all'; // 'all' | 'garden' | 'desert' | 'snow' | 'forest' | 'beach' | 'legendary'
  String _currencyTab = 'diamonds'; // 'diamonds' | 'coins'
  String? _toastMessage;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  String _getBannerTitle() {
    switch (_activeTab) {
      case 'categories':
        return 'SHOP CATEGORIES';
      case 'diamonds':
        return _currencyTab == 'diamonds'
            ? 'BUY DIAMONDS (PHP ₱)'
            : 'BUY COINS (DIAMONDS)';
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
    // Exactly matching React max-w-5xl (1024px) aspect 3:2 and max-h-[92vh]
    final double maxModalW = (screenSize.width - 32.0).clamp(320.0, 1024.0);
    final double maxModalH = (screenSize.height * 0.92).clamp(240.0, 682.0);
    double modalW = maxModalW;
    double modalH = modalW * (2.0 / 3.0);
    if (modalH > maxModalH) {
      modalH = maxModalH;
      modalW = modalH * (3.0 / 2.0);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: SizedBox(
          width: modalW,
          height: modalH,
          child: Stack(
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

              // ── 4. Main Parchment Board Area (Padded to fit perfectly inside wooden frame) ──
              Positioned(
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
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              HoverScale(
                                scale: 1.05,
                                onTap: () => setState(() => _activeTab = 'categories'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
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
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_back,
                                          size: 14, color: Color(0xFF3B1404)),
                                      SizedBox(width: 4),
                                      Text(
                                        'CATEGORIES',
                                        style: TextStyle(
                                          color: Color(0xFF3B1404),
                                          fontFamily: 'Lilita One',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Currency tabs when in diamonds category
                              if (_activeTab == 'diamonds')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildCurrencyFilterTab('diamonds', 'DIAMONDS'),
                                    _buildCurrencyFilterTab('coins', 'COINS'),
                                  ],
                                ),

                              // Dog Habitat tabs
                              if (_activeTab == 'dogs')
                                Row(
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
                            ],
                          ),
                        ),
                      ] else ...[
                        // Matching height spacer so Categories panel is the exact same size as other panels
                        const SizedBox(height: 36),
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
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  borderRadius: BorderRadius.circular(18),
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
                      child: Center(
                        child: Image.asset(
                          cat['image'] as String,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title
                    Text(
                      cat['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF451A03),
                        fontFamily: 'Lilita One',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),

                    // Description Subtitle
                    Text(
                      cat['desc'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF78350F),
                        fontFamily: 'Fredoka',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Action Pill: "EXPLORE"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
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
                      child: const Text(
                        'EXPLORE',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Lilita One',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
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
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
            final isUnlocked = widget.game.level >= hab.requiredLevel;

            return _buildItemCard(
              name: hab.name,
              image: hab.assetImage,
              element: hab.element,
              subtitle: '${hab.sizeW}×${hab.sizeH} Plot · +${hab.coinRate}',
              costCoins: hab.costCoins,
              costDiamonds: hab.costDiamonds,
              requiredLevel: hab.requiredLevel,
              isUnlocked: isUnlocked,
              canAfford: canAfford,
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
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
            final isUnlocked = widget.game.level >= dog.requiredLevel;

            // Check if player has an available compatible habitat with open slot (<4 dogs)
            final compatibleHabs = widget.game.placedHabitats
                .where((h) =>
                    h.type == 'habitat' &&
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
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
            final isUnlocked = widget.game.level >= item.requiredLevel;

            return _buildItemCard(
              name: item.name,
              image: item.assetImage,
              element: 'Care Facility',
              subtitle: '${item.sizeW}×${item.sizeH} Plot · ${item.description}',
              costCoins: item.costCoins,
              costDiamonds: item.costDiamonds,
              requiredLevel: item.requiredLevel,
              isUnlocked: isUnlocked,
              canAfford: canAfford,
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
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
            final isUnlocked = widget.game.level >= item.requiredLevel;

            return _buildItemCard(
              name: item.name,
              image: item.assetImage,
              element: 'Island Decor',
              subtitle: '${item.sizeW}×${item.sizeH} · Ornaments',
              costCoins: item.costCoins,
              costDiamonds: item.costDiamonds,
              requiredLevel: item.requiredLevel,
              isUnlocked: isUnlocked,
              canAfford: canAfford,
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
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
            final costCoins = pack['costCoins'] as int;
            final costDiamonds = pack['costDiamonds'] as int;
            final canAfford = widget.game.coins >= costCoins &&
                widget.game.crystals >= costDiamonds;

            return _buildItemCard(
              name: pack['name'] as String,
              image: pack['image'] as String,
              element: pack['element'] as String,
              subtitle: 'Instant Resource Pack',
              costCoins: costCoins,
              costDiamonds: costDiamonds,
              requiredLevel: 1,
              isUnlocked: true,
              canAfford: canAfford,
              onBuy: () {
                if (widget.game.spendCurrency(
                    coins: costCoins, crystals: costDiamonds)) {
                  final kibbleAdd = pack['kibble'] as int;
                  final coinsAdd = pack['coins'] as int;
                  if (kibbleAdd > 0) widget.game.addKibble(kibbleAdd);
                  if (coinsAdd > 0) widget.game.addCoins(coinsAdd);
                  _showToast('Purchased ${pack['name']}!');
                }
              },
            );
          },
        );
      },
    );
  }

  // ── 7. Diamonds / Currency View ──
  Widget _buildDiamondsView() {
    if (_currencyTab == 'coins') {
      return _buildCoinsCurrencyView();
    }
    final tiers = [
      {'name': 'Pile of Diamonds', 'amount': 50, 'price': '₱49.00', 'badge': ''},
      {'name': 'Bag of Diamonds', 'amount': 150, 'price': '₱129.00', 'badge': ''},
      {'name': 'Chest of Diamonds', 'amount': 500, 'price': '₱399.00', 'badge': 'POPULAR'},
      {'name': 'Vault of Diamonds', 'amount': 1200, 'price': '₱799.00', 'badge': 'BEST VALUE'},
      {'name': 'Treasury of Diamonds', 'amount': 2800, 'price': '₱1,499.00', 'badge': '+60% EXTRA'},
      {'name': 'Mountain of Diamonds', 'amount': 6500, 'price': '₱2,999.00', 'badge': 'MEGA HOARD'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
            final badge = t['badge'] as String;

            return HoverScale(
              scale: 1.04,
              onTap: () {
                widget.game.addDiamonds(t['amount'] as int);
                _showToast('+${t['amount']} Star Crystals added!');
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(10),
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Lilita One',
                                fontSize: 11.5,
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
      {'name': 'Pouch of Coins', 'amount': 15000, 'costDiamonds': 25, 'badge': ''},
      {'name': 'Sack of Coins', 'amount': 60000, 'costDiamonds': 80, 'badge': ''},
      {'name': 'Chest of Coins', 'amount': 150000, 'costDiamonds': 160, 'badge': 'POPULAR'},
      {'name': 'Mountain of Coins', 'amount': 250000, 'costDiamonds': 250, 'badge': 'BEST VALUE'},
      {'name': 'Treasury of Coins', 'amount': 600000, 'costDiamonds': 550, 'badge': '+40% BONUS'},
      {'name': 'Royal Vault of Coins', 'amount': 1500000, 'costDiamonds': 1200, 'badge': 'MEGA HOARD'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 10.0;
        final double cardW = (constraints.maxWidth - spacing * 2) / 3;
        final double cardH = (constraints.maxHeight - spacing) / 2;
        final double ratio = cardW / cardH;

        return GridView.builder(
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
            final badge = t['badge'] as String;
            final costDiamonds = t['costDiamonds'] as int;
            final coinsAmount = t['amount'] as int;
            final canAfford = widget.game.crystals >= costDiamonds;

            return HoverScale(
              scale: 1.04,
              onTap: () {
                if (widget.game.spendCurrency(crystals: costDiamonds)) {
                  widget.game.addCoins(coinsAmount);
                  _showToast('+${_fmt(coinsAmount)} Paw Coins added!');
                } else {
                  _showToast('Not enough Diamonds!');
                }
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: canAfford
                                  ? const LinearGradient(
                                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                              borderRadius: BorderRadius.circular(10),
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
                                  width: 13,
                                  height: 13,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$costDiamonds',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Lilita One',
                                    fontSize: 11.5,
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
    required int costCoins,
    required int costDiamonds,
    required int requiredLevel,
    required bool isUnlocked,
    required bool canAfford,
    required VoidCallback onBuy,
  }) {
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            // Graphic Image with hover scale and drop shadow (solid black silhouette when locked)
            Expanded(
              child: Center(
                child: Image.asset(
                  image,
                  color: isUnlocked ? null : Colors.black,
                  colorBlendMode: isUnlocked ? null : BlendMode.srcIn,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 2),

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
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),

            // Button or Level Lock
            if (!isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF786C5F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF9CA3AF), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'LVL $requiredLevel REQUIRED',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              )
            else
              HoverScale(
                scale: 1.06,
                onTap: canAfford ? onBuy : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                        Image.asset('assets/ui/coins.png', width: 13, height: 13),
                        const SizedBox(width: 4),
                        Text(
                          _fmt(costCoins),
                          style: const TextStyle(
                            color: Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (costDiamonds > 0) ...[
                        if (costCoins > 0) const SizedBox(width: 5),
                        Image.asset('assets/ui/diamonds.png',
                            width: 13, height: 13),
                        const SizedBox(width: 4),
                        Text(
                          '$costDiamonds',
                          style: const TextStyle(
                            color: Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                      if (costCoins == 0 && costDiamonds == 0)
                        const Text(
                          'FREE',
                          style: TextStyle(
                            color: Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: 11,
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
