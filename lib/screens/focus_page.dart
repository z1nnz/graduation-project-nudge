import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/focus_activity_ledger_controller.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../models/companion_pose.dart';
import '../widgets/focus_result_sheet.dart';
import '../widgets/companion_sprite.dart';
import '../widgets/player_avatar.dart';
import '../widgets/world_life.dart';
import '../models/cabin_companion_brain.dart';
import '../models/cabin_layout.dart';
import '../models/cabin_presentation.dart';
import '../models/daily_next_action.dart';
import '../widgets/immersive_cabin.dart';
import '../models/focus_sound.dart';
import '../services/audioplayers_focus_backend.dart';
import '../widgets/focus_sound_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _PomodoroPhase { focus, rest }

class FocusPage extends StatefulWidget {
  final bool autoStart;
  final int initialFocusMinutes;

  /// Desk mode: the session happens inside the cabin, with the companion at
  /// the desk and a clock on the wall, instead of the card layout.
  final bool immersive;

  const FocusPage({
    super.key,
    this.autoStart = false,
    this.initialFocusMinutes = 25,
    this.immersive = false,
  }) : assert(initialFocusMinutes >= 1 && initialFocusMinutes <= 120);

  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  late int selectedFocusMinutes;
  int selectedRestMinutes = 5;
  late int remainingSeconds;
  _PomodoroPhase currentPhase = _PomodoroPhase.focus;

  Timer? timer;
  bool isRunning = false;
  int completedPomodoros = 0;
  FocusActivityLedgerController? _ledgerController;
  AppState? _ledgerAppState;
  FocusSoundController? _sound;
  PlayerLook _look = PlayerLook.standard;

  /// When the last focus round finished: the companion cheers and rewards
  /// fly out of the book for a moment (J8).
  DateTime? _cheerAt;

  /// Created only when needed, so pages without sound never touch audio.
  FocusSoundController _ensureSound() =>
      _sound ??= FocusSoundController(backend: AudioplayersFocusBackend());

  Future<void> _restoreSavedSound() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || !prefs.containsKey('focus_sound_id')) return;
    final sound = _ensureSound();
    await sound.restore();
    if (mounted && isRunning) await sound.resume();
  }

  Future<void> _openSoundSheet() async {
    final sound = _ensureSound();
    if (sound.current == null) await sound.restore();
    if (!mounted) return;
    await showFocusSoundSheet(context, sound);
    if (mounted) setState(() {});
  }

  bool get isFocusPhase => currentPhase == _PomodoroPhase.focus;

  int get focusSeconds => selectedFocusMinutes * 60;

  int get restSeconds => selectedRestMinutes * 60;

  int get phaseTotalSeconds => isFocusPhase ? focusSeconds : restSeconds;

  Color phaseColor(Color accentColor) => accentColor;

  @override
  void initState() {
    super.initState();
    selectedFocusMinutes = widget.initialFocusMinutes;
    remainingSeconds = selectedFocusMinutes * 60;
    PlayerLookStore.load().then((l) {
      if (mounted) setState(() => _look = l);
    });
    if (widget.immersive) unawaited(_restoreSavedSound());
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(startTimer());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ledgerAppState ??= context.read<AppState>();
    _ledgerController ??= FocusActivityLedgerController(
      eventSink:
          ({
            required sessionId,
            required eventType,
            required elapsedSeconds,
            required occurredAt,
          }) {
            return _ledgerAppState!.queuePersonalFocusLedgerEvent(
              sessionId: sessionId,
              eventType: eventType,
              elapsedSeconds: elapsedSeconds,
              occurredAt: occurredAt,
            );
          },
    );
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

  void _showLedgerFailure(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> changePomodoroPreset({
    required int focusMinutes,
    required int restMinutes,
  }) async {
    if (isRunning) return;
    try {
      await _ledgerController?.discard(elapsedSeconds: elapsedSeconds);
    } catch (_) {
      _showLedgerFailure('模式變更尚未安全保存，請稍後重試');
      return;
    }

    if (!mounted) return;
    setState(() {
      selectedFocusMinutes = focusMinutes;
      selectedRestMinutes = restMinutes;
      currentPhase = _PomodoroPhase.focus;
      remainingSeconds = focusMinutes * 60;
      completedPomodoros = 0;
    });
  }

  Future<void> startTimer() async {
    if (isRunning) return;
    unawaited(_sound?.resume());
    if (isFocusPhase) {
      try {
        await _ledgerController?.startOrResume(elapsedSeconds: elapsedSeconds);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('專注事件尚未安全保存，請稍後重試')));
        return;
      }
    }

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
        unawaited(completeCurrentPhase());
      }
    });
  }

  Future<void> completeCurrentPhase() async {
    final finishedPhase = currentPhase;
    final finishedFocusMinutes = selectedFocusMinutes;
    final finishedRestMinutes = selectedRestMinutes;

    if (finishedPhase == _PomodoroPhase.focus) {
      if (mounted) {
        setState(() {
          isRunning = false;
        });
      }
      try {
        await _ledgerController?.complete(elapsedSeconds: focusSeconds);
      } catch (_) {
        _showLedgerFailure('完成事件尚未安全保存，專注進度未變更');
        return;
      }
      if (!mounted) return;
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
        _cheerAt = DateTime.now();
      }
      currentPhase = nextPhase;
      remainingSeconds = phaseTotalSeconds;
    });

    if (!mounted) return;

    if (widget.immersive && finishedPhase == _PomodoroPhase.focus) {
      final startRest = await _showResult(
        minutes: finishedFocusMinutes,
        round: completedPomodoros,
        restMinutes: finishedRestMinutes,
      );
      if (!mounted) return;
      if (startRest == true) {
        unawaited(startTimer());
      } else {
        unawaited(Navigator.of(context).maybePop());
      }
      return;
    }

    final shouldStartNext = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isFinishedFocus = finishedPhase == _PomodoroPhase.focus;
        return AlertDialog(
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
      unawaited(startTimer());
    }
  }

  /// Desk mode celebrates a finished focus with the game result screen.
  /// The reward line follows the Cloud's confirmed activity feedback.
  Future<bool?> _showResult({
    required int minutes,
    required int round,
    required int? restMinutes,
  }) async {
    final appState = context.read<AppState>();
    final feedback = ValueNotifier(appState.confirmedActivityFeedback);
    void sync() => feedback.value = appState.confirmedActivityFeedback;
    appState.addListener(sync);
    try {
      return await showFocusResult(
        context,
        profile: appState.avatarProfile,
        focusMinutes: minutes,
        round: round,
        restMinutes: restMinutes,
        feedback: feedback,
      );
    } finally {
      appState.removeListener(sync);
      feedback.dispose();
    }
  }

  Future<void> pauseTimer() async {
    unawaited(_sound?.pause());
    if (isFocusPhase) {
      try {
        await _ledgerController?.pause(elapsedSeconds: elapsedSeconds);
      } catch (_) {
        _showLedgerFailure('暫停事件尚未安全保存，計時會繼續');
        return;
      }
    }
    timer?.cancel();
    if (!mounted) return;
    setState(() {
      isRunning = false;
    });
  }

  Future<void> resetTimer() async {
    try {
      await _ledgerController?.discard(elapsedSeconds: elapsedSeconds);
    } catch (_) {
      _showLedgerFailure('重設事件尚未安全保存，原有計時狀態已保留');
      return;
    }
    timer?.cancel();
    if (!mounted) return;
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
        if (wasRunning) unawaited(startTimer());
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
      if (wasRunning) unawaited(startTimer());
      return;
    }

    final savedSeconds = elapsedSeconds;
    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
      if (wasRunning) unawaited(startTimer());
      return;
    }

    timer?.cancel();

    final appState = context.read<AppState>();
    try {
      await _ledgerController?.complete(elapsedSeconds: savedSeconds);
    } catch (_) {
      _showLedgerFailure('完成事件尚未安全保存，專注進度未變更');
      if (wasRunning && mounted) unawaited(startTimer());
      return;
    }
    if (!mounted) return;
    appState.addFocusSeconds(savedSeconds);

    setState(() {
      isRunning = false;
      currentPhase = _PomodoroPhase.focus;
      remainingSeconds = focusSeconds;
    });

    if (widget.immersive) {
      await _showResult(
        minutes: (savedSeconds / 60).round(),
        round: completedPomodoros + 1,
        restMinutes: null,
      );
      if (mounted) unawaited(Navigator.of(context).maybePop());
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已記錄 ${formatDuration(savedSeconds)}專注時間')),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _sound?.dispose();
    if (isFocusPhase) {
      final pendingDiscard = _ledgerController?.discard(
        elapsedSeconds: elapsedSeconds,
      );
      if (pendingDiscard != null) {
        unawaited(
          pendingDiscard.catchError((Object error, StackTrace stackTrace) {
            debugPrint('Unable to durably discard the focus session: $error');
          }),
        );
      }
    }
    super.dispose();
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
      await changePomodoroPreset(
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

  Future<CabinLayout>? _cabinLayout;

  bool get _cheering =>
      _cheerAt != null &&
      DateTime.now().difference(_cheerAt!) < const Duration(seconds: 3);

  /// Reads while focusing; during the break stretches, has tea, looks out.
  PlayerAnimation _deskAnimation() {
    if (_cheering) return PlayerAnimation.happy;
    if (!isRunning) return PlayerAnimation.sit;
    if (isFocusPhase) return PlayerAnimation.read;
    return switch ((remainingSeconds ~/ 20) % 3) {
      0 => PlayerAnimation.stretch,
      1 => PlayerAnimation.snack,
      _ => PlayerAnimation.look,
    };
  }

  Widget _buildDesk(BuildContext context, AppState appState) {
    _cabinLayout ??= CabinLayout.load(DefaultAssetBundle.of(context));
    final pose = !isRunning
        ? CompanionPose.idle
        : isFocusPhase
        ? CompanionPose.read
        : CompanionPose.sleep;
    return Scaffold(
      body: FutureBuilder<CabinLayout>(
        future: _cabinLayout,
        builder: (context, snapshot) {
          final layout = snapshot.data;
          if (layout == null) {
            return const ColoredBox(color: Color(0xFF3B2418));
          }
          final presentation = CabinPresentation.resolve(
            summaries: appState.dailySummaries,
            badges: appState.badgeRecords,
            decor: appState.homeDecor,
            action: DailyNextAction.resolve(appState.tasks),
            openTaskCount: 0,
            hasDevice: false,
            deviceFocusing: false,
          );
          return CabinStage(
            layout: layout,
            presentation: presentation,
            builder: (context, box) {
              final charHeight = layout.character.height * box.height;
              final seat = CabinCompanionBrain.desk;
              final top = MediaQuery.paddingOf(context).top;
              Widget button(
                String label,
                VoidCallback? onTap, {
                bool gold = true,
              }) => Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: gold
                        ? const Color(0xFFFFC54D)
                        : const Color(0xFF8A5A34),
                    foregroundColor: gold
                        ? const Color(0xFF2A1600)
                        : Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: onTap,
                  child: Text(label),
                ),
              );
              return [
                Positioned(
                  left: box.left + seat.dx * box.width - charHeight / 2,
                  top: box.top + seat.dy * box.height - charHeight,
                  width: charHeight,
                  height: charHeight,
                  child: FittedBox(
                    alignment: Alignment.bottomCenter,
                    child: PlayerAvatar(
                      key: const Key('desk-player'),
                      look: _look,
                      animation: _deskAnimation(),
                      scale: (charHeight / (56 * 0.72)).roundToDouble().clamp(
                        1,
                        6,
                      ),
                      fallback: CompanionSprite(
                        profile: appState.avatarProfile,
                        pose: pose,
                        size: charHeight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: box.left + 0.66 * box.width,
                  top: box.top + 0.385 * box.height,
                  width: box.width * 0.07,
                  height: box.height * 0.065,
                  child: Semantics(
                    label:
                        '沙漏：${isFocusPhase ? '專注' : '休息'}還剩 ${(100 * remainingSeconds / phaseTotalSeconds).round()}%',
                    child: CustomPaint(
                      key: const Key('desk-hourglass'),
                      painter: HourglassPainter(
                        left: (remainingSeconds / phaseTotalSeconds).clamp(
                          0.0,
                          1.0,
                        ),
                        flipped: !isFocusPhase,
                      ),
                    ),
                  ),
                ),
                if (_cheering)
                  Positioned(
                    left: box.left + 0.42 * box.width,
                    top: box.top + 0.3 * box.height,
                    width: box.width * 0.3,
                    height: box.height * 0.16,
                    child: IgnorePointer(
                      child: WorldClock(
                        builder: (_, f, still) => CustomPaint(
                          key: const Key('desk-rewards'),
                          painter: _RewardPainter(still ? 12 : f % 24),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: box.top + box.height * 0.075,
                  child: Center(
                    child: Container(
                      key: const Key('desk-clock'),
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A5A34), Color(0xFF5A3826)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        border: Border.all(
                          color: const Color(0xFFC9934F),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFF3B2418),
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              fontFamily: 'Cubic11',
                              color: Color(0xFFFFE6A3),
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              fontFeatures: [FontFeature.tabularFigures()],
                              shadows: [
                                Shadow(
                                  color: Color(0x99FFC850),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            phaseTitle,
                            style: const TextStyle(
                              color: Color(0xFFF3D9B0),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: top + 6,
                  child: Material(
                    color: const Color(0xB3201008),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: '回到小屋',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: top + 6,
                  child: Material(
                    color: const Color(0xB3201008),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      key: const Key('desk-sound'),
                      customBorder: const StadiumBorder(),
                      onTap: _openSoundSheet,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.music_note_rounded,
                              color: Color(0xFFFFE6A3),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sound?.current?.label ?? '聲音',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.paddingOf(context).bottom + 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRunning)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (final (f, r) in const [
                                (2, 1),
                                (25, 5),
                                (50, 10),
                              ])
                                ChoiceChip(
                                  // Too tired to start? Two minutes is enough to begin.
                                  label: Text(f == 2 ? '先 2 分鐘' : '$f + $r'),
                                  selected:
                                      selectedFocusMinutes == f &&
                                      selectedRestMinutes == r,
                                  onSelected: (_) => changePomodoroPreset(
                                    focusMinutes: f,
                                    restMinutes: r,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Row(
                        children: isRunning
                            ? [
                                button('暫停', pauseTimer, gold: false),
                                const SizedBox(width: 10),
                                button('結束並記錄', endEarlyAndSave),
                              ]
                            : [button(startButtonText, startTimer)],
                      ),
                    ],
                  ),
                ),
              ];
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (widget.immersive) return _buildDesk(context, appState);
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
                onTap: () => unawaited(
                  changePomodoroPreset(focusMinutes: 25, restMinutes: 5),
                ),
                accentColor: accentColor,
              ),
              const SizedBox(width: 10),
              buildModeButton(
                title: '50 + 10',
                isSelected:
                    selectedFocusMinutes == 50 && selectedRestMinutes == 10,
                onTap: () => unawaited(
                  changePomodoroPreset(focusMinutes: 50, restMinutes: 10),
                ),
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
                  const SizedBox(height: 12),
                  // The companion keeps you company: reads while you focus,
                  // dozes during the break.
                  CompanionSprite(
                    key: const Key('focus-companion'),
                    profile: appState.avatarProfile,
                    pose: !isRunning
                        ? CompanionPose.idle
                        : isFocusPhase
                        ? CompanionPose.read
                        : CompanionPose.sleep,
                    size: 140,
                  ),
                  const SizedBox(height: 8),
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

/// The focus timer as a pixel hourglass: the top bulb empties as time runs
/// out; it is turned over for the break.
class HourglassPainter extends CustomPainter {
  HourglassPainter({required this.left, required this.flipped});
  final double left;
  final bool flipped;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 14, size.height / 22);
    final p = Paint()..isAntiAlias = false;
    void row(int y, int w, Color c) => canvas.drawRect(
      Rect.fromLTWH(7.0 - w, y.toDouble(), w * 2.0, 1),
      p..color = c,
    );
    int width(int y) => (5 * (y - 11).abs() / 9).round().clamp(1, 5);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 14, 2),
      p..color = const Color(0xFF8A5A34),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 20, 14, 2),
      p..color = const Color(0xFF8A5A34),
    );
    for (var y = 2; y < 20; y++) {
      row(y, width(y), const Color(0x8CBEDCFF));
    }
    final top = flipped ? 1 - left : left;
    final up = (8 * top).round(), down = (8 * (1 - top)).round();
    for (var k = 0; k < up; k++) {
      row(10 - k, width(10 - k), const Color(0xFFFFC54D));
    }
    for (var k = 0; k < down; k++) {
      row(19 - k, width(19 - k), const Color(0xFFFFC54D));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HourglassPainter old) =>
      old.left != left || old.flipped != flipped;
}

class _RewardPainter extends CustomPainter {
  _RewardPainter(this.frame);
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    for (var i = 0; i < 10; i++) {
      final t = frame / 24;
      final x = size.width * (0.5 + (i - 5) * 0.08 * t);
      final y = size.height * (1 - t) - (i % 3) * 6;
      p.color = i.isEven ? const Color(0xFFFFC54D) : const Color(0xFFFFF3CF);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, y), width: 6, height: 6),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_RewardPainter old) => old.frame != frame;
}
