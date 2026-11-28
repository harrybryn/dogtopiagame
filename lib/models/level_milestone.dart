class LevelMilestone {
  final int level;
  final String title;
  final int rewardCoins;
  final int rewardCrystals;
  final int rewardKibble;

  const LevelMilestone({
    required this.level,
    required this.title,
    required this.rewardCoins,
    required this.rewardCrystals,
    required this.rewardKibble,
  });

  static const List<LevelMilestone> defaults = [
    LevelMilestone(
      level: 5,
      title: 'Puppy Apprentice',
      rewardCoins: 3000,
      rewardCrystals: 15,
      rewardKibble: 1200,
    ),
    LevelMilestone(
      level: 10,
      title: 'Island Builder',
      rewardCoins: 10000,
      rewardCrystals: 30,
      rewardKibble: 3500,
    ),
    LevelMilestone(
      level: 15,
      title: 'Pack Guardian',
      rewardCoins: 25000,
      rewardCrystals: 50,
      rewardKibble: 8000,
    ),
    LevelMilestone(
      level: 20,
      title: 'Kibble Tycoon',
      rewardCoins: 50000,
      rewardCrystals: 75,
      rewardKibble: 18000,
    ),
    LevelMilestone(
      level: 25,
      title: 'Master Breeder',
      rewardCoins: 80000,
      rewardCrystals: 100,
      rewardKibble: 30000,
    ),
    LevelMilestone(
      level: 30,
      title: 'Dogtopia Legend',
      rewardCoins: 120000,
      rewardCrystals: 150,
      rewardKibble: 50000,
    ),
  ];

  static LevelMilestone forLevel(int milestoneLevel) {
    for (final m in defaults) {
      if (m.level == milestoneLevel) return m;
    }
    final tier = milestoneLevel ~/ 5;
    return LevelMilestone(
      level: milestoneLevel,
      title: 'Sanctuary Champion $tier',
      rewardCoins: tier * 20000,
      rewardCrystals: tier * 25,
      rewardKibble: tier * 8000,
    );
  }
}
