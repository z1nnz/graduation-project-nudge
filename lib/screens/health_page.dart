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
      lastSyncTime = formatNow();
    });

    if (result.success) {
      context.read<AppState>().updateHealthData(
        isConnected: true,
        sleepHours: result.sleepHours,
        steps: result.steps,
        exerciseMinutes: result.exerciseMinutes,
      );

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

  Widget buildStatusHintCard({
    required bool isConnected,
    required bool hasAnyData,
    required String message,
    required Color accentColor,
  }) {
    final bodyStyle = TextStyle(
      fontSize: 14,
      color: AppUI.textPrimaryOf(context),
      height: 1.5,
    );

    if (!isConnected) {
      return Card(
        shape: AppUI.cardShape(),
        color: AppUI.isDark(context)
            ? const Color(0xFF2A231C)
            : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(AppUI.innerPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '尚未連接健康資料。完成連接後，可同步睡眠、步數與運動資料，作為自動追蹤任務的判定來源。',
                  style: bodyStyle,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasAnyData) {
      return Card(
        shape: AppUI.cardShape(),
        color: AppUI.isDark(context)
            ? const Color(0xFF241F31)
            : const Color(0xFFF8F5FF),
        child: Padding(
          padding: const EdgeInsets.all(AppUI.innerPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_outlined, color: accentColor),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: bodyStyle)),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: AppUI.cardShape(),
      color: AppUI.isDark(context)
          ? const Color(0xFF1F2C22)
          : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text('健康資料已同步完成，現在可以把睡眠、步數、運動設成自動追蹤任務。', style: bodyStyle),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;

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

    final hasAnyData = getHasAnyHealthData(
      sleepHours: sleepHours,
      steps: steps,
      exerciseMinutes: exerciseMinutes,
    );

    final healthStatus = getHealthStatus(
      isConnected: isConnected,
      sleepHours: sleepHours,
      steps: steps,
      exerciseMinutes: exerciseMinutes,
    );

    final isBusy = isSyncing || isRequestingPermission;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('健康同步')),
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
                  child: Icon(
                    isConnected ? Icons.health_and_safety : Icons.watch,
                    color: Colors.white,
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
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isConnected ? '已連接健康資料' : '尚未連接',
                        style: const TextStyle(
                          color: Colors.white,
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
                          color: Colors.white70,
                          fontSize: 13,
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
          Card(
            shape: AppUI.cardShape(),
            child: ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: AppUI.softCardOf(context, accentColor),
                child: Icon(
                  platformStatus.provider == HealthDataProvider.appleHealth
                      ? Icons.apple
                      : platformStatus.provider ==
                            HealthDataProvider.healthConnect
                      ? Icons.health_and_safety_outlined
                      : Icons.info_outline,
                  color: accentColor,
                ),
              ),
              title: Text(platformStatus.title),
              subtitle: Text(platformStatus.description),
              trailing: _StatusDot(
                label: platformStatus.isSupported ? '可同步' : '不支援',
                color: platformStatus.isSupported ? AppUI.green : AppUI.orange,
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      statusMessage.isEmpty ? '尚未同步健康資料' : statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppUI.textPrimaryOf(context),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: isBusy
                        ? null
                        : () {
                            if (isConnected) {
                              syncHealthData();
                            } else {
                              showConnectInfoDialog();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      isRequestingPermission
                          ? '授權中...'
                          : isSyncing
                          ? '同步中...'
                          : isConnected
                          ? '重新同步'
                          : '連接',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _HealthSyncStatusCard(
            isConnected: isConnected,
            lastSyncTime: lastSyncTime,
            statusMessage: statusMessage.isEmpty ? '尚未同步健康資料' : statusMessage,
            healthTasks: healthTasks,
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.cardGap),
          buildStatusHintCard(
            isConnected: isConnected,
            hasAnyData: hasAnyData,
            message: normalizeMessage(statusMessage),
            accentColor: accentColor,
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
          Card(
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
                          style: TextStyle(fontSize: 16, color: secondaryText),
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
          Row(
            children: [
              Expanded(
                child: _HealthMiniCard(
                  icon: Icons.bedtime_outlined,
                  title: '睡眠',
                  value: isConnected
                      ? '${sleepHours.toStringAsFixed(1)} 小時'
                      : '尚未讀取',
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HealthMiniCard(
                  icon: Icons.directions_walk,
                  title: '步數',
                  value: isConnected ? '$steps 步' : '尚未讀取',
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.cardGap),
          _HealthWideCard(
            icon: Icons.fitness_center,
            title: '運動資料',
            value: isConnected ? '$exerciseMinutes 分鐘' : '尚未讀取',
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _HealthMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _HealthMiniCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: AppUI.softCardOf(context, color),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 13, color: secondaryText)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthSyncStatusCard extends StatelessWidget {
  final bool isConnected;
  final String? lastSyncTime;
  final String statusMessage;
  final List<TaskModel> healthTasks;
  final Color accentColor;

  const _HealthSyncStatusCard({
    required this.isConnected,
    required this.lastSyncTime,
    required this.statusMessage,
    required this.healthTasks,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '同步狀態',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusDot(
                  label: isConnected ? '已連接' : '未連接',
                  color: isConnected ? AppUI.green : AppUI.orange,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              statusMessage,
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
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
                  label: '上次同步 ${lastSyncTime ?? '--'}',
                  color: accentColor,
                ),
                _StatusDot(
                  label: '影響 ${healthTasks.length} 個任務',
                  color: AppUI.purple,
                ),
              ],
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
                            color: task.isDone ? AppUI.green : secondaryText,
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
                                fontSize: 13,
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
      decoration: AppUI.softCardOf(context, color),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HealthWideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _HealthWideCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Card(
      shape: AppUI.cardShape(),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: AppUI.softCardOf(context, color),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
      ),
    );
  }
}
