import 'package:flutter/material.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class ProgressDialog extends StatelessWidget {
  const ProgressDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final stages = [
      {
        'num': '1',
        'name': 'Oasis Awakening',
        'desc': 'Build Desert Oasis & place first pup',
        'done': true,
        'reward': '+500 Coins',
      },
      {
        'num': '2',
        'name': 'Water & Warmth',
        'desc': 'Place Stone Water Station & Golden Palm',
        'done': true,
        'reward': '+1,000 Coins',
      },
      {
        'num': '3',
        'name': 'Canine Caregiver',
        'desc': 'Perform 10 Feed & Bath tasks',
        'progress': '7 / 10',
        'done': false,
        'reward': '+2,500 Coins',
      },
      {
        'num': '4',
        'name': 'Pack Expansion',
        'desc': 'Build Snowy Peak or Forest Meadow',
        'progress': '0 / 1',
        'done': false,
        'reward': '+5,000 Coins',
      },
      {
        'num': '5',
        'name': 'Legendary Discovery',
        'desc': 'Breed a hybrid puppy in the Breeding Den',
        'progress': '0 / 1',
        'done': false,
        'reward': '+10,000 Coins & 15 Crystals',
      },
    ];

    return GenericModal(
      title: 'ISLAND PROGRESS',
      onClose: () => Navigator.of(context).pop(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        itemCount: stages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final st = stages[index];
          final isDone = st['done'] == true;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isDone
                  ? const LinearGradient(
                      colors: [Color(0xFFE2D9CC), Color(0xFFD4C8B8)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone ? const Color(0xFFB8A894) : const Color(0xFFD97706),
                width: 1.8,
              ),
              boxShadow: isDone
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x2478350F),
                        offset: Offset(0, 3),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Milestone Number or Checkmark Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: isDone
                        ? const LinearGradient(
                            colors: [Color(0xFF34D399), Color(0xFF059669)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDone ? const Color(0xFFA7F3D0) : const Color(0xFFD97706),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            st['num'] as String,
                            style: const TextStyle(
                              color: Color(0xFF78350F),
                              fontFamily: 'Lilita One',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        st['name'] as String,
                        style: TextStyle(
                          color: isDone ? const Color(0xFF786B5A) : const Color(0xFF3B1404),
                          fontFamily: 'Lilita One',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        st['desc'] as String,
                        style: TextStyle(
                          color: isDone ? const Color(0xFF8C7E6D) : const Color(0xFF78350F),
                          fontFamily: 'Fredoka',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status or Progress
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'COMPLETED',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      st['progress'] as String? ?? 'In Progress',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontFamily: 'Lilita One',
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
