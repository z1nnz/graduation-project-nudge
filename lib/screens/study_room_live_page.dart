import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_profile.dart';
import '../models/room_activity_session.dart';
import '../models/room_resonance.dart';
import '../models/study_hall_layout.dart';
import '../models/study_hall_seating.dart';
import '../models/study_room_models.dart';
import '../models/task_model.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/room_resonance_panel.dart';
import '../widgets/study_hall_scene.dart';
import 'health_page.dart';
import 'study_room_chat_page.dart';

class StudyRoomLivePage extends StatefulWidget {
  final String roomId;

  const StudyRoomLivePage({super.key, required this.roomId});

  @override
  State<StudyRoomLivePage> createState() => _StudyRoomLivePageState();
}

class _StudyRoomLivePageState extends State<StudyRoomLivePage> {
  static const int _defaultFocusSeconds = 25 * 60;

  Timer? _timer;
  int _durationSeconds = _defaultFocusSeconds;
  int _remainingSeconds = _defaultFocusSeconds;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  DateTime? _sessionStartTime;
  String? _roomActivitySessionId;
  // Voice joins the room once the App voice client lands (shared contract).
  final bool _voiceJoined = false;
  final bool _micMuted = false;
  DateTime? _chatLastRead;
  bool _chatReadLoaded = false;
  final Map<String, String> _reactions = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AppState>();
      _loadChatRead(appState.currentUser?.id ?? 'local_user');
    });
  }

  Future<void> _loadChatRead(String myId) async {
    final value = await RoomChatReadState.lastRead(widget.roomId, myId);
    if (!mounted) return;
    setState(() {
      _chatLastRead = value;
      _chatReadLoaded = true;
    });
  }

  Future<void> _openChat(String myId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyRoomChatPage(roomId: widget.roomId),
      ),
    );
    await _loadChatRead(myId);
  }

  /// Shared-goal lantern: 0 unlit, 1 half way, 2 reached.
  int _lanternStage(StudyRoomData room, List<StudyMemberData> members) {
    final goal = room.challengeGoalSeconds;
    if (goal <= 0) return 0;
    final total = members.fold<int>(0, (sum, m) => sum + m.todayFocusSeconds);
    final ratio = total / goal;
    if (ratio >= 1) return 2;
    if (ratio >= 0.5) return 1;
    return 0;
  }

  String _reactionGlyph(RoomResonanceResponse response) => switch (response) {
    RoomResonanceResponse.withYou => '🤝',
    RoomResonanceResponse.cheer => '✨',
    RoomResonanceResponse.takeYourTime => '🍵',
  };

  Future<void> _respond(
    AppState appState,
    RoomResonanceSignal signal,
    RoomResonanceResponse response,
    String memberId,
  ) async {
    try {
      await appState.acknowledgeRoomResonance(
        signal: signal,
        response: response,
      );
      if (!mounted) return;
      setState(() => _reactions[memberId] = _reactionGlyph(response));
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _reactions.remove(memberId));
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('回應沒有送出：$error')));
    }
  }

  void _showMember(
    AppState appState,
    StudyRoomData room,
    StudyMemberData member,
    String myId,
  ) {
    final name = member.roomNickname.isEmpty
        ? member.name
        : member.roomNickname;
    final mine = member.memberId == myId;
    final signal = appState
        .roomResonanceSignals(room.id)
        .where(
          (s) =>
              s.ownerUserId == member.memberId &&
              s.status == RoomResonanceStatus.active,
        )
        .firstOrNull;
    final minutes = member.todayFocusSeconds ~/ 60;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          key: const Key('room-member-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mine ? '$name（你）' : name,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(_memberStatusText(room, member.status)),
              Text('今天累積 $minutes 分鐘'),
              if (!mine && signal != null) ...[
                const SizedBox(height: 14),
                Text('$name：${signal.cue.label}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final response in RoomResonanceResponse.values)
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _respond(appState, signal, response, member.memberId);
                        },
                        child: Text(response.label),
                      ),
                  ],
                ),
              ] else if (!mine) ...[
                const SizedBox(height: 12),
                const Text('對方沒有發出共鳴信號時，安靜陪伴就是最好的支持。'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_commitSessionAsResting());
    if (_voiceJoined) {
      try {
        context.read<AppState>().leaveVoiceRoom(widget.roomId);
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _startSession(AppState appState, StudyRoomData room) async {
    if (_isRunning) return;
    RoomActivitySession? sessionForStart;
    try {
      final current = appState.activeRoomActivitySession(room.id);
      if (current == null) {
        sessionForStart = await appState.startRoomActivitySession(
          roomId: room.id,
          targetValue: _durationSeconds / 60,
        );
        _roomActivitySessionId = sessionForStart.sessionId;
      } else {
        sessionForStart = current;
        _roomActivitySessionId = current.sessionId;
        if (current.status == RoomActivitySessionStatus.paused) {
          final localMetric = _sessionMetricValue(room);
          sessionForStart = await appState.transitionRoomActivitySession(
            roomId: room.id,
            sessionId: current.sessionId,
            status: RoomActivitySessionStatus.active,
            metricValue: localMetric < current.metricValue
                ? current.metricValue
                : localMetric,
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('無法開始這輪活動：$error')));
      return;
    }
    if (!mounted) return;
    if (_hasInRoomTimer(room)) {
      final restoredSeconds = (sessionForStart.metricValue * 60).round();
      final restoredTargetSeconds = (sessionForStart.targetValue * 60).round();
      _durationSeconds = restoredTargetSeconds;
      _elapsedSeconds = restoredSeconds.clamp(0, restoredTargetSeconds);
      _remainingSeconds = (restoredTargetSeconds - _elapsedSeconds).clamp(
        1,
        restoredTargetSeconds,
      );
    }
    setState(() {
      _isRunning = true;
      _sessionStartTime = DateTime.now();
    });
    await _recordRoomEvent(
      appState,
      roomId: room.id,
      text: '${appState.profileNickname} 開始${_activeNoun(room)}',
      type: StudyRoomEventType.start,
    );

    appState.updateMyStudyRoomPresence(
      roomId: room.id,
      status: StudyMemberStatus.studying,
      sessionSeconds: _elapsedSeconds,
    );

    _scheduleSessionTimer(appState, room);
  }

  void _scheduleSessionTimer(
    AppState appState,
    StudyRoomData room, {
    bool autoComplete = true,
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1 && autoComplete) {
        _timer?.cancel();
        unawaited(_completeSession(appState, room));
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
        _elapsedSeconds++;
      });
    });
  }

  void _restartSessionTimer(
    AppState appState,
    StudyRoomData room, {
    bool autoComplete = true,
  }) {
    if (!mounted || !_isRunning) return;
    _scheduleSessionTimer(appState, room, autoComplete: autoComplete);
  }

  Future<void> _pauseSession(AppState appState, StudyRoomData room) async {
    if (!_isRunning) return;
    _timer?.cancel();
    final sessionId = _roomActivitySessionId;
    if (sessionId != null) {
      try {
        await appState.transitionRoomActivitySession(
          roomId: room.id,
          sessionId: sessionId,
          status: RoomActivitySessionStatus.paused,
          metricValue: _sessionMetricValue(room),
        );
      } catch (error) {
        if (!mounted) return;
        _restartSessionTimer(appState, room);
        _showSessionSyncError(error);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _isRunning = false;
    });
    await _recordRoomEvent(
      appState,
      roomId: room.id,
      text: '${appState.profileNickname} 暫停了這輪${_metricName(room)}',
      type: StudyRoomEventType.pause,
    );
    appState.updateMyStudyRoomPresence(
      roomId: room.id,
      status: StudyMemberStatus.resting,
      sessionSeconds: _elapsedSeconds,
    );
  }

  Future<void> _completeSession(AppState appState, StudyRoomData room) async {
    _timer?.cancel();
    final finishedSeconds = _elapsedSeconds + 1;
    final sessionId = _roomActivitySessionId;
    if (sessionId != null) {
      try {
        await appState.transitionRoomActivitySession(
          roomId: room.id,
          sessionId: sessionId,
          status: RoomActivitySessionStatus.completed,
          metricValue: _sessionMetricValue(
            room,
            elapsedSeconds: finishedSeconds,
          ),
        );
      } catch (error) {
        if (!mounted) return;
        _restartSessionTimer(appState, room, autoComplete: false);
        _showSessionSyncError(error);
        return;
      }
    }
    if (_isFocusRoom(room) && finishedSeconds > 0) {
      final endTime = DateTime.now();
      final startTime =
          _sessionStartTime ??
          endTime.subtract(Duration(seconds: finishedSeconds));
      appState.addSecureFocusSeconds(finishedSeconds, startTime, endTime);
    }
    appState.updateMyStudyRoomPresence(
      roomId: room.id,
      status: StudyMemberStatus.resting,
      sessionSeconds: 0,
    );
    await _recordRoomEvent(
      appState,
      roomId: room.id,
      text: '${appState.profileNickname} 完成一輪${_metricName(room)}',
      type: StudyRoomEventType.complete,
    );
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _remainingSeconds = _durationSeconds;
      _roomActivitySessionId = null;
    });
  }

  Future<void> _stopSession(AppState appState, StudyRoomData room) async {
    _timer?.cancel();
    final sessionId = _roomActivitySessionId;
    if (sessionId != null) {
      try {
        await appState.transitionRoomActivitySession(
          roomId: room.id,
          sessionId: sessionId,
          status: RoomActivitySessionStatus.cancelled,
          metricValue: _sessionMetricValue(room),
        );
      } catch (error) {
        if (!mounted) return;
        _restartSessionTimer(appState, room);
        _showSessionSyncError(error);
        return;
      }
    }
    if (_isFocusRoom(room) && _elapsedSeconds > 0) {
      final endTime = DateTime.now();
      final startTime =
          _sessionStartTime ??
          endTime.subtract(Duration(seconds: _elapsedSeconds));
      appState.addSecureFocusSeconds(_elapsedSeconds, startTime, endTime);
    }
    appState.clearMyStudyRoomPresence(room.id);
    await _recordRoomEvent(
      appState,
      roomId: room.id,
      text: '${appState.profileNickname} 離開即時房間',
      type: StudyRoomEventType.leave,
    );
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _remainingSeconds = _durationSeconds;
      _roomActivitySessionId = null;
    });
  }

  Future<void> _commitSessionAsResting() async {
    if (!_isRunning || _elapsedSeconds <= 0) return;
    final appState = context.read<AppState>();
    final room = appState.getStudyRoomById(widget.roomId);
    if (room == null) return;
    final sessionId = _roomActivitySessionId;
    final elapsedSeconds = _elapsedSeconds;
    final metricValue = _sessionMetricValue(room);
    final endTime = DateTime.now();
    final startTime =
        _sessionStartTime ??
        endTime.subtract(Duration(seconds: elapsedSeconds));
    if (sessionId != null) {
      try {
        await appState.transitionRoomActivitySession(
          roomId: room.id,
          sessionId: sessionId,
          status: RoomActivitySessionStatus.paused,
          metricValue: metricValue,
        );
      } catch (error) {
        debugPrint('Failed to pause room activity during dispose: $error');
        return;
      }
    }
    if (_isFocusRoom(room)) {
      appState.addSecureFocusSeconds(elapsedSeconds, startTime, endTime);
    }
    appState.updateMyStudyRoomPresence(
      roomId: room.id,
      status: StudyMemberStatus.resting,
      sessionSeconds: 0,
    );
  }

  double _sessionMetricValue(StudyRoomData room, {int? elapsedSeconds}) {
    final seconds = elapsedSeconds ?? _elapsedSeconds;
    if (_isFocusRoom(room) || room.roomType == StudyRoomType.custom) {
      return seconds / 60;
    }
    final me = room.members.where(
      (member) =>
          member.memberId == 'local_user' ||
          member.memberId == context.read<AppState>().currentUser?.id,
    );
    return me.isEmpty ? 0 : me.first.todayMetricValue;
  }

  void _showSessionSyncError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('活動狀態同步失敗：$error')));
  }

  Future<void> _recordRoomEvent(
    AppState appState, {
    required String roomId,
    required String text,
    required StudyRoomEventType type,
  }) async {
    try {
      await appState.addStudyRoomEvent(roomId: roomId, text: text, type: type);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('活動已同步，但房間動態紀錄失敗：$error')));
    }
  }

  void _setDuration(int seconds) {
    if (_isRunning) return;
    setState(() {
      _durationSeconds = seconds;
      _remainingSeconds = seconds;
      _elapsedSeconds = 0;
    });
  }

  bool _isFocusRoom(StudyRoomData room) {
    return room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes;
  }

  bool _usesExternalProgress(StudyRoomData room) {
    return room.goalSourceType == TaskSourceType.sleepHours ||
        room.goalSourceType == TaskSourceType.exerciseMinutes ||
        room.goalSourceType == TaskSourceType.steps;
  }

  bool _hasInRoomTimer(StudyRoomData room) {
    return !_usesExternalProgress(room);
  }

  String _formatMetricValue(StudyRoomData room, double value) {
    if (value % 1 == 0) return '${value.toInt()} ${room.goalUnitLabel}';
    return '${value.toStringAsFixed(1)} ${room.goalUnitLabel}';
  }

  String _healthSyncDescription(StudyRoomData room) {
    switch (room.roomType) {
      case StudyRoomType.sleep:
        return '睡眠房不在房內開始計時；App 會將 Health Connect 或 Apple Health 的睡眠紀錄送往活動帳本，驗證後自動更新房間進度。';
      case StudyRoomType.exercise:
        return '運動分鐘會由 Health Connect 或 Apple Health 送往活動帳本，驗證後自動更新房間進度；房內保留聊天和鼓勵打卡。';
      case StudyRoomType.steps:
        return '步數房不在房內手動登錄；App 會將 Health Connect 或 Apple Health 的步數送往活動帳本，驗證後自動更新房間進度。';
      case StudyRoomType.study:
      case StudyRoomType.custom:
        return '這間房會從可信任的外部資料來源同步今日進度。';
    }
  }

  String _metricName(StudyRoomData room) {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '專注';
      case StudyRoomType.sleep:
        return '睡眠';
      case StudyRoomType.exercise:
        return '運動';
      case StudyRoomType.steps:
        return '步數';
      case StudyRoomType.custom:
        return '自律';
    }
  }

  String _activeNoun(StudyRoomData room) {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '專注';
      case StudyRoomType.sleep:
        return '睡覺';
      case StudyRoomType.exercise:
        return '運動';
      case StudyRoomType.steps:
        return '走路';
      case StudyRoomType.custom:
        return '自律';
    }
  }

  String _startActionText(StudyRoomData room) {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '開始專注';
      case StudyRoomType.sleep:
        return '同步睡眠';
      case StudyRoomType.exercise:
        return '同步運動';
      case StudyRoomType.steps:
        return '同步步數';
      case StudyRoomType.custom:
        return '開始自律';
    }
  }

  IconData _startActionIcon(StudyRoomData room) {
    switch (room.roomType) {
      case StudyRoomType.study:
        return Icons.play_arrow_rounded;
      case StudyRoomType.sleep:
        return Icons.bedtime_outlined;
      case StudyRoomType.exercise:
        return Icons.fitness_center;
      case StudyRoomType.steps:
        return Icons.directions_walk;
      case StudyRoomType.custom:
        return Icons.bolt_outlined;
    }
  }

  String _memberStatusText(StudyRoomData room, StudyMemberStatus status) {
    if (_usesExternalProgress(room)) {
      return switch (status) {
        StudyMemberStatus.studying => '同步中',
        StudyMemberStatus.resting => '已達標',
        StudyMemberStatus.offline => '待同步',
      };
    }

    switch (status) {
      case StudyMemberStatus.studying:
        return '${_activeNoun(room)}中';
      case StudyMemberStatus.resting:
        return '休息中';
      case StudyMemberStatus.offline:
        return '離線';
    }
  }

  AvatarProfile _memberAvatarProfile(
    AppState appState,
    StudyMemberData member,
  ) {
    if (member.memberId == 'local_user' ||
        member.memberId == appState.currentUser?.id) {
      return appState.avatarProfile;
    }
    return member.avatarProfile ??
        appState.avatarVariantForSeed(
          member.memberId.isEmpty
              ? member.name.hashCode
              : member.memberId.hashCode,
        );
  }

  String _timerText() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Timer length, health sync, resonance signals and room activity: the
  /// tools that used to be stacked under the hall, now one tap away.
  void _showRoomTools({
    required AppState appState,
    required StudyRoomData room,
    required StudyMemberData me,
    required double externalProgress,
    required List<StudyMemberData> approvedMembers,
    required String currentMemberId,
    required bool hasApprovedMembership,
  }) {
    final accent = room.accentColor;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6E7C8),
      // The sheet does not rebuild with the page, so it ticks on its own
      // to keep the countdown in step.
      builder: (sheetContext) => _EverySecond(
        builder: (_) => DraggableScrollableSheet(
          key: const Key('room-tools-sheet'),
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              if (_hasInRoomTimer(room))
                _TimerPanel(
                  accent: accent,
                  timerText: _timerText(),
                  isRunning: _isRunning,
                  progress: _durationSeconds <= 0
                      ? 0
                      : 1 - (_remainingSeconds / _durationSeconds),
                  startText: _startActionText(room),
                  startIcon: _startActionIcon(room),
                  onStart: () => _startSession(appState, room),
                  onPause: () => _pauseSession(appState, room),
                  onStop: () {
                    Navigator.pop(sheetContext);
                    _stopSession(appState, room);
                  },
                  onDurationChanged: _setDuration,
                  selectedDuration: _durationSeconds,
                )
              else
                _HealthSyncPanel(
                  accent: accent,
                  metricName: _metricName(room),
                  currentValueText: _formatMetricValue(
                    room,
                    me.todayMetricValue,
                  ),
                  goalText: _formatMetricValue(room, room.dailyGoalValue),
                  progress: externalProgress,
                  isHealthConnected: appState.isHealthConnected,
                  description: _healthSyncDescription(room),
                  onSync: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HealthPage()),
                    );
                  },
                ),
              const SizedBox(height: AppUI.sectionGap),
              RoomResonancePanel(
                accent: accent,
                currentUserId: currentMemberId,
                available:
                    appState.currentUser != null &&
                    !appState.isGuestMode &&
                    hasApprovedMembership,
                sharingEnabled: appState.roomResonanceSharingEnabled(room.id),
                signals: appState.roomResonanceSignals(room.id),
                memberNames: {
                  for (final member in approvedMembers)
                    member.memberId: member.roomNickname.isEmpty
                        ? member.name
                        : member.roomNickname,
                },
                onSharingChanged: (enabled) => appState.setRoomResonanceSharing(
                  roomId: room.id,
                  enabled: enabled,
                ),
                onPublish: (cue) async {
                  await appState.publishRoomResonance(
                    roomId: room.id,
                    cue: cue,
                  );
                },
                onWithdraw: () => appState.withdrawRoomResonance(room.id),
                onAcknowledge: (signal, response) async {
                  await appState.acknowledgeRoomResonance(
                    signal: signal,
                    response: response,
                  );
                },
              ),
              const SizedBox(height: AppUI.sectionGap),
              Card(
                shape: AppUI.cardShape(),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  title: const Text('房間動態'),
                  children: [_EventPanel(events: room.events, accent: accent)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final room = appState.getStudyRoomById(widget.roomId);
        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('即時自律房')),
            body: const Center(child: Text('找不到這個房間')),
          );
        }

        final approvedMembers = room.members
            .where((member) => member.isApproved)
            .toList(growable: false);
        final activityCount = _usesExternalProgress(room)
            ? approvedMembers
                  .where((member) => member.hasReachedPersonalGoal)
                  .length
            : approvedMembers
                  .where(
                    (member) => member.status == StudyMemberStatus.studying,
                  )
                  .length;
        final currentMemberId = appState.currentUser?.id ?? 'local_user';
        final hasApprovedMembership = approvedMembers.any(
          (member) => member.memberId == currentMemberId,
        );
        final me = approvedMembers.firstWhere(
          (member) => member.memberId == currentMemberId,
          orElse: () => StudyMemberData(
            memberId: 'local_user',
            name: appState.profileNickname,
            roomNickname: appState.profileNickname,
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: appState.focusSeconds,
            todayMetricValue: 0,
            avatarColor: const Color(0xFF7C6AE6),
          ),
        );
        final externalProgress = room.dailyGoalValue <= 0
            ? 0.0
            : (me.todayMetricValue / room.dailyGoalValue)
                  .clamp(0.0, 1.0)
                  .toDouble();

        final unread = _chatReadLoaded
            ? RoomChatReadState.unreadCount(
                room.messages,
                lastRead: _chatLastRead,
                myId: currentMemberId,
              )
            : 0;
        final hasSession = _isRunning || _roomActivitySessionId != null;
        final timerRoom = _hasInRoomTimer(room);
        final padding = MediaQuery.paddingOf(context);
        final seating = StudyHallSeating.assign([
          for (final member in approvedMembers)
            member.avatarProfile != null
                ? member
                : member.copyWith(
                    avatarProfile: _memberAvatarProfile(appState, member),
                  ),
        ], myId: currentMemberId);

        void say(String text) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(text)));
        }

        void onVoice() {
          if (!room.voiceEnabled) {
            say('房主開啟語音後，就能一起開麥克風讀書');
            return;
          }
          say('App 的語音自習即將開放，現在可以先在 Web 版加入');
        }

        Future<void> onMain() async {
          if (!timerRoom) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HealthPage()),
            );
            return;
          }
          if (_isRunning) {
            await _pauseSession(appState, room);
          } else {
            await _startSession(appState, room);
          }
        }

        final mainLabel = !timerRoom
            ? '同步'
            : _isRunning
            ? '暫停'
            : hasSession
            ? '繼續'
            : _startActionText(room);
        final mainIcon = !timerRoom
            ? Icons.sync_rounded
            : _isRunning
            ? Icons.pause_rounded
            : _startActionIcon(room);

        return Scaffold(
          backgroundColor: const Color(0xFF1B1530),
          body: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // The portrait hall covers the whole screen.
                    var w = box.maxWidth;
                    var h = w / StudyHallLayout.aspect;
                    if (h < box.maxHeight) {
                      h = box.maxHeight;
                      w = h * StudyHallLayout.aspect;
                    }
                    return ClipRect(
                      child: OverflowBox(
                        maxWidth: w,
                        maxHeight: h,
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: StudyHallScene(
                            roomType: room.roomType,
                            seating: seating,
                            myId: currentMemberId,
                            lanternStage: _lanternStage(room, approvedMembers),
                            reactions: _reactions,
                            fullBleed: true,
                            bannerTop: padding.top + 72,
                            onMemberTap: (member) => _showMember(
                              appState,
                              room,
                              member,
                              currentMemberId,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: padding.top + 10,
                child: Row(
                  children: [
                    _WoodRoundButton(
                      key: const Key('room-back'),
                      icon: Icons.arrow_back_rounded,
                      label: '離開房間',
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RoomNamePlate(
                        key: const Key('room-title'),
                        name: room.name,
                        detail: _usesExternalProgress(room)
                            ? '$activityCount 人達標'
                            : '$activityCount 人進行中',
                      ),
                    ),
                  ],
                ),
              ),
              if (timerRoom && hasSession)
                Positioned(
                  left: 0,
                  right: 0,
                  top: padding.top + 178,
                  child: Center(
                    child: _RoomClock(
                      key: const Key('room-timer'),
                      text: _timerText(),
                      running: _isRunning,
                      progress: _durationSeconds <= 0
                          ? 0
                          : 1 - (_remainingSeconds / _durationSeconds),
                    ),
                  ),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: padding.bottom + 8,
                child: _RoomControlBar(
                  micOn: _voiceJoined && !_micMuted,
                  voiceJoined: _voiceJoined,
                  mainLabel: mainLabel,
                  mainIcon: mainIcon,
                  mainGlow: !_isRunning,
                  unread: unread,
                  onMic: onVoice,
                  onVoice: onVoice,
                  onMain: onMain,
                  onChat: () => _openChat(currentMemberId),
                  onMore: () => _showRoomTools(
                    appState: appState,
                    room: room,
                    me: me,
                    externalProgress: externalProgress,
                    approvedMembers: approvedMembers,
                    currentMemberId: currentMemberId,
                    hasApprovedMembership: hasApprovedMembership,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HealthSyncPanel extends StatelessWidget {
  final Color accent;
  final String metricName;
  final String currentValueText;
  final String goalText;
  final double progress;
  final bool isHealthConnected;
  final String description;
  final VoidCallback onSync;

  const _HealthSyncPanel({
    required this.accent,
    required this.metricName,
    required this.currentValueText,
    required this.goalText,
    required this.progress,
    required this.isHealthConnected,
    required this.description,
    required this.onSync,
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.health_and_safety_outlined, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '健康資料同步',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isHealthConnected ? '已連接健康資料' : '尚未連接健康資料',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isHealthConnected
                              ? const Color(0xFF10B981)
                              : secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SyncMetricTile(
                    label: '今日$metricName',
                    value: currentValueText,
                    icon: Icons.insights_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SyncMetricTile(
                    label: '房間目標',
                    value: goalText,
                    icon: Icons.flag_outlined,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUI.radiusPill),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: AppUI.isDark(context)
                    ? const Color(0xFF2A2F3A)
                    : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '目前進度 ${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSync,
                icon: const Icon(Icons.health_and_safety_outlined),
                label: Text(isHealthConnected ? '更新健康資料' : '連接健康資料'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SyncMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppUI.softCardOf(context, color),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerPanel extends StatelessWidget {
  final Color accent;
  final String timerText;
  final bool isRunning;
  final double progress;
  final String startText;
  final IconData startIcon;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final ValueChanged<int> onDurationChanged;
  final int selectedDuration;

  const _TimerPanel({
    required this.accent,
    required this.timerText,
    required this.isRunning,
    required this.progress,
    required this.startText,
    required this.startIcon,
    required this.onStart,
    required this.onPause,
    required this.onStop,
    required this.onDurationChanged,
    required this.selectedDuration,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    const options = [15 * 60, 25 * 60, 45 * 60, 60 * 60];

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '本輪倒數',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '倒數完成後會把讀書房專注時間同步進自律分數。',
              style: TextStyle(fontSize: 13, color: secondaryText),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                timerText,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: primaryText,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppUI.radiusPill),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: AppUI.isDark(context)
                    ? const Color(0xFF2A2F3A)
                    : const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((seconds) {
                return ChoiceChip(
                  label: Text('${seconds ~/ 60} 分'),
                  selected: selectedDuration == seconds,
                  onSelected: isRunning
                      ? null
                      : (_) => onDurationChanged(seconds),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: isRunning ? null : onStart,
                  icon: Icon(startIcon),
                  label: Text(startText),
                ),
                OutlinedButton.icon(
                  onPressed: isRunning ? onPause : null,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('暫停'),
                ),
                OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('結束'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventPanel extends StatelessWidget {
  final List<StudyRoomEvent> events;
  final Color accent;

  const _EventPanel({required this.events, required this.accent});

  IconData _iconFor(StudyRoomEventType type) {
    switch (type) {
      case StudyRoomEventType.join:
        return Icons.login_rounded;
      case StudyRoomEventType.start:
        return Icons.play_arrow_rounded;
      case StudyRoomEventType.pause:
        return Icons.pause_circle_outline;
      case StudyRoomEventType.complete:
        return Icons.check_circle_outline;
      case StudyRoomEventType.cancel:
        return Icons.cancel_outlined;
      case StudyRoomEventType.leave:
        return Icons.logout_rounded;
      case StudyRoomEventType.message:
        return Icons.chat_bubble_outline;
      case StudyRoomEventType.sticker:
        return Icons.volunteer_activism_outlined;
      case StudyRoomEventType.system:
        return Icons.meeting_room_outlined;
    }
  }

  Color _colorFor(StudyRoomEventType type) {
    switch (type) {
      case StudyRoomEventType.start:
      case StudyRoomEventType.complete:
        return const Color(0xFF10B981);
      case StudyRoomEventType.pause:
        return const Color(0xFFF59E0B);
      case StudyRoomEventType.cancel:
      case StudyRoomEventType.leave:
        return const Color(0xFF64748B);
      case StudyRoomEventType.message:
        return const Color(0xFF4F8CFF);
      case StudyRoomEventType.sticker:
      case StudyRoomEventType.join:
      case StudyRoomEventType.system:
        return accent;
    }
  }

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
            Text(
              '房間事件',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              Text(
                '還沒有事件紀錄，開始一輪自律後會出現在這裡。',
                style: TextStyle(fontSize: 13, color: secondaryText),
              )
            else
              ...events.take(6).map((event) {
                final color = _colorFor(event.type);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconFor(event.type),
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          event.text,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryText,
                          ),
                        ),
                      ),
                      Text(
                        '剛剛',
                        style: TextStyle(fontSize: 11, color: secondaryText),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

/// Entry to the room chat page: latest message preview and unread count.

const _font = 'Cubic11';

class _WoodRoundButton extends StatelessWidget {
  const _WoodRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8A5A34), Color(0xFF5A3826)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC9934F), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), offset: Offset(0, 3)),
            ],
          ),
          child: Icon(icon, color: const Color(0xFFFFE6A3)),
        ),
      ),
    );
  }
}

class _RoomNamePlate extends StatelessWidget {
  const _RoomNamePlate({super.key, required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xEE8A5A34), Color(0xEE5A3826)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC9934F), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 18,
              color: Color(0xFFFFF3D6),
            ),
          ),
          Text(
            detail,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 13,
              color: Color(0xFFFFD76A),
            ),
          ),
        ],
      ),
    );
  }
}

/// The shared wall clock while my session runs.
class _RoomClock extends StatelessWidget {
  const _RoomClock({
    super.key,
    required this.text,
    required this.running,
    required this.progress,
  });

  final String text;
  final bool running;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      decoration: BoxDecoration(
        color: const Color(0xEE3A2216),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9934F), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontFamily: _font,
              fontSize: 40,
              color: Color(0xFFFFE6A3),
            ),
          ),
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0x55000000),
                color: running
                    ? const Color(0xFFFFC54D)
                    : const Color(0xFF9C8A70),
              ),
            ),
          ),
          if (!running)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '已暫停',
                style: TextStyle(
                  fontFamily: _font,
                  fontSize: 12,
                  color: Color(0xFFE8D5B5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom wooden bar: mic, voice, the big main action, chat and more.
class _RoomControlBar extends StatelessWidget {
  const _RoomControlBar({
    required this.micOn,
    required this.voiceJoined,
    required this.mainLabel,
    required this.mainIcon,
    required this.mainGlow,
    required this.unread,
    required this.onMic,
    required this.onVoice,
    required this.onMain,
    required this.onChat,
    required this.onMore,
  });

  final bool micOn;
  final bool voiceJoined;
  final String mainLabel;
  final IconData mainIcon;
  final bool mainGlow;
  final int unread;
  final VoidCallback onMic;
  final VoidCallback onVoice;
  final VoidCallback onMain;
  final VoidCallback onChat;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xEE8A5A34), Color(0xEE4A2D1E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC9934F), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _BarSlot(
                key: const Key('room-mic'),
                icon: micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                label: micOn ? '麥克風' : '靜音',
                onTap: onMic,
              ),
              _BarSlot(
                key: const Key('room-voice'),
                icon: voiceJoined
                    ? Icons.headset_rounded
                    : Icons.headset_off_rounded,
                label: voiceJoined ? '離開語音' : '加入語音',
                onTap: onVoice,
              ),
              Expanded(
                flex: 6,
                child: _MainMedallion(
                  key: const Key('room-main-action'),
                  icon: mainIcon,
                  label: mainLabel,
                  glow: mainGlow,
                  onTap: onMain,
                ),
              ),
              _BarSlot(
                key: const Key('room-chat'),
                icon: Icons.forum_rounded,
                label: '聊天',
                badge: unread,
                onTap: onChat,
              ),
              _BarSlot(
                key: const Key('room-more'),
                icon: Icons.more_horiz_rounded,
                label: '更多',
                onTap: onMore,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarSlot extends StatelessWidget {
  const _BarSlot({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          button: true,
          label: badge > 0 ? '$label，$badge 則未讀' : label,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                Container(
                  height: 66,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E7C8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4A2D22),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: const Color(0xFF8A5A34), size: 28),
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 13,
                          color: Color(0xFF3A1D0C),
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -6,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8452E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFFFF3D6),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontFamily: _font,
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The big round gold button in the middle of the bar.
class _MainMedallion extends StatelessWidget {
  const _MainMedallion({
    super.key,
    required this.icon,
    required this.label,
    required this.glow,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool glow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  colors: [
                    Color(0xFFFFF6D0),
                    Color(0xFFFFC54D),
                    Color(0xFFE07A1F),
                  ],
                  stops: [0, 0.55, 1],
                ),
                border: Border.all(color: const Color(0xFF4A2410), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: glow
                        ? const Color(0x99FFC85A)
                        : const Color(0x66000000),
                    blurRadius: glow ? 18 : 6,
                    spreadRadius: glow ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: const Color(0xFF4A2410)),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9C7BEF), Color(0xFF6A4FC8)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2E1A5C), width: 2),
                ),
                // Labels like 開始專注 shrink to fit instead of being cut.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: _font,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rebuilds its child once a second while it is on screen.
class _EverySecond extends StatefulWidget {
  const _EverySecond({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<_EverySecond> {
  late final Timer _tick = Timer.periodic(
    const Duration(seconds: 1),
    (_) => setState(() {}),
  );

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
