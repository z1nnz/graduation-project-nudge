import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_profile.dart';
import '../models/study_room_models.dart';
import '../models/task_model.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'health_page.dart';
import 'study_room_live_page.dart';

class StudyRoomDetailPage extends StatelessWidget {
  final String roomId;

  const StudyRoomDetailPage({super.key, required this.roomId});

  String _formatHours(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours 小時 $minutes 分';
    }
    return '$minutes 分';
  }

  String _formatGoalNumber(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  IconData _roomTypeIcon(StudyRoomType type) {
    switch (type) {
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

  String _roomTypeLabel(StudyRoomType type) {
    switch (type) {
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

  String _metricName(StudyRoomData room) {
    switch (room.goalSourceType) {
      case TaskSourceType.sleepHours:
        return '睡眠';
      case TaskSourceType.exerciseMinutes:
        return '運動';
      case TaskSourceType.steps:
        return '步數';
      case TaskSourceType.focusMinutes:
      case TaskSourceType.studyRoom:
        return '專注';
      case TaskSourceType.manual:
      case TaskSourceType.system:
        return '進度';
    }
  }

  double _roomTrackedValue(StudyRoomData room) {
    switch (room.goalSourceType) {
      case TaskSourceType.focusMinutes:
      case TaskSourceType.studyRoom:
        return room.members
            .where((member) => member.isApproved)
            .fold<double>(
              0,
              (sum, member) => sum + (member.todayFocusSeconds / 3600),
            );
      case TaskSourceType.sleepHours:
      case TaskSourceType.exerciseMinutes:
      case TaskSourceType.steps:
        return room.members
            .where((member) => member.isApproved)
            .fold<double>(0, (sum, member) => sum + member.todayMetricValue);
      case TaskSourceType.manual:
      case TaskSourceType.system:
        return 0;
    }
  }

  double _memberTrackedValue(StudyRoomData room, StudyMemberData member) {
    if (room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes) {
      return member.todayFocusSeconds / 3600;
    }
    return member.todayMetricValue;
  }

  String _formatRoomTrackedValue(StudyRoomData room, double value) {
    if (room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes) {
      return _formatHours((value * 3600).round());
    }
    if (value % 1 == 0) return '${value.toInt()} ${room.goalUnitLabel}';
    return '${value.toStringAsFixed(1)} ${room.goalUnitLabel}';
  }

  String _goalText(StudyRoomData room) {
    return '${_formatGoalNumber(room.dailyGoalValue)} ${room.goalUnitLabel}';
  }

  String _roomDefaultDescription(StudyRoomData room) {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '一起穩定專注的房間';
      case StudyRoomType.sleep:
        return '一起把作息拉回節奏';
      case StudyRoomType.exercise:
        return '一起累積運動量';
      case StudyRoomType.steps:
        return '一起把步數走起來';
      case StudyRoomType.custom:
        return '一起完成自訂自律目標';
    }
  }

  String _activeStatusText(StudyRoomData room) {
    if (_usesExternalProgress(room)) {
      return '同步中';
    }

    switch (room.roomType) {
      case StudyRoomType.study:
        return '專注中';
      case StudyRoomType.sleep:
        return '睡覺中';
      case StudyRoomType.exercise:
        return '運動中';
      case StudyRoomType.steps:
        return '走路中';
      case StudyRoomType.custom:
        return '自律中';
    }
  }

  bool _usesExternalProgress(StudyRoomData room) {
    return room.goalSourceType == TaskSourceType.sleepHours ||
        room.goalSourceType == TaskSourceType.exerciseMinutes ||
        room.goalSourceType == TaskSourceType.steps;
  }

  bool _hasInRoomTimer(StudyRoomData room) {
    return !_usesExternalProgress(room);
  }

  String _liveRoomTitle(StudyRoomData room) {
    return _hasInRoomTimer(room) ? '即時自律房' : '房間同步看板';
  }

  String _liveRoomSubtitle(StudyRoomData room) {
    if (!_usesExternalProgress(room)) {
      return '進入角色房間，開始倒數、聊天、送鼓勵貼圖。';
    }

    switch (room.roomType) {
      case StudyRoomType.sleep:
        return '睡眠時數由健康資料導入，房內負責陪伴、提醒與查看進度。';
      case StudyRoomType.exercise:
        return '運動分鐘由健康資料導入，房內用打卡與鼓勵維持節奏。';
      case StudyRoomType.steps:
        return '步數由健康資料導入，房內查看排行榜並互相提醒去走走。';
      case StudyRoomType.study:
      case StudyRoomType.custom:
        return '查看同步進度、聊天、送鼓勵貼圖。';
    }
  }

  String _liveRoomButtonLabel(
    StudyRoomData room, {
    required bool isCurrentUserPending,
  }) {
    if (isCurrentUserPending) return '審核中';
    return _hasInRoomTimer(room) ? '進入' : '查看';
  }

  String _activityMetricTitle(StudyRoomData room) {
    return _usesExternalProgress(room) ? '已達標人數' : '進行中人數';
  }

  IconData _activityMetricIcon(StudyRoomData room) {
    return _usesExternalProgress(room)
        ? Icons.verified_outlined
        : Icons.local_fire_department_outlined;
  }

  Color _activityMetricColor(StudyRoomData room) {
    return _usesExternalProgress(room)
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF10B981);
  }

  String _personalGoalText(StudyRoomData room, StudyMemberData member) {
    if (_usesExternalProgress(room)) return _goalText(room);
    return _formatHours(member.personalGoalSeconds);
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
        StudyMemberStatus.resting => '已同步達標',
        StudyMemberStatus.offline => '待同步',
      };
    }

    switch (status) {
      case StudyMemberStatus.studying:
        return _activeStatusText(room);
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

  String _joinModeText(StudyRoomJoinMode mode) {
    switch (mode) {
      case StudyRoomJoinMode.instant:
        return '立即加入';
      case StudyRoomJoinMode.approval:
        return '審核加入';
    }
  }

  void _showEditAnnouncementDialog(
    BuildContext context,
    AppState appState,
    StudyRoomData room,
  ) {
    final controller = TextEditingController(text: room.announcement);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('編輯房間公告'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '公告內容',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                appState.updateRoomAnnouncement(
                  roomId: room.id,
                  announcement: controller.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  void _showSetChallengeDialog(
    BuildContext context,
    AppState appState,
    StudyRoomData room,
  ) {
    final titleController = TextEditingController(text: room.challengeTitle);
    final descriptionController = TextEditingController(
      text: room.challengeDescription,
    );
    final deadlineController = TextEditingController(
      text: room.challengeDeadlineLabel,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('設定房間挑戰'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '挑戰標題',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '挑戰說明',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deadlineController,
                  decoration: const InputDecoration(
                    labelText: '截止說明',
                    hintText: '例如：今天 23:59',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                appState.setRoomChallenge(
                  roomId: room.id,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  goalSeconds: room.challengeGoalSeconds,
                  deadlineLabel: deadlineController.text.trim(),
                );
                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLeaveRoom(
    BuildContext context,
    AppState appState,
    StudyRoomData room,
  ) async {
    final approvedCount = room.members
        .where((member) => member.isApproved)
        .length;
    final isOnlyOwner = room.ownerId == 'local_user' && approvedCount <= 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isOnlyOwner ? '關閉房間？' : '退出房間？'),
          content: Text(
            isOnlyOwner
                ? '這間房目前只剩你一個人，退出後房間會被關閉。'
                : '退出後你會從成員列表移除；如果你是房主，房主會轉給下一位成員。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isOnlyOwner ? '關閉房間' : '退出房間'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    appState.leaveStudyRoom(room.id);
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  void _showSetPersonalGoalDialog(
    BuildContext context,
    AppState appState,
    StudyRoomData room,
  ) {
    final me = room.members.firstWhere(
      (m) => m.memberId == 'local_user',
      orElse: () => StudyMemberData(
        memberId: 'local_user',
        name: appState.profileNickname,
        roomNickname: appState.profileNickname,
        status: StudyMemberStatus.offline,
        sessionSeconds: 0,
        todayFocusSeconds: appState.focusSeconds,
        avatarColor: const Color(0xFF7C6AE6),
      ),
    );

    final controller = TextEditingController(
      text: (me.personalGoalSeconds ~/ 3600).toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('設定我的房內目標'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '目標時數',
              hintText: '例如：2',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final hours = int.tryParse(controller.text.trim()) ?? 1;
                appState.setMyRoomPersonalGoal(
                  roomId: room.id,
                  goalSeconds: hours * 3600,
                );
                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  void _showInviteMemberDialog(
    BuildContext context,
    AppState appState,
    StudyRoomData room,
  ) {
    final nameController = TextEditingController();
    final nicknameController = TextEditingController();
    final answerController = TextEditingController();

    Color selectedColor = const Color(0xFF4F8CFF);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('邀請成員'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '成員名稱',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nicknameController,
                      decoration: const InputDecoration(
                        labelText: '房內暱稱',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (room.joinQuestionsEnabled) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: answerController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '加入問題回答',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '頭像顏色',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppUI.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children:
                          [
                            const Color(0xFF4F8CFF),
                            const Color(0xFF10B981),
                            const Color(0xFFF59E0B),
                            const Color(0xFFEC4899),
                            const Color(0xFF8B5CF6),
                          ].map((color) {
                            final isSelected = selectedColor == color;
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedColor = color;
                                });
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: AppUI.isDark(context)
                                              ? Colors.white
                                              : Colors.black,
                                          width: 2,
                                        )
                                      : Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    appState.inviteMemberToRoom(
                      roomId: room.id,
                      memberName: name,
                      avatarColor: selectedColor,
                      memberId:
                          'member_${DateTime.now().millisecondsSinceEpoch}',
                      roomNickname: nicknameController.text.trim(),
                      isApproved: room.joinMode == StudyRoomJoinMode.instant,
                      joinAnswer: answerController.text.trim(),
                    );

                    Navigator.pop(context);
                  },
                  child: const Text('加入'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditRoomSettingsDialog(
    BuildContext context,
    AppState appState,
    StudyRoomData room,
  ) {
    final tagsController = TextEditingController(text: room.tags.join(', '));
    final memberLimitController = TextEditingController(
      text: room.memberLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('調整房間資訊'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: '房間標籤（逗號分隔）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memberLimitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '人數上限',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final tags = tagsController.text
                    .split(RegExp(r'[,，、]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                final memberLimit =
                    int.tryParse(memberLimitController.text.trim()) ??
                    room.memberLimit;

                appState.updateRoomTags(roomId: room.id, tags: tags);
                appState.updateRoomMemberLimit(
                  roomId: room.id,
                  memberLimit: memberLimit,
                );
                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final room = appState.getStudyRoomById(roomId);

        if (room == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('自律房')),
            body: Center(
              child: Text(
                '找不到這個房間',
                style: TextStyle(
                  fontSize: 16,
                  color: AppUI.textSecondaryOf(context),
                ),
              ),
            ),
          );
        }

        final primaryText = AppUI.textPrimaryOf(context);
        final secondaryText = AppUI.textSecondaryOf(context);
        final accent = room.accentColor;
        final isOwner = appState.isCurrentUserOwner(room.id);
        final pendingRequests = room.members
            .where((member) => !member.isApproved)
            .toList(growable: false);
        final approvedMembers = room.members
            .where((member) => member.isApproved)
            .toList(growable: false);
        StudyMemberData? currentUserMember;
        for (final member in room.members) {
          if (member.memberId == 'local_user') {
            currentUserMember = member;
            break;
          }
        }
        final isCurrentUserPending =
            currentUserMember != null && !currentUserMember.isApproved;
        final canEnterLiveRoom = currentUserMember == null
            ? isOwner
            : currentUserMember.isApproved;

        final trackedValue = _roomTrackedValue(room);
        final trackedValueText = _formatRoomTrackedValue(room, trackedValue);
        final goalText = _goalText(room);
        final activityCount = _usesExternalProgress(room)
            ? approvedMembers.where((m) => m.hasReachedPersonalGoal).length
            : approvedMembers
                  .where((m) => m.status == StudyMemberStatus.studying)
                  .length;
        final double progress = room.dailyGoalValue <= 0
            ? 0.0
            : (trackedValue / room.dailyGoalValue).clamp(0.0, 1.0).toDouble();

        final sortedMembers = [...approvedMembers]
          ..sort(
            (a, b) => _memberTrackedValue(
              room,
              b,
            ).compareTo(_memberTrackedValue(room, a)),
          );

        final me = approvedMembers.firstWhere(
          (m) => m.memberId == 'local_user',
          orElse: () => StudyMemberData(
            memberId: 'local_user',
            name: appState.profileNickname,
            roomNickname: appState.profileNickname,
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: appState.focusSeconds,
            todayMetricValue: appState.focusSeconds / 3600,
            avatarColor: const Color(0xFF7C6AE6),
          ),
        );
        final meAvatarProfile = _memberAvatarProfile(appState, me);

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(room.name),
              bottom: const TabBar(
                isScrollable: false,
                tabs: [
                  Tab(text: '首頁'),
                  Tab(text: '成員'),
                  Tab(text: '排行'),
                  Tab(text: '規則'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(AppUI.pagePadding),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppUI.heroGradient(accent),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _roomTypeIcon(room.roomType),
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      room.description.isEmpty
                                          ? _roomDefaultDescription(room)
                                          : room.description,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HeroInfoChip(
                                text: _roomTypeLabel(room.roomType),
                                color: Colors.white,
                                bgColor: Colors.white.withValues(alpha: 0.18),
                              ),
                              _HeroInfoChip(
                                text: room.category,
                                color: Colors.white,
                                bgColor: Colors.white.withValues(alpha: 0.18),
                              ),
                              _HeroInfoChip(
                                text:
                                    '${approvedMembers.length}/${room.memberLimit} 人',
                                color: Colors.white,
                                bgColor: Colors.white.withValues(alpha: 0.18),
                              ),
                              if (isOwner && pendingRequests.isNotEmpty)
                                _HeroInfoChip(
                                  text: '待審 ${pendingRequests.length}',
                                  color: Colors.white,
                                  bgColor: const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.32),
                                ),
                              _HeroInfoChip(
                                text: _joinModeText(room.joinMode),
                                color: Colors.white,
                                bgColor: Colors.white.withValues(alpha: 0.18),
                              ),
                              _HeroInfoChip(
                                text: '每日 $goalText',
                                color: Colors.white,
                                bgColor: Colors.white.withValues(alpha: 0.18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppUI.sectionGap),

                    Card(
                      shape: AppUI.cardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppUI.innerPadding),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.meeting_room_outlined,
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _liveRoomTitle(room),
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _liveRoomSubtitle(room),
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: canEnterLiveRoom
                                  ? () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StudyRoomLivePage(
                                            roomId: room.id,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              icon: const Icon(Icons.login_rounded),
                              label: Text(
                                _liveRoomButtonLabel(
                                  room,
                                  isCurrentUserPending: isCurrentUserPending,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isCurrentUserPending) ...[
                      const SizedBox(height: AppUI.cardGap),
                      Card(
                        shape: AppUI.cardShape(),
                        color: AppUI.isDark(context)
                            ? const Color(0xFF2A231C)
                            : const Color(0xFFFFF7ED),
                        child: Padding(
                          padding: const EdgeInsets.all(AppUI.innerPadding),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.hourglass_top_rounded,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '你的加入申請正在等待房主審核。通過後才能進入即時自律房、開始互動與同步房間任務。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: primaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppUI.sectionGap),

                    Card(
                      shape: AppUI.cardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppUI.innerPadding),
                        child: Row(
                          children: [
                            Expanded(
                              child: _DashboardMiniInfo(
                                title: '今日${_metricName(room)}',
                                value: trackedValueText,
                                icon: _roomTypeIcon(room.roomType),
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DashboardMiniInfo(
                                title: _activityMetricTitle(room),
                                value: '$activityCount 人',
                                icon: _activityMetricIcon(room),
                                color: _activityMetricColor(room),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DashboardMiniInfo(
                                title: '我的進度',
                                value: _formatRoomTrackedValue(
                                  room,
                                  _memberTrackedValue(room, me),
                                ),
                                icon: Icons.person_outline,
                                color: const Color(0xFF7C6AE6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppUI.sectionGap),

                    _SectionHeader(title: '房間公告', subtitle: '這裡顯示房主想提醒大家的內容。'),
                    const SizedBox(height: AppUI.cardGap),

                    Card(
                      shape: AppUI.cardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppUI.innerPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.announcement.isEmpty
                                  ? '目前還沒有公告，大家可以先照自己的進度前進。'
                                  : room.announcement,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.55,
                                color: primaryText,
                              ),
                            ),
                            if (isOwner) ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showEditAnnouncementDialog(
                                    context,
                                    appState,
                                    room,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('編輯公告'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppUI.sectionGap),

                    _SectionHeader(
                      title: '今日共同目標',
                      subtitle: '依照房間類型追蹤今天的共同自律進度。',
                    ),
                    const SizedBox(height: AppUI.cardGap),

                    Card(
                      shape: AppUI.cardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppUI.innerPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.challengeTitle == '今日房間挑戰'
                                  ? '今日${_metricName(room)}挑戰'
                                  : room.challengeTitle,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              room.challengeDescription == '一起累積專注時數'
                                  ? '一起累積 $goalText，完成今天的房間目標。'
                                  : room.challengeDescription,
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryText,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppUI.radiusPill,
                              ),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: AppUI.isDark(context)
                                    ? const Color(0xFF2A2F3A)
                                    : const Color(0xFFE5E7EB),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '目前進度：${(progress * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText,
                                    ),
                                  ),
                                ),
                                Text(
                                  room.challengeDeadlineLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '累積 $trackedValueText / 目標 $goalText',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryText,
                              ),
                            ),
                            if (isOwner) ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showSetChallengeDialog(
                                    context,
                                    appState,
                                    room,
                                  ),
                                  icon: const Icon(Icons.flag_outlined),
                                  label: const Text('調整挑戰'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppUI.sectionGap),

                    _SectionHeader(
                      title: '我的房內狀態',
                      subtitle: '查看自己在這間房的狀態與今日進度。',
                    ),
                    const SizedBox(height: AppUI.cardGap),

                    Card(
                      shape: AppUI.cardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppUI.innerPadding),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: meAvatarProfile.backgroundColor,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: AvatarPreview(
                                    profile: meAvatarProfile,
                                    size: 56,
                                    showBackgroundRing: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        me.roomNickname.isEmpty
                                            ? me.name
                                            : me.roomNickname,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '目前狀態：${_memberStatusText(room, me.status)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: _memberStatusColor(me.status),
                                          fontWeight: FontWeight.w700,
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
                                  child: _DashboardMiniInfo(
                                    title: '今日${_metricName(room)}',
                                    value: _formatRoomTrackedValue(
                                      room,
                                      _memberTrackedValue(room, me),
                                    ),
                                    icon: _roomTypeIcon(room.roomType),
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DashboardMiniInfo(
                                    title: '個人目標',
                                    value: _personalGoalText(room, me),
                                    icon: Icons.track_changes_outlined,
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_hasInRoomTimer(room))
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 2.7,
                                children: [
                                  _RoomActionButton(
                                    label: _startActionText(room),
                                    icon: _startActionIcon(room),
                                    isPrimary: true,
                                    onPressed: () {
                                      appState.updateMyStudyRoomPresence(
                                        roomId: room.id,
                                        status: StudyMemberStatus.studying,
                                        sessionSeconds: 25 * 60,
                                      );
                                    },
                                  ),
                                  _RoomActionButton(
                                    label: '休息',
                                    icon: Icons.free_breakfast_outlined,
                                    onPressed: () {
                                      appState.updateMyStudyRoomPresence(
                                        roomId: room.id,
                                        status: StudyMemberStatus.resting,
                                        sessionSeconds: 0,
                                      );
                                    },
                                  ),
                                  _RoomActionButton(
                                    label: '離線',
                                    icon: Icons.stop_circle_outlined,
                                    onPressed: () {
                                      appState.clearMyStudyRoomPresence(
                                        room.id,
                                      );
                                    },
                                  ),
                                  _RoomActionButton(
                                    label: '改目標',
                                    icon: Icons.edit_note_outlined,
                                    onPressed: () => _showSetPersonalGoalDialog(
                                      context,
                                      appState,
                                      room,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: AppUI.softCardOf(context, accent),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.health_and_safety_outlined,
                                          color: accent,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '這間房不在房內手動計時，今日${_metricName(room)}會從健康資料同步進來。',
                                            style: TextStyle(
                                              fontSize: 13,
                                              height: 1.45,
                                              color: primaryText,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const HealthPage(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.sync_outlined),
                                          label: const Text('同步健康資料'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _showSetPersonalGoalDialog(
                                                context,
                                                appState,
                                                room,
                                              ),
                                          icon: const Icon(
                                            Icons.edit_note_outlined,
                                          ),
                                          label: const Text('改目標'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            if (room.syncTaskEnabled) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    appState.disableStudyRoomGoalTaskSync(
                                      room.id,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已取消同步到任務頁'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.link_off_outlined),
                                  label: const Text('取消任務同步'),
                                ),
                              ),
                            ],
                            if (room.goalSourceType !=
                                    TaskSourceType.studyRoom &&
                                room.goalSourceType !=
                                    TaskSourceType.focusMinutes) ...[
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: AppUI.softCardOf(context, accent),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.sync_outlined,
                                      color: accent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '這間房會依健康資料同步「${_metricName(room)}」進度。到健康頁同步資料後，房間進度會跟著更新。',
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.45,
                                          color: primaryText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    if (isOwner) ...[
                      const SizedBox(height: AppUI.sectionGap),
                      _SectionHeader(
                        title: '房主管理',
                        subtitle: '你可以從這裡快速調整房間設定。',
                      ),
                      const SizedBox(height: AppUI.cardGap),
                      Card(
                        shape: AppUI.cardShape(),
                        child: Padding(
                          padding: const EdgeInsets.all(AppUI.innerPadding),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showInviteMemberDialog(
                                  context,
                                  appState,
                                  room,
                                ),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('邀請成員'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showEditRoomSettingsDialog(
                                  context,
                                  appState,
                                  room,
                                ),
                                icon: const Icon(Icons.settings_outlined),
                                label: const Text('房間資訊'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),

                ListView(
                  padding: const EdgeInsets.all(AppUI.pagePadding),
                  children: [
                    _SectionHeader(
                      title: '房內成員',
                      subtitle: '查看目前成員狀態、專注時數與房內身份。',
                    ),
                    const SizedBox(height: AppUI.cardGap),
                    if (isOwner && pendingRequests.isNotEmpty) ...[
                      _PendingJoinRequestsCard(
                        room: room,
                        requests: pendingRequests,
                        onApprove: (member) {
                          appState.approveStudyRoomJoinRequest(
                            roomId: room.id,
                            memberId: member.memberId,
                          );
                        },
                        onReject: (member) {
                          appState.rejectStudyRoomJoinRequest(
                            roomId: room.id,
                            memberId: member.memberId,
                          );
                        },
                      ),
                      const SizedBox(height: AppUI.cardGap),
                    ],
                    if (approvedMembers.isEmpty)
                      Card(
                        shape: AppUI.cardShape(),
                        child: Padding(
                          padding: const EdgeInsets.all(AppUI.innerPadding),
                          child: Text(
                            '目前還沒有已通過的成員。',
                            style: TextStyle(
                              color: secondaryText,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                    ...approvedMembers.map((member) {
                      final statusColor = _memberStatusColor(member.status);
                      final isMe = member.memberId == 'local_user';
                      final avatarProfile = _memberAvatarProfile(
                        appState,
                        member,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          shape: AppUI.cardShape(),
                          child: Padding(
                            padding: const EdgeInsets.all(AppUI.innerPadding),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: avatarProfile.backgroundColor,
                                    borderRadius: BorderRadius.circular(19),
                                  ),
                                  child: AvatarPreview(
                                    profile: avatarProfile,
                                    size: 58,
                                    showBackgroundRing: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            member.roomNickname.isEmpty
                                                ? member.name
                                                : member.roomNickname,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: primaryText,
                                            ),
                                          ),
                                          if (member.role == 'owner')
                                            const _InlineBadge(
                                              text: '房主',
                                              bgColor: Color(0xFFEDE9FE),
                                              textColor: Color(0xFF7C3AED),
                                            ),
                                          if (isMe)
                                            const _InlineBadge(
                                              text: '我',
                                              bgColor: Color(0xFFE0F2FE),
                                              textColor: Color(0xFF0284C7),
                                            ),
                                          _InlineBadge(
                                            text: _memberStatusText(
                                              room,
                                              member.status,
                                            ),
                                            bgColor: statusColor.withValues(
                                              alpha: 0.14,
                                            ),
                                            textColor: statusColor,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '今日${_metricName(room)}：${_formatRoomTrackedValue(room, _memberTrackedValue(room, member))}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: secondaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '個人目標：${_formatHours(member.personalGoalSeconds)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: secondaryText,
                                        ),
                                      ),
                                      if (member.joinAnswer.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          '加入回答：${member.joinAnswer}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryText,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isOwner &&
                                    member.role != 'owner' &&
                                    member.memberId != 'local_user')
                                  IconButton(
                                    onPressed: () {
                                      appState.removeMemberFromRoom(
                                        roomId: room.id,
                                        memberName: member.name,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.person_remove_outlined,
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

                ListView(
                  padding: const EdgeInsets.all(AppUI.pagePadding),
                  children: [
                    _SectionHeader(
                      title: '今日排行',
                      subtitle: '依房間追蹤的「${_metricName(room)}」數值排序。',
                    ),
                    const SizedBox(height: AppUI.cardGap),
                    Card(
                      shape: AppUI.cardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppUI.innerPadding),
                        child: Column(
                          children: sortedMembers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final member = entry.value;
                            final contribution = trackedValue <= 0
                                ? 0.0
                                : _memberTrackedValue(room, member) /
                                      trackedValue;

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == sortedMembers.length - 1
                                    ? 0
                                    : 14,
                              ),
                              child: _RoomRankingTile(
                                rank: index + 1,
                                member: member,
                                avatarProfile: _memberAvatarProfile(
                                  appState,
                                  member,
                                ),
                                focusText: _formatRoomTrackedValue(
                                  room,
                                  _memberTrackedValue(room, member),
                                ),
                                contributionText:
                                    '貢獻 ${(contribution * 100).round()}%',
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),

                ListView(
                  padding: const EdgeInsets.all(AppUI.pagePadding),
                  children: [
                    _SectionHeader(
                      title: '房間規則與設定',
                      subtitle: '這裡整理房間定位、加入方式、規則與補充資訊。',
                    ),
                    const SizedBox(height: AppUI.cardGap),

                    _InfoBlock(title: '房間類別', content: room.category),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '房間類型',
                      content: _roomTypeLabel(room.roomType),
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '加入方式',
                      content: _joinModeText(room.joinMode),
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(title: '每日目標', content: '每天 $goalText'),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '房間標籤',
                      content: room.tags.isEmpty
                          ? '目前沒有設定標籤'
                          : room.tags.join('、'),
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '暱稱規則',
                      content: room.nicknameRuleEnabled
                          ? (room.nicknameRuleText.isEmpty
                                ? '此房間啟用了暱稱規則'
                                : room.nicknameRuleText)
                          : '未啟用',
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '加入問題',
                      content: room.joinQuestionsEnabled
                          ? (room.joinQuestions.isEmpty
                                ? '已開啟，但目前沒有題目'
                                : room.joinQuestions
                                      .asMap()
                                      .entries
                                      .map((e) => '${e.key + 1}. ${e.value}')
                                      .join('\n'))
                          : '未啟用',
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '房規 / 補充說明',
                      content: room.roomRules.isEmpty
                          ? '目前沒有補充規則'
                          : room.roomRules,
                    ),
                    const SizedBox(height: AppUI.sectionGap),
                    Card(
                      shape: AppUI.cardShape(),
                      child: Padding(
                        padding: const EdgeInsets.all(AppUI.innerPadding),
                        child: Row(
                          children: [
                            Icon(
                              Icons.exit_to_app_rounded,
                              color: const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.ownerId == 'local_user' &&
                                            approvedMembers.length <= 1
                                        ? '關閉房間'
                                        : '退出房間',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '這是房間層級操作，會影響你是否仍是這個自律房的成員。',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () =>
                                  _confirmLeaveRoom(context, appState, room),
                              child: Text(
                                room.ownerId == 'local_user' &&
                                        approvedMembers.length <= 1
                                    ? '關閉'
                                    : '退出',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingJoinRequestsCard extends StatelessWidget {
  final StudyRoomData room;
  final List<StudyMemberData> requests;
  final ValueChanged<StudyMemberData> onApprove;
  final ValueChanged<StudyMemberData> onReject;

  const _PendingJoinRequestsCard({
    required this.room,
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accent = room.accentColor;

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
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.how_to_reg_outlined,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '加入申請',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '房主審核後，成員才會正式進房。',
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ),
                _InlineBadge(
                  text: '${requests.length} 筆',
                  bgColor: accent.withValues(alpha: 0.12),
                  textColor: accent,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...requests.map((member) {
              final displayName = member.roomNickname.isEmpty
                  ? member.name
                  : member.roomNickname;
              final profile = member.avatarProfile ?? AvatarProfile.initial();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppUI.isDark(context)
                        ? const Color(0xFF151A24)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: profile.backgroundColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: AvatarPreview(profile: profile, size: 48),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  member.joinAnswer.isEmpty
                                      ? '沒有填寫加入回答。'
                                      : member.joinAnswer,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => onReject(member),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('拒絕'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => onApprove(member),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('同意'),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: secondaryText, height: 1.4),
        ),
      ],
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  final String text;
  final Color color;
  final Color bgColor;

  const _HeroInfoChip({
    required this.text,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _DashboardMiniInfo extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _DashboardMiniInfo({
    required this.title,
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
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: secondaryText),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
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

class _RoomActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _RoomActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppState>().currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final foreground = isPrimary ? Colors.white : primaryText;
    final background = isPrimary
        ? accent
        : AppUI.textPrimaryOf(context).withValues(alpha: 0.035);
    final borderColor = isPrimary
        ? accent
        : AppUI.textSecondaryOf(context).withValues(alpha: 0.32);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineBadge extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const _InlineBadge({
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

// ignore: unused_element
class _RoomLiveStage extends StatelessWidget {
  final StudyRoomData room;
  final List<StudyMemberData> members;
  final Color accent;
  final String Function(StudyMemberStatus status) statusTextFor;
  final Color Function(StudyMemberStatus status) statusColorFor;
  final AvatarProfile Function(StudyMemberData member) avatarProfileFor;

  const _RoomLiveStage({
    required this.room,
    required this.members,
    required this.accent,
    required this.statusTextFor,
    required this.statusColorFor,
    required this.avatarProfileFor,
  });

  Color _skyColor(BuildContext context) {
    if (AppUI.isDark(context)) return const Color(0xFF111827);
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

  String _emptyText() {
    switch (room.roomType) {
      case StudyRoomType.study:
        return '按下開始專注後，你的人物會出現在房間裡。';
      case StudyRoomType.sleep:
        return '同步健康資料後，你的睡眠進度會出現在房間裡。';
      case StudyRoomType.exercise:
        return '同步健康資料後，你的運動進度會出現在房間裡。';
      case StudyRoomType.steps:
        return '同步健康資料後，你的步數進度會出現在房間裡。';
      case StudyRoomType.custom:
        return '按下開始自律後，你的人物會出現在房間裡。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final visibleMembers = [...members]
      ..sort((a, b) {
        final aActive = a.status == StudyMemberStatus.studying ? 0 : 1;
        final bActive = b.status == StudyMemberStatus.studying ? 0 : 1;
        if (aActive != bActive) return aActive.compareTo(bActive);
        return b.todayFocusSeconds.compareTo(a.todayFocusSeconds);
      });
    final stageMembers = visibleMembers.take(8).toList();

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
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_ambientIcon(), color: accent, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '即時自律房',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '開始後，大家的人物會一起出現在這個房間。',
                        style: TextStyle(fontSize: 12, color: secondaryText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 286,
              decoration: BoxDecoration(
                color: _skyColor(context),
                borderRadius: BorderRadius.circular(AppUI.radiusCard),
                border: Border.all(
                  color: accent.withValues(
                    alpha: AppUI.isDark(context) ? 0.28 : 0.16,
                  ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final positions = <Offset>[
                    Offset(width * 0.42, 36),
                    Offset(width * 0.12, 78),
                    Offset(width * 0.68, 82),
                    Offset(width * 0.26, 150),
                    Offset(width * 0.55, 152),
                    Offset(width * 0.78, 158),
                    Offset(width * 0.04, 170),
                    Offset(width * 0.42, 198),
                  ];

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          children: [
                            Expanded(
                              flex: 7,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _skyColor(context),
                                      _skyColor(
                                        context,
                                      ).withValues(alpha: 0.72),
                                    ],
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Icon(
                                      _ambientIcon(),
                                      color: accent.withValues(alpha: 0.16),
                                      size: 72,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Container(
                                width: double.infinity,
                                color: _floorColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (stageMembers.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _emptyText(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: secondaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else
                        ...stageMembers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final member = entry.value;
                          final avatarProfile = avatarProfileFor(member);
                          final statusColor = statusColorFor(member.status);
                          final position = positions[index];
                          final isActive =
                              member.status == StudyMemberStatus.studying;
                          final avatarSize = isActive ? 72.0 : 62.0;

                          return Positioned(
                            left: position.dx.clamp(8.0, width - 96.0),
                            top: position.dy,
                            child: _StageMemberAvatar(
                              member: member,
                              avatarProfile: avatarProfile,
                              avatarSize: avatarSize,
                              statusText: statusTextFor(member.status),
                              statusColor: statusColor,
                              dimmed:
                                  member.status == StudyMemberStatus.offline,
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
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
      opacity: dimmed ? 0.52 : 1,
      child: SizedBox(
        width: 92,
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
              constraints: const BoxConstraints(maxWidth: 88),
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

class _RoomRankingTile extends StatelessWidget {
  final int rank;
  final StudyMemberData member;
  final AvatarProfile avatarProfile;
  final String focusText;
  final String contributionText;

  const _RoomRankingTile({
    required this.rank,
    required this.member,
    required this.avatarProfile,
    required this.focusText,
    required this.contributionText,
  });

  Color _rankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF9CA3AF);
      case 3:
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _rankColor(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: avatarProfile.backgroundColor,
            borderRadius: BorderRadius.circular(17),
          ),
          child: AvatarPreview(
            profile: avatarProfile,
            size: 50,
            showBackgroundRing: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.roomNickname.isEmpty ? member.name : member.roomNickname,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                contributionText,
                style: TextStyle(fontSize: 12, color: secondaryText),
              ),
            ],
          ),
        ),
        Text(
          focusText,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primaryText,
          ),
        ),
      ],
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String content;

  const _InfoBlock({required this.title, required this.content});

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
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
