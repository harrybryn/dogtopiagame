class TaskModel {
  final String id;
  final String type;
  final String desc;
  final int rewardCoins;
  final int rewardXp;
  final int rewardCrystals;
  int progress;
  final int target;
  bool done;

  String get title => desc;
  int get coinReward => rewardCoins;
  int get xpReward => rewardXp;
  bool get isCompleted => progress >= target;

  TaskModel({
    required this.id,
    required this.type,
    required this.desc,
    this.rewardCoins = 0,
    this.rewardXp = 0,
    this.rewardCrystals = 0,
    this.progress = 0,
    this.target = 1,
    this.done = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'desc': desc,
        'rewardCoins': rewardCoins,
        'rewardXp': rewardXp,
        'rewardCrystals': rewardCrystals,
        'progress': progress,
        'target': target,
        'done': done,
      };

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String? ?? 'task_1',
        type: json['type'] as String? ?? 'Feed',
        desc: json['desc'] as String? ?? 'Feed dogs',
        rewardCoins: json['rewardCoins'] as int? ?? 0,
        rewardXp: json['rewardXp'] as int? ?? 0,
        rewardCrystals: json['rewardCrystals'] as int? ?? 0,
        progress: json['progress'] as int? ?? 0,
        target: json['target'] as int? ?? 1,
        done: json['done'] as bool? ?? false,
      );

  static List<TaskModel> defaultTasks() => [
        TaskModel(
          id: 'task-1',
          type: 'Feed',
          desc: 'Feed a dog kibble',
          rewardCoins: 350,
          rewardXp: 120,
          target: 1,
        ),
        TaskModel(
          id: 'task-2',
          type: 'Collect',
          desc: 'Collect coins from a habitat',
          rewardCoins: 500,
          rewardXp: 180,
          target: 1,
        ),
        TaskModel(
          id: 'task-3',
          type: 'Bake',
          desc: 'Bake kibble in the Dogfood Factory',
          rewardCoins: 400,
          rewardXp: 150,
          target: 1,
        ),
        TaskModel(
          id: 'task-4',
          type: 'Care',
          desc: 'Pet or care for a dog',
          rewardCoins: 200,
          rewardXp: 80,
          target: 1,
        ),
        TaskModel(
          id: 'task-5',
          type: 'Build',
          desc: 'Place a habitat or adopt a dog',
          rewardCrystals: 5,
          rewardXp: 250,
          target: 1,
        ),
      ];
}
