import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_profile.dart';
import '../models/study_room_models.dart';
import '../models/task_model.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'health_page.dart';

class StudyRoomLivePage extends StatefulWidget {
  final String roomId;

  const StudyRoomLivePage({super.key, required this.roomId});

  @override
  State<StudyRoomLivePage> createState() => _StudyRoomLivePageState();
}

class _StudyRoomLivePageState extends State<StudyRoomLivePage> {
  static const int _defaultFocusSeconds = 25 * 60;

  final TextEditingController _chatController = TextEditingController();

  Timer? _timer;
  int _durationSeconds = _defaultFocusSeconds;
  int _remainingSeconds = _defaultFocusSeconds;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  DateTime? _sessionStartTime;
  bool _voiceJoined = false;
  bool _micMuted = false;

  @override
  void dispose() {
    _timer?.cancel();
    _commitSessionAsResting();
    _chatController.dispose();
    if (_voiceJoined) {
      try {
        context.read<AppState>().leaveVoiceRoom(widget.roomId);
      } catch (_) {}
    }
    super.dispose();
  }

  void _startSession(AppState appState, StudyRoomData room) {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _sessionStartTime = DateTime.now();
    });
    appState.addStudyRoomEvent(
      roomId: room.id,
      text: '${appState.profileNickname} 開始${_activeNoun(room)}',
      type: StudyRoomEventType.start,
    );

    appState.updateMyStudyRoomPresence(
      roomId: room.id,
      status: StudyMemberStatus.studying,
      sessionSeconds: _elapsedSeconds,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        _completeSession(appState, room);
        return;
      }
      setState(() {
        _remainingSeconds--;
        _elapsedSeconds++;
      });
    });
  }

  void _pauseSession(AppState appState, StudyRoomData room) {
    if (!_isRunning) return;
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    appState.addStudyRoomEvent(
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

  void _completeSession(AppState appState, StudyRoomData room) {
    _timer?.cancel();
    final finishedSeconds = _elapsedSeconds + 1;
    if (_isFocusRoom(room) && finishedSeconds > 0) {
      final endTime = DateTime.now();
      final startTime = _sessionStartTime ?? endTime.subtract(Duration(seconds: finishedSeconds));
      appState.addSecureFocusSeconds(finishedSeconds, startTime, endTime);
    }
    appState.updateMyStudyRoomPresence(
      roomId: room.id,
      status: StudyMemberStatus.resting,
      sessionSeconds: 0,
    );
    appState.addStudyRoomEvent(
      roomId: room.id,
      text: '${appState.profileNickname} 完成一輪${_metricName(room)}',
      type: StudyRoomEventType.complete,
    );
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _remainingSeconds = _durationSeconds;
    });
  }

  void _stopSession(AppState appState, StudyRoomData room) {
    _timer?.cancel();
    if (_isFocusRoom(room) && _elapsedSeconds > 0) {
      final endTime = DateTime.now();
      final startTime = _sessionStartTime ?? endTime.subtract(Duration(seconds: _elapsedSeconds));
      appState.addSecureFocusSeconds(_elapsedSeconds, startTime, endTime);
    }
    appState.clearMyStudyRoomPresence(room.id);
    appState.addStudyRoomEvent(
      roomId: room.id,
      text: '${appState.profileNickname} 離開即時房間',
      type: StudyRoomEventType.leave,
    );
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
      _remainingSeconds = _durationSeconds;
    });
  }

  void _commitSessionAsResting() {
    if (!_isRunning || _elapsedSeconds <= 0) return;
    final appState = context.read<AppState>();
    final room = appState.getStudyRoomById(widget.roomId);
    if (room == null) return;
    if (_isFocusRoom(room)) {
      final endTime = DateTime.now();
      final startTime = _sessionStartTime ?? endTime.subtract(Duration(seconds: _elapsedSeconds));
      appState.addSecureFocusSeconds(_elapsedSeconds, startTime, endTime);
    }
    appState.updateMyStudyRoomPresence(
      roomId: room.id,
      status: StudyMemberStatus.resting,
      sessionSeconds: 0,
    );
  }

  void _setDuration(int seconds) {
    if (_isRunning) return;
    setState(() {
      _durationSeconds = seconds;
      _remainingSeconds = seconds;
      _elapsedSeconds = 0;
    });
  }

  void _sendMessage(AppState appState) {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    appState.addStudyRoomMessage(roomId: widget.roomId, text: text);
    appState.addStudyRoomEvent(
      roomId: widget.roomId,
      text: '${appState.profileNickname} 傳送了一則訊息',
      type: StudyRoomEventType.message,
    );
  }

  void _sendSticker(AppState appState, StudyRoomData room, String sticker) {
    appState.addStudyRoomMessage(
      roomId: room.id,
      text: sticker,
      type: StudyRoomMessageType.sticker,
    );
    appState.addStudyRoomEvent(
      roomId: room.id,
      text: '${appState.profileNickname} 送出鼓勵貼圖 $sticker',
      type: StudyRoomEventType.sticker,
    );
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
        return '睡眠房不在房內開始計時，會讀取健康資料中的睡眠時數來更新進度。';
      case StudyRoomType.exercise:
        return '運動房以健康資料的運動分鐘更新進度，房內保留聊天和鼓勵打卡。';
      case StudyRoomType.steps:
        return '步數房不在房內開始走路，會讀取健康資料中的今日步數來更新進度。';
      case StudyRoomType.study:
      case StudyRoomType.custom:
        return '這間房會從外部資料同步今日進度。';
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

  Color _memberStatusColor(StudyMemberStatus status) {
    switch (status) {
      case StudyMemberStatus.studying:
        return const Color(0xFF10B981);
      case StudyMemberStatus.resting:
        return const Color(0xFFF59E0B);
      case StudyMemberStatus.offline:
        return const Color(0xFF64748B);
    }
  }

  AvatarProfile _memberAvatarProfile(
    AppState appState,
    StudyMemberData member,
  ) {
    if (member.memberId == 'local_user') return appState.avatarProfile;
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

        final accent = room.accentColor;
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
        final me = approvedMembers.firstWhere(
          (member) => member.memberId == 'local_user',
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

        return Scaffold(
          appBar: AppBar(
            title: Text(room.name),
            actions: [
              if (_voiceJoined)
                IconButton(
                  icon: Icon(_micMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: _micMuted ? Colors.red : const Color(0xFF10B981)),
                  tooltip: _micMuted ? '取消靜音' : '靜音',
                  onPressed: () {
                    setState(() {
                      _micMuted = !_micMuted;
                    });
                  },
                ),
              IconButton(
                icon: Icon(_voiceJoined ? Icons.headset_rounded : Icons.headset_off_rounded, color: _voiceJoined ? accent : null),
                tooltip: _voiceJoined ? '退出語音房' : '加入語音房',
                onPressed: () async {
                  if (_voiceJoined) {
                    await appState.leaveVoiceRoom(widget.roomId);
                    setState(() {
                      _voiceJoined = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已退出語音房間')),
                      );
                    }
                  } else {
                    await appState.joinVoiceRoom(widget.roomId);
                    setState(() {
                      _voiceJoined = true;
                      _micMuted = false;
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已進入自律語音房 (Firestore 信令準備中)')),
                      );
                    }
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: _LivePill(
                    text: _usesExternalProgress(room)
                        ? '$activityCount 人達標'
                        : '$activityCount 人進行中',
                    color: _usesExternalProgress(room)
                        ? const Color(0xFF0EA5E9)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppUI.pagePadding),
            children: [
              _LiveRoomHeader(
                room: room,
                activeCount: activityCount,
                messageCount: room.messages.length,
                eventCount: room.events.length,
                accent: accent,
                metricName: _metricName(room),
              ),
              const SizedBox(height: AppUI.cardGap),
              _LiveStage(
                room: room,
                members: approvedMembers,
                themeKey: appState.backgroundThemeSetting,
                accent: accent,
                statusTextFor: (status) => _memberStatusText(room, status),
                statusColorFor: _memberStatusColor,
                avatarProfileFor: (member) =>
                    _memberAvatarProfile(appState, member),
              ),
              const SizedBox(height: AppUI.sectionGap),
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
                  onStop: () => _stopSession(appState, room),
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
              _StickerPanel(
                accent: accent,
                onStickerTap: (sticker) =>
                    _sendSticker(appState, room, sticker),
              ),
              const SizedBox(height: AppUI.sectionGap),
              _ChatPanel(
                controller: _chatController,
                messages: room.messages,
                currentUserId: 'local_user',
                accent: accent,
                onSend: () => _sendMessage(appState),
              ),
              const SizedBox(height: AppUI.sectionGap),
              _EventPanel(events: room.events, accent: accent),
              const SizedBox(height: 28),
            ],
          ),
        );
      },
    );
  }
}

class _LiveRoomHeader extends StatelessWidget {
  final StudyRoomData room;
  final int activeCount;
  final int messageCount;
  final int eventCount;
  final Color accent;
  final String metricName;

  const _LiveRoomHeader({
    required this.room,
    required this.activeCount,
    required this.messageCount,
    required this.eventCount,
    required this.accent,
    required this.metricName,
  });

  String _roomTypeLabel() {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '讀書房';
      case StudyRoomType.sleep:
        return '睡眠房';
      case StudyRoomType.exercise:
        return '運動房';
      case StudyRoomType.steps:
        return '步數房';
      case StudyRoomType.custom:
        return '自訂房';
    }
  }

  IconData _roomIcon() {
    switch (room.roomType) {
      case StudyRoomType.study:
        return Icons.menu_book_rounded;
      case StudyRoomType.sleep:
        return Icons.bedtime_outlined;
      case StudyRoomType.exercise:
        return Icons.fitness_center;
      case StudyRoomType.steps:
        return Icons.directions_walk;
      case StudyRoomType.custom:
        return Icons.auto_awesome_outlined;
    }
  }

  bool _usesExternalProgress() {
    return room.goalSourceType == TaskSourceType.sleepHours ||
        room.goalSourceType == TaskSourceType.exerciseMinutes ||
        room.goalSourceType == TaskSourceType.steps;
  }

  String _activityLabel() {
    return _usesExternalProgress() ? '達標' : '進行中';
  }

  IconData _activityIcon() {
    return _usesExternalProgress()
        ? Icons.verified_outlined
        : Icons.local_fire_department_outlined;
  }

  Color _activityColor() {
    return _usesExternalProgress()
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(AppUI.innerPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accent.withValues(alpha: AppUI.isDark(context) ? 0.28 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_roomIcon(), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_roomTypeLabel()} · 今日$metricName目標 ${room.dailyGoalValue % 1 == 0 ? room.dailyGoalValue.toInt() : room.dailyGoalValue} ${room.goalUnitLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: _activityLabel(),
                  value: '$activeCount',
                  icon: _activityIcon(),
                  color: _activityColor(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderMetric(
                  label: '訊息',
                  value: '$messageCount',
                  icon: Icons.chat_bubble_outline,
                  color: const Color(0xFF4F8CFF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderMetric(
                  label: '事件',
                  value: '$eventCount',
                  icon: Icons.bolt_outlined,
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HeaderMetric({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
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

class _LiveStage extends StatelessWidget {
  final StudyRoomData room;
  final List<StudyMemberData> members;
  final String themeKey;
  final Color accent;
  final String Function(StudyMemberStatus status) statusTextFor;
  final Color Function(StudyMemberStatus status) statusColorFor;
  final AvatarProfile Function(StudyMemberData member) avatarProfileFor;

  const _LiveStage({
    required this.room,
    required this.members,
    required this.themeKey,
    required this.accent,
    required this.statusTextFor,
    required this.statusColorFor,
    required this.avatarProfileFor,
  });

  String _stageTitle() {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '專注書桌區';
      case StudyRoomType.sleep:
        return '睡眠休息區';
      case StudyRoomType.exercise:
        return '運動訓練區';
      case StudyRoomType.steps:
        return '步數散步道';
      case StudyRoomType.custom:
        return '自律集合區';
    }
  }

  String _stageSubtitle() {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '大家各自安靜讀書，進度會同步到房間。';
      case StudyRoomType.sleep:
        return '睡眠時數由健康資料同步，房內負責提醒與陪伴。';
      case StudyRoomType.exercise:
        return '運動分鐘由健康資料同步，房內負責打卡與鼓勵。';
      case StudyRoomType.steps:
        return '今日步數由健康資料同步，房內負責排行榜與提醒。';
      case StudyRoomType.custom:
        return '開始自律後，房內成員會一起進入狀態。';
    }
  }

  Color _skyColor(BuildContext context) {
    if (AppUI.isDark(context)) return const Color(0xFF111827);
    if (themeKey != 'softGlow') {
      return AppUI.backgroundThemeColors(themeKey, AppUI.isDark(context)).first;
    }
    switch (room.roomType) {
      case StudyRoomType.study:
        return const Color(0xFFEFF6FF);
      case StudyRoomType.sleep:
        return const Color(0xFFEDE9FE);
      case StudyRoomType.exercise:
        return const Color(0xFFECFDF5);
      case StudyRoomType.steps:
        return const Color(0xFFF0FDFA);
      case StudyRoomType.custom:
        return const Color(0xFFFFF7ED);
    }
  }

  Color _floorColor(BuildContext context) {
    if (AppUI.isDark(context)) return const Color(0xFF1F2937);
    if (themeKey != 'softGlow') {
      final colors = AppUI.backgroundThemeColors(
        themeKey,
        AppUI.isDark(context),
      );
      return Color.lerp(colors.last, accent, 0.12) ?? colors.last;
    }
    switch (room.roomType) {
      case StudyRoomType.study:
        return const Color(0xFFDDEBFF);
      case StudyRoomType.sleep:
        return const Color(0xFFE4D8FF);
      case StudyRoomType.exercise:
        return const Color(0xFFD1FAE5);
      case StudyRoomType.steps:
        return const Color(0xFFCCFBF1);
      case StudyRoomType.custom:
        return const Color(0xFFFFEDD5);
    }
  }

  IconData _ambientIcon() {
    switch (room.roomType) {
      case StudyRoomType.study:
        return Icons.menu_book_rounded;
      case StudyRoomType.sleep:
        return Icons.nights_stay_outlined;
      case StudyRoomType.exercise:
        return Icons.fitness_center;
      case StudyRoomType.steps:
        return Icons.directions_walk;
      case StudyRoomType.custom:
        return Icons.auto_awesome_outlined;
    }
  }

  List<IconData> _propIcons() {
    switch (room.roomType) {
      case StudyRoomType.study:
        return const [
          Icons.menu_book_rounded,
          Icons.edit_note_rounded,
          Icons.coffee_outlined,
          Icons.lightbulb_outline,
        ];
      case StudyRoomType.sleep:
        return const [
          Icons.bedtime_outlined,
          Icons.hotel_rounded,
          Icons.nights_stay_outlined,
          Icons.alarm_rounded,
        ];
      case StudyRoomType.exercise:
        return const [
          Icons.fitness_center,
          Icons.monitor_heart_outlined,
          Icons.sports_gymnastics_rounded,
          Icons.water_drop_outlined,
        ];
      case StudyRoomType.steps:
        return const [
          Icons.directions_walk,
          Icons.route_outlined,
          Icons.park_outlined,
          Icons.flag_outlined,
        ];
      case StudyRoomType.custom:
        return const [
          Icons.auto_awesome_outlined,
          Icons.check_circle_outline,
          Icons.bolt_outlined,
          Icons.track_changes_outlined,
        ];
    }
  }

  List<Offset> _seatPositions(double width, double height) {
    switch (room.roomType) {
      case StudyRoomType.study:
        return [
          Offset(width * 0.36, 86),
          Offset(width * 0.10, 128),
          Offset(width * 0.64, 128),
          Offset(width * 0.24, 218),
          Offset(width * 0.54, 218),
          Offset(width * 0.78, 225),
          Offset(width * 0.04, 230),
          Offset(width * 0.42, 258),
        ];
      case StudyRoomType.sleep:
        return [
          Offset(width * 0.40, 82),
          Offset(width * 0.14, 142),
          Offset(width * 0.66, 142),
          Offset(width * 0.26, 225),
          Offset(width * 0.56, 225),
          Offset(width * 0.78, 236),
          Offset(width * 0.04, 238),
          Offset(width * 0.42, 268),
        ];
      case StudyRoomType.exercise:
        return [
          Offset(width * 0.40, 72),
          Offset(width * 0.12, 118),
          Offset(width * 0.68, 118),
          Offset(width * 0.22, 204),
          Offset(width * 0.56, 204),
          Offset(width * 0.78, 218),
          Offset(width * 0.04, 225),
          Offset(width * 0.42, 250),
        ];
      case StudyRoomType.steps:
        return [
          Offset(width * 0.18, 90),
          Offset(width * 0.48, 112),
          Offset(width * 0.70, 145),
          Offset(width * 0.34, 180),
          Offset(width * 0.08, 218),
          Offset(width * 0.58, 228),
          Offset(width * 0.78, 252),
          Offset(width * 0.30, 270),
        ];
      case StudyRoomType.custom:
        return [
          Offset(width * 0.42, 74),
          Offset(width * 0.12, 124),
          Offset(width * 0.68, 124),
          Offset(width * 0.24, 212),
          Offset(width * 0.55, 212),
          Offset(width * 0.78, 225),
          Offset(width * 0.04, 232),
          Offset(width * 0.42, 262),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleMembers = [...members]
      ..sort((a, b) {
        final aActive = a.status == StudyMemberStatus.studying ? 0 : 1;
        final bActive = b.status == StudyMemberStatus.studying ? 0 : 1;
        if (aActive != bActive) return aActive.compareTo(bActive);
        return b.todayFocusSeconds.compareTo(a.todayFocusSeconds);
      });
    final stageMembers = visibleMembers.take(8).toList();

    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: _skyColor(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accent.withValues(alpha: AppUI.isDark(context) ? 0.28 : 0.16),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final positions = _seatPositions(width, height);
          final propIcons = _propIcons();

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoomStagePainter(
                    roomType: room.roomType,
                    accent: accent,
                    themeKey: themeKey,
                    skyColor: _skyColor(context),
                    floorColor: _floorColor(context),
                    isDark: AppUI.isDark(context),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                right: 18,
                child: _StageTitlePanel(
                  title: _stageTitle(),
                  subtitle: _stageSubtitle(),
                  icon: _ambientIcon(),
                  accent: accent,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 18,
                child: _StagePropStrip(icons: propIcons, accent: accent),
              ),
              Positioned(
                left: width * 0.10,
                top: height * 0.48,
                child: _StageFloorMark(color: accent),
              ),
              Positioned(
                right: width * 0.12,
                top: height * 0.55,
                child: _StageFloorMark(color: accent.withValues(alpha: 0.65)),
              ),
              ...stageMembers.asMap().entries.map((entry) {
                final index = entry.key;
                final member = entry.value;
                final avatarProfile = avatarProfileFor(member);
                final statusColor = statusColorFor(member.status);
                final position = positions[index];
                final isActive = member.status == StudyMemberStatus.studying;
                final avatarSize = isActive ? 82.0 : 68.0;

                return Positioned(
                  left: position.dx.clamp(8.0, width - 104.0),
                  top: position.dy,
                  child: _StageMemberAvatar(
                    member: member,
                    avatarProfile: avatarProfile,
                    avatarSize: avatarSize,
                    statusText: statusTextFor(member.status),
                    statusColor: statusColor,
                    dimmed: member.status == StudyMemberStatus.offline,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _StageTitlePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _StageTitlePanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(alpha: AppUI.isDark(context) ? 0.25 : 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
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

class _RoomStagePainter extends CustomPainter {
  final StudyRoomType roomType;
  final Color accent;
  final String themeKey;
  final Color skyColor;
  final Color floorColor;
  final bool isDark;

  const _RoomStagePainter({
    required this.roomType,
    required this.accent,
    required this.themeKey,
    required this.skyColor,
    required this.floorColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [skyColor, Color.lerp(skyColor, floorColor, 0.28)!],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, skyPaint);

    final floorTop = size.height * 0.66;
    final floorPaint = Paint()..color = floorColor;
    canvas.drawRect(
      Rect.fromLTWH(0, floorTop, size.width, size.height - floorTop),
      floorPaint,
    );

    final horizonPaint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.18 : 0.12)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, floorTop),
      Offset(size.width, floorTop),
      horizonPaint,
    );

    switch (roomType) {
      case StudyRoomType.study:
        _drawStudyRoom(canvas, size, floorTop);
        break;
      case StudyRoomType.sleep:
        _drawSleepRoom(canvas, size, floorTop);
        break;
      case StudyRoomType.exercise:
        _drawExerciseRoom(canvas, size, floorTop);
        break;
      case StudyRoomType.steps:
        _drawStepsRoom(canvas, size, floorTop);
        break;
      case StudyRoomType.custom:
        _drawCustomRoom(canvas, size, floorTop);
        break;
    }

    _drawThemeMotifs(canvas, size);
  }

  void _drawThemeMotifs(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent.withValues(alpha: isDark ? 0.16 : 0.13);
    switch (themeKey) {
      case 'nightStudy':
        for (final point in [
          Offset(size.width * 0.18, size.height * 0.18),
          Offset(size.width * 0.36, size.height * 0.12),
          Offset(size.width * 0.82, size.height * 0.28),
        ]) {
          canvas.drawCircle(point, 3, paint);
        }
        break;
      case 'sakuraWalk':
        for (final point in [
          Offset(size.width * 0.16, size.height * 0.26),
          Offset(size.width * 0.30, size.height * 0.18),
          Offset(size.width * 0.76, size.height * 0.22),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(center: point, width: 12, height: 7),
            paint,
          );
        }
        break;
      case 'galaxySleep':
        canvas.drawCircle(
          Offset(size.width * 0.78, size.height * 0.18),
          34,
          paint,
        );
        canvas.drawCircle(
          Offset(size.width * 0.80, size.height * 0.16),
          29,
          Paint()..color = skyColor,
        );
        break;
      case 'gymEnergy':
        final linePaint = Paint()
          ..color = accent.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        final path = Path()
          ..moveTo(size.width * 0.12, size.height * 0.30)
          ..lineTo(size.width * 0.24, size.height * 0.24)
          ..lineTo(size.width * 0.34, size.height * 0.34)
          ..lineTo(size.width * 0.48, size.height * 0.18);
        canvas.drawPath(path, linePaint);
        break;
      case 'softGlow':
      default:
        break;
    }
  }

  void _drawStudyRoom(Canvas canvas, Size size, double floorTop) {
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()..color = accent.withValues(alpha: 0.10);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.16, 78, 54),
        const Radius.circular(10),
      ),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.08, size.height * 0.16, 78, 54),
        const Radius.circular(10),
      ),
      linePaint,
    );

    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * 0.66 + i * 18,
          floorTop - 48 - i * 5,
          12,
          48 + i * 5,
        ),
        Paint()..color = accent.withValues(alpha: 0.14 + i * 0.04),
      );
    }
    _drawDesk(
      canvas,
      Offset(size.width * 0.15, floorTop + 28),
      size.width * 0.25,
    );
    _drawDesk(
      canvas,
      Offset(size.width * 0.54, floorTop + 26),
      size.width * 0.26,
    );
  }

  void _drawSleepRoom(Canvas canvas, Size size, double floorTop) {
    final moonPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.80 : 0.65);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.20),
      28,
      moonPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.18),
      25,
      Paint()..color = skyColor,
    );

    final starPaint = Paint()..color = accent.withValues(alpha: 0.32);
    for (final point in [
      Offset(size.width * 0.18, size.height * 0.18),
      Offset(size.width * 0.34, size.height * 0.25),
      Offset(size.width * 0.62, size.height * 0.13),
      Offset(size.width * 0.72, size.height * 0.35),
    ]) {
      canvas.drawCircle(point, 3, starPaint);
    }

    _drawBed(
      canvas,
      Offset(size.width * 0.10, floorTop + 34),
      size.width * 0.35,
    );
    _drawBed(
      canvas,
      Offset(size.width * 0.52, floorTop + 36),
      size.width * 0.34,
    );
  }

  void _drawExerciseRoom(Canvas canvas, Size size, double floorTop) {
    final matPaint = Paint()..color = accent.withValues(alpha: 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.14, floorTop + 42, size.width * 0.28, 18),
        const Radius.circular(999),
      ),
      matPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.54, floorTop + 54, size.width * 0.30, 18),
        const Radius.circular(999),
      ),
      matPaint,
    );

    final weightPaint = Paint()
      ..color = accent.withValues(alpha: 0.24)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.18, floorTop - 40),
      Offset(size.width * 0.36, floorTop - 40),
      weightPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.16, floorTop - 40),
      12,
      Paint()..color = accent.withValues(alpha: 0.18),
    );
    canvas.drawCircle(
      Offset(size.width * 0.38, floorTop - 40),
      12,
      Paint()..color = accent.withValues(alpha: 0.18),
    );

    final chartPaint = Paint()
      ..color = accent.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(size.width * 0.58, size.height * 0.34)
      ..lineTo(size.width * 0.64, size.height * 0.28)
      ..lineTo(size.width * 0.70, size.height * 0.36)
      ..lineTo(size.width * 0.78, size.height * 0.22);
    canvas.drawPath(path, chartPaint);
  }

  void _drawStepsRoom(Canvas canvas, Size size, double floorTop) {
    final pathPaint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.80)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.58,
        size.width * 0.46,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.88,
        size.width * 0.90,
        size.height * 0.62,
      );
    canvas.drawPath(path, pathPaint);

    final treePaint = Paint()..color = accent.withValues(alpha: 0.20);
    for (final x in [size.width * 0.14, size.width * 0.72, size.width * 0.84]) {
      canvas.drawRect(Rect.fromLTWH(x - 3, floorTop - 28, 6, 28), treePaint);
      canvas.drawCircle(Offset(x, floorTop - 36), 16, treePaint);
    }

    final flagPaint = Paint()..color = accent.withValues(alpha: 0.35);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.82, floorTop - 72, 4, 60),
      flagPaint,
    );
    final flag = Path()
      ..moveTo(size.width * 0.826, floorTop - 72)
      ..lineTo(size.width * 0.90, floorTop - 58)
      ..lineTo(size.width * 0.826, floorTop - 44)
      ..close();
    canvas.drawPath(flag, flagPaint);
  }

  void _drawCustomRoom(Canvas canvas, Size size, double floorTop) {
    final ringPaint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final rect in [
      Rect.fromCircle(
        center: Offset(size.width * 0.22, floorTop - 42),
        radius: 30,
      ),
      Rect.fromCircle(
        center: Offset(size.width * 0.68, floorTop - 48),
        radius: 38,
      ),
      Rect.fromCircle(
        center: Offset(size.width * 0.48, size.height * 0.30),
        radius: 24,
      ),
    ]) {
      canvas.drawOval(rect, ringPaint);
    }

    final cardPaint = Paint()..color = accent.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.10, floorTop + 32, 82, 48),
        const Radius.circular(14),
      ),
      cardPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, floorTop + 38, 88, 46),
        const Radius.circular(14),
      ),
      cardPaint,
    );
  }

  void _drawDesk(Canvas canvas, Offset origin, double width) {
    final paint = Paint()..color = accent.withValues(alpha: 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, width, 14),
        const Radius.circular(999),
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + width * 0.16, origin.dy + 12, 8, 34),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + width * 0.78, origin.dy + 12, 8, 34),
      paint,
    );
  }

  void _drawBed(Canvas canvas, Offset origin, double width) {
    final paint = Paint()..color = accent.withValues(alpha: 0.16);
    final pillowPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.18 : 0.64);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, width, 32),
        const Radius.circular(12),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + 8, origin.dy + 6, width * 0.28, 18),
        const Radius.circular(8),
      ),
      pillowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RoomStagePainter oldDelegate) {
    return oldDelegate.roomType != roomType ||
        oldDelegate.accent != accent ||
        oldDelegate.themeKey != themeKey ||
        oldDelegate.skyColor != skyColor ||
        oldDelegate.floorColor != floorColor ||
        oldDelegate.isDark != isDark;
  }
}

class _StagePropStrip extends StatelessWidget {
  final List<IconData> icons;
  final Color accent;

  const _StagePropStrip({required this.icons, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: icons.map((icon) {
        return Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent.withValues(alpha: 0.78), size: 20),
        );
      }).toList(),
    );
  }
}

class _StageFloorMark extends StatelessWidget {
  final Color color;

  const _StageFloorMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.16,
      child: Container(
        width: 84,
        height: 18,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppUI.radiusPill),
        ),
      ),
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
                icon: const Icon(Icons.sync_outlined),
                label: const Text('前往健康頁同步'),
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

class _StickerPanel extends StatelessWidget {
  final Color accent;
  final ValueChanged<String> onStickerTap;

  const _StickerPanel({required this.accent, required this.onStickerTap});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    const stickers = ['加油', '穩住', '太強了', '一起衝', '休息一下'];

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '鼓勵貼圖',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stickers.map((sticker) {
                return ActionChip(
                  avatar: Icon(
                    Icons.volunteer_activism_outlined,
                    color: accent,
                    size: 18,
                  ),
                  label: Text(sticker),
                  onPressed: () => onStickerTap(sticker),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  final TextEditingController controller;
  final List<StudyRoomMessage> messages;
  final String currentUserId;
  final Color accent;
  final VoidCallback onSend;

  const _ChatPanel({
    required this.controller,
    required this.messages,
    required this.currentUserId,
    required this.accent,
    required this.onSend,
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
            Text(
              '房內聊天',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: '傳一句鼓勵或進度',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (messages.isEmpty)
              Text(
                '目前還沒有訊息，送出第一句鼓勵吧。',
                style: TextStyle(fontSize: 13, color: secondaryText),
              )
            else
              ...messages.take(5).map((message) {
                final isMe = message.senderId == currentUserId;
                final color = isMe ? accent : const Color(0xFF4F8CFF);
                final isSticker = message.type == StudyRoomMessageType.sticker;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 260),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message.text,
                            style: TextStyle(
                              fontSize: isSticker ? 17 : 13,
                              height: 1.35,
                              fontWeight: isSticker
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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

class _StageMemberAvatar extends StatelessWidget {
  final StudyMemberData member;
  final AvatarProfile avatarProfile;
  final double avatarSize;
  final String statusText;
  final Color statusColor;
  final bool dimmed;

  const _StageMemberAvatar({
    required this.member,
    required this.avatarProfile,
    required this.avatarSize,
    required this.statusText,
    required this.statusColor,
    required this.dimmed,
  });

  @override
  Widget build(BuildContext context) {
    final name = member.roomNickname.isEmpty
        ? member.name
        : member.roomNickname;

    return Opacity(
      opacity: dimmed ? 0.48 : 1,
      child: SizedBox(
        width: 96,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                color: avatarProfile.backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AvatarPreview(
                profile: avatarProfile,
                size: avatarSize,
                showBackgroundRing: false,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxWidth: 90),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppUI.radiusPill),
              ),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppUI.textPrimaryOf(context),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppUI.radiusPill),
              ),
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final String text;
  final Color color;

  const _LivePill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
