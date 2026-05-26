import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

enum _PomodoroPhase { focus, rest }

class FocusPage extends StatefulWidget {
  final bool autoStart;

  const FocusPage({super.key, this.autoStart = false});

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  int selectedFocusMinutes = 25;
  int selectedRestMinutes = 5;
  int remainingSeconds = 25 * 60;
  _PomodoroPhase currentPhase = _PomodoroPhase.focus;

  Timer? timer;
  bool isRunning = false;
  int completedPomodoros = 0;

  bool get isFocusPhase => currentPhase == _PomodoroPhase.focus;

  int get focusSeconds => selectedFocusMinutes * 60;

  int get restSeconds => selectedRestMinutes * 60;

  int get phaseTotalSeconds => isFocusPhase ? focusSeconds : restSeconds;

  Color phaseColor(Color accentColor) =>
      isFocusPhase ? accentColor : const Color(0xFF20A994);

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
    final value = phaseTotalSeconds - remainingSeconds;
    return value < 0 ? 0 : value;
  }

  int get currentRoundFocusSeconds {
    if (isFocusPhase) return elapsedSeconds;
    return focusSeconds;
  }

  int get elapsedMinutes => currentRoundFocusSeconds ~/ 60;

  String get formattedTime {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final restSeconds = seconds % 60;
    if (minutes <= 0) return '$restSeconds 秒';
    if (restSeconds == 0) return '$minutes 分鐘';
    return '$minutes 分 $restSeconds 秒';
  }

  String get currentStatusText {
    if (isRunning) return isFocusPhase ? '專注進行中' : '休息中';
    if (remainingSeconds != phaseTotalSeconds && remainingSeconds > 0) {
      return isFocusPhase ? '專注暫停' : '休息暫停';
    }
    return isFocusPhase ? '準備專注' : '準備休息';
  }

  String get phaseTitle => isFocusPhase ? '專注階段' : '休息階段';

  String get startButtonText {
    if (isRunning) return isFocusPhase ? '專注中' : '休息中';
    return isFocusPhase ? '開始專注' : '開始休息';
  }

  void changePomodoroPreset({
    required int focusMinutes,
    required int restMinutes,
  }) {
    if (isRunning) return;

    setState(() {
      selectedFocusMinutes = focusMinutes;
      selectedRestMinutes = restMinutes;
      currentPhase = _PomodoroPhase.focus;
      remainingSeconds = focusMinutes * 60;
      completedPomodoros = 0;
    });
  }

  void startTimer() {
    if (isRunning) return;

    setState(() {
      if (remainingSeconds <= 0) {
        remainingSeconds = phaseTotalSeconds;
      }
      isRunning = true;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remainingSeconds > 1) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        completeCurrentPhase();
      }
    });
  }

  Future<void> completeCurrentPhase() async {
    final finishedPhase = currentPhase;
    final finishedFocusMinutes = selectedFocusMinutes;
    final finishedRestMinutes = selectedRestMinutes;

    if (finishedPhase == _PomodoroPhase.focus) {
      context.read<AppState>().addFocusSeconds(focusSeconds);
    }

    if (!mounted) return;

    setState(() {
      isRunning = false;
      remainingSeconds = 0;
    });

    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    final nextPhase = finishedPhase == _PomodoroPhase.focus
        ? _PomodoroPhase.rest
        : _PomodoroPhase.focus;

    setState(() {
      if (finishedPhase == _PomodoroPhase.focus) {
        completedPomodoros++;
      }
      currentPhase = nextPhase;
      remainingSeconds = phaseTotalSeconds;
    });

    if (!mounted) return;

    final shouldStartNext = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isFinishedFocus = finishedPhase == _PomodoroPhase.focus;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(isFinishedFocus ? '專注完成，休息一下' : '休息完成，回到專注'),
          content: Text(
            isFinishedFocus
                ? '已記錄 $finishedFocusMinutes 分鐘專注。接下來休息 $finishedRestMinutes 分鐘，讓大腦喘口氣。'
                : '這輪休息結束了，可以開始下一輪 $finishedFocusMinutes 分鐘專注。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('稍後'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isFinishedFocus ? '開始休息' : '開始專注'),
            ),
          ],
        );
      },
    );

    if (shouldStartNext == true && mounted) {
      startTimer();
    }
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
      currentPhase = _PomodoroPhase.focus;
      remainingSeconds = focusSeconds;
      isRunning = false;
      completedPomodoros = 0;
    });
  }

  Future<void> endEarlyAndSave() async {
    final wasRunning = isRunning;
    if (wasRunning) {
      timer?.cancel();
      setState(() {
        isRunning = false;
      });
    }

    if (!isFocusPhase) {
      final bool? shouldSkipRest = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('提前結束休息'),
            content: const Text('現在是休息階段，提前結束不會增加專注時間。要直接回到下一輪專注嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('回到專注'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      if (shouldSkipRest != true) {
        if (wasRunning) startTimer();
        return;
      }

      setState(() {
        currentPhase = _PomodoroPhase.focus;
        remainingSeconds = focusSeconds;
        isRunning = false;
      });
      return;
    }

    if (elapsedSeconds <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目前還沒有可記錄的專注時間')));
      if (wasRunning) startTimer();
      return;
    }

    final savedSeconds = elapsedSeconds;
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('提前結束'),
          content: Text(
            '你目前已專注 ${formatDuration(savedSeconds)}，是否要提前結束並記錄這段時間？',
          ),
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

    if (!mounted) return;
    if (shouldSave != true) {
      if (wasRunning) startTimer();
      return;
    }

    timer?.cancel();

    final appState = context.read<AppState>();
    appState.addFocusSeconds(savedSeconds);

    setState(() {
      isRunning = false;
      currentPhase = _PomodoroPhase.focus;
      remainingSeconds = focusSeconds;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已記錄 ${formatDuration(savedSeconds)}專注時間')),
    );
  }

  Future<void> showCustomMinutesDialog() async {
    if (isRunning) return;

    final focusController = TextEditingController(
      text: selectedFocusMinutes.toString(),
    );
    final restController = TextEditingController(
      text: selectedRestMinutes.toString(),
    );

    final customMinutes = await showDialog<({int focus, int rest})>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('自訂番茄鐘'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: focusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '專注分鐘',
                  hintText: '例如 25',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: restController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '休息分鐘',
                  hintText: '例如 5',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final focus = int.tryParse(focusController.text.trim());
                final rest = int.tryParse(restController.text.trim());
                if (focus == null || rest == null || focus <= 0 || rest <= 0) {
                  return;
                }
                Navigator.pop(dialogContext, (focus: focus, rest: rest));
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );

    focusController.dispose();
    restController.dispose();

    if (customMinutes != null) {
      changePomodoroPreset(
        focusMinutes: customMinutes.focus,
        restMinutes: customMinutes.rest,
      );
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

  Widget buildPhasePill({
    required String title,
    required bool isActive,
    required Color activeColor,
  }) {
    final secondaryText = AppUI.textSecondaryOf(context);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.14)
              : Theme.of(context).dividerColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppUI.radiusPill),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? activeColor : secondaryText,
            fontSize: 13,
            fontWeight: FontWeight.bold,
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
    final activeColor = phaseColor(accentColor);
    final totalFocusMinutes = appState.focusMinutes;
    final progress = phaseTotalSeconds == 0
        ? 0.0
        : (elapsedSeconds / phaseTotalSeconds).clamp(0.0, 1.0);

    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDark = AppUI.isDark(context);

    return Scaffold(
      appBar: AppBar(title: const Text('番茄鐘')),
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
                  child: Icon(
                    isFocusPhase
                        ? Icons.timer_outlined
                        : Icons.local_cafe_outlined,
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
                      const SizedBox(height: 6),
                      Text(
                        '專注 $selectedFocusMinutes 分鐘 · 休息 $selectedRestMinutes 分鐘',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppUI.sectionGap),
          _FocusSectionTitle(title: '番茄鐘模式', color: primaryText),
          const SizedBox(height: AppUI.cardGap),
          Row(
            children: [
              buildModeButton(
                title: '25 + 5',
                isSelected:
                    selectedFocusMinutes == 25 && selectedRestMinutes == 5,
                onTap: () =>
                    changePomodoroPreset(focusMinutes: 25, restMinutes: 5),
                accentColor: accentColor,
              ),
              const SizedBox(width: 10),
              buildModeButton(
                title: '50 + 10',
                isSelected:
                    selectedFocusMinutes == 50 && selectedRestMinutes == 10,
                onTap: () =>
                    changePomodoroPreset(focusMinutes: 50, restMinutes: 10),
                accentColor: accentColor,
              ),
              const SizedBox(width: 10),
              buildModeButton(
                title: '自訂',
                isSelected:
                    !(selectedFocusMinutes == 25 && selectedRestMinutes == 5) &&
                    !(selectedFocusMinutes == 50 && selectedRestMinutes == 10),
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
                  Row(
                    children: [
                      buildPhasePill(
                        title: '專注',
                        isActive: isFocusPhase,
                        activeColor: accentColor,
                      ),
                      const SizedBox(width: 10),
                      buildPhasePill(
                        title: '休息',
                        isActive: !isFocusPhase,
                        activeColor: const Color(0xFF20A994),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                    '$phaseTitle · 本輪專注 $selectedFocusMinutes 分鐘 / 休息 $selectedRestMinutes 分鐘',
                    style: TextStyle(fontSize: 15, color: secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppUI.radiusPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: activeColor.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '已完成 $completedPomodoros 顆番茄',
                    style: TextStyle(fontSize: 13, color: secondaryText),
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
                    backgroundColor: activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(startButtonText),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isRunning ? pauseTimer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
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
                    side: BorderSide(color: activeColor),
                    foregroundColor: activeColor,
                  ),
                  child: const Text('重設'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: endEarlyAndSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
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
                value: formatDuration(currentRoundFocusSeconds),
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
