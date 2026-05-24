import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_room_models.dart';
import '../models/task_model.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'study_room_detail_page.dart';

enum _RoomSortType {
  defaultOrder,
  activeFirst,
  nearFullFirst,
  progressHighFirst,
}

class StudyRoomListPage extends StatefulWidget {
  const StudyRoomListPage({super.key});

  @override
  State<StudyRoomListPage> createState() => _StudyRoomListPageState();
}

class _StudyRoomListPageState extends State<StudyRoomListPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _onlyMine = false;
  bool _onlyNearFull = false;
  bool _onlyActive = false;
  String _selectedTag = '全部';
  String _searchQuery = '';
  _RoomSortType _sortType = _RoomSortType.activeFirst;
  String? _joiningRoomId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatMMSS(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _roomTotalFocusSeconds(StudyRoomData room) {
    return room.members
        .where((member) => member.isApproved)
        .fold<int>(0, (sum, m) => sum + m.todayFocusSeconds);
  }

  double _roomTrackedValue(StudyRoomData room) {
    switch (room.goalSourceType) {
      case TaskSourceType.sleepHours:
      case TaskSourceType.exerciseMinutes:
      case TaskSourceType.steps:
        return room.members
            .where((member) => member.isApproved)
            .fold<double>(0, (sum, member) => sum + member.todayMetricValue);
      case TaskSourceType.focusMinutes:
      case TaskSourceType.studyRoom:
        return _roomTotalFocusSeconds(room) / 3600;
      case TaskSourceType.manual:
      case TaskSourceType.system:
        return 0;
    }
  }

  String _formatRoomValue(StudyRoomData room, double value) {
    if (room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes) {
      return _formatMMSS((value * 3600).round());
    }
    if (value % 1 == 0) return '${value.toInt()} ${room.goalUnitLabel}';
    return '${value.toStringAsFixed(1)} ${room.goalUnitLabel}';
  }

  int _activeMemberCount(StudyRoomData room) {
    return room.members
        .where(
          (m) =>
              m.isApproved &&
              (m.status == StudyMemberStatus.studying ||
                  m.status == StudyMemberStatus.resting),
        )
        .length;
  }

  bool _isCurrentUserParticipating(StudyRoomData room) {
    return room.members.any(
      (member) => member.memberId == 'local_user' && member.isApproved,
    );
  }

  int _roomPriorityScore(StudyRoomData room, AppState appState) {
    var score = 0;
    score += _activeMemberCount(room) * 100;
    if (_isCurrentUserParticipating(room)) score += 60;
    if (_challengeProgress(room) >= 0.75 && _challengeProgress(room) < 1) {
      score += 35;
    }
    if (appState.isCurrentUserOwner(room.id)) score += 12;
    score += (_challengeProgress(room) * 20).round();
    return score;
  }

  double _challengeProgress(StudyRoomData room) {
    if (room.dailyGoalValue <= 0) return 0;
    return (_roomTrackedValue(room) / room.dailyGoalValue).clamp(0, 1);
  }

  StudyMemberData? _topMember(StudyRoomData room) {
    final approvedMembers = room.members
        .where((member) => member.isApproved)
        .toList();
    if (approvedMembers.isEmpty) return null;
    final sorted = [...approvedMembers]
      ..sort(
        (a, b) => _memberTrackedValue(
          room,
          b,
        ).compareTo(_memberTrackedValue(room, a)),
      );
    return sorted.first;
  }

  double _memberTrackedValue(StudyRoomData room, StudyMemberData member) {
    if (room.goalSourceType == TaskSourceType.studyRoom ||
        room.goalSourceType == TaskSourceType.focusMinutes) {
      return member.todayFocusSeconds / 3600;
    }
    return member.todayMetricValue;
  }

  bool _isNearFull(StudyRoomData room) {
    final approvedCount = room.members
        .where((member) => member.isApproved)
        .length;
    return approvedCount >= room.memberLimit - 1;
  }

  List<String> _displayTags(StudyRoomData room) {
    if (room.tags.isNotEmpty) return room.tags;
    return [_roomTypeLabel(room.roomType)];
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

  List<String> _allTags(List<StudyRoomData> rooms) {
    final tagSet = <String>{'全部'};
    for (final room in rooms) {
      for (final tag in _displayTags(room)) {
        tagSet.add(tag);
      }
    }
    return tagSet.toList();
  }

  List<StudyRoomData> _filteredAndSortedRooms(
    List<StudyRoomData> rooms,
    AppState appState,
  ) {
    final filtered = rooms.where((room) {
      if (_onlyMine && !appState.isCurrentUserOwner(room.id)) {
        return false;
      }

      if (_onlyNearFull && !_isNearFull(room)) {
        return false;
      }

      if (_onlyActive && _activeMemberCount(room) <= 0) {
        return false;
      }

      if (_selectedTag != '全部') {
        final tags = _displayTags(room);
        if (!tags.contains(_selectedTag)) {
          return false;
        }
      }

      return true;
    }).toList();

    switch (_sortType) {
      case _RoomSortType.defaultOrder:
        return filtered;
      case _RoomSortType.activeFirst:
        filtered.sort((a, b) {
          final priorityCompare = _roomPriorityScore(
            b,
            appState,
          ).compareTo(_roomPriorityScore(a, appState));
          if (priorityCompare != 0) return priorityCompare;
          return _roomTrackedValue(b).compareTo(_roomTrackedValue(a));
        });
        return filtered;
      case _RoomSortType.nearFullFirst:
        filtered.sort((a, b) {
          final aApproved = a.members
              .where((member) => member.isApproved)
              .length;
          final bApproved = b.members
              .where((member) => member.isApproved)
              .length;
          final aScore = aApproved / a.memberLimit;
          final bScore = bApproved / b.memberLimit;
          return bScore.compareTo(aScore);
        });
        return filtered;
      case _RoomSortType.progressHighFirst:
        filtered.sort(
          (a, b) => _challengeProgress(b).compareTo(_challengeProgress(a)),
        );
        return filtered;
    }
  }

  String _sortLabel(_RoomSortType type) {
    switch (type) {
      case _RoomSortType.defaultOrder:
        return '預設';
      case _RoomSortType.activeFirst:
        return '專注中優先';
      case _RoomSortType.nearFullFirst:
        return '快滿房優先';
      case _RoomSortType.progressHighFirst:
        return '挑戰進度高優先';
    }
  }

  Future<void> _openCreateRoomPage(BuildContext context) async {
    final result = await Navigator.push<_CreateRoomResult>(
      context,
      MaterialPageRoute(builder: (_) => const _CreateRoomFlowPage()),
    );

    if (result == null) return;
    if (!context.mounted) return;

    context.read<AppState>().createStudyRoom(
      name: result.name,
      description: result.description,
      accentColor: result.accentColor,
      ownerId: 'local_user',
      ownerName: context.read<AppState>().profileNickname,
      tags: result.tags,
      memberLimit: result.memberLimit,
      category: result.category,
      dailyGoalHours: result.dailyGoalHours,
      roomType: result.roomType,
      goalSourceType: result.goalSourceType,
      dailyGoalValue: result.dailyGoalValue,
      goalUnitLabel: result.goalUnitLabel,
      joinMode: result.joinMode,
      joinQuestionsEnabled: result.joinQuestionsEnabled,
      joinQuestions: result.joinQuestions,
      nicknameRuleEnabled: result.nicknameRuleEnabled,
      nicknameRuleText: result.nicknameRuleText,
      roomRules: result.roomRules,
      password: result.password,
      challengeTitle: '今日房間挑戰',
      challengeDescription: result.challengeDescription,
      challengeDeadlineLabel: '今天 23:59',
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已建立房間：${result.name}')));
  }

  void _resetFilters() {
    setState(() {
      _onlyMine = false;
      _onlyNearFull = false;
      _onlyActive = false;
      _selectedTag = '全部';
      _sortType = _RoomSortType.activeFirst;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  bool _hasCurrentUserJoined(StudyRoomData room) {
    return room.members.any((member) => member.memberId == 'local_user');
  }

  bool _matchesSearch(StudyRoomData room, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return room.id.toLowerCase().contains(q) ||
        room.name.toLowerCase().contains(q) ||
        room.category.toLowerCase().contains(q) ||
        room.ownerName.toLowerCase().contains(q) ||
        _displayTags(room).any((tag) => tag.toLowerCase().contains(q));
  }

  List<StudyRoomData> _publicDiscoveryRooms(List<StudyRoomData> joinedRooms) {
    final joinedIds = joinedRooms.map((room) => room.id).toSet();
    final rooms = [
      StudyRoomData(
        id: 'public_focus_library',
        name: '圖書館靜音房',
        description: '不聊天，只打卡專注。適合需要安靜陪伴的人。',
        accentColor: const Color(0xFF14B8A6),
        ownerId: 'public_owner_library',
        ownerName: '林同學',
        announcement: '進房後先設定今天要完成的一件事。',
        tags: const ['靜音房', '高效率', '專題'],
        memberLimit: 12,
        category: '讀書房',
        dailyGoalHours: 3,
        roomType: StudyRoomType.study,
        goalSourceType: TaskSourceType.studyRoom,
        dailyGoalValue: 3,
        goalUnitLabel: '小時',
        joinMode: StudyRoomJoinMode.instant,
        roomRules: '專注期間保持安靜，休息時再留言。',
        password: '',
        challengeTitle: '圖書館自習挑戰',
        challengeDescription: '今天一起累積 3 小時專注。',
        challengeGoalSeconds: 3 * 60 * 60,
        challengeDeadlineLabel: '今天 23:59',
        members: const [
          StudyMemberData(
            memberId: 'public_amy',
            name: 'Amy',
            roomNickname: 'Amy',
            status: StudyMemberStatus.studying,
            sessionSeconds: 38 * 60,
            todayFocusSeconds: 96 * 60,
            avatarColor: Color(0xFF14B8A6),
            role: 'owner',
            personalGoalSeconds: 90 * 60,
            hasReachedPersonalGoal: true,
          ),
          StudyMemberData(
            memberId: 'public_kai',
            name: 'Kai',
            roomNickname: 'Kai',
            status: StudyMemberStatus.resting,
            sessionSeconds: 0,
            todayFocusSeconds: 52 * 60,
            avatarColor: Color(0xFF4F8CFF),
            personalGoalSeconds: 60 * 60,
            hasReachedPersonalGoal: false,
          ),
        ],
      ),
      StudyRoomData(
        id: 'public_sleep_reset',
        name: '早睡重整房',
        description: '用健康資料同步睡眠目標，互相提醒不要熬夜。',
        accentColor: const Color(0xFF8B5CF6),
        ownerId: 'public_owner_sleep',
        ownerName: '小眠',
        tags: const ['早睡挑戰', '睡眠調整', '健康同步'],
        memberLimit: 8,
        category: '睡眠房',
        dailyGoalHours: 7,
        roomType: StudyRoomType.sleep,
        goalSourceType: TaskSourceType.sleepHours,
        dailyGoalValue: 7,
        goalUnitLabel: '小時',
        joinMode: StudyRoomJoinMode.approval,
        joinQuestionsEnabled: true,
        joinQuestions: const ['你想調整的睡覺時間是幾點？'],
        roomRules: '晚上固定時間互相提醒，隔天用健康資料回報。',
        challengeTitle: '早睡重整挑戰',
        challengeDescription: '今晚一起達成 7 小時睡眠。',
        challengeGoalSeconds: 7 * 60 * 60,
        challengeDeadlineLabel: '明天 09:00',
        members: const [
          StudyMemberData(
            memberId: 'public_sleep_1',
            name: '小眠',
            roomNickname: '小眠',
            status: StudyMemberStatus.offline,
            sessionSeconds: 0,
            todayFocusSeconds: 0,
            todayMetricValue: 6.5,
            avatarColor: Color(0xFF8B5CF6),
            role: 'owner',
            personalGoalSeconds: 7 * 60 * 60,
            hasReachedPersonalGoal: false,
          ),
        ],
      ),
      StudyRoomData(
        id: 'public_exam_pass',
        name: '考試倒數密碼房',
        description: '小型讀書房，需要房主提供密碼才可加入。',
        accentColor: const Color(0xFFF59E0B),
        ownerId: 'public_owner_exam',
        ownerName: '阿哲',
        tags: const ['考試衝刺', '夜讀'],
        memberLimit: 6,
        category: '考試衝刺',
        dailyGoalHours: 4,
        roomType: StudyRoomType.study,
        goalSourceType: TaskSourceType.studyRoom,
        dailyGoalValue: 4,
        goalUnitLabel: '小時',
        joinMode: StudyRoomJoinMode.instant,
        password: 'nudge',
        roomRules: '進房需密碼，專注期間以任務進度回報為主。',
        challengeTitle: '考試倒數挑戰',
        challengeDescription: '今天一起累積 4 小時專注。',
        challengeGoalSeconds: 4 * 60 * 60,
        challengeDeadlineLabel: '今天 23:59',
        members: const [
          StudyMemberData(
            memberId: 'public_exam_1',
            name: '阿哲',
            roomNickname: '阿哲',
            status: StudyMemberStatus.studying,
            sessionSeconds: 21 * 60,
            todayFocusSeconds: 77 * 60,
            avatarColor: Color(0xFFF59E0B),
            role: 'owner',
            personalGoalSeconds: 120 * 60,
            hasReachedPersonalGoal: false,
          ),
        ],
      ),
    ];

    return rooms.where((room) => !joinedIds.contains(room.id)).toList();
  }

  List<StudyRoomData> _discoveryRooms(
    List<StudyRoomData> rooms,
    AppState appState,
  ) {
    final publicRooms = _publicDiscoveryRooms(rooms);
    final combined = [...publicRooms, ...rooms];
    return _filteredAndSortedRooms(
      combined,
      appState,
    ).where((room) => _matchesSearch(room, _searchQuery)).toList();
  }

  void _openRoom(BuildContext context, StudyRoomData room) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudyRoomDetailPage(roomId: room.id)),
    );
  }

  Future<void> _joinDiscoveryRoom(
    BuildContext context,
    StudyRoomData room,
  ) async {
    if (_joiningRoomId == room.id) return;

    final appState = context.read<AppState>();
    final alreadyJoined = appState.studyRooms.any(
      (existing) =>
          existing.id == room.id &&
          existing.members.any((member) => member.memberId == 'local_user'),
    );

    if (alreadyJoined) {
      _openRoom(context, room);
      return;
    }

    final approvedCount = room.members
        .where((member) => member.isApproved)
        .length;
    if (approvedCount >= room.memberLimit) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('這間房間已滿')));
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _joiningRoomId = room.id;
    });

    try {
      if (room.password.isNotEmpty) {
        final password = await _askRoomPassword(context, roomName: room.name);
        if (!context.mounted) return;
        if (password == null) return;
        if (password != room.password) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('密碼不正確')));
          return;
        }
      }

      final needsApproval = room.joinMode == StudyRoomJoinMode.approval;
      if (needsApproval) {
        appState.joinStudyRoomFromDiscovery(
          room: room,
          isApproved: false,
          joinAnswer: '我想加入這間自律房一起完成目標。',
        );
      } else {
        appState.joinStudyRoomFromDiscovery(room: room);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            needsApproval ? '已送出加入申請：${room.name}' : '已加入房間：${room.name}',
          ),
        ),
      );
    } finally {
      if (mounted && _joiningRoomId == room.id) {
        setState(() {
          _joiningRoomId = null;
        });
      }
    }
  }

  Future<String?> _askRoomPassword(
    BuildContext context, {
    required String roomName,
  }) async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        useRootNavigator: false,
        requestFocus: false,
        builder: (dialogContext) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            title: const Text('輸入房間密碼'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppUI.textPrimaryOf(dialogContext),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: false,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '房間密碼',
                    hintText: '請輸入房主提供的密碼',
                  ),
                  onSubmitted: (value) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(dialogContext).pop(value.trim());
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('加入'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Widget _buildRoomList({
    required BuildContext context,
    required List<StudyRoomData> rooms,
    required String emptyTitle,
    required String emptySubtitle,
    bool discoveryMode = false,
  }) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    if (rooms.isEmpty) {
      return Card(
        shape: AppUI.cardShape(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 40, color: secondaryText),
              const SizedBox(height: 10),
              Text(
                emptyTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryText,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: rooms
          .map(
            (room) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StudyRoomCard(
                room: room,
                trackedValue: _roomTrackedValue(room),
                trackedValueText: _formatRoomValue(
                  room,
                  _roomTrackedValue(room),
                ),
                activeCount: _activeMemberCount(room),
                progress: _challengeProgress(room),
                topMember: _topMember(room),
                topMemberValueText: _topMember(room) == null
                    ? ''
                    : _formatRoomValue(
                        room,
                        _memberTrackedValue(room, _topMember(room)!),
                      ),
                nearFull: _isNearFull(room),
                tags: _displayTags(room),
                roomTypeIcon: _roomTypeIcon(room.roomType),
                roomTypeLabel: _roomTypeLabel(room.roomType),
                isJoining: _joiningRoomId == room.id,
                onTap: () => discoveryMode && !_hasCurrentUserJoined(room)
                    ? _joinDiscoveryRoom(context, room)
                    : _openRoom(context, room),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final rooms = appState.studyRooms;
    final allTags = _allTags(rooms);
    final accentColor = appState.currentIconColor;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    if (!allTags.contains(_selectedTag)) {
      _selectedTag = '全部';
    }

    final displayRooms = _filteredAndSortedRooms(rooms, appState);
    final activeRooms =
        rooms.where((room) => _activeMemberCount(room) > 0).toList()..sort(
          (a, b) => _roomPriorityScore(
            b,
            appState,
          ).compareTo(_roomPriorityScore(a, appState)),
        );
    final discoveryRooms = _discoveryRooms(rooms, appState);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('自律房'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '探索'),
              Tab(text: '進行中'),
              Tab(text: '我的房間'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: () => _openCreateRoomPage(context),
          backgroundColor: accentColor.withValues(alpha: 0.30),
          foregroundColor: accentColor,
          icon: const Icon(Icons.add),
          label: const Text('建立自律房'),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(AppUI.pagePadding),
              children: [
                _SectionHeader(
                  title: '探索公開房間',
                  subtitle: '搜尋房間名稱或 ID，也可以加入系統推薦的免密碼、需審核或密碼房。',
                ),
                const SizedBox(height: AppUI.cardGap),
                Card(
                  shape: AppUI.cardShape(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: '搜尋房間名稱、ID、標籤',
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _searchController.clear();
                                      });
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _RoomFilterPill(
                                label: '進行中',
                                selected: _onlyActive,
                                onTap: () {
                                  setState(() {
                                    _onlyActive = !_onlyActive;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RoomFilterPill(
                                label: '快滿房',
                                selected: _onlyNearFull,
                                onTap: () {
                                  setState(() {
                                    _onlyNearFull = !_onlyNearFull;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _RoomFilterPill(
                                label: '我建立的',
                                selected: _onlyMine,
                                onTap: () {
                                  setState(() {
                                    _onlyMine = !_onlyMine;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _resetFilters,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('重設'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppUI.sectionGap),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '推薦與搜尋結果',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ),
                    Text(
                      '共 ${discoveryRooms.length} 間',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRoomList(
                  context: context,
                  rooms: discoveryRooms,
                  emptyTitle: '目前找不到房間',
                  emptySubtitle: '可以換個關鍵字，或建立自己的自律房。',
                  discoveryMode: true,
                ),
                const SizedBox(height: 84),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(AppUI.pagePadding),
              children: [
                _SectionHeader(
                  title: '正在進行中的自律房',
                  subtitle: '目前有人正在自律的房間會優先顯示。',
                ),
                const SizedBox(height: AppUI.cardGap),
                _buildRoomList(
                  context: context,
                  rooms: activeRooms,
                  emptyTitle: '目前沒有進行中的房間',
                  emptySubtitle: '等好友開始自律，或自己進入房間開始一輪專注。',
                ),
                const SizedBox(height: 84),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(AppUI.pagePadding),
              children: [
                _SectionHeader(title: '我已加入的自律房', subtitle: '這裡只放你已經加入或建立的房間。'),
                const SizedBox(height: AppUI.cardGap),
                Card(
                  shape: AppUI.cardShape(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '篩選我的房間',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: primaryText,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _resetFilters,
                              child: const Text('重設'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = (constraints.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: allTags.map((tag) {
                                final selected = _selectedTag == tag;
                                return SizedBox(
                                  width: itemWidth,
                                  child: _RoomFilterPill(
                                    label: tag,
                                    selected: selected,
                                    onTap: () {
                                      setState(() {
                                        _selectedTag = tag;
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<_RoomSortType>(
                          initialValue: _sortType,
                          decoration: const InputDecoration(
                            labelText: '排序',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: _RoomSortType.values
                              .map(
                                (type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(_sortLabel(type)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _sortType = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppUI.sectionGap),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '自律房列表',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ),
                    Text(
                      '共 ${displayRooms.length} 間',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRoomList(
                  context: context,
                  rooms: displayRooms,
                  emptyTitle: '目前沒有符合條件的房間',
                  emptySubtitle: '你可以調整篩選條件，或直接建立新的房間。',
                ),
                const SizedBox(height: 84),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRoomResult {
  final String name;
  final String description;
  final String category;
  final int dailyGoalHours;
  final StudyRoomType roomType;
  final TaskSourceType goalSourceType;
  final double dailyGoalValue;
  final String goalUnitLabel;
  final int memberLimit;
  final StudyRoomJoinMode joinMode;
  final bool joinQuestionsEnabled;
  final List<String> joinQuestions;
  final bool nicknameRuleEnabled;
  final String nicknameRuleText;
  final String roomRules;
  final String password;
  final List<String> tags;
  final Color accentColor;
  final String challengeDescription;

  const _CreateRoomResult({
    required this.name,
    required this.description,
    required this.category,
    required this.dailyGoalHours,
    required this.roomType,
    required this.goalSourceType,
    required this.dailyGoalValue,
    required this.goalUnitLabel,
    required this.memberLimit,
    required this.joinMode,
    required this.joinQuestionsEnabled,
    required this.joinQuestions,
    required this.nicknameRuleEnabled,
    required this.nicknameRuleText,
    required this.roomRules,
    required this.password,
    required this.tags,
    required this.accentColor,
    required this.challengeDescription,
  });
}

class _RoomTemplate {
  final String title;
  final String description;
  final StudyRoomType roomType;
  final String name;
  final String category;
  final double goalValue;
  final int memberLimit;
  final Color accentColor;
  final List<String> tags;
  final String rules;

  const _RoomTemplate({
    required this.title,
    required this.description,
    required this.roomType,
    required this.name,
    required this.category,
    required this.goalValue,
    required this.memberLimit,
    required this.accentColor,
    required this.tags,
    required this.rules,
  });
}

class _CreateRoomFlowPage extends StatefulWidget {
  const _CreateRoomFlowPage();

  @override
  State<_CreateRoomFlowPage> createState() => _CreateRoomFlowPageState();
}

class _CreateRoomFlowPageState extends State<_CreateRoomFlowPage> {
  final PageController _pageController = PageController();

  int _stepIndex = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _customTagController = TextEditingController();
  final TextEditingController _question1Controller = TextEditingController();
  final TextEditingController _question2Controller = TextEditingController();
  final TextEditingController _nicknameRuleController = TextEditingController();
  final TextEditingController _roomRulesController = TextEditingController();

  final List<String> _presetTags = [
    '考試衝刺',
    '夜讀',
    '晨讀',
    '靜音房',
    '英文',
    '數學',
    '程式',
    '研究所',
    '國考',
    '專題',
    '自律打卡',
    '陪伴學習',
  ];

  List<String> get _currentPresetTags {
    switch (_roomType) {
      case StudyRoomType.study:
        return _presetTags;
      case StudyRoomType.sleep:
        return const ['早睡挑戰', '睡眠調整', '固定作息', '無手機睡前', '健康同步'];
      case StudyRoomType.exercise:
        return const ['運動習慣', '重訓', '有氧', '伸展', '每日打卡', '健康同步'];
      case StudyRoomType.steps:
        return const ['步數挑戰', '通勤走路', '散步', '萬步挑戰', '健康同步'];
      case StudyRoomType.custom:
        return const ['自律打卡', '生活習慣', '互相提醒', '每日固定活動', '陪伴挑戰'];
    }
  }

  final List<String> _categories = [
    '國小',
    '國中',
    '高一',
    '高二',
    '高三',
    '重考生',
    '大學生',
    '研究生',
    '國家考試',
    '地方特考',
    '語言檢定',
    '程式學習',
    '自訂',
  ];

  List<String> get _currentCategories {
    switch (_roomType) {
      case StudyRoomType.study:
        return _categories;
      case StudyRoomType.sleep:
        return const ['早睡早起', '睡眠時數', '作息調整', '健康同步', '自訂'];
      case StudyRoomType.exercise:
        return const ['有氧運動', '重訓', '伸展瑜珈', '每日運動', '健康同步', '自訂'];
      case StudyRoomType.steps:
        return const ['每日步數', '通勤走路', '散步陪伴', '萬步挑戰', '健康同步', '自訂'];
      case StudyRoomType.custom:
        return const ['生活習慣', '專題進度', '家事整理', '興趣練習', '自訂'];
    }
  }

  final List<int> _goalHoursOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  final List<int> _sleepGoalOptions = [6, 7, 8, 9];
  final List<int> _exerciseGoalOptions = [15, 30, 45, 60, 90];
  final List<int> _stepsGoalOptions = [3000, 5000, 8000, 10000, 12000];
  final List<int> _memberLimitOptions = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  final List<_RoomTemplate> _roomTemplates = const [
    _RoomTemplate(
      title: '考前衝刺',
      description: '讀書房、每日 3 小時、適合考試或專題死線前。',
      roomType: StudyRoomType.study,
      name: '考前衝刺讀書房',
      category: '考試衝刺',
      goalValue: 3,
      memberLimit: 6,
      accentColor: Color(0xFF7C6AE6),
      tags: ['考試衝刺', '靜音房', '夜讀'],
      rules: '進房後先設定今日目標，開始專注後盡量保持安靜。',
    ),
    _RoomTemplate(
      title: '早睡挑戰',
      description: '睡眠房、每日 7 小時、適合調整作息。',
      roomType: StudyRoomType.sleep,
      name: '早睡早起自律房',
      category: '作息調整',
      goalValue: 7,
      memberLimit: 8,
      accentColor: Color(0xFF8B5CF6),
      tags: ['早睡挑戰', '固定作息', '健康同步'],
      rules: '晚上固定時間互相提醒，隔天用健康資料確認睡眠目標。',
    ),
    _RoomTemplate(
      title: '每日運動',
      description: '運動房、每日 30 分鐘、適合建立運動習慣。',
      roomType: StudyRoomType.exercise,
      name: '每日運動打卡房',
      category: '每日運動',
      goalValue: 30,
      memberLimit: 10,
      accentColor: Color(0xFFF97316),
      tags: ['運動習慣', '每日打卡', '健康同步'],
      rules: '完成運動後回房內打卡，健康資料同步後會更新進度。',
    ),
    _RoomTemplate(
      title: '萬步挑戰',
      description: '步數房、每日 10000 步、適合朋友互相督促走路。',
      roomType: StudyRoomType.steps,
      name: '一起走路萬步房',
      category: '萬步挑戰',
      goalValue: 10000,
      memberLimit: 12,
      accentColor: Color(0xFF10B981),
      tags: ['步數挑戰', '萬步挑戰', '散步'],
      rules: '每日晚上統計步數，還沒達標的人可以在聊天室互相提醒。',
    ),
  ];

  String _selectedCategory = '大學生';
  int _dailyGoalHours = 2;
  StudyRoomType _roomType = StudyRoomType.study;
  TaskSourceType _goalSourceType = TaskSourceType.studyRoom;
  double _dailyGoalValue = 2;
  String _goalUnitLabel = '小時';
  int _memberLimit = 8;
  StudyRoomJoinMode _joinMode = StudyRoomJoinMode.instant;
  bool _joinQuestionsEnabled = false;
  bool _nicknameRuleEnabled = false;
  final List<String> _selectedTags = [];
  Color _selectedColor = const Color(0xFF7C6AE6);

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _descriptionController.dispose();
    _customTagController.dispose();
    _question1Controller.dispose();
    _question2Controller.dispose();
    _nicknameRuleController.dispose();
    _roomRulesController.dispose();
    super.dispose();
  }

  int get _totalSteps => 5;

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  void _addCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isEmpty) return;

    if (!_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
      });
    }
    _customTagController.clear();
  }

  List<String> _buildJoinQuestions() {
    if (!_joinQuestionsEnabled) return const [];
    final raw = [
      _question1Controller.text.trim(),
      _question2Controller.text.trim(),
    ];
    return raw.where((e) => e.isNotEmpty).toList();
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

  String _defaultCategoryFor(StudyRoomType type) {
    switch (type) {
      case StudyRoomType.study:
        return '大學生';
      case StudyRoomType.sleep:
        return '睡眠時數';
      case StudyRoomType.exercise:
        return '每日運動';
      case StudyRoomType.steps:
        return '每日步數';
      case StudyRoomType.custom:
        return '生活習慣';
    }
  }

  String _defaultNameFor(StudyRoomType type) {
    switch (type) {
      case StudyRoomType.study:
        return '今晚一起讀書房';
      case StudyRoomType.sleep:
        return '早睡早起自律房';
      case StudyRoomType.exercise:
        return '每日運動打卡房';
      case StudyRoomType.steps:
        return '一起走路步數房';
      case StudyRoomType.custom:
        return '每日自律打卡房';
    }
  }

  String _challengeDescriptionForRoom() {
    switch (_roomType) {
      case StudyRoomType.study:
        return '一起累積專注時間';
      case StudyRoomType.sleep:
        return '一起達成今天的睡眠目標';
      case StudyRoomType.exercise:
        return '一起完成今天的運動時間';
      case StudyRoomType.steps:
        return '一起累積今天的步數';
      case StudyRoomType.custom:
        return '一起完成今天的自律目標';
    }
  }

  void _selectRoomType(StudyRoomType type) {
    setState(() {
      final currentName = _nameController.text.trim();
      final wasSuggestedName = StudyRoomType.values.any(
        (item) => currentName == _defaultNameFor(item),
      );
      _roomType = type;
      _selectedCategory = _defaultCategoryFor(type);
      if (currentName.isEmpty || wasSuggestedName) {
        _nameController.text = _defaultNameFor(type);
      }
      switch (type) {
        case StudyRoomType.study:
          _goalSourceType = TaskSourceType.studyRoom;
          _dailyGoalValue = _dailyGoalHours.toDouble();
          _goalUnitLabel = '小時';
          break;
        case StudyRoomType.sleep:
          _goalSourceType = TaskSourceType.sleepHours;
          _dailyGoalValue = 7;
          _goalUnitLabel = '小時';
          break;
        case StudyRoomType.exercise:
          _goalSourceType = TaskSourceType.exerciseMinutes;
          _dailyGoalValue = 30;
          _goalUnitLabel = '分鐘';
          break;
        case StudyRoomType.steps:
          _goalSourceType = TaskSourceType.steps;
          _dailyGoalValue = 8000;
          _goalUnitLabel = '步';
          break;
        case StudyRoomType.custom:
          _goalSourceType = TaskSourceType.studyRoom;
          _dailyGoalValue = _dailyGoalHours.toDouble();
          _goalUnitLabel = '小時';
          break;
      }
    });
  }

  void _applyTemplate(_RoomTemplate template) {
    _selectRoomType(template.roomType);
    setState(() {
      _nameController.text = template.name;
      _descriptionController.text = template.description;
      _selectedCategory = template.category;
      _dailyGoalValue = template.goalValue;
      if (template.roomType == StudyRoomType.study ||
          template.roomType == StudyRoomType.custom) {
        _dailyGoalHours = template.goalValue.round();
      }
      _memberLimit = template.memberLimit;
      _selectedColor = template.accentColor;
      _roomRulesController.text = template.rules;
      _selectedTags
        ..clear()
        ..addAll(template.tags);
    });
  }

  bool _validateCurrentStep() {
    if (_stepIndex == 1) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('請先輸入房間名稱')));
        return false;
      }
    }

    if (_stepIndex == 2 && _joinQuestionsEnabled) {
      if (_buildJoinQuestions().isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已開啟加入問題，至少請填一題')));
        return false;
      }
    }

    return true;
  }

  void _goNext() {
    if (!_validateCurrentStep()) return;

    if (_stepIndex < _totalSteps - 1) {
      setState(() {
        _stepIndex++;
      });
      _pageController.animateToPage(
        _stepIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    } else {
      _submit();
    }
  }

  void _goBack() {
    if (_stepIndex == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _stepIndex--;
    });
    _pageController.animateToPage(
      _stepIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _submit() {
    final result = _CreateRoomResult(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      dailyGoalHours: _dailyGoalHours,
      roomType: _roomType,
      goalSourceType: _goalSourceType,
      dailyGoalValue: _dailyGoalValue,
      goalUnitLabel: _goalUnitLabel,
      memberLimit: _memberLimit,
      joinMode: _joinMode,
      joinQuestionsEnabled: _joinQuestionsEnabled,
      joinQuestions: _buildJoinQuestions(),
      nicknameRuleEnabled: _nicknameRuleEnabled,
      nicknameRuleText: _nicknameRuleController.text.trim(),
      roomRules: _roomRulesController.text.trim(),
      password: _passwordController.text.trim(),
      tags: _selectedTags,
      accentColor: _selectedColor,
      challengeDescription: _challengeDescriptionForRoom(),
    );

    Navigator.pop(context, result);
  }

  String _buttonLabel() {
    if (_stepIndex == _totalSteps - 1) return '建立房間';
    return '下一步 ${_stepIndex + 1}/$_totalSteps';
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('建立自律房 ${_stepIndex + 1}/$_totalSteps'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppUI.pagePadding,
                8,
                AppUI.pagePadding,
                0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.radiusPill),
                child: LinearProgressIndicator(
                  value: (_stepIndex + 1) / _totalSteps,
                  minHeight: 8,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _CreateStepPositioning(
                    templates: _roomTemplates,
                    onTemplateSelected: _applyTemplate,
                    roomTypes: StudyRoomType.values,
                    selectedRoomType: _roomType,
                    roomTypeLabel: _roomTypeLabel,
                    onRoomTypeChanged: _selectRoomType,
                    goalHoursOptions: _goalHoursOptions,
                    dailyGoalHours: _dailyGoalHours,
                    onGoalHoursChanged: (value) {
                      setState(() {
                        _dailyGoalHours = value;
                        if (_goalSourceType == TaskSourceType.studyRoom ||
                            _goalSourceType == TaskSourceType.focusMinutes) {
                          _dailyGoalValue = value.toDouble();
                        }
                      });
                    },
                    sleepGoalOptions: _sleepGoalOptions,
                    exerciseGoalOptions: _exerciseGoalOptions,
                    stepsGoalOptions: _stepsGoalOptions,
                    goalSourceType: _goalSourceType,
                    dailyGoalValue: _dailyGoalValue,
                    goalUnitLabel: _goalUnitLabel,
                    onGoalValueChanged: (value) {
                      setState(() {
                        _dailyGoalValue = value;
                      });
                    },
                    memberLimitOptions: _memberLimitOptions,
                    memberLimit: _memberLimit,
                    onMemberLimitChanged: (value) {
                      setState(() {
                        _memberLimit = value;
                      });
                    },
                  ),
                  _CreateStepBasicInfo(
                    nameController: _nameController,
                    descriptionController: _descriptionController,
                    roomTypeLabel: _roomTypeLabel(_roomType),
                    categories: _currentCategories,
                    selectedCategory: _selectedCategory,
                    onCategoryChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                  _CreateStepJoinRules(
                    joinMode: _joinMode,
                    onJoinModeChanged: (value) {
                      setState(() {
                        _joinMode = value;
                      });
                    },
                    joinQuestionsEnabled: _joinQuestionsEnabled,
                    onJoinQuestionsEnabledChanged: (value) {
                      setState(() {
                        _joinQuestionsEnabled = value;
                      });
                    },
                    passwordController: _passwordController,
                    question1Controller: _question1Controller,
                    question2Controller: _question2Controller,
                  ),
                  _CreateStepNicknameAndTags(
                    nicknameRuleEnabled: _nicknameRuleEnabled,
                    onNicknameRuleEnabledChanged: (value) {
                      setState(() {
                        _nicknameRuleEnabled = value;
                      });
                    },
                    nicknameRuleController: _nicknameRuleController,
                    presetTags: _currentPresetTags,
                    selectedTags: _selectedTags,
                    onToggleTag: _toggleTag,
                    customTagController: _customTagController,
                    onAddCustomTag: _addCustomTag,
                  ),
                  _CreateStepFinal(
                    roomRulesController: _roomRulesController,
                    selectedColor: _selectedColor,
                    onColorChanged: (value) {
                      setState(() {
                        _selectedColor = value;
                      });
                    },
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppUI.pagePadding,
                0,
                AppUI.pagePadding,
                AppUI.pagePadding,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goNext,
                  child: Text(_buttonLabel()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateStepBasicInfo extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final String roomTypeLabel;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  const _CreateStepBasicInfo({
    required this.nameController,
    required this.descriptionController,
    required this.roomTypeLabel,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        Text(
          '命名這間$roomTypeLabel',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '系統會依照上一頁的自律目標先幫你放好預設名稱，你可以再改成更有辨識度的房名。',
          style: TextStyle(fontSize: 14, color: secondaryText, height: 1.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '房間名稱',
            hintText: '例如：夜讀靜音房',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: descriptionController,
          decoration: const InputDecoration(
            labelText: '房間簡介',
            hintText: '例如：晚上安靜讀書、互相打卡進度',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          textInputAction: TextInputAction.newline,
        ),
        const SizedBox(height: 20),
        Text(
          '房間類別',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((item) {
            return ChoiceChip(
              label: Text(item),
              selected: selectedCategory == item,
              onSelected: (_) => onCategoryChanged(item),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CreateStepPositioning extends StatelessWidget {
  final List<_RoomTemplate> templates;
  final ValueChanged<_RoomTemplate> onTemplateSelected;
  final List<StudyRoomType> roomTypes;
  final StudyRoomType selectedRoomType;
  final String Function(StudyRoomType) roomTypeLabel;
  final ValueChanged<StudyRoomType> onRoomTypeChanged;
  final List<int> goalHoursOptions;
  final int dailyGoalHours;
  final ValueChanged<int> onGoalHoursChanged;
  final List<int> sleepGoalOptions;
  final List<int> exerciseGoalOptions;
  final List<int> stepsGoalOptions;
  final TaskSourceType goalSourceType;
  final double dailyGoalValue;
  final String goalUnitLabel;
  final ValueChanged<double> onGoalValueChanged;
  final List<int> memberLimitOptions;
  final int memberLimit;
  final ValueChanged<int> onMemberLimitChanged;

  const _CreateStepPositioning({
    required this.templates,
    required this.onTemplateSelected,
    required this.roomTypes,
    required this.selectedRoomType,
    required this.roomTypeLabel,
    required this.onRoomTypeChanged,
    required this.goalHoursOptions,
    required this.dailyGoalHours,
    required this.onGoalHoursChanged,
    required this.sleepGoalOptions,
    required this.exerciseGoalOptions,
    required this.stepsGoalOptions,
    required this.goalSourceType,
    required this.dailyGoalValue,
    required this.goalUnitLabel,
    required this.onGoalValueChanged,
    required this.memberLimitOptions,
    required this.memberLimit,
    required this.onMemberLimitChanged,
  });

  String _goalTitle() {
    switch (selectedRoomType) {
      case StudyRoomType.study:
        return '每日讀書目標';
      case StudyRoomType.sleep:
        return '每日睡眠目標';
      case StudyRoomType.exercise:
        return '每日運動目標';
      case StudyRoomType.steps:
        return '每日步數目標';
      case StudyRoomType.custom:
        return '每日自律目標';
    }
  }

  String _goalDescription() {
    switch (selectedRoomType) {
      case StudyRoomType.study:
        return '用房內專注計時累積，適合讀書、報告和考試準備。';
      case StudyRoomType.sleep:
        return '用健康資料的睡眠時數判定，適合互相提醒早睡。';
      case StudyRoomType.exercise:
        return '用健康資料的運動分鐘判定，適合一起運動打卡。';
      case StudyRoomType.steps:
        return '用健康資料的每日步數判定，適合萬步挑戰或散步陪伴。';
      case StudyRoomType.custom:
        return '用房內打卡或專注時間累積，適合自訂生活習慣。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        Text(
          '先選自律目標',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '先決定這間房要一起讀書、睡覺、運動還是走路。後面的名稱、規則和標籤都會跟著這個目標走。',
          style: TextStyle(fontSize: 14, color: secondaryText, height: 1.5),
        ),
        const SizedBox(height: 20),

        Text(
          '快速模板',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final template = templates[index];
              return _RoomTemplateCard(
                template: template,
                selected: selectedRoomType == template.roomType,
                onTap: () => onTemplateSelected(template),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemCount: templates.length,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          '房間類型',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: roomTypes.map((type) {
            return ChoiceChip(
              label: Text(roomTypeLabel(type)),
              selected: selectedRoomType == type,
              onSelected: (_) => onRoomTypeChanged(type),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: Text(
                _goalTitle(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
            ),
            _RoomSourcePill(
              roomType: selectedRoomType,
              sourceType: goalSourceType,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _goalDescription(),
          style: TextStyle(fontSize: 13, color: secondaryText, height: 1.45),
        ),
        const SizedBox(height: 10),
        _GoalPicker(
          selectedRoomType: selectedRoomType,
          goalHoursOptions: goalHoursOptions,
          sleepGoalOptions: sleepGoalOptions,
          exerciseGoalOptions: exerciseGoalOptions,
          stepsGoalOptions: stepsGoalOptions,
          goalSourceType: goalSourceType,
          dailyGoalHours: dailyGoalHours,
          dailyGoalValue: dailyGoalValue,
          goalUnitLabel: goalUnitLabel,
          onGoalHoursChanged: onGoalHoursChanged,
          onGoalValueChanged: onGoalValueChanged,
        ),

        const SizedBox(height: 20),

        Text(
          '可容納人數',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: memberLimitOptions.map((count) {
            return ChoiceChip(
              label: Text('$count 人'),
              selected: memberLimit == count,
              onSelected: (_) => onMemberLimitChanged(count),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _GoalPicker extends StatelessWidget {
  final StudyRoomType selectedRoomType;
  final List<int> goalHoursOptions;
  final List<int> sleepGoalOptions;
  final List<int> exerciseGoalOptions;
  final List<int> stepsGoalOptions;
  final TaskSourceType goalSourceType;
  final int dailyGoalHours;
  final double dailyGoalValue;
  final String goalUnitLabel;
  final ValueChanged<int> onGoalHoursChanged;
  final ValueChanged<double> onGoalValueChanged;

  const _GoalPicker({
    required this.selectedRoomType,
    required this.goalHoursOptions,
    required this.sleepGoalOptions,
    required this.exerciseGoalOptions,
    required this.stepsGoalOptions,
    required this.goalSourceType,
    required this.dailyGoalHours,
    required this.dailyGoalValue,
    required this.goalUnitLabel,
    required this.onGoalHoursChanged,
    required this.onGoalValueChanged,
  });

  List<int> get _options {
    switch (goalSourceType) {
      case TaskSourceType.sleepHours:
        return sleepGoalOptions;
      case TaskSourceType.exerciseMinutes:
        return exerciseGoalOptions;
      case TaskSourceType.steps:
        return stepsGoalOptions;
      case TaskSourceType.focusMinutes:
      case TaskSourceType.studyRoom:
      case TaskSourceType.manual:
      case TaskSourceType.system:
        return goalHoursOptions;
    }
  }

  String _label(int value) {
    switch (selectedRoomType) {
      case StudyRoomType.study:
        return '專注 $value 小時';
      case StudyRoomType.sleep:
        return '睡滿 $value 小時';
      case StudyRoomType.exercise:
        return '運動 $value 分鐘';
      case StudyRoomType.steps:
        return '$value 步';
      case StudyRoomType.custom:
        return '累積 $value 小時';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((value) {
        final selected =
            goalSourceType == TaskSourceType.studyRoom ||
                goalSourceType == TaskSourceType.focusMinutes
            ? dailyGoalHours == value
            : dailyGoalValue == value;

        return ChoiceChip(
          label: Text(_label(value)),
          selected: selected,
          onSelected: (_) {
            if (goalSourceType == TaskSourceType.studyRoom ||
                goalSourceType == TaskSourceType.focusMinutes) {
              onGoalHoursChanged(value);
            } else {
              onGoalValueChanged(value.toDouble());
            }
          },
        );
      }).toList(),
    );
  }
}

class _RoomTemplateCard extends StatelessWidget {
  final _RoomTemplate template;
  final bool selected;
  final VoidCallback onTap;

  const _RoomTemplateCard({
    required this.template,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final color = template.accentColor;

    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.radiusLarge),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: AppUI.isDark(context) ? 0.22 : 0.12)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppUI.radiusLarge),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard_customize_outlined,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              template.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomSourcePill extends StatelessWidget {
  final StudyRoomType roomType;
  final TaskSourceType sourceType;

  const _RoomSourcePill({required this.roomType, required this.sourceType});

  IconData get _icon {
    switch (roomType) {
      case StudyRoomType.study:
      case StudyRoomType.custom:
        return Icons.timer_outlined;
      case StudyRoomType.sleep:
        return Icons.bedtime_outlined;
      case StudyRoomType.exercise:
        return Icons.local_fire_department_outlined;
      case StudyRoomType.steps:
        return Icons.directions_walk_outlined;
    }
  }

  String get _label {
    switch (sourceType) {
      case TaskSourceType.sleepHours:
      case TaskSourceType.exerciseMinutes:
      case TaskSourceType.steps:
        return '健康同步';
      case TaskSourceType.studyRoom:
      case TaskSourceType.focusMinutes:
        return '房內計時';
      case TaskSourceType.manual:
      case TaskSourceType.system:
        return '系統判定';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.watch<AppState>().currentIconColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppUI.softCardOf(context, accentColor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: accentColor, size: 16),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateStepJoinRules extends StatelessWidget {
  final StudyRoomJoinMode joinMode;
  final ValueChanged<StudyRoomJoinMode> onJoinModeChanged;
  final bool joinQuestionsEnabled;
  final ValueChanged<bool> onJoinQuestionsEnabledChanged;
  final TextEditingController passwordController;
  final TextEditingController question1Controller;
  final TextEditingController question2Controller;

  const _CreateStepJoinRules({
    required this.joinMode,
    required this.onJoinModeChanged,
    required this.joinQuestionsEnabled,
    required this.onJoinQuestionsEnabledChanged,
    required this.passwordController,
    required this.question1Controller,
    required this.question2Controller,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        Text(
          '設定加入規則',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '你可以決定是直接加入，還是先審核。若想篩選成員，也能加上加入問題。',
          style: TextStyle(fontSize: 14, color: secondaryText, height: 1.5),
        ),
        const SizedBox(height: 20),

        _SelectCard(
          title: '立即加入',
          subtitle: '任何人都可以直接加入房間。',
          selected: joinMode == StudyRoomJoinMode.instant,
          onTap: () => onJoinModeChanged(StudyRoomJoinMode.instant),
        ),
        const SizedBox(height: 12),
        _SelectCard(
          title: '審核後加入',
          subtitle: '需要房主批准後才能加入。',
          selected: joinMode == StudyRoomJoinMode.approval,
          onTap: () => onJoinModeChanged(StudyRoomJoinMode.approval),
        ),

        const SizedBox(height: 20),

        SwitchListTile(
          value: joinQuestionsEnabled,
          onChanged: onJoinQuestionsEnabledChanged,
          title: Text(
            '開啟加入問題',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryText),
          ),
          subtitle: Text(
            '例如：你的目標是什麼？是否願意遵守房規？',
            style: TextStyle(color: secondaryText),
          ),
          contentPadding: EdgeInsets.zero,
        ),

        if (joinQuestionsEnabled) ...[
          const SizedBox(height: 12),
          TextField(
            controller: question1Controller,
            decoration: const InputDecoration(
              labelText: '問題 1',
              hintText: '例如：你今天想完成什麼？',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: question2Controller,
            decoration: const InputDecoration(
              labelText: '問題 2（可選）',
              hintText: '例如：是否願意遵守房間規則？',
              border: OutlineInputBorder(),
            ),
          ),
        ],

        const SizedBox(height: 20),
        TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: '房間密碼（可選）',
            hintText: '想做小圈圈房間時再設定',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

class _CreateStepNicknameAndTags extends StatelessWidget {
  final bool nicknameRuleEnabled;
  final ValueChanged<bool> onNicknameRuleEnabledChanged;
  final TextEditingController nicknameRuleController;
  final List<String> presetTags;
  final List<String> selectedTags;
  final ValueChanged<String> onToggleTag;
  final TextEditingController customTagController;
  final VoidCallback onAddCustomTag;

  const _CreateStepNicknameAndTags({
    required this.nicknameRuleEnabled,
    required this.onNicknameRuleEnabledChanged,
    required this.nicknameRuleController,
    required this.presetTags,
    required this.selectedTags,
    required this.onToggleTag,
    required this.customTagController,
    required this.onAddCustomTag,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        Text(
          '暱稱規則與房間標籤',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '這一步決定房內成員要怎麼顯示，以及其他人能不能快速透過標籤找到你的房間。',
          style: TextStyle(fontSize: 14, color: secondaryText, height: 1.5),
        ),
        const SizedBox(height: 20),

        SwitchListTile(
          value: nicknameRuleEnabled,
          onChanged: onNicknameRuleEnabledChanged,
          title: Text(
            '啟用暱稱規則',
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryText),
          ),
          subtitle: Text(
            '例如：學校 / 年級 / 目標',
            style: TextStyle(color: secondaryText),
          ),
          contentPadding: EdgeInsets.zero,
        ),

        if (nicknameRuleEnabled) ...[
          const SizedBox(height: 12),
          TextField(
            controller: nicknameRuleController,
            decoration: const InputDecoration(
              labelText: '暱稱規則說明',
              hintText: '例如：請輸入學校/年級/每日目標',
              border: OutlineInputBorder(),
            ),
          ),
        ],

        const SizedBox(height: 20),

        Text(
          '預設標籤',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presetTags.map((tag) {
            final selected = selectedTags.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: selected,
              onSelected: (_) => onToggleTag(tag),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customTagController,
                decoration: const InputDecoration(
                  labelText: '自訂標籤',
                  hintText: '輸入後按加入',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onAddCustomTag(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: onAddCustomTag, child: const Text('加入')),
          ],
        ),

        const SizedBox(height: 10),

        if (selectedTags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedTags.map((tag) {
              return Chip(label: Text(tag), onDeleted: () => onToggleTag(tag));
            }).toList(),
          ),
      ],
    );
  }
}

class _CreateStepFinal extends StatelessWidget {
  final TextEditingController roomRulesController;
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;
  final Color primaryText;
  final Color secondaryText;

  const _CreateStepFinal({
    required this.roomRulesController,
    required this.selectedColor,
    required this.onColorChanged,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF7C6AE6),
      const Color(0xFF4F8CFF),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        Text(
          '最後補上房規與主色',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '完成後就能建立房間。房規不是必填，但建議寫清楚，其他人比較容易理解你的房間風格。',
          style: TextStyle(fontSize: 14, color: secondaryText, height: 1.5),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: roomRulesController,
          decoration: const InputDecoration(
            labelText: '房規 / 補充說明',
            hintText: '例如：進房後請直接開始專注，禁止閒聊',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 20),
        Text(
          '房間主色',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final selected = selectedColor == color;
            return GestureDetector(
              onTap: () => onColorChanged(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(
                          color: AppUI.isDark(context)
                              ? Colors.white
                              : Colors.black,
                          width: 2,
                        )
                      : Border.all(color: Theme.of(context).dividerColor),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SelectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accentColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(AppUI.radiusCard),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppUI.radiusCard),
          border: Border.all(
            color: selected ? accentColor : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
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
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryText,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: selected ? accentColor : secondaryText,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
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

class _RoomFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoomFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = context.watch<AppState>().currentIconColor;
    final textColor = selected ? accentColor : AppUI.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? accentColor.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppUI.radiusPill),
            border: Border.all(
              color: selected
                  ? accentColor.withValues(alpha: 0.55)
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 16, color: accentColor),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyRoomCard extends StatelessWidget {
  final StudyRoomData room;
  final double trackedValue;
  final String trackedValueText;
  final int activeCount;
  final double progress;
  final StudyMemberData? topMember;
  final String topMemberValueText;
  final bool nearFull;
  final List<String> tags;
  final IconData roomTypeIcon;
  final String roomTypeLabel;
  final bool isJoining;
  final VoidCallback onTap;

  const _StudyRoomCard({
    required this.room,
    required this.trackedValue,
    required this.trackedValueText,
    required this.activeCount,
    required this.progress,
    required this.topMember,
    required this.topMemberValueText,
    required this.nearFull,
    required this.tags,
    required this.roomTypeIcon,
    required this.roomTypeLabel,
    this.isJoining = false,
    required this.onTap,
  });

  String _joinModeLabel() {
    switch (room.joinMode) {
      case StudyRoomJoinMode.instant:
        return '立即加入';
      case StudyRoomJoinMode.approval:
        return '審核加入';
    }
  }

  @override
  Widget build(BuildContext context) {
    final approvedCount = room.members
        .where((member) => member.isApproved)
        .length;
    final pendingCount = room.members.length - approvedCount;
    final isFull = approvedCount >= room.memberLimit;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final accent = room.accentColor;

    return Card(
      shape: AppUI.cardShape(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: isJoining ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppUI.innerPadding),
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(roomTypeIcon, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          room.description.isEmpty
                              ? '一起完成今天的$roomTypeLabel目標。'
                              : room.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (isJoining)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    )
                  else
                    Icon(Icons.chevron_right, color: secondaryText),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoomTag(
                    text: roomTypeLabel,
                    bgColor: AppUI.isDark(context)
                        ? accent.withValues(alpha: 0.14)
                        : accent.withValues(alpha: 0.08),
                    textColor: accent,
                  ),
                  _RoomTag(
                    text: room.category,
                    bgColor: AppUI.isDark(context)
                        ? accent.withValues(alpha: 0.14)
                        : accent.withValues(alpha: 0.08),
                    textColor: accent,
                  ),
                  _RoomTag(
                    text: '房主 ${room.ownerName}',
                    bgColor: AppUI.isDark(context)
                        ? const Color(0xFF273041)
                        : const Color(0xFFF3F4F6),
                    textColor: secondaryText,
                  ),
                  _RoomTag(
                    text: '$approvedCount/${room.memberLimit} 人',
                    bgColor: AppUI.isDark(context)
                        ? const Color(0xFF273041)
                        : const Color(0xFFF3F4F6),
                    textColor: secondaryText,
                  ),
                  if (pendingCount > 0)
                    const _RoomTag(
                      text: '有待審',
                      bgColor: Color(0xFFFFEDD5),
                      textColor: Color(0xFFEA580C),
                    ),
                  _RoomTag(
                    text: _joinModeLabel(),
                    bgColor: AppUI.isDark(context)
                        ? const Color(0xFF273041)
                        : const Color(0xFFF3F4F6),
                    textColor: secondaryText,
                  ),
                  if (room.password.isNotEmpty)
                    const _RoomTag(
                      text: '需密碼',
                      bgColor: Color(0xFFEDE9FE),
                      textColor: Color(0xFF7C3AED),
                    ),
                  _RoomTag(
                    text:
                        '每日 ${room.dailyGoalValue % 1 == 0 ? room.dailyGoalValue.toInt() : room.dailyGoalValue} ${room.goalUnitLabel}',
                    bgColor: const Color(0xFFE8F7EC),
                    textColor: const Color(0xFF16A34A),
                  ),
                  if (room.joinQuestionsEnabled)
                    const _RoomTag(
                      text: '有加入問題',
                      bgColor: Color(0xFFFFEDD5),
                      textColor: Color(0xFFEA580C),
                    ),
                  if (room.nicknameRuleEnabled)
                    const _RoomTag(
                      text: '有暱稱規則',
                      bgColor: Color(0xFFEDE9FE),
                      textColor: Color(0xFF7C3AED),
                    ),
                  if (isFull)
                    const _RoomTag(
                      text: '已滿',
                      bgColor: Color(0xFFFEE2E2),
                      textColor: Color(0xFFDC2626),
                    )
                  else if (nearFull)
                    const _RoomTag(
                      text: '快滿房',
                      bgColor: Color(0xFFFFEDD5),
                      textColor: Color(0xFFEA580C),
                    ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags
                      .map(
                        (tag) => _RoomTag(
                          text: '#$tag',
                          bgColor: AppUI.isDark(context)
                              ? accent.withValues(alpha: 0.14)
                              : accent.withValues(alpha: 0.08),
                          textColor: accent,
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _RoomMiniInfo(
                      title: '今日累積',
                      value: trackedValueText,
                      icon: Icons.access_time,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoomMiniInfo(
                      title: '挑戰進度',
                      value: '${(progress * 100).round()}%',
                      icon: Icons.flag_outlined,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppUI.radiusPill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppUI.isDark(context)
                      ? const Color(0xFF2A2F3A)
                      : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              if (topMember != null) ...[
                const SizedBox(height: 12),
                Text(
                  '今日領先：${topMember!.roomNickname.isNotEmpty ? topMember!.roomNickname : topMember!.name}（$topMemberValueText）',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomMiniInfo extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _RoomMiniInfo({
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
                  maxLines: 1,
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

class _RoomTag extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const _RoomTag({
    required this.text,
    required this.bgColor,
    required this.textColor,
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
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
