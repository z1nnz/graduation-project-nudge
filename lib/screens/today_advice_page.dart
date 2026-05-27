import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'focus_page.dart';
import 'health_page.dart';
import 'study_room_detail_page.dart';
import 'study_room_list_page.dart';
import 'tasks_page.dart';

class TodayAdvicePage extends StatelessWidget {
  final VoidCallback? onOpenTasks;
  final ValueChanged<int>? onNavigate;

  const TodayAdvicePage({super.key, this.onOpenTasks, this.onNavigate});

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  int? _daysUntil(String? dueDate) {
    final parsed = _parseDate(dueDate);
    if (parsed == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(parsed.year, parsed.month, parsed.day);
    return target.difference(today).inDays;
  }

  String _displayDueDate(String? dueDate) {
    final days = _daysUntil(dueDate);
    if (days == null) return '未設定截止日';
    if (days == 0) return '今天到期';
    if (days == 1) return '明天到期';
    if (days < 0) return '已逾期';
    return '$days 天後到期';
  }

  List<Map<String, dynamic>> _unfinishedTasks(AppState appState) {
    return appState.tasks.where((task) => task['done'] != true).toList();
  }

  List<Map<String, dynamic>> _unfinishedDeadlineTasks(AppState appState) {
    return _unfinishedTasks(appState)
        .where(
          (task) =>
              (task['taskType'] ?? 'fixed') == 'deadline' &&
              ((_daysUntil(task['dueDate'] as String?) ?? 9999) <= 0),
        )
        .toList();
  }

  List<Map<String, dynamic>> _unfinishedFixedTasks(AppState appState) {
    return _unfinishedTasks(
      appState,
    ).where((task) => (task['taskType'] ?? 'fixed') == 'fixed').toList();
  }

  int _priorityRank(String p) {
    switch (p) {
      case '高':
        return 0;
      case '中':
        return 1;
      case '低':
        return 2;
      default:
        return 3;
    }
  }

  Map<String, dynamic>? _highestPriorityUrgentDeadlineTask(AppState appState) {
    final tasks = _unfinishedDeadlineTasks(appState);
    if (tasks.isEmpty) return null;

    tasks.sort((a, b) {
      final aPriority = _priorityRank((a['priority'] ?? '中') as String);
      final bPriority = _priorityRank((b['priority'] ?? '中') as String);

      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      final aDays = _daysUntil(a['dueDate'] as String?) ?? 9999;
      final bDays = _daysUntil(b['dueDate'] as String?) ?? 9999;
      return aDays.compareTo(bDays);
    });

    return tasks.first;
  }

  Map<String, dynamic>? _highestPriorityTask(AppState appState) {
    final tasks = _unfinishedTasks(appState);
    if (tasks.isEmpty) return null;

    tasks.sort((a, b) {
      final aPriority = _priorityRank((a['priority'] ?? '中') as String);
      final bPriority = _priorityRank((b['priority'] ?? '中') as String);

      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      final aType = (a['taskType'] ?? 'fixed') as String;
      final bType = (b['taskType'] ?? 'fixed') as String;

      if (aType != bType) {
        if (aType == 'deadline') return -1;
        if (bType == 'deadline') return 1;
      }

      final aDays = _daysUntil(a['dueDate'] as String?) ?? 9999;
      final bDays = _daysUntil(b['dueDate'] as String?) ?? 9999;
      return aDays.compareTo(bDays);
    });

    return tasks.first;
  }

  List<String> _otherAdvices(AppState appState) {
    final advices = <String>[];

    final fixedTasks = _unfinishedFixedTasks(appState);
    final deadlineTasks = _unfinishedDeadlineTasks(appState);

    if (fixedTasks.isNotEmpty) {
      advices.add('今天也別忘了固定任務，先完成一項日常活動讓節奏穩下來。');
    }

    if (appState.focusMinutes < 25) {
      advices.add('今天再補一輪專注，讓任務推進更明顯。');
    }

    if (appState.steps < 4000) {
      advices.add('今天步數偏少，可以安排一小段散步。');
    }

    if (appState.exerciseMinutes < 20) {
      advices.add('今天可以補一段短時間運動，提升健康表現。');
    }

    if (appState.sleepHours > 0 && appState.sleepHours < 6.5) {
      advices.add('昨晚睡眠稍微不足，今天安排任務時記得留一點緩衝。');
    }

    if (deadlineTasks.isEmpty && advices.isEmpty) {
      advices.add('今天的整體節奏不錯，先從一件最容易完成的任務開始。');
    }

    return advices;
  }

  IconData _primaryActionIcon(TaskModel? task) {
    switch (task?.sourceType) {
      case TaskSourceType.focusMinutes:
        return Icons.timer_outlined;
      case TaskSourceType.sleepHours:
      case TaskSourceType.steps:
      case TaskSourceType.exerciseMinutes:
        return Icons.health_and_safety_outlined;
      case TaskSourceType.studyRoom:
        return Icons.groups_2_outlined;
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        return Icons.checklist_rounded;
    }
  }

  String _primaryActionTitle(TaskModel? task) {
    switch (task?.sourceType) {
      case TaskSourceType.focusMinutes:
        return '開始專注';
      case TaskSourceType.sleepHours:
      case TaskSourceType.steps:
      case TaskSourceType.exerciseMinutes:
        return '查看健康';
      case TaskSourceType.studyRoom:
        return '進入自律房';
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        return task == null ? '前往任務' : '打開任務詳情';
    }
  }

  String _primaryActionSubtitle(TaskModel? task) {
    switch (task?.sourceType) {
      case TaskSourceType.focusMinutes:
        return '開啟專注頁，直接補今天的專注時間';
      case TaskSourceType.sleepHours:
      case TaskSourceType.steps:
      case TaskSourceType.exerciseMinutes:
        return '查看同步狀態與哪些任務吃到健康資料';
      case TaskSourceType.studyRoom:
        return '進房開始，讓角色出現在即時自律空間';
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        return task == null ? '回任務頁處理今天的項目' : '查看分數、截止日與完成規則';
    }
  }

  void _navigateToTab(BuildContext context, int index) {
    if (onNavigate != null) {
      Navigator.pop(context);
      onNavigate!(index);
      return;
    }

    final fallbackPage = switch (index) {
      1 => const TasksPage(),
      2 => const FocusPage(),
      4 => const HealthPage(),
      _ => const StudyRoomListPage(),
    };
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => fallbackPage),
    );
  }

  void _openTasks(BuildContext context) {
    if (onOpenTasks != null) {
      Navigator.pop(context);
      onOpenTasks!();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TasksPage()),
    );
  }

  void _showAICoachDialog(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AICoachBottomSheet(appState: appState);
      },
    );
  }

  void _runPrimaryAction(
    BuildContext context,
    AppState appState,
    TaskModel? task,
  ) {
    switch (task?.sourceType) {
      case TaskSourceType.focusMinutes:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FocusPage(autoStart: true)),
        );
        return;
      case TaskSourceType.sleepHours:
      case TaskSourceType.steps:
      case TaskSourceType.exerciseMinutes:
        _navigateToTab(context, 4);
        return;
      case TaskSourceType.studyRoom:
        final roomId = task?.sourceId;
        final room = roomId == null ? null : appState.getStudyRoomById(roomId);
        if (room != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StudyRoomDetailPage(roomId: room.id),
            ),
          );
        } else {
          _navigateToTab(context, 3);
        }
        return;
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        if (task != null) {
          _showTaskDetailSheet(context, appState, task);
          return;
        }
        _openTasks(context);
        return;
    }
  }

  void _showTaskDetailSheet(
    BuildContext context,
    AppState appState,
    TaskModel task,
  ) {
    final accentColor = appState.currentIconColor;
    final sourceLabel = TaskModel.sourceTypeToChinese(task.sourceType);
    final potentialScore = appState.taskPotentialScoreForTask(task);
    final rewardReason = appState.taskRewardReasonForTask(task);
    final isDeadline = task.taskType == TaskType.deadline;
    final canCompleteToday = appState.isTaskActionableToday(task);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final primaryText = AppUI.textPrimaryOf(context);
        final secondaryText = AppUI.textSecondaryOf(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppUI.pagePadding,
            8,
            AppUI.pagePadding,
            MediaQuery.of(context).viewInsets.bottom + AppUI.pagePadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: AppUI.softCardOf(context, accentColor),
                    child: Icon(Icons.assignment_outlined, color: accentColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.category,
                          style: TextStyle(color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _DetailPill(
                    label: '今日分數',
                    value: '+$potentialScore 分',
                    color: accentColor,
                  ),
                  _DetailPill(
                    label: '來源',
                    value: sourceLabel,
                    color: AppUI.blue,
                  ),
                  _DetailPill(
                    label: '狀態',
                    value: canCompleteToday ? '今日可執行' : '等待驗收',
                    color: canCompleteToday ? AppUI.green : AppUI.orange,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                rewardReason,
                style: TextStyle(
                  color: secondaryText,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isDeadline) ...[
                const SizedBox(height: 10),
                Text(
                  '截止日規則：截止日任務只在到期日或逾期後驗收，不列入每日任務分母；完成後會走額外自律幣管道。',
                  style: TextStyle(color: secondaryText, height: 1.5),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _openTasks(context);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('前往任務頁'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    final urgentDeadlineTask = _highestPriorityUrgentDeadlineTask(appState);
    final topTask = _highestPriorityTask(appState);
    final otherAdvices = _otherAdvices(appState);
    final weightedRecommendations =
        appState.taskModels
            .where(
              (task) => !task.isDone && appState.isTaskActionableToday(task),
            )
            .toList()
          ..sort(
            (a, b) => appState
                .taskPotentialScoreForTask(b)
                .compareTo(appState.taskPotentialScoreForTask(a)),
          );
    final weightedTask = weightedRecommendations.isEmpty
        ? null
        : weightedRecommendations.first;
    final mainLineTasks = weightedRecommendations.take(3).toList();

    final mainAdviceTitle = urgentDeadlineTask != null
        ? '今天最優先'
        : (topTask != null ? '今日最優先' : '今天建議');
    final mainAdviceContent = urgentDeadlineTask != null
        ? '先完成「${urgentDeadlineTask['title']}」，因為它屬於高優先級，且${_displayDueDate(urgentDeadlineTask['dueDate'] as String?)}。'
        : (topTask != null
              ? '先完成「${topTask['title']}」，這是一個中優先級的固定任務。'
              : '今天可以先新增一個明確任務，讓系統開始幫你建立節奏。');

    return Scaffold(
      appBar: AppBar(title: const Text('今日建議')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '今日建議',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '根據任務優先級、截止日、專注與健康狀態，整理今天最適合先做的事情。',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.12),
                    accentColor.withValues(alpha: 0.03),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: accentColor.withValues(alpha: 0.18),
                      child: Icon(Icons.psychology_outlined, size: 28, color: accentColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 智能自律導師',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '一鍵診斷歷史健康與專注的盲點關聯性',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showAICoachDialog(context, appState),
                      child: const Text('諮詢', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          if (mainLineTasks.isNotEmpty) ...[
            Card(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.route_outlined, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          '今日主線任務',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '先處理這 ${mainLineTasks.length} 件，今天就會有清楚推進感。',
                      style: TextStyle(
                        color: secondaryText,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...mainLineTasks.asMap().entries.map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == mainLineTasks.length - 1
                              ? 0
                              : 10,
                        ),
                        child: _MainQuestCard(
                          index: entry.key + 1,
                          task: entry.value,
                          score: appState.taskPotentialScoreForTask(
                            entry.value,
                          ),
                          reason: appState.taskRewardReasonForTask(entry.value),
                          accentColor: accentColor,
                          onStart: () =>
                              _runPrimaryAction(context, appState, entry.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
          ],
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star_border, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        mainAdviceTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    mainAdviceContent,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '因為目前還有未完成的中優先級固定任務，先完成一件能讓今天有進度。',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        '現在可以做',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _AdviceActionCard(
                    icon: _primaryActionIcon(weightedTask),
                    title: _primaryActionTitle(weightedTask),
                    subtitle: _primaryActionSubtitle(weightedTask),
                    color: accentColor,
                    onTap: () {
                      _runPrimaryAction(context, appState, weightedTask);
                    },
                  ),
                  const SizedBox(height: 12),
                  _AdviceActionCard(
                    icon: Icons.checklist_rounded,
                    title: '查看任務列表',
                    subtitle: '想自己挑任務時，回任務頁整理今天的項目',
                    color: accentColor,
                    onTap: () {
                      _openTasks(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.view_list_outlined, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        '其他建議',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...otherAdvices.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.circle, size: 10, color: accentColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryText,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppUI.isDark(context) ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppUI.textSecondaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainQuestCard extends StatelessWidget {
  final int index;
  final TaskModel task;
  final int score;
  final String reason;
  final Color accentColor;
  final VoidCallback onStart;

  const _MainQuestCard({
    required this.index,
    required this.task,
    required this.score,
    required this.reason,
    required this.accentColor,
    required this.onStart,
  });

  IconData get _icon {
    switch (task.sourceType) {
      case TaskSourceType.focusMinutes:
        return Icons.timer_outlined;
      case TaskSourceType.sleepHours:
      case TaskSourceType.steps:
      case TaskSourceType.exerciseMinutes:
        return Icons.health_and_safety_outlined;
      case TaskSourceType.studyRoom:
        return Icons.groups_2_outlined;
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        return Icons.checklist_rounded;
    }
  }

  String get _actionLabel {
    switch (task.sourceType) {
      case TaskSourceType.focusMinutes:
        return '開始專注';
      case TaskSourceType.sleepHours:
      case TaskSourceType.steps:
      case TaskSourceType.exerciseMinutes:
        return '去健康頁';
      case TaskSourceType.studyRoom:
        return '進入房間';
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        return '看詳情';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUI.surfaceVariantOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: AppUI.softCardOf(context, accentColor),
                child: Icon(_icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index. ${task.title}',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _DetailPill(label: '完成後', value: '+$score 分', color: accentColor),
              _DetailPill(
                label: '自律幣',
                value: score > 0 ? '跨門檻 +3' : '額外規則',
                color: AppUI.orange,
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(_actionLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdviceActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _AdviceActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppUI.isDark(context)
                ? color.withValues(alpha: 0.10)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                        height: 1.4,
                      ),
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
}

class _AICoachBottomSheet extends StatefulWidget {
  final AppState appState;
  const _AICoachBottomSheet({required this.appState});

  @override
  State<_AICoachBottomSheet> createState() => _AICoachBottomSheetState();
}

class _AICoachBottomSheetState extends State<_AICoachBottomSheet> {
  bool _loading = true;
  String _advice = '';

  @override
  void initState() {
    super.initState();
    _fetchAdvice();
  }

  Future<void> _fetchAdvice() async {
    final response = await widget.appState.askAICoach();
    if (mounted) {
      setState(() {
        _advice = response;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accentColor = widget.appState.currentIconColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                  child: Icon(Icons.psychology_alt_outlined, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 智能自律導師',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '基於歷史步數、睡眠與專注關聯性診斷',
                        style: TextStyle(color: secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '正在分析你過去 7 天的自律數據...',
                            style: TextStyle(color: secondaryText, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '尋找睡眠、步數與專注之間的盲點關聯...',
                            style: TextStyle(color: secondaryText, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          _advice,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
            ),
            if (!_loading) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('好的，我會試著調整', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
