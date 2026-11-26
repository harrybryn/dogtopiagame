import 'package:flutter/material.dart';
import '../../state/game_controller.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class GoalsDialog extends StatelessWidget {
  final GameController game;

  const GoalsDialog({super.key, required this.game});

  String _getTaskIcon(String type) {
    switch (type) {
      case 'Feed':
      case 'Bake':
        return 'assets/ui/dogfood.png';
      case 'Collect':
      case 'Refill':
        return 'assets/ui/coins.png';
      case 'Build':
      case 'Care':
      case 'Bath':
      case 'Play':
      case 'Groom':
      default:
        return 'assets/ui/diamonds.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return GenericModal(
          title: 'DAILY GOALS & TASKS',
          onClose: () => Navigator.of(context).pop(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
            itemCount: game.tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final task = game.tasks[index];
              final isDone = task.done;
              final isReady = !isDone && task.isCompleted;

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isDone
                      ? const LinearGradient(
                          colors: [Color(0xFFE2D9CC), Color(0xFFD4C8B8)],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFFFFBF2),
                            Color(0xFFFAECD5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDone
                        ? const Color(0xFFB8A894)
                        : (isReady
                            ? const Color(0xFF10B981)
                            : const Color(0xFFD97706)),
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
                    // Task Icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFFC7B9A6)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFFA89884)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                      child: Center(
                        child: Image.asset(
                          _getTaskIcon(task.type),
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Task Title & Rewards
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              color: isDone
                                  ? const Color(0xFF786B5A)
                                  : const Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              if (task.coinReward > 0)
                                Text(
                                  '+${task.coinReward} Coins',
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              if (task.rewardCrystals > 0)
                                Text(
                                  '+${task.rewardCrystals} Diamonds',
                                  style: const TextStyle(
                                    color: Color(0xFF0284C7),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              if (task.xpReward > 0)
                                Text(
                                  '+${task.xpReward} XP',
                                  style: const TextStyle(
                                    color: Color(0xFF047857),
                                    fontFamily: 'Fredoka',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action / Claim Button
                    if (isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'CLAIMED',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Lilita One',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isReady)
                      HoverScale(
                        scale: 1.08,
                        onTap: () => game.completeTask(task.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFFFEF3C7), width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'CLAIM',
                            style: TextStyle(
                              color: Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFD97706), width: 1.2),
                        ),
                        child: Text(
                          '${task.progress}/${task.target}',
                          style: const TextStyle(
                            color: Color(0xFF78350F),
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
      },
    );
  }
}
