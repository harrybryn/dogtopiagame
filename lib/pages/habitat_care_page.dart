import 'package:flutter/material.dart';
import '../state/game_controller.dart';
import '../models/habitat_model.dart';
import '../models/dog_model.dart';
import '../models/dog_evolution.dart';
import '../models/friend_visit_model.dart';
import '../models/habitat_catalog.dart';
import '../models/walkthrough_step.dart';
import '../components/common/hover_scale.dart';
import '../services/audio_service.dart';

class HabitatCarePage extends StatefulWidget {
  final GameController game;
  final HabitatModel habitat;
  final VoidCallback onBackToWorld;
  final Function(DogModel dog, String fromHabitatId)? onStartTransferDog;
  final int initialDogIndex;
  final Map<String, GlobalKey>? walkthroughKeys;

  /// When true this is a mock friend visit: feeding uses your kibble to help
  /// the friend's dog grow, but ownership actions (rename/transfer/sell) are
  /// unavailable and you do not earn their coins.
  final bool isVisitMode;
  final MockFriend? visitFriend;

  const HabitatCarePage({
    super.key,
    required this.game,
    required this.habitat,
    required this.onBackToWorld,
    this.onStartTransferDog,
    this.initialDogIndex = 0,
    this.walkthroughKeys,
    this.isVisitMode = false,
    this.visitFriend,
  });

  @override
  State<HabitatCarePage> createState() => _HabitatCarePageState();
}

class _HabitatCarePageState extends State<HabitatCarePage> {
  late int _selectedDogIndex;
  bool _showPetHeart = false;
  String? _toastMessage;

  @override
  void initState() {
    super.initState();
    _selectedDogIndex = widget.initialDogIndex.clamp(
      0,
      widget.habitat.dogs.isNotEmpty ? widget.habitat.dogs.length - 1 : 0,
    );
  }

  DogModel? get _currentDog {
    if (widget.habitat.dogs.isEmpty) return null;
    final idx = _selectedDogIndex.clamp(0, widget.habitat.dogs.length - 1);
    return widget.habitat.dogs[idx];
  }

  String _getInsideBackground() {
    return widget.habitat.insideAsset;
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)} K';
    return n.toString();
  }

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  void _petDog() {
    final dog = _currentDog;
    if (widget.isVisitMode) {
      widget.visitFriend?.helpCount += 1;
      _showToast('${dog?.name ?? 'Companion'} loved the attention!');
    } else {
      widget.game.addCoins(50);
      _showToast('+50 Paw Coins! Companion Loved!');
    }
    setState(() => _showPetHeart = true);
    SoundManager.instance.playPet();
    SoundManager.instance.playDogBark(isPuppy: dog?.isPuppy ?? true, force: true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showPetHeart = false);
    });
  }

  bool _feedVisitDog(DogModel dog) {
    final info = DogStageInfo.getInfo(dog);
    if (!widget.game.spendCurrency(kibble: info.kibbleCostPerFeed)) {
      SoundManager.instance.playSadWhimper();
      _showToast('Not enough Kibble! Produce more in the Kibble Bakery.');
      return false;
    }

    final prevLevel = dog.level;
    dog.feedProgress += 1;
    if (dog.feedProgress >= dog.feedRequired) {
      dog.feedProgress = 0;
      dog.level += 1;
      if (dog.level >= 12) {
        dog.stage = 'Adult';
      } else if (dog.level >= 4) {
        dog.stage = 'Young';
      }
    }

    widget.visitFriend?.helpCount += 1;
    SoundManager.instance.playFeed();
    if (dog.level > prevLevel) {
      SoundManager.instance.playLevelUp();
      SoundManager.instance.playDogBark(
        isPuppy: dog.stage == 'Puppy',
        force: true,
      );
      _showToast('LEVEL UP! ${dog.name} is now Level ${dog.level}!');
    }
    return true;
  }

  void _feedSteps(int steps) {
    final dog = _currentDog;
    if (dog == null) return;

    if (widget.isVisitMode) {
      for (int i = 0; i < steps; i++) {
        if (!_feedVisitDog(dog)) break;
      }
      setState(() {});
      return;
    }

    for (int i = 0; i < steps; i++) {
      final prevLevel = dog.level;
      final success = widget.game.feedDog(widget.habitat.id, dog.id);
      if (!success) {
        _showToast('Not enough Kibble! Produce more in the Kibble Bakery.');
        break;
      }
      if (dog.level > prevLevel) {
        _showToast('LEVEL UP! ${dog.name} is now Level ${dog.level}!');
      }
    }
    setState(() {});
  }

  void _renameCurrentDog() {
    final dog = _currentDog;
    if (dog == null) return;

    final controller = TextEditingController(text: dog.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1205),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 2),
        ),
        title: const Text(
          'RENAME DOG',
          style: TextStyle(
            color: Color(0xFFFEF08A),
            fontFamily: 'Lilita One',
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Lilita One',
            fontSize: 16,
          ),
          decoration: const InputDecoration(
            hintText: 'Enter dog name...',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF59E0B)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFFEF08A), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white70, fontFamily: 'Lilita One')),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                widget.game.renameDog(widget.habitat.id, dog.id, newName);
                setState(() {});
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF3B1404),
            ),
            child: const Text('SAVE',
                style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Lilita One')),
          ),
        ],
      ),
    );
  }

  void _showSellConfirmModal() {
    final dog = _currentDog;
    if (dog == null) return;
    final refund = 300 + dog.level * 100;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2A1205),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFBBF24), width: 2.5),
        ),
        title: Center(
          child: Text(
            'SELL ${dog.name.toUpperCase()}?',
            style: const TextStyle(
              color: Color(0xFFFEF08A),
              fontFamily: 'Lilita One',
              fontSize: 18,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to sell ${dog.name}?\nYou will receive +$refund Paw Coins.',
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
                Image.asset('assets/ui/coins.png', width: 22, height: 22),
                const SizedBox(width: 6),
                Text(
                  '+$refund Coins',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontFamily: 'Lilita One',
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white70, fontFamily: 'Lilita One')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.game.sellDog(widget.habitat.id, dog.id, refund);
              if (widget.habitat.dogs.isEmpty) {
                widget.onBackToWorld();
              } else {
                setState(() => _selectedDogIndex = 0);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('CONFIRM SELL',
                style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'Lilita One')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dog = _currentDog;
    final info = dog != null ? DogStageInfo.getInfo(dog) : null;
    final hasEnoughKibble =
        info != null && widget.game.kibble >= info.kibbleCostPerFeed;

    final media = MediaQuery.of(context);
    final screenW = media.size.width;
    final isCompact = screenW < 980;
    // Short landscape windows need smaller art and tighter spacing, otherwise
    // the dog info sits far below the fold and requires endless scrolling.
    final shortStage = media.size.height < 560;
    final pillW = isCompact ? 112.0 : 138.0;
    final pillH = isCompact ? 36.0 : 44.0;

    return Scaffold(
      backgroundColor: const Color(0xFF160702),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Habitat Inside Background ──
          Positioned.fill(
            child: Image.asset(
              _getInsideBackground(),
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),

          // ── 2. Unified Responsive Top Bar ──
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildBackButton(isCompact: isCompact),
                Expanded(
                  flex: isCompact ? 2 : 1,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildTitlePlaque(isCompact: isCompact),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  flex: isCompact ? 3 : 0,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/diamonds.png',
                            value: '${widget.game.crystals}',
                            onPlus: widget.onBackToWorld,
                            pillW: pillW,
                            pillH: pillH,
                          ),
                          SizedBox(width: isCompact ? 6 : 8),
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/coins.png',
                            value: _fmt(widget.game.coins),
                            onPlus: widget.onBackToWorld,
                            pillW: pillW,
                            pillH: pillH,
                          ),
                          SizedBox(width: isCompact ? 6 : 8),
                          _buildWoodResourcePill(
                            iconAsset: 'assets/ui/dogfood.png',
                            value: _fmt(widget.game.kibble),
                            onPlus: widget.onBackToWorld,
                            pillW: pillW,
                            pillH: pillH,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 3. Main Stage Content Area ──
          Positioned(
            top: isCompact ? 74 : 86,
            bottom: 18,
            left: isCompact ? 14 : 36,
            right: isCompact ? 14 : 48,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1060),
                // Always side-by-side, like the desktop layout. FittedBox
                // scales each column down on short landscape windows so no
                // scrolling is needed to reach the dog info.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 360,
                          child: _buildDogStage(
                            dog,
                            info,
                            hasEnoughKibble,
                            compact: shortStage,
                          ),
                        ),
                      ),
                    ),
                    if (dog != null && info != null) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 400,
                            child: _buildStatCard(
                              dog,
                              info,
                              compact: shortStage,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── 4. Toast Notification Overlay ──
          if (_toastMessage != null)
            Positioned(
              top: isCompact ? 122 : 76,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xEE1E0A02),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    _toastMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFEF08A),
                      fontFamily: 'Lilita One',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
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
      key: widget.walkthroughKeys?[WalkthroughTargets.careBackButton],
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
    final double plaqueW = isCompact ? 180.0 : 280.0;
    final double plaqueH = plaqueW * (160.0 / 320.0);
    return SizedBox(
      width: plaqueW,
      height: plaqueH,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/ui/HabitatCare.png',
            width: plaqueW,
            height: plaqueH,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          Positioned(
            left: plaqueW * (104.0 / 320.0),
            right: plaqueW * (37.0 / 320.0),
            top: 0,
            bottom: 0,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.habitat.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Lilita One',
                    fontSize: isCompact ? 13.0 : 17.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    shadows: const [
                      Shadow(
                        color: Color(0xFF3B1404),
                        offset: Offset(0, 2),
                        blurRadius: 2,
                      ),
                      Shadow(
                        color: Colors.black,
                        offset: Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDogStage(
    DogModel? dog,
    DogStageInfo? info,
    bool hasEnoughKibble, {
    bool compact = false,
  }) {
    final artH = compact ? 132.0 : 220.0;
    final artW = compact ? 150.0 : 220.0;
    final shadowH = compact ? 18.0 : 26.0;
    final gap = compact ? 4.0 : 8.0;

    return dog == null || info == null
                      ? Center(
                          child: Text(
                            'No dogs living here yet!\nAdopt puppies from the Shop.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontFamily: 'Lilita One',
                              fontSize: 16,
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            key: widget.walkthroughKeys?[
                                WalkthroughTargets.careDogStation],
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            // 1. Dog Name Plaque with Edit Pencil & Level Pill + Left/Right arrows
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.habitat.dogs.length > 1)
                                  HoverScale(
                                    scale: 1.15,
                                    onTap: () {
                                      setState(() {
                                        _selectedDogIndex = (_selectedDogIndex - 1 + widget.habitat.dogs.length) %
                                            widget.habitat.dogs.length;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xCC290E02),
                                        border: Border.all(
                                            color: const Color(0xFFFBBF24), width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x40000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                                          size: 13, color: Color(0xFFFEF08A)),
                                    ),
                                  ),

                                HoverScale(
                                  scale: 1.05,
                                  onTap:
                                      widget.isVisitMode ? null : _renameCurrentDog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFFFBBF24), width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!widget.isVisitMode) ...[
                                          const Icon(Icons.edit_rounded,
                                              size: 13,
                                              color: Color(0xFF78350F)),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          dog.name.toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFF451A03),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'LV ${dog.level}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Lilita One',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (widget.habitat.dogs.length > 1)
                                  HoverScale(
                                    scale: 1.15,
                                    onTap: () {
                                      setState(() {
                                        _selectedDogIndex =
                                            (_selectedDogIndex + 1) % widget.habitat.dogs.length;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xCC290E02),
                                        border: Border.all(
                                            color: const Color(0xFFFBBF24), width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x40000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.arrow_forward_ios_rounded,
                                          size: 13, color: Color(0xFFFEF08A)),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: compact ? 3 : 6),

                            // 2. The Companion Dog with Ground Contact Shadow & Pet interaction
                            GestureDetector(
                              key: widget.isVisitMode
                                  ? const Key('friend_pet_dog')
                                  : null,
                              behavior: HitTestBehavior.opaque,
                              onTap: _petDog,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                clipBehavior: Clip.none,
                                children: [
                                  // Radial Ground Shadow
                                  Container(
                                    width: artW,
                                    height: shadowH,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(
                                          Radius.elliptical(artW, shadowH)),
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0xBB0F0702),
                                          Color(0x330F0702),
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.6, 1.0],
                                      ),
                                    ),
                                  ),

                                  // Sitting Dog Sprite
                                  Image.asset(
                                    info.sitImg,
                                    height: artH,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),

                                  // Floating Heart Burst on Pet
                                  if (_showPetHeart)
                                    Positioned(
                                      top: 20,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFEC4899),
                                        ),
                                        child: const Icon(Icons.favorite_rounded,
                                            color: Colors.white, size: 28),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(height: gap),

                            // 3. Four-Segment Feed Progress Meter
                            Container(
                              width: 280,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xCC000000),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0x66B45309), width: 1.2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x66000000),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header Row: FEED PROGRESS (x/4) & NEXT LEVEL
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text(
                                                'FEED PROGRESS ',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 10.5,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              Text(
                                                '(${dog.feedProgress}/4)',
                                                style: const TextStyle(
                                                  color: Color(0xFFFEF08A),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF451A03),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFFF59E0B),
                                              width: 1),
                                        ),
                                        child: Text(
                                          'NEXT LEVEL ${dog.level + 1}',
                                          style: const TextStyle(
                                            color: Color(0xFFFEF08A),
                                            fontFamily: 'Lilita One',
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // 4 Segmented Slots
                                  Row(
                                    children: List.generate(4, (index) {
                                      final isFilled = index < dog.feedProgress;
                                      return Expanded(
                                        child: Container(
                                          height: 18,
                                          margin: EdgeInsets.only(
                                              right: index < 3 ? 4 : 0),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            gradient: isFilled
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFFFDE047),
                                                      Color(0xFFF59E0B),
                                                    ],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  )
                                                : null,
                                            color: isFilled
                                                ? null
                                                : const Color(0xFF18181B),
                                            border: Border.all(
                                              color: isFilled
                                                  ? const Color(0xFFFEF08A)
                                                  : const Color(0xFF3F3F46),
                                              width: 1,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: isFilled
                                              ? const Icon(
                                                  Icons.check_rounded,
                                                  size: 13,
                                                  color: Color(0xFF451A03),
                                                )
                                              : null,
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: gap),

                            // 4. Dual Action Feed Buttons (FEED & FEED x4)
                            SizedBox(
                              key: widget.walkthroughKeys?[
                                  WalkthroughTargets.careFeedButton],
                              width: 280,
                              child: Row(
                                children: [
                                  // Primary Feed Button
                                  Expanded(
                                    flex: 3,
                                    child: HoverScale(
                                      scale: hasEnoughKibble ? 1.05 : 1.0,
                                      onTap: hasEnoughKibble
                                          ? () => _feedSteps(1)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          gradient: hasEnoughKibble
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFBBF24),
                                                    Color(0xFFD97706),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                )
                                              : const LinearGradient(
                                                  colors: [
                                                    Color(0xFF9CA3AF),
                                                    Color(0xFF6B7280),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFFEF3C7),
                                              width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/ui/dogfood.png',
                                              width: 20,
                                              height: 20,
                                              fit: BoxFit.contain,
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'FEED',
                                                  style: TextStyle(
                                                    color: Color(0xFF3B1404),
                                                    fontFamily: 'Lilita One',
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w900,
                                                    height: 1.0,
                                                  ),
                                                ),
                                                Text(
                                                  '${info.kibbleCostPerFeed} Kibble',
                                                  style: const TextStyle(
                                                    color: Color(0xFF451A03),
                                                    fontFamily: 'Fredoka',
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Quick Feed x4 (or remaining)
                                  Expanded(
                                    flex: 2,
                                    child: HoverScale(
                                      scale: hasEnoughKibble ? 1.05 : 1.0,
                                      onTap: hasEnoughKibble
                                          ? () => _feedSteps(
                                              4 - dog.feedProgress)
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFDE047),
                                              Color(0xFFF59E0B),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white, width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          'FEED X${4 - dog.feedProgress}',
                                          style: const TextStyle(
                                            color: Color(0xFF3B1404),
                                            fontFamily: 'Lilita One',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.3,
                                            height: 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
  }

  Widget _buildStatCard(DogModel dog, DogStageInfo info,
      {bool compact = false}) {
    final vGap = compact ? 7.0 : 14.0;
    return Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 26,
                          vertical: compact ? 10 : 22),
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.4),
                          radius: 0.9,
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFFFF9EC),
                            Color(0xFFFCE9C8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: const Color(0xFFFBBF24), width: 3.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xB3000000),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: ELEMENTS & SOURCE
                          Row(
                            children: [
                              // Elements
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'ELEMENTS',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF059669),
                                                Color(0xFF15803D),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: const Color(0xFF6EE7B7),
                                                width: 1),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.star_rounded,
                                                    color: Colors.white,
                                                    size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dog.element.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'Lilita One',
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Source
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'SOURCE',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFFEC4899),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                  Icons.favorite_rounded,
                                                  color: Colors.white,
                                                  size: 13),
                                            ),
                                            const SizedBox(width: 5),
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFFF59E0B),
                                              ),
                                              alignment: Alignment.center,
                                              child: Image.asset(
                                                'assets/ui/coins.png',
                                                width: 14,
                                                height: 14,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Expanded(
                                              child: Text(
                                                'STARTER / SANCTUARY',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Color(0xFF78350F),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: vGap),

                              const Divider(
                                  color: Color(0x3378350F), height: 1),
                              SizedBox(height: vGap),

                              // Row 2: INCOME & MASTER POINTS
                              Row(
                                children: [
                                  // Income
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'INCOME',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(
                                                'assets/ui/coins.png',
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '+${info.coinRatePerMin}/min',
                                                style: const TextStyle(
                                                  color: Color(0xFF3B1404),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Master Points
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'MASTER POINTS',
                                          style: TextStyle(
                                            color: Color(0xFF78350F),
                                            fontFamily: 'Lilita One',
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.emoji_events_rounded,
                                                color: Color(0xFFF59E0B),
                                                size: 24,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${dog.level * 40 + 15}',
                                                style: const TextStyle(
                                                  color: Color(0xFF3B1404),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // The description is the tallest block. Drop it
                              // on short windows so the card fits without a scroll.
                              if (!compact) ...[
                                SizedBox(height: vGap),
                                const Divider(
                                    color: Color(0x3378350F), height: 1),
                                SizedBox(height: vGap),
                                const Text(
                                  'DESCRIPTION',
                                  style: TextStyle(
                                    color: Color(0xFF78350F),
                                    fontFamily: 'Lilita One',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0x66FEF3C7),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0x40D97706), width: 1),
                                  ),
                                  child: Text(
                                    info.description +
                                        (info.isHusky
                                            ? ' He loves frosty adventures and hearty meat feasts on the tundra!'
                                            : ' He loves hearty kibble feasts and cozy afternoon naps on the lawn!'),
                                    style: const TextStyle(
                                      color: Color(0xFF3B1404),
                                      fontFamily: 'Fredoka',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (compact) ...[
                                Padding(
                                  padding: EdgeInsets.only(top: vGap + 2),
                                  child: Text(
                                    info.description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF78350F),
                                      fontFamily: 'Fredoka',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Row 4: Ownership actions are hidden on a friend visit.
                              if (!widget.isVisitMode)
                                Row(
                                  children: [
                                  // TRANSFER HABITAT Button
                                  Expanded(
                                    child: HoverScale(
                                      scale: 1.05,
                                      onTap: () {
                                        final compatibleOtherHabs = widget
                                            .game.placedHabitats
                                            .where((h) =>
                                                h.type == 'habitat' &&
                                                h.id != widget.habitat.id &&
                                                h.dogs.length < 4 &&
                                                HabitatCatalog
                                                    .isHabitatCompatible(
                                                  habitatCatalogId: h.habitatId,
                                                  breedId: dog.breedId,
                                                  element: dog.element,
                                                ))
                                            .toList();

                                        if (compatibleOtherHabs.isEmpty) {
                                          final anyOtherPlaced = widget
                                              .game.placedHabitats
                                              .any((h) =>
                                                  h.type == 'habitat' &&
                                                  h.id != widget.habitat.id &&
                                                  HabitatCatalog
                                                      .isHabitatCompatible(
                                                    habitatCatalogId:
                                                        h.habitatId,
                                                    breedId: dog.breedId,
                                                    element: dog.element,
                                                  ));
                                          if (anyOtherPlaced) {
                                            _showToast(
                                                'Other compatible habitats are full (4/4 dogs)!');
                                          } else {
                                            _showToast(
                                                'No other compatible habitat placed! Build one first.');
                                          }
                                          return;
                                        }

                                        if (widget.onStartTransferDog != null) {
                                          widget.onStartTransferDog!(
                                              dog, widget.habitat.id);
                                        } else {
                                          widget.onBackToWorld();
                                        }
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: compact ? 8 : 12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF38BDF8),
                                              Color(0xFF0284C7),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white, width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x400284C7),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.open_with_rounded,
                                                  size: 17, color: Colors.white),
                                              SizedBox(width: 6),
                                              Text(
                                                'TRANSFER HABITAT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // SELL DOG Button
                                  Expanded(
                                    child: HoverScale(
                                      scale: 1.05,
                                      onTap: _showSellConfirmModal,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: compact ? 8 : 12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFF59E0B),
                                              Color(0xFFD97706),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFFEF3C7),
                                              width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40D97706),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Image.asset(
                                                'assets/ui/coins.png',
                                                width: 18,
                                                height: 18,
                                                fit: BoxFit.contain,
                                              ),
                                              const SizedBox(width: 6),
                                              const Text(
                                                'SELL DOG',
                                                style: TextStyle(
                                                  color: Color(0xFF3B1404),
                                                  fontFamily: 'Lilita One',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
  }

  Widget _buildWoodResourcePill({
    required String iconAsset,
    required String value,
    required VoidCallback onPlus,
    double pillW = 138.0,
    double pillH = 44.0,
  }) {
    final double iconSize = (pillH * 0.52).clamp(16.0, 24.0);
    final double plusSize = (pillH * 0.46).clamp(16.0, 22.0);
    final double fontSize = (pillH * 0.34).clamp(12.0, 15.0);

    return HoverScale(
      scale: 1.05,
      onTap: onPlus,
      child: SizedBox(
        width: pillW,
        height: pillH,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
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
            Positioned.fill(
              child: Image.asset(
                'assets/ui/ResourcesPlaceHolder.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
              ),
            ),
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
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: pillW * 0.82 - plusSize / 2,
              top: (pillH - plusSize) / 2,
              width: plusSize,
              height: plusSize,
              child: Container(
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
          ],
        ),
      ),
    );
  }
}