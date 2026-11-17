import 'package:flutter/material.dart';
import '../../models/level_milestone.dart';
import '../../state/game_controller.dart';
import '../common/generic_modal.dart';
import '../common/hover_scale.dart';

class ProgressDialog extends StatelessWidget {
  final GameController game;

  const ProgressDialog({super.key, required this.game});

  String _fmtNum(int n) {
    return n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final milestones = game.levelMilestones;
        final xpRatio = (game.xp / game.maxXp).clamp(0.0, 1.0);
        final levelsToNext = (game.nextMilestoneLevel - game.level).clamp(0, 5);

        return GenericModal(
          title: 'LEVEL MILESTONES',
          maxWidth: 640,
          onClose: () => Navigator.of(context).pop(),
          child: Column(
            children: [
              // ── Current Level & XP Summary Banner ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF451A03), Color(0xFF260D02)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: const Color(0xFFFBBF24), width: 2.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Level Emblem
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFDE047), Color(0xFFD97706)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(color: Colors.white, width: 2.2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'LVL',
                            style: TextStyle(
                              color: Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: 9,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '${game.level}',
                            style: const TextStyle(
                              color: Color(0xFF3B1404),
                              fontFamily: 'Lilita One',
                              fontSize: 21,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // XP Bar + Next 5-Level Reward Hint
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                game.hasUsername
                                    ? game.playerUsername
                                    : 'Island Keeper',
                                style: const TextStyle(
                                  color: Color(0xFFFEF08A),
                                  fontFamily: 'Lilita One',
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${_fmtNum(game.xp)} / ${_fmtNum(game.maxXp)} XP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Lilita One',
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 12,
                              color: const Color(0xFF1A0801),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: xpRatio.clamp(0.03, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFF59E0B),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            game.unclaimedMilestoneCount > 0
                                ? '${game.unclaimedMilestoneCount} milestone reward${game.unclaimedMilestoneCount > 1 ? 's' : ''} ready to claim!'
                                : 'Earn a bonus reward every 5 levels ($levelsToNext lvl${levelsToNext == 1 ? '' : 's'} to Level ${game.nextMilestoneLevel})',
                            style: TextStyle(
                              color: game.unclaimedMilestoneCount > 0
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFFDE68A),
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Every-5-Levels Milestone Rewards List ──
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  itemCount: milestones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _buildMilestoneCard(milestones[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMilestoneCard(LevelMilestone m) {
    final isClaimed = game.isMilestoneClaimed(m.level);
    final isClaimable = game.canClaimMilestone(m.level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isClaimed
            ? const LinearGradient(
                colors: [Color(0xFFE2D9CC), Color(0xFFD4C8B8)],
              )
            : (isClaimable
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFFFBEB),
                      Color(0xFFFEF3C7),
                      Color(0xFFFDE68A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : const LinearGradient(
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFFFFBF2),
                      Color(0xFFFAECD5),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClaimed
              ? const Color(0xFFB8A894)
              : (isClaimable
                  ? const Color(0xFF059669)
                  : const Color(0xFFD97706)),
          width: isClaimable ? 2.4 : 1.8,
        ),
        boxShadow: isClaimed
            ? null
            : [
                BoxShadow(
                  color: isClaimable
                      ? const Color(0x44059669)
                      : const Color(0x2078350F),
                  offset: const Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Row(
        children: [
          // Level Badge (LVL 5, LVL 10, ...)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isClaimed
                  ? const LinearGradient(
                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                    )
                  : (isClaimable
                      ? const LinearGradient(
                          colors: [Color(0xFFFDE047), Color(0xFFD97706)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        )),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isClaimed
                    ? const Color(0xFFA7F3D0)
                    : const Color(0xFFD97706),
                width: 1.6,
              ),
            ),
            child: Center(
              child: isClaimed
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 24)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'LVL',
                          style: TextStyle(
                            color: Color(0xFF78350F),
                            fontFamily: 'Lilita One',
                            fontSize: 9,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          '${m.level}',
                          style: const TextStyle(
                            color: Color(0xFF3B1404),
                            fontFamily: 'Lilita One',
                            fontSize: 18,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Title + Reward Preview Chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Level ${m.level} · ${m.title}',
                  style: TextStyle(
                    color: isClaimed
                        ? const Color(0xFF786B5A)
                        : const Color(0xFF3B1404),
                    fontFamily: 'Lilita One',
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _rewardTag('assets/ui/coins.png', '+${_fmtNum(m.rewardCoins)}',
                        muted: isClaimed),
                    _rewardTag('assets/ui/diamonds.png', '+${m.rewardCrystals}',
                        muted: isClaimed),
                    _rewardTag(
                        'assets/ui/dogfood.png', '+${_fmtNum(m.rewardKibble)}',
                        muted: isClaimed),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Status / Claim Action
          if (isClaimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'CLAIMED',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Lilita One',
                  fontSize: 10.5,
                ),
              ),
            )
          else if (isClaimable)
            HoverScale(
              scale: 1.08,
              onTap: () => game.claimLevelMilestone(m.level),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEF08A), width: 1.8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55059669),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'CLAIM',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Lilita One',
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                  ),
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
                'LVL ${game.level} / ${m.level}',
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontFamily: 'Lilita One',
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rewardTag(String asset, String label, {bool muted = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: muted ? 0.55 : 1.0,
          child: Image.asset(asset, width: 16, height: 16, fit: BoxFit.contain),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: muted ? const Color(0xFF8C7E6D) : const Color(0xFF78350F),
            fontFamily: 'Fredoka',
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
