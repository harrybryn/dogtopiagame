class TaskModel {
  final String id;
  final String type;
  final String desc;
  final int rewardCoins;
  final int rewardXp;
  final int rewardCrystals;
  bool done;

  String get title => desc;
  int get coinReward => rewardCoins;
  int get xpReward => rewardXp;

  TaskModel({
    required this.id,
    required this.type,
    required this.desc,
    this.rewardCoins = 0,
    this.rewardXp = 0,
    this.rewardCrystals = 0,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'desc': desc,
        'rewardCoins': rewardCoins,
        'rewardXp': rewardXp,
        'rewardCrystals': rewardCrystals,
        'done': done,
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String? ?? 'task_1',
        type: json['type'] as String? ?? 'Feed',
        desc: json['desc'] as String? ?? 'Feed dogs',
        rewardCoins: json['rewardCoins'] as int? ?? 0,
        rewardXp: json['rewardXp'] as int? ?? 0,
        rewardCrystals: json['rewardCrystals'] as int? ?? 0,
        done: json['done'] as bool? ?? false,
      );

  static List<TaskModel> defaultTasks() => [
        TaskModel(
          id: 'task-1',
          type: 'Feed',
          desc: 'Feed dogs basic kibble',
          rewardCoins: 350,
          rewardXp: 120,
        ),
        TaskModel(
          id: 'task-2',
          type: 'Bath',
          desc: 'Scrub dog at the oasis pond',
          rewardCoins: 500,
          rewardXp: 180,
        ),
        TaskModel(
          id: 'task-3',
          type: 'Play',
          desc: 'Throw a bone for Basenji',
          rewardCoins: 400,
          rewardXp: 150,
        ),
        TaskModel(
          id: 'task-4',
          type: 'Refill',
          desc: 'Refill stone water station',
          rewardCoins: 200,
          rewardXp: 80,
        ),
        TaskModel(
          id: 'task-5',
          type: 'Groom',
          desc: 'Brush Pharaoh Hound coat',
          rewardCrystals: 5,
          rewardXp: 250,
        ),
      ];
}
