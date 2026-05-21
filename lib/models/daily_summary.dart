class DailySummary {
  final String date; // yyyy-MM-dd
  final int completedTasks;
  final int totalTasks;
  final int focusMinutes;
  final double sleepHours;
  final int steps;
  final int exerciseMinutes;
  final int disciplineScore;
  final int coinsEarned;
  final int autoTrackedCompleted;
  final int autoTrackedTotal;
  final int healthCompleted;
  final int healthTotal;
  final int roomCompleted;
  final int roomTotal;
  final int focusCompleted;
  final int focusTotal;
  final List<String> autoTrackedSources;

  const DailySummary({
    required this.date,
    required this.completedTasks,
    required this.totalTasks,
    required this.focusMinutes,
    required this.sleepHours,
    required this.steps,
    required this.exerciseMinutes,
    required this.disciplineScore,
    this.coinsEarned = 0,
    this.autoTrackedCompleted = 0,
    this.autoTrackedTotal = 0,
    this.healthCompleted = 0,
    this.healthTotal = 0,
    this.roomCompleted = 0,
    this.roomTotal = 0,
    this.focusCompleted = 0,
    this.focusTotal = 0,
    this.autoTrackedSources = const [],
  });

  int get manualTotal => totalTasks - autoTrackedTotal;
  int get manualCompleted => completedTasks - autoTrackedCompleted;

  int get nextCoinMilestone {
    const thresholds = [20, 40, 60, 80, 100];
    for (final threshold in thresholds) {
      if (disciplineScore < threshold) return threshold;
    }
    return 0;
  }

  String get sourceSummary {
    if (autoTrackedSources.isEmpty) return '手動任務';
    return autoTrackedSources.join('、');
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'completedTasks': completedTasks,
      'totalTasks': totalTasks,
      'focusMinutes': focusMinutes,
      'sleepHours': sleepHours,
      'steps': steps,
      'exerciseMinutes': exerciseMinutes,
      'disciplineScore': disciplineScore,
      'coinsEarned': coinsEarned,
      'autoTrackedCompleted': autoTrackedCompleted,
      'autoTrackedTotal': autoTrackedTotal,
      'healthCompleted': healthCompleted,
      'healthTotal': healthTotal,
      'roomCompleted': roomCompleted,
      'roomTotal': roomTotal,
      'focusCompleted': focusCompleted,
      'focusTotal': focusTotal,
      'autoTrackedSources': autoTrackedSources,
    };
  }

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    final rawSources = json['autoTrackedSources'];
    final sources = rawSources is List
        ? rawSources.whereType<String>().toList()
        : const <String>[];

    return DailySummary(
      date: json['date'] as String,
      completedTasks: json['completedTasks'] as int,
      totalTasks: json['totalTasks'] as int,
      focusMinutes: json['focusMinutes'] as int,
      sleepHours: (json['sleepHours'] as num).toDouble(),
      steps: json['steps'] as int,
      exerciseMinutes: json['exerciseMinutes'] as int,
      disciplineScore: json['disciplineScore'] as int,
      coinsEarned: json['coinsEarned'] as int? ?? 0,
      autoTrackedCompleted: json['autoTrackedCompleted'] as int? ?? 0,
      autoTrackedTotal: json['autoTrackedTotal'] as int? ?? 0,
      healthCompleted: json['healthCompleted'] as int? ?? 0,
      healthTotal: json['healthTotal'] as int? ?? 0,
      roomCompleted: json['roomCompleted'] as int? ?? 0,
      roomTotal: json['roomTotal'] as int? ?? 0,
      focusCompleted: json['focusCompleted'] as int? ?? 0,
      focusTotal: json['focusTotal'] as int? ?? 0,
      autoTrackedSources: sources,
    );
  }
}
