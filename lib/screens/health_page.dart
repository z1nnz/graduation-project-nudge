import '../theme/game_ui.dart';
import '../widgets/game_facility_scene.dart';
import '../widgets/game_scene_life.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task_model.dart';
import '../services/health_service.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'privacy_data_page.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  bool isSyncing = false;
  bool isRequestingPermission = false;
  String statusMessage = '';
  String? lastSyncTime;

  String getHealthStatus({
    required bool isConnected,
    required double sleepHours,
    required int steps,
    required int exerciseMinutes,
  }) {
    if (!isConnected) return '尚未同步資料';

    if (sleepHours == 0 && steps == 0 && exerciseMinutes == 0) {
      return '目前查無資料';
    }

    int score = 0;
    if (sleepHours >= 7) score += 1;
    if (steps >= 6000) score += 1;
    if (exerciseMinutes >= 30) score += 1;

    if (score == 3) return '狀態很好';
    if (score == 2) return '表現不錯';
    if (score == 1) return '還可加強';
    return '今日狀態偏低';
  }

  String normalizeMessage(String message) {
    if (message.contains('No data available for the specified predicate')) {
      return '目前找不到符合條件的健康資料，可能是今日尚未產生紀錄，或裝置內暫時沒有可讀資料。';
    }

    if (message.contains('HealthKit unavailable')) {
      return '目前裝置無法使用 Apple 健康資料。';
    }

    if (message.contains('Health Connect unavailable')) {
      return '目前裝置無法使用 Health Connect，請確認 Android 系統或 Google Play 已支援健康資料同步。';
    }

    if (message.contains('Health Connect permission not granted')) {
      return '尚未取得 Health Connect 授權。';
    }

    if (message.contains('MissingPluginException')) {
      return '健康同步模組尚未正確載入，請重新啟動 App 再試一次。';
    }

    if (message.contains('同步失敗：')) {
      return message;
    }

    if (message.trim().isEmpty) {
      return '尚未同步健康資料';
    }

    return message;
  }

  String formatNow() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool getHasAnyHealthData({
    required double sleepHours,
    required int steps,
    required int exerciseMinutes,
  }) {
    return sleepHours > 0 || steps > 0 || exerciseMinutes > 0;
  }

  Future<void> connectHealthData() async {
    setState(() {
      isRequestingPermission = true;
      statusMessage = '正在請求健康資料權限...';
    });

    final granted = await HealthService.requestHealthPermission();

    if (!mounted) return;

    if (!granted) {
      setState(() {
        isRequestingPermission = false;
        statusMessage = '尚未取得健康資料授權';
      });

      showMessageDialog(title: '授權失敗', content: '目前尚未取得健康資料授權，請稍後再試一次。');
      return;
    }

    setState(() {
      isRequestingPermission = false;
      statusMessage = '已取得健康資料授權';
    });

    await syncHealthData();
  }

  Future<void> syncHealthData() async {
    setState(() {
      isSyncing = true;
      statusMessage = '正在同步健康資料...';
    });

    final result = await HealthService.syncHealthData();

    if (!mounted) return;

    final normalized = normalizeMessage(result.message);

    setState(() {
      isSyncing = false;
      statusMessage = normalized;
    });

    if (result.success) {
      final accepted = await context.read<AppState>().updateHealthData(
        isConnected: true,
        sleepHours: result.sleepHours,
        steps: result.steps,
        exerciseMinutes: result.exerciseMinutes,
        snapshots: result.snapshots,
      );

      if (!mounted) return;
      if (!accepted) {
        setState(() {
          statusMessage = '健康資料尚未安全保存，原有進度未變更';
        });
        showMessageDialog(
          title: '同步尚未完成',
          content: '無法先保存到 Activity Ledger，已保留原有健康資料與任務狀態，請稍後重試。',
        );
        return;
      }

      setState(() {
        lastSyncTime = formatNow();
      });

      final hasData = getHasAnyHealthData(
        sleepHours: result.sleepHours,
        steps: result.steps,
        exerciseMinutes: result.exerciseMinutes,
      );

      showMessageDialog(
        title: '同步完成',
        content: hasData ? '已成功同步健康資料。' : '已完成同步，但目前查無符合條件的健康資料。',
      );
    } else {
      showMessageDialog(title: '同步失敗', content: normalized);
    }
  }

  void showConnectInfoDialog() {
    final platformStatus = HealthService.platformStatus;
    final appState = context.read<AppState>();
    if (!appState.hasAcceptedPrivacyPolicy) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: GamePalette.of(context).backgroundTop,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: GamePalette.of(context).wood, width: 3),
            ),
            title: const Text('先同意隱私權政策'),
            content: const Text(
              '健康資料包含睡眠、步數與運動紀錄，連接前需要先閱讀並同意隱私權政策。完成同意後，再回來連接健康資料。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('稍後'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyDataPage()),
                  );
                },
                child: const Text('前往同意'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GamePalette.of(context).backgroundTop,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: GamePalette.of(context).wood, width: 3),
          ),
          title: const Text('連接健康資料'),
          content: Text(
            '目前裝置來源：${platformStatus.title}\n'
            '${platformStatus.description}\n\n'
            '同步項目包含：\n\n'
            '• 睡眠時數\n'
            '• 步數\n'
            '• 運動時間\n\n'
            '這些資料將用來作為任務自動判定的資料來源，不會在未授權的情況下讀取。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: platformStatus.isSupported
                  ? () async {
                      Navigator.pop(context);
                      await connectHealthData();
                    }
                  : null,
              child: const Text('同意並連接'),
            ),
          ],
        );
      },
    );
  }

  void showMessageDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GamePalette.of(context).backgroundTop,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: GamePalette.of(context).wood, width: 3),
          ),
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  TaskModel? _trackingTaskForSource(
    List<TaskModel> tasks,
    TaskSourceType sourceType,
  ) {
    for (final task in tasks) {
      if (task.sourceType == sourceType) return task;
    }
    return null;
  }

  String _formatGoalValue(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  double _effectiveTargetValue(TaskModel? task, double fallback) {
    final value = task?.targetValue;
    if (value == null || value <= 0) return fallback;
    return value;
  }

  Future<void> _showHealthGoalDialog({
    required TaskSourceType sourceType,
    required String metricName,
    required String category,
    required double currentTargetValue,
    required String unitLabel,
    required bool hasTrackingTask,
  }) async {
    // 使用獨立的 StatefulWidget 管理 TextEditingController 生命週期，
    // 避免 showDialog await 返回後立刻 dispose controller，
    // 但退場動畫仍在執行，造成 ChangeNotifier disposed 無限 rebuild 崩潰。
    final targetValue = await showDialog<double>(
      context: context,
      builder: (context) => _HealthGoalDialogWidget(
        sourceType: sourceType,
        metricName: metricName,
        unitLabel: unitLabel,
        initialValue: _formatGoalValue(currentTargetValue),
        hasTrackingTask: hasTrackingTask,
      ),
    );

    if (!mounted || targetValue == null) return;

    final title = '$metricName ${_formatGoalValue(targetValue)} $unitLabel';
    context.read<AppState>().setHealthTrackingTask(
      sourceType: sourceType,
      title: title,
      category: category,
      targetValue: targetValue,
      unitLabel: unitLabel,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hasTrackingTask ? '已更新：$title' : '已新增：$title')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    const accentColor = GamePalette.goldDeep;

    final isConnected = appState.isHealthConnected;
    final platformStatus = HealthService.platformStatus;
    final sleepHours = appState.sleepHours;
    final steps = appState.steps;
    final exerciseMinutes = appState.exerciseMinutes;
    final healthTasks = appState.taskModels.where((task) {
      return task.sourceType == TaskSourceType.sleepHours ||
          task.sourceType == TaskSourceType.steps ||
          task.sourceType == TaskSourceType.exerciseMinutes;
    }).toList();
    final sleepTask = _trackingTaskForSource(
      healthTasks,
      TaskSourceType.sleepHours,
    );
    final stepsTask = _trackingTaskForSource(healthTasks, TaskSourceType.steps);
    final exerciseTask = _trackingTaskForSource(
      healthTasks,
      TaskSourceType.exerciseMinutes,
    );
    final sleepTarget = _effectiveTargetValue(sleepTask, 7);
    final stepsTarget = _effectiveTargetValue(stepsTask, 8000);
    final exerciseTarget = _effectiveTargetValue(exerciseTask, 30);

    final healthStatus = getHealthStatus(
      isConnected: isConnected,
      sleepHours: sleepHours,
      steps: steps,
      exerciseMinutes: exerciseMinutes,
    );

    final isBusy = isSyncing || isRequestingPermission;
    final primaryText = GamePalette.of(context).ink;
    final secondaryText = GamePalette.of(context).inkMuted;

    final metrics = <String, Widget>{
      '睡眠': _HealthMetricProgressCard(
        icon: Icons.bedtime_outlined,
        title: '睡眠',
        value: isConnected ? sleepHours.toStringAsFixed(1) : '--',
        unit: '小時',
        progress: isConnected ? (sleepHours / sleepTarget).clamp(0.0, 1.0) : 0,
        targetText: '目標 ${_formatGoalValue(sleepTarget)} 小時',
        color: GamePalette.violet,
        hasTrackingTask: sleepTask != null,
        onSetGoal: () => _showHealthGoalDialog(
          sourceType: TaskSourceType.sleepHours,
          metricName: '睡眠',
          category: '睡眠',
          currentTargetValue: sleepTarget,
          unitLabel: '小時',
          hasTrackingTask: sleepTask != null,
        ),
      ),
      '步數': _HealthMetricProgressCard(
        icon: Icons.directions_walk,
        title: '步數',
        value: isConnected ? '$steps' : '--',
        unit: '步',
        progress: isConnected ? (steps / stepsTarget).clamp(0.0, 1.0) : 0,
        targetText: '目標 ${_formatGoalValue(stepsTarget)} 步',
        color: GamePalette.green,
        hasTrackingTask: stepsTask != null,
        onSetGoal: () => _showHealthGoalDialog(
          sourceType: TaskSourceType.steps,
          metricName: '步數',
          category: '運動',
          currentTargetValue: stepsTarget,
          unitLabel: '步',
          hasTrackingTask: stepsTask != null,
        ),
      ),
      '運動': _HealthMetricProgressCard(
        icon: Icons.fitness_center,
        title: '運動',
        value: isConnected ? '$exerciseMinutes' : '--',
        unit: '分鐘',
        progress: isConnected
            ? (exerciseMinutes / exerciseTarget).clamp(0.0, 1.0)
            : 0,
        targetText: '目標 ${_formatGoalValue(exerciseTarget)} 分鐘',
        color: GamePalette.goldDeep,
        hasTrackingTask: exerciseTask != null,
        onSetGoal: () => _showHealthGoalDialog(
          sourceType: TaskSourceType.exerciseMinutes,
          metricName: '運動',
          category: '運動',
          currentTargetValue: exerciseTarget,
          unitLabel: '分鐘',
          hasTrackingTask: exerciseTask != null,
        ),
      ),
    };
    void showMetric(String key) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: GamePalette.of(context).backgroundTop,
          child: SingleChildScrollView(
            child: GamePanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  metrics[key]!,
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('闔上健康紀錄'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('健康同步')),
      body: GameFacilityScene(
        title: '健康小屋',
        background: 'assets/scenes/journal/health_cabin.webp',
        guide: 'sprout',
        guideLine: '床記錄睡眠，鞋子記錄步數，單槓記錄運動。先依原有授權連結資料，再看自己的進度。',
        objectLabel: '翻開健康手冊',
        objectIcon: Icons.health_and_safety_outlined,
        foreground: Positioned.fill(
          child: GameSceneObjects(
            objects: [
              GameSceneProp(
                label: '床與月亮・睡眠',
                icon: Icons.bedtime_outlined,
                x: .21,
                y: .24,
                value: isConnected
                    ? '${sleepHours.toStringAsFixed(1)} / ${_formatGoalValue(sleepTarget)} 小時'
                    : '尚未連結',
                progress: isConnected
                    ? (sleepHours / sleepTarget).clamp(0.0, 1.0)
                    : null,
                gaugeKind: '睡眠',
                onTap: () => showMetric('睡眠'),
              ),
              GameSceneProp(
                label: '門口鞋子・步數',
                icon: Icons.directions_walk,
                x: .73,
                y: .52,
                value: isConnected
                    ? '$steps / ${_formatGoalValue(stepsTarget)} 步'
                    : '尚未連結',
                progress: isConnected
                    ? (steps / stepsTarget).clamp(0.0, 1.0)
                    : null,
                gaugeKind: '步數',
                onTap: () => showMetric('步數'),
              ),
              GameSceneProp(
                label: '單槓・運動',
                icon: Icons.fitness_center,
                x: .79,
                y: .23,
                value: isConnected
                    ? '$exerciseMinutes / ${_formatGoalValue(exerciseTarget)} 分鐘'
                    : '尚未連結',
                progress: isConnected
                    ? (exerciseMinutes / exerciseTarget).clamp(0.0, 1.0)
                    : null,
                gaugeKind: '運動',
                onTap: () => showMetric('運動'),
              ),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppUI.pagePadding),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: GameRecordStyle.hero(accentColor),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: GamePalette.inkLight.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isConnected ? Icons.health_and_safety : Icons.watch,
                      color: GamePalette.inkLight,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '健康資料同步',
                          style: TextStyle(
                            color: GamePalette.inkLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isConnected ? '已連接健康資料' : '尚未連接',
                          style: const TextStyle(
                            color: GamePalette.inkLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isConnected
                              ? '健康資料會作為任務頁自動追蹤任務的判定來源。'
                              : '目前會使用 ${platformStatus.title} 作為健康來源。',
                          style: const TextStyle(
                            color: GamePalette.inkLight,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            _HealthConnectionPanel(
              isConnected: isConnected,
              isBusy: isBusy,
              platformStatus: platformStatus,
              lastSyncTime: lastSyncTime,
              statusMessage: statusMessage.isEmpty ? '尚未同步健康資料' : statusMessage,
              healthTasks: healthTasks,
              accentColor: accentColor,
              onPressed: () {
                if (isConnected) {
                  syncHealthData();
                } else {
                  showConnectInfoDialog();
                }
              },
              buttonLabel: isRequestingPermission
                  ? '授權中...'
                  : isSyncing
                  ? '同步中...'
                  : isConnected
                  ? '更新資料'
                  : '連接',
            ),
            const SizedBox(height: AppUI.sectionGap),
            Text(
              '今日健康總覽',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            GameArtifact(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.favorite, color: Colors.red, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '健康狀態',
                            style: TextStyle(
                              fontSize: 16,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            healthStatus,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppUI.cardGap),
            metrics['睡眠']!,
            const SizedBox(height: AppUI.cardGap),
            metrics['步數']!,
            const SizedBox(height: AppUI.cardGap),
            metrics['運動']!,
          ],
        ),
      ),
    );
  }
}

class _HealthConnectionPanel extends StatelessWidget {
  final bool isConnected;
  final bool isBusy;
  final HealthPlatformStatus platformStatus;
  final String? lastSyncTime;
  final String statusMessage;
  final List<TaskModel> healthTasks;
  final Color accentColor;
  final VoidCallback onPressed;
  final String buttonLabel;

  const _HealthConnectionPanel({
    required this.isConnected,
    required this.isBusy,
    required this.platformStatus,
    required this.lastSyncTime,
    required this.statusMessage,
    required this.healthTasks,
    required this.accentColor,
    required this.onPressed,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = GamePalette.of(context).ink;
    final secondaryText = GamePalette.of(context).inkMuted;

    return GameArtifact(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  platformStatus.provider == HealthDataProvider.appleHealth
                      ? Icons.apple
                      : platformStatus.provider ==
                            HealthDataProvider.healthConnect
                      ? Icons.health_and_safety_outlined
                      : Icons.info_outline,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    platformStatus.title,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusDot(
                  label: platformStatus.isSupported ? '可用' : '不支援',
                  color: platformStatus.isSupported
                      ? GamePalette.green
                      : GamePalette.goldDeep,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              platformStatus.description,
              style: TextStyle(color: secondaryText, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              statusMessage,
              style: TextStyle(
                color: secondaryText,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusDot(
                  label: isConnected ? '已連接' : '未連接',
                  color: isConnected ? GamePalette.green : GamePalette.goldDeep,
                ),
                _StatusDot(
                  label: '上次同步 ${lastSyncTime ?? '--'}',
                  color: accentColor,
                ),
                _StatusDot(
                  label: '影響 ${healthTasks.length} 個任務',
                  color: GamePalette.violet,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GamePalette.woodDark,
                  foregroundColor: GamePalette.inkLight,
                ),
                icon: Icon(isConnected ? Icons.refresh : Icons.link),
                label: Text(buttonLabel),
              ),
            ),
            if (healthTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...healthTasks
                  .take(3)
                  .map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            task.isDone
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            color: task.isDone
                                ? GamePalette.green
                                : secondaryText,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: GameRecordStyle.inset(context, color),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HealthMetricProgressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final double progress;
  final String targetText;
  final Color color;
  final bool hasTrackingTask;
  final VoidCallback onSetGoal;

  const _HealthMetricProgressCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.progress,
    required this.targetText,
    required this.color,
    required this.hasTrackingTask,
    required this.onSetGoal,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = GamePalette.of(context).ink;
    final secondaryText = GamePalette.of(context).inkMuted;

    return GameArtifact(
      shape: AppUI.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSetGoal,
        child: Padding(
          padding: const EdgeInsets.all(AppUI.innerPadding),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: GameRecordStyle.inset(context, color),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$value $unit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onSetGoal,
                    icon: Icon(
                      hasTrackingTask ? Icons.tune : Icons.add_circle_outline,
                      size: 18,
                    ),
                    label: Text(hasTrackingTask ? '設定' : '追蹤'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.radiusPill),
                child: GameObjectGauge(
                  value: progress,
                  kind: title.contains('睡眠')
                      ? '睡眠'
                      : title.contains('步數')
                      ? '步數'
                      : '運動',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    targetText,
                    style: TextStyle(color: secondaryText, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 獨立的 StatefulWidget 管理 TextEditingController 生命週期。
/// 確保 controller.dispose() 在 Dialog 退場動畫完全結束後才被呼叫，
/// 避免「動畫仍在執行時 TextField 嘗試 addListener 到已 dispose 的 controller」
/// 所造成的 ChangeNotifier.debugAssertNotDisposed 無限 rebuild 崩潰。
class _HealthGoalDialogWidget extends StatefulWidget {
  final TaskSourceType sourceType;
  final String metricName;
  final String unitLabel;
  final String initialValue;
  final bool hasTrackingTask;

  const _HealthGoalDialogWidget({
    required this.sourceType,
    required this.metricName,
    required this.unitLabel,
    required this.initialValue,
    required this.hasTrackingTask,
  });

  @override
  State<_HealthGoalDialogWidget> createState() =>
      _HealthGoalDialogWidgetState();
}

class _HealthGoalDialogWidgetState extends State<_HealthGoalDialogWidget> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    // Flutter 在 Dialog 退場動畫完全結束後才呼叫此方法，
    // 確保 controller 不會在動畫期間被提前 dispose。
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: GamePalette.of(context).backgroundTop,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: GamePalette.of(context).wood, width: 3),
      ),
      title: Text('設定${widget.metricName}目標'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('你今天想達成多少${widget.unitLabel}？設定後會自動建立健康追蹤任務，達標時任務會自動完成。'),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.sourceType == TaskSourceType.sleepHours,
            ),
            decoration: InputDecoration(
              labelText: '目標',
              suffixText: widget.unitLabel,
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(_controller.text.trim());
            if (value == null || value <= 0) {
              setState(() {
                _errorText = '請輸入大於 0 的目標';
              });
              return;
            }
            if (widget.sourceType != TaskSourceType.sleepHours &&
                value % 1 != 0) {
              setState(() {
                _errorText = '${widget.metricName}目標請輸入整數';
              });
              return;
            }
            Navigator.pop(context, value);
          },
          child: Text(widget.hasTrackingTask ? '更新目標' : '開始追蹤'),
        ),
      ],
    );
  }
}
