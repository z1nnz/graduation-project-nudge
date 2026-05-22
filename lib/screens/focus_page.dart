import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class FocusPage extends StatefulWidget {
  final bool autoStart;

  const FocusPage({super.key, this.autoStart = false});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  int selectedMinutes = 25;
  int remainingSeconds = 25 * 60;

  Timer? timer;
  bool isRunning = false;
  bool hasCountedThisRound = false;

  int get initialSeconds => selectedMinutes * 60;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) startTimer();
      });
    }
  }

  int get elapsedSeconds {
    final value = initialSeconds - remainingSeconds;
    return value < 0 ? 0 : value;
  }

  int get elapsedMinutes => elapsedSeconds ~/ 60;

  String get formattedTime {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get currentStatusText {
    if (isRunning) return '專注進行中';
    if (remainingSeconds != initialSeconds && remainingSeconds > 0) {
      return '已暫停';
    }
    return '準備開始';
  }

  void changeFocusMinutes(int minutes) {
    if (isRunning) return;

    setState(() {
      selectedMinutes = minutes;
      remainingSeconds = minutes * 60;
      hasCountedThisRound = false;
    });
  }

  void startTimer() {
    if (isRunning) return;

    setState(() {
      isRunning = true;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();

        if (!hasCountedThisRound) {
          context.read<AppState>().addFocusMinutes(selectedMinutes);
          hasCountedThisRound = true;
        }

        setState(() {
          isRunning = false;
        });

        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('專注完成'),
              content: Text('恭喜你完成 $selectedMinutes 分鐘專注！'),
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
    });
  }

  void pauseTimer() {
    timer?.cancel();
    setState(() {
      isRunning = false;
    });
  }

  void resetTimer() {
    timer?.cancel();
    setState(() {
      remainingSeconds = selectedMinutes * 60;
      isRunning = false;
      hasCountedThisRound = false;
    });
  }

  Future<void> endEarlyAndSave() async {
    if (elapsedSeconds <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前還沒有可記錄的專注時間')));
      return;
    }

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('提前結束'),
          content: Text('你目前已專注 $elapsedMinutes 分鐘，是否要提前結束並記錄這段時間？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('結束並記錄'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;
    if (!mounted) return;

    timer?.cancel();

    final appState = context.read<AppState>();

    if (!hasCountedThisRound && elapsedMinutes > 0) {
      appState.addFocusMinutes(elapsedMinutes);
    }

    setState(() {
      isRunning = false;
      hasCountedThisRound = false;
      remainingSeconds = selectedMinutes * 60;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已記錄 $elapsedMinutes 分鐘專注時間')));
  }

  Future<void> showCustomMinutesDialog() async {
    if (isRunning) return;

    final controller = TextEditingController(text: selectedMinutes.toString());

    final int? customMinutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('自訂專注時間'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: '請輸入分鐘數',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final minutes = int.tryParse(controller.text.trim());
                if (minutes == null || minutes <= 0) return;
                Navigator.pop(dialogContext, minutes);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    if (customMinutes != null) {
      changeFocusMinutes(customMinutes);
    }
  }

  Widget buildModeButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accentColor : Theme.of(context).dividerColor,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : primaryText,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Expanded(
      child: Card(
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
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final totalFocusMinutes = appState.focusMinutes;
    final progress = initialSeconds == 0
        ? 0.0
        : (elapsedSeconds / initialSeconds).clamp(0.0, 1.0);

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

    return Scaffold(
      appBar: AppBar(title: const Text('專注模式')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppUI.pagePadding,
          12,
          AppUI.pagePadding,
          28,
        ),
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
                    Icons.timer_outlined,
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
                        '今日專注狀態',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currentStatusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          _FocusSectionTitle(title: '專注模式', color: primaryText),
          const SizedBox(height: AppUI.cardGap),
          Row(
            children: [
              buildModeButton(
                title: '25 分鐘',
                isSelected: selectedMinutes == 25,
                onTap: () => changeFocusMinutes(25),
                accentColor: accentColor,
              ),
              const SizedBox(width: 10),
              buildModeButton(
                title: '50 分鐘',
                isSelected: selectedMinutes == 50,
                onTap: () => changeFocusMinutes(50),
                accentColor: accentColor,
              ),
              const SizedBox(width: 10),
              buildModeButton(
                title: '自訂',
                isSelected: selectedMinutes != 25 && selectedMinutes != 50,
                onTap: showCustomMinutesDialog,
                accentColor: accentColor,
              ),
            ],
          ),
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              child: Column(
                children: [
                  Text(
                    formattedTime,
                    style: TextStyle(
                      fontSize: 58,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '目前設定：$selectedMinutes 分鐘',
                    style: TextStyle(fontSize: 15, color: secondaryText),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.radiusPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: accentColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          _FocusSectionTitle(title: '控制面板', color: primaryText),
          const SizedBox(height: AppUI.cardGap),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isRunning ? null : startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('開始'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isRunning ? pauseTimer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('暫停'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.cardGap),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: resetTimer,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: accentColor),
                    foregroundColor: accentColor,
                  ),
                  child: const Text('重設'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: endEarlyAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('提前結束'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppUI.sectionGap),
          Row(
            children: [
              buildInfoCard(
                icon: Icons.hourglass_bottom_outlined,
                title: '本輪已專注',
                value: '$elapsedMinutes 分鐘',
                color: accentColor,
              ),
              const SizedBox(width: 12),
              buildInfoCard(
                icon: Icons.insights_outlined,
                title: '今日累積',
                value: '$totalFocusMinutes 分鐘',
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: AppUI.sectionGap),
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: accentColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isRunning
                          ? '正在專注中，若臨時有事，可以用「提前結束」保留已完成的專注時間。'
                          : '你可以使用 25 分鐘、50 分鐘，或自訂時長；若想讓它影響分數，建議把專注分鐘數設成任務。',
                      style: TextStyle(
                        fontSize: 14,
                        color: primaryText,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isDark) const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FocusSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _FocusSectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
    );
  }
}
