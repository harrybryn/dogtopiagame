import 'dart:async';
import 'package:flutter/material.dart';
import '../state/game_controller.dart';

class BreedingPage extends StatefulWidget {
  final GameController game;
  final VoidCallback onBackToWorld;

  const BreedingPage({
    super.key,
    required this.game,
    required this.onBackToWorld,
  });

  @override
  State<BreedingPage> createState() => _BreedingPageState();
}

class _BreedingPageState extends State<BreedingPage> {
  String _parent1 = 'Basenji';
  String _parent2 = 'Pharaoh Hound';
  String _breedingState = 'idle'; // 'idle' | 'breeding' | 'hatched'
  Map<String, String>? _hatchedPup;

  final List<Map<String, String>> _parentOptions = const [
    {'name': 'Basenji', 'trait': 'Agile & Alert', 'element': 'Desert Element'},
    {'name': 'Pharaoh Hound', 'trait': 'Royal Sight', 'element': 'Desert Element'},
    {'name': 'Shiba Inu', 'trait': 'Spirited Loyal', 'element': 'Garden Element'},
    {'name': 'Husky', 'trait': 'Arctic Endurance', 'element': 'Snow Element'},
  ];

  void _startBreeding() {
    if (widget.game.coins < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need 500 Paw Coins to breed!')),
      );
      return;
    }

    widget.game.addCurrency(coins: -500, xp: 100);

    setState(() {
      _breedingState = 'breeding';
    });

    Timer(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      setState(() {
        _breedingState = 'hatched';
        _hatchedPup = {
          'name': 'Sun Chaser Pup',
          'desc':
              'Rare hybrid offspring of $_parent1 & $_parent2! Inherited Golden Coat & Speed.',
          'rarity': 'Rare Hybrid',
        };
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120601),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: widget.onBackToWorld,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Island View',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xDD2A1106),
                      foregroundColor: const Color(0xFFFEF3C7),
                      side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),

                  // Coins
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xEE2A1106),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        Image.asset('assets/ui/coins.png', width: 18, height: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.game.coins}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Title Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1005),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD97706), width: 2),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/itemsInShop/building/BreedingDen.webp',
                        width: 50, height: 50),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ancient Breeding Den',
                            style: TextStyle(
                              color: Color(0xFFFEF08A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pair two champion dogs to unlock mythical hybrid breeds and puppy traits!',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Parents Selection Cards
              Row(
                children: [
                  Expanded(
                    child: _buildParentSelector(
                      'Parent 1',
                      _parent1,
                      (val) => setState(() => _parent1 = val),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 32),
                  ),
                  Expanded(
                    child: _buildParentSelector(
                      'Parent 2',
                      _parent2,
                      (val) => setState(() => _parent2 = val),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Breeding Action & Hatching Area
              if (_breedingState == 'idle')
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _startBreeding,
                    icon: const Icon(Icons.favorite),
                    label: const Text('START BREEDING (500 Paw Coins)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC4899),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                    ),
                  ),
                )
              else if (_breedingState == 'breeding')
                Column(
                  children: [
                    const SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                        strokeWidth: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Breeding in progress... Incubating mystery egg!',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else if (_breedingState == 'hatched' && _hatchedPup != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF381503),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.amber, width: 2.5),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'EGG HATCHED!',
                        style: TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Image.asset('assets/dogs/BulldogPuppySit.png',
                          width: 100, height: 100),
                      const SizedBox(height: 10),
                      Text(
                        _hatchedPup!['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hatchedPup!['rarity']!,
                        style: const TextStyle(
                          color: Colors.pinkAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hatchedPup!['desc']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _breedingState = 'idle';
                            _hatchedPup = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: const Color(0xFF451A03),
                        ),
                        child: const Text('BREED ANOTHER',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentSelector(
      String label, String currentVal, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1005),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF78350F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFEF08A),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: currentVal,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E0A02),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            underline: Container(height: 1, color: Colors.amber),
            items: _parentOptions
                .map(
                  (opt) => DropdownMenuItem<String>(
                    value: opt['name']!,
                    child: Text(opt['name']!),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}
