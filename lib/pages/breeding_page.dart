import 'dart:async';
import 'package:flutter/material.dart';
import '../components/common/generic_modal.dart';
import '../components/common/hover_scale.dart';
import '../models/dog_evolution.dart';
import '../models/dog_model.dart';
import '../services/audio_service.dart';
import '../state/game_controller.dart';

/// Minimum dog level required for breeding (Young Pup stage or Adult).
const int minBreedingLevel = 4;

class BreedingDialog extends StatefulWidget {
  final GameController game;
  final VoidCallback? onClose;

  const BreedingDialog({super.key, required this.game, this.onClose});

  @override
  State<BreedingDialog> createState() => _BreedingDialogState();
}

class BreedingPage extends StatelessWidget {
  final GameController game;
  final VoidCallback onBackToWorld;

  const BreedingPage({
    super.key,
    required this.game,
    required this.onBackToWorld,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120601),
      body: BreedingDialog(game: game, onClose: onBackToWorld),
    );
  }
}

class _BreedingDialogState extends State<BreedingDialog> {
  String? _parent1Id;
  String? _parent2Id;
  String _breedingState = 'idle'; // 'idle' | 'breeding' | 'hatched'
  Map<String, String>? _hatchedPup;
  Timer? _breedTimer;

  List<DogModel> get _allOwnedDogs =>
      widget.game.currentIslandHabitats.expand((h) => h.dogs).toList();

  List<DogModel> get _eligibleDogs =>
      _allOwnedDogs.where((d) => d.level >= minBreedingLevel).toList();

  @override
  void dispose() {
    _breedTimer?.cancel();
    super.dispose();
  }

  void _showErrorSnack(String message) {
    SoundManager.instance.playSadWhimper();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFEF08A),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startBreeding(DogModel? p1, DogModel? p2) {
    if (p1 == null || p2 == null) {
      _showErrorSnack(
        'Select two Level $minBreedingLevel+ dogs of the same breed!',
      );
      return;
    }
    if (p1.level < minBreedingLevel || p2.level < minBreedingLevel) {
      _showErrorSnack(
        'Both dogs must be at least Level $minBreedingLevel (Young Pup or Adult)!',
      );
      return;
    }
    if (DogStageInfo.getBreedPrefix(p1.breedId) !=
        DogStageInfo.getBreedPrefix(p2.breedId)) {
      _showErrorSnack('Only dogs of the same breed can be paired!');
      return;
    }
    if (!widget.game.hasHabitatSpace) {
      _showErrorSnack(
        'All habitats are full (max 4 dogs each). Make room first!',
      );
      return;
    }
    if (widget.game.coins < 500) {
      _showErrorSnack('You need 500 Paw Coins to breed!');
      return;
    }

    widget.game.addCurrency(coins: -500, xp: 100);

    setState(() {
      _breedingState = 'breeding';
      SoundManager.instance.playBake();
    });

    _breedTimer?.cancel();
    _breedTimer = Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      final breedName = DogStageInfo.getBreedDisplayName(p1.breedId);
      final placedHabitat = widget.game.addBredPuppy(p1.breedId, p1.element);
      final previewPup = DogModel(
        id: 'preview',
        breedId: p1.breedId,
        name: breedName,
        level: 1,
        feedProgress: 0,
        stage: 'Puppy',
        element: p1.element,
        habitatId: '',
        habitatName: '',
      );
      final pupImg = DogStageInfo.getInfo(previewPup).sitImg;

      setState(() {
        _breedingState = 'hatched';
        SoundManager.instance.playLevelUp();
        SoundManager.instance.playDogBark(isPuppy: true, force: true);
        _hatchedPup = {
          'name': 'Purebred $breedName Pup',
          'img': pupImg,
          'rarity': 'Same-Breed Offspring',
          'desc': placedHabitat != null
              ? 'Born from ${p1.name} & ${p2.name}! Sent to $placedHabitat.'
              : 'Born from ${p1.name} & ${p2.name}!',
        };
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final allDogs = _allOwnedDogs;
    final eligible = _eligibleDogs;
    final DogModel? parent1 = eligible.isEmpty
        ? null
        : eligible.firstWhere(
            (d) => d.id == _parent1Id,
            orElse: () => eligible.first,
          );
    final String? p1Prefix = parent1 != null
        ? DogStageInfo.getBreedPrefix(parent1.breedId)
        : null;
    final List<DogModel> compatiblePartners = parent1 == null
        ? const []
        : eligible
              .where(
                (d) =>
                    d.id != parent1.id &&
                    DogStageInfo.getBreedPrefix(d.breedId) == p1Prefix,
              )
              .toList();
    final DogModel? parent2 = compatiblePartners.isEmpty
        ? null
        : compatiblePartners.firstWhere(
            (d) => d.id == _parent2Id,
            orElse: () => compatiblePartners.first,
          );
    final bool canBreed = parent1 != null && parent2 != null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top info banner + Coin Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/itemsInShop/building/BreedingDen.webp',
                width: 34,
                height: 34,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Same-Breed Purebred Pairing',
                      style: TextStyle(
                        fontFamily: 'Lilita One',
                        fontSize: 13.5,
                        color: Color(0xFF451A03),
                      ),
                    ),
                    Text(
                      'Uses dogs on this island • Level $minBreedingLevel+ required',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78350F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B1404),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFBBF24),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/ui/coins.png', width: 14, height: 14),
                    const SizedBox(width: 4),
                    Text(
                      GameController.formatCoins(widget.game.coins),
                      style: const TextStyle(
                        fontFamily: 'Lilita One',
                        fontSize: 12,
                        color: Color(0xFFFEF08A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        if (_breedingState == 'idle') ...[
          // Parent cards row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildParentCard(
                  label: 'PARENT 1',
                  selectedDog: parent1,
                  options: eligible,
                  emptyText: allDogs.isEmpty
                      ? 'No dogs on this island'
                      : 'No Level $minBreedingLevel+ dogs yet',
                  onChanged: (id) => setState(() {
                    _parent1Id = id;
                    _parent2Id = null;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 52, left: 6, right: 6),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF472B6), Color(0xFFDB2777)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              Expanded(
                child: _buildParentCard(
                  label: 'PARENT 2',
                  selectedDog: parent2,
                  options: compatiblePartners,
                  emptyText: parent1 == null
                      ? 'Need Level $minBreedingLevel+ Parent 1'
                      : 'Need another Lv $minBreedingLevel+ ${DogStageInfo.getBreedDisplayName(parent1.breedId)}',
                  onChanged: (id) => setState(() => _parent2Id = id),
                ),
              ),
            ],
          ),

          if (!canBreed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: Text(
                parent1 == null
                    ? 'Raise at least two same-breed dogs on this island to Level $minBreedingLevel+ (Young Pup)!'
                    : 'Adopt or raise a second ${DogStageInfo.getBreedDisplayName(parent1.breedId)} on this island to Level $minBreedingLevel+.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF78350F),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          Center(
            child: HoverScale(
              scale: canBreed ? 1.05 : 1.0,
              onTap: canBreed ? () => _startBreeding(parent1, parent2) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: canBreed
                        ? const [Color(0xFFF472B6), Color(0xFFDB2777)]
                        : const [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: canBreed
                        ? const Color(0xFFFBCFE8)
                        : const Color(0xFFD1D5DB),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'START BREEDING',
                      style: TextStyle(
                        fontFamily: 'Lilita One',
                        fontSize: 14,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x33000000),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/ui/coins.png',
                            width: 13,
                            height: 13,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '500',
                            style: TextStyle(
                              fontFamily: 'Lilita One',
                              fontSize: 12.5,
                              color: Color(0xFFFEF08A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else if (_breedingState == 'breeding') ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/itemsInShop/building/BreedingDen.webp',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 10),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    color: Color(0xFFDB2777),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Incubating Purebred Puppy...',
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    color: Color(0xFF78350F),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ] else if (_breedingState == 'hatched' && _hatchedPup != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF59E0B), width: 2),
            ),
            child: Column(
              children: [
                const Text(
                  'PUPPY HATCHED!',
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    color: Color(0xFFB45309),
                    fontSize: 19,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF59E0B),
                      width: 2,
                    ),
                  ),
                  child: Image.asset(
                    _hatchedPup!['img'] ??
                        'assets/itemsInShop/dogs/BulldogPuppySit.png',
                    width: 78,
                    height: 78,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _hatchedPup!['name']!,
                  style: const TextStyle(
                    fontFamily: 'Lilita One',
                    color: Color(0xFF3B1404),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _hatchedPup!['rarity']!,
                  style: const TextStyle(
                    color: Color(0xFFDB2777),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _hatchedPup!['desc']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF78350F),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                HoverScale(
                  scale: 1.05,
                  onTap: () {
                    setState(() {
                      _breedingState = 'idle';
                      _hatchedPup = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFEF3C7),
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'BREED ANOTHER',
                      style: TextStyle(
                        fontFamily: 'Lilita One',
                        color: Color(0xFF3B1404),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    return GenericModal(
      title: 'BREEDING DEN',
      maxWidth: 800,
      scrollable: false,
      onClose: widget.onClose ?? () => Navigator.of(context).pop(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needsScale =
              constraints.maxWidth < 500 || constraints.maxHeight < 305;

          if (needsScale) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(width: 540, child: content),
              ),
            );
          }

          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(width: constraints.maxWidth, child: content),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParentCard({
    required String label,
    required DogModel? selectedDog,
    required List<DogModel> options,
    required String emptyText,
    required ValueChanged<String> onChanged,
  }) {
    final DogStageInfo? selectedInfo = selectedDog != null
        ? DogStageInfo.getInfo(selectedDog)
        : null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD97706), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF451A03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Lilita One',
                color: Color(0xFFFEF08A),
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            alignment: Alignment.center,
            child: selectedInfo != null
                ? Image.asset(
                    selectedInfo.sitImg,
                    width: 62,
                    height: 62,
                    fit: BoxFit.contain,
                  )
                : const Icon(
                    Icons.pets_rounded,
                    color: Color(0xFFD97706),
                    size: 32,
                  ),
          ),
          const SizedBox(height: 6),
          if (selectedDog != null && selectedInfo != null)
            Text(
              'Lv ${selectedDog.level} • ${selectedInfo.stageLabel}',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 4),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            DropdownButton<String>(
              value: selectedDog?.id,
              isExpanded: true,
              dropdownColor: const Color(0xFFFFFBEB),
              style: const TextStyle(
                color: Color(0xFF3B1404),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
              underline: Container(height: 1.5, color: const Color(0xFFD97706)),
              items: options.map((dog) {
                final info = DogStageInfo.getInfo(dog);
                return DropdownMenuItem<String>(
                  value: dog.id,
                  child: Row(
                    children: [
                      Image.asset(info.sitImg, width: 22, height: 22),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${dog.name} (${info.breedName})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
        ],
      ),
    );
  }
}
