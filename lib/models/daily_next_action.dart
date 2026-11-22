enum DailyNextActionKind { task, tracking, rest, plan }

class DailyNextAction {
  const DailyNextAction(this.kind, this.title, this.detail, this.button);

  final DailyNextActionKind kind;
  final String title;
  final String detail;
  final String button;

  static DailyNextAction resolve(List<Map<String, dynamic>> tasks) {
    final fixed = tasks
        .where((task) => task['taskType'] != 'deadline')
        .toList();
    final pending = fixed
        .where((task) => task['done'] != true && task['isDone'] != true)
        .toList();
    final manual = pending
        .where(
          (task) =>
              task['isAutoTracked'] != true &&
              !const [
                'sleepHours',
                'steps',
                'exerciseMinutes',
                'focusMinutes',
                'studyRoom',
              ].contains(task['sourceType']) &&
              (task['title'] is String &&
                  (task['title'] as String).trim().isNotEmpty),
        )
        .toList();
    Map<String, dynamic>? next;
    int rank(Object? value) => switch (value) {
      '高' || 'high' => 0,
      '低' || 'low' => 2,
      _ => 1,
    };
    for (final task in manual) {
      if (next == null || rank(task['priority']) < rank(next['priority'])) {
        next = task;
      }
    }
    if (next != null) {
      return DailyNextAction(
        DailyNextActionKind.task,
        (next['title'] as String).trim(),
        '先從這一件開始；可以到任務頁調整或拆小。',
        '查看我的任務',
      );
    }
    if (pending.isNotEmpty) {
      return const DailyNextAction(
        DailyNextActionKind.tracking,
        '讓紀錄跟上你的行動',
        '目前有自動追蹤或待整理的項目，請到任務頁確認來源與目標。',
        '查看追蹤項目',
      );
    }
    if (fixed.isNotEmpty) {
      return const DailyNextAction(
        DailyNextActionKind.rest,
        '今天的清單完成了',
        '可以休息一下；不需要為了累積獎勵再塞滿任務。',
        '回顧今日任務',
      );
    }
    return const DailyNextAction(
      DailyNextActionKind.plan,
      '從一件做得到的小事開始',
      '先安排一個日常任務，今天不必一次改變所有習慣。',
      '安排我的任務',
    );
  }
}
