import 'package:flutter/material.dart';
import '../common/generic_modal.dart';

class RankingDialog extends StatelessWidget {
  const RankingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final trainers = [
      {'rank': 1, 'name': 'Alpha Trainer Leo', 'score': '24,800', 'dog': 'Galaxy Dog', 'isYou': false},
      {'rank': 2, 'name': 'Canine Master Chloe', 'score': '19,450', 'dog': 'Cerberus Pup', 'isYou': false},
      {'rank': 3, 'name': 'Island Scout Kai', 'score': '14,120', 'dog': 'Pharaoh Hound', 'isYou': false},
      {'rank': 4, 'name': 'You (Island Trainer)', 'score': '8,500', 'dog': 'Bulldog Puppy', 'isYou': true},
      {'rank': 5, 'name': 'Pup Explorer Maya', 'score': '7,200', 'dog': 'Arctic Husky', 'isYou': false},
    ];

    return GenericModal(
      title: 'ISLAND LEADERBOARD',
      onClose: () => Navigator.of(context).pop(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        itemCount: trainers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final t = trainers[index];
          final isYou = t['isYou'] == true;
          final rank = t['rank'] as int;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isYou
                  ? const LinearGradient(
                      colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFFBF2), Color(0xFFFAECD5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isYou ? const Color(0xFFD97706) : const Color(0xFFE5D5C2),
                width: isYou ? 2.2 : 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1878350F),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                // Rank Circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rank == 1
                        ? const Color(0xFFF59E0B)
                        : rank == 2
                            ? const Color(0xFF9CA3AF)
                            : rank == 3
                                ? const Color(0xFFB45309)
                                : const Color(0xFF78350F),
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lilita One',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Top Dog
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t['name'] as String,
                        style: TextStyle(
                          color: isYou ? const Color(0xFF92400E) : const Color(0xFF3B1404),
                          fontFamily: 'Lilita One',
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        t['dog'] as String,
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontFamily: 'Fredoka',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Score
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/ui/coins.png', width: 16, height: 16),
                    const SizedBox(width: 4),
                    Text(
                      t['score'] as String,
                      style: const TextStyle(
                        color: Color(0xFF3B1404),
                        fontFamily: 'Lilita One',
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
