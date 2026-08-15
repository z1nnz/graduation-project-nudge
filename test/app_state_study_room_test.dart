import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_ledger.dart';
import 'package:nudge/models/room_activity_session.dart';
import 'package:nudge/models/health_activity_snapshot.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/models/task_model.dart';
import 'package:nudge/models/user_model.dart';
import 'package:nudge/services/activity_ledger_outbox.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:nudge/services/cloud_health_snapshot_gateway.dart';
import 'package:nudge/services/health_snapshot_outbox.dart';
import 'package:nudge/services/room_activity_session_ledger_gateway.dart';
import 'package:nudge/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RejectingHealthSnapshotOutbox extends HealthSnapshotOutbox {
  _RejectingHealthSnapshotOutbox()
    : super(
        gateway: CloudHealthSnapshotGateway.withCallable(
          (_) async => throw StateError('Cloud should not be called'),
        ),
      );

  @override
  Future<void> enqueueAll(List<HealthActivitySnapshot> snapshots) {
    return Future<void>.error(StateError('outbox unavailable'));
  }
}

class _CloudRejectedHealthSnapshotOutbox extends HealthSnapshotOutbox {
  _CloudRejectedHealthSnapshotOutbox()
    : super(
        gateway: CloudHealthSnapshotGateway.withCallable(
          (_) async => throw StateError('Cloud should not be called'),
        ),
      );

  int enqueued = 0;

  @override
  Future<void> enqueueAll(List<HealthActivitySnapshot> snapshots) async {
    enqueued += snapshots.length;
  }

  @override
  Future<HealthSnapshotFlushReport> flush() async {
    return const HealthSnapshotFlushReport(
      succeeded: [],
      permanentlyRejected: 1,
      retryBlocked: false,
    );
  }
}

ActivityRecordResult acceptedRoomActivity(ActivityEvidence evidence) {
  return ActivityRecordResult(
    status: ActivityRecordStatus.accepted,
    acknowledgedEventId: evidence.eventId,
    acknowledgedSourceRecordId: evidence.sourceRecordId,
    canonicalSessionId: evidence.sessionId,
    receipt: null,
    contributions: const [],
    wasDuplicate: false,
  );
}

class _RejectingRoomActivitySessionLedgerGateway
    implements RoomActivitySessionLedgerGateway {
  int recordAttempts = 0;

  @override
  Future<ActivityRecordResult> record({
    required ActivityEvidence evidence,
    required RoomActivitySession session,
  }) {
    recordAttempts++;
    return Future<ActivityRecordResult>.error(
      StateError('Cloud room command unavailable'),
    );
  }
}

class _RejectingSecondRoomActivitySessionLedgerGateway
    implements RoomActivitySessionLedgerGateway {
  int recordAttempts = 0;

  @override
  Future<ActivityRecordResult> record({
    required ActivityEvidence evidence,
    required RoomActivitySession session,
  }) async {
    recordAttempts++;
    if (recordAttempts == 2) {
      throw StateError('Cloud room transition unavailable');
    }
    return acceptedRoomActivity(evidence);
  }
}

StudyRoomData signedInRoomFixture(UserModel user) {
  return StudyRoomData(
    id: 'room-ledger-first',
    name: 'Ledger-first 房間',
    description: '先保存活動證據',
    accentColor: const Color(0xFF7C6AE6),
    ownerId: user.id,
    ownerName: user.nickname,
    roomType: StudyRoomType.study,
    goalSourceType: TaskSourceType.focusMinutes,
    dailyGoalValue: 25,
    goalUnitLabel: '分鐘',
    members: [
      StudyMemberData(
        memberId: user.id,
        name: user.nickname,
        roomNickname: user.nickname,
        status: StudyMemberStatus.offline,
        sessionSeconds: 0,
        todayFocusSeconds: 0,
        avatarColor: const Color(0xFF7C6AE6),
        role: 'owner',
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('study room start updates local user as active and adds focus time', () {
    final appState = AppState();

    appState.createStudyRoom(
      name: '測試讀書房',
      description: '一起讀書',
      accentColor: const Color(0xFF7C6AE6),
      roomType: StudyRoomType.study,
      goalSourceType: TaskSourceType.studyRoom,
      dailyGoalValue: 2,
      goalUnitLabel: '小時',
    );

    final roomId = appState.studyRooms.first.id;

    appState.updateMyStudyRoomPresence(
      roomId: roomId,
      status: StudyMemberStatus.studying,
      sessionSeconds: 25 * 60,
    );

    final updatedRoom = appState.getStudyRoomById(roomId)!;
    final me = updatedRoom.members.firstWhere(
      (member) => member.memberId == 'local_user',
    );

    expect(me.status, StudyMemberStatus.studying);
    expect(me.todayFocusSeconds, 25 * 60);
    expect(me.todayMetricValue, closeTo(25 / 60, 0.001));
  });

  test(
    'sleep room start marks local user as active without requiring focus',
    () async {
      final appState = AppState();

      appState.createStudyRoom(
        name: '測試睡眠房',
        description: '一起早睡',
        accentColor: const Color(0xFF7C6AE6),
        roomType: StudyRoomType.sleep,
        goalSourceType: TaskSourceType.sleepHours,
        dailyGoalValue: 7,
        goalUnitLabel: '小時',
      );

      final roomId = appState.studyRooms.first.id;

      appState.updateMyStudyRoomPresence(
        roomId: roomId,
        status: StudyMemberStatus.studying,
        sessionSeconds: 0,
      );

      final updatedRoom = appState.getStudyRoomById(roomId)!;
      final me = updatedRoom.members.firstWhere(
        (member) => member.memberId == 'local_user',
      );

      expect(me.status, StudyMemberStatus.studying);
    },
  );

  test('member controls their own room activity lifecycle', () async {
    final appState = AppState();

    appState.createStudyRoom(
      name: '自主活動房',
      description: '每位成員控制自己的紀錄',
      accentColor: const Color(0xFF7C6AE6),
      roomType: StudyRoomType.study,
      goalSourceType: TaskSourceType.focusMinutes,
      dailyGoalValue: 60,
      goalUnitLabel: '分鐘',
    );

    final roomId = appState.studyRooms.first.id;
    final started = await appState.startRoomActivitySession(
      roomId: roomId,
      targetValue: 25,
    );
    expect(started.actorId, 'local_user');
    expect(started.status, RoomActivitySessionStatus.active);

    final paused = await appState.transitionRoomActivitySession(
      roomId: roomId,
      sessionId: started.sessionId,
      status: RoomActivitySessionStatus.paused,
      metricValue: 10,
    );
    expect(paused.status, RoomActivitySessionStatus.paused);

    final resumed = await appState.transitionRoomActivitySession(
      roomId: roomId,
      sessionId: started.sessionId,
      status: RoomActivitySessionStatus.active,
      metricValue: 10,
    );
    expect(resumed.status, RoomActivitySessionStatus.active);

    final completed = await appState.transitionRoomActivitySession(
      roomId: roomId,
      sessionId: started.sessionId,
      status: RoomActivitySessionStatus.completed,
      metricValue: 25,
    );
    expect(completed.status, RoomActivitySessionStatus.completed);
    expect(appState.activeRoomActivitySession(roomId), isNull);
  });

  test('study room hours become a minute-based Ledger target', () async {
    final appState = AppState();
    appState.createStudyRoom(
      name: '兩小時共學房',
      description: '跨端使用相同分鐘目標',
      accentColor: const Color(0xFF7C6AE6),
      roomType: StudyRoomType.study,
      goalSourceType: TaskSourceType.studyRoom,
      dailyGoalValue: 2,
      goalUnitLabel: '小時',
    );

    final session = await appState.startRoomActivitySession(
      roomId: appState.studyRooms.first.id,
    );

    expect(session.metricUnit, 'minutes');
    expect(session.targetValue, 120);
  });

  test(
    'signed-in room start does not project before Cloud Ledger acceptance',
    () async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'room-user-1',
        username: 'room-user-1',
        nickname: '房間測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      const roomId = 'room-ledger-first';
      final room = signedInRoomFixture(user);
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
        'study_rooms_setting': jsonEncode([room.toJson()]),
      });
      final gateway = _RejectingRoomActivitySessionLedgerGateway();
      final appState = AppState(roomActivitySessionLedgerGateway: gateway);
      await appState.loadAllLocalData();

      await expectLater(
        appState.startRoomActivitySession(roomId: roomId),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Cloud room command unavailable',
          ),
        ),
      );

      expect(gateway.recordAttempts, 1);
      expect(appState.activeRoomActivitySession(roomId), isNull);
      expect(appState.roomActivitySessions, isEmpty);
    },
  );

  test(
    'room transition keeps prior state when Cloud Ledger command fails',
    () async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'room-user-2',
        username: 'room-user-2',
        nickname: '房間轉換測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      final room = signedInRoomFixture(user);
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
        'study_rooms_setting': jsonEncode([room.toJson()]),
      });
      final gateway = _RejectingSecondRoomActivitySessionLedgerGateway();
      final appState = AppState(roomActivitySessionLedgerGateway: gateway);
      await appState.loadAllLocalData();
      final started = await appState.startRoomActivitySession(roomId: room.id);

      await expectLater(
        appState.transitionRoomActivitySession(
          roomId: room.id,
          sessionId: started.sessionId,
          status: RoomActivitySessionStatus.paused,
          metricValue: 10,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Cloud room transition unavailable',
          ),
        ),
      );

      expect(gateway.recordAttempts, 2);
      expect(
        appState.activeRoomActivitySession(room.id)?.status,
        RoomActivitySessionStatus.active,
      );
      expect(appState.roomActivitySessions.single.metricValue, 0);
    },
  );

  test('health progress becomes a member-owned room activity', () async {
    final appState = AppState();
    appState.createStudyRoom(
      name: '睡眠同行房',
      description: '同步自己的睡眠進度',
      accentColor: const Color(0xFF2563EB),
      roomType: StudyRoomType.sleep,
      goalSourceType: TaskSourceType.sleepHours,
      dailyGoalValue: 7,
      goalUnitLabel: '小時',
    );

    final roomId = appState.studyRooms.first.id;
    final started = await appState.startRoomActivitySession(
      roomId: roomId,
      source: RoomActivitySource.health,
    );
    final completed = await appState.transitionRoomActivitySession(
      roomId: roomId,
      sessionId: started.sessionId,
      status: RoomActivitySessionStatus.completed,
      metricValue: 7.2,
    );

    expect(completed.activityKind, RoomActivityKind.sleep);
    expect(completed.source, RoomActivitySource.health);
    expect(completed.metricUnit, 'hours');
    expect(completed.metricValue, 7.2);
  });

  test('room messages and events are persisted on the room model', () async {
    final appState = AppState();

    appState.createStudyRoom(
      name: '測試互動房',
      description: '一起加油',
      accentColor: const Color(0xFF7C6AE6),
    );

    final roomId = appState.studyRooms.first.id;

    await appState.addStudyRoomMessage(roomId: roomId, text: '加油');
    await appState.addStudyRoomMessage(
      roomId: roomId,
      text: '穩住',
      type: StudyRoomMessageType.sticker,
    );
    await appState.addStudyRoomEvent(
      roomId: roomId,
      text: '老闆 開始專注',
      type: StudyRoomEventType.start,
    );

    final room = appState.getStudyRoomById(roomId)!;

    expect(room.messages, hasLength(2));
    expect(room.messages.first.type, StudyRoomMessageType.sticker);
    expect(room.events.first.type, StudyRoomEventType.start);
  });

  test('owner leaving an empty room closes that room', () {
    final appState = AppState();

    appState.createStudyRoom(
      name: '測試退出房',
      description: '只剩房主',
      accentColor: const Color(0xFF7C6AE6),
    );

    final roomId = appState.studyRooms.first.id;

    appState.leaveStudyRoom(roomId);

    expect(appState.getStudyRoomById(roomId), isNull);
  });

  test('creating a study room creates a linked task goal', () {
    final appState = AppState();

    appState.createStudyRoom(
      name: '測試任務同步房',
      description: '一起同步任務',
      accentColor: const Color(0xFF7C6AE6),
      roomType: StudyRoomType.study,
      goalSourceType: TaskSourceType.studyRoom,
      dailyGoalValue: 2,
      goalUnitLabel: '小時',
    );

    final room = appState.studyRooms.first;
    final linkedTasks = appState.taskModels
        .where((task) => task.sourceId == room.id)
        .toList();

    expect(linkedTasks, hasLength(1));
    expect(linkedTasks.first.title, '完成「測試任務同步房」今日目標');
    expect(linkedTasks.first.category, '自律房');
    expect(linkedTasks.first.sourceType, TaskSourceType.studyRoom);
    expect(linkedTasks.first.targetValue, 120);
    expect(linkedTasks.first.unitLabel, '分鐘');
  });

  test(
    'deleting a linked room task only disables sync and keeps room joined',
    () {
      final appState = AppState();

      appState.createStudyRoom(
        name: '測試取消同步房',
        description: '任務刪除不退房',
        accentColor: const Color(0xFF7C6AE6),
      );

      final roomId = appState.studyRooms.first.id;
      final taskIndex = appState.taskModels.indexWhere(
        (task) => task.sourceId == roomId,
      );

      appState.deleteTask(taskIndex);

      expect(appState.getStudyRoomById(roomId), isNotNull);
      expect(appState.getStudyRoomById(roomId)!.syncTaskEnabled, isFalse);
      expect(
        appState.taskModels.where((task) => task.sourceId == roomId),
        isEmpty,
      );
    },
  );

  test('approval room requests can be accepted or rejected by owner', () async {
    final appState = AppState();

    appState.createStudyRoom(
      name: '審核讀書房',
      description: '需要房主審核',
      accentColor: const Color(0xFF7C6AE6),
      joinMode: StudyRoomJoinMode.approval,
    );

    final roomId = appState.studyRooms.first.id;

    appState.inviteMemberToRoom(
      roomId: roomId,
      memberName: '小明',
      memberId: 'friend_ming',
      avatarColor: const Color(0xFF4F8CFF),
      isApproved: false,
      joinAnswer: '我想一起準備考試',
    );

    var room = appState.getStudyRoomById(roomId)!;
    var applicant = room.members.firstWhere((m) => m.memberId == 'friend_ming');
    expect(applicant.isApproved, isFalse);

    await appState.approveStudyRoomJoinRequest(
      roomId: roomId,
      memberId: 'friend_ming',
    );

    room = appState.getStudyRoomById(roomId)!;
    applicant = room.members.firstWhere((m) => m.memberId == 'friend_ming');
    expect(applicant.isApproved, isTrue);
    expect(room.events.first.text, contains('加入申請已通過'));

    appState.inviteMemberToRoom(
      roomId: roomId,
      memberName: '小華',
      memberId: 'friend_hua',
      avatarColor: const Color(0xFF10B981),
      isApproved: false,
      joinAnswer: '想加入早讀',
    );

    await appState.rejectStudyRoomJoinRequest(
      roomId: roomId,
      memberId: 'friend_hua',
    );

    room = appState.getStudyRoomById(roomId)!;
    expect(room.members.any((m) => m.memberId == 'friend_hua'), isFalse);
    expect(room.events.first.text, contains('加入申請已拒絕'));
  });

  test('room owner explicitly transfers ownership before leaving', () async {
    final appState = AppState();
    appState.createStudyRoom(
      name: '房主移交測試房',
      description: '房主不能被隨機轉移',
      accentColor: const Color(0xFF7C6AE6),
    );
    final roomId = appState.studyRooms.first.id;
    appState.inviteMemberToRoom(
      roomId: roomId,
      memberName: '小明',
      memberId: 'friend_ming',
      avatarColor: const Color(0xFF2563EB),
    );

    await appState.transferStudyRoomOwnership(
      roomId: roomId,
      newOwnerId: 'friend_ming',
    );

    final room = appState.getStudyRoomById(roomId)!;
    expect(room.ownerId, 'friend_ming');
    expect(
      room.members
          .firstWhere((member) => member.memberId == 'friend_ming')
          .role,
      'owner',
    );
    expect(
      room.members.firstWhere((member) => member.memberId == 'local_user').role,
      'member',
    );
  });

  test('leaving a room removes its linked task goal', () {
    final appState = AppState();

    appState.createStudyRoom(
      name: '測試退房任務移除',
      description: '退房時任務也移除',
      accentColor: const Color(0xFF7C6AE6),
    );

    final roomId = appState.studyRooms.first.id;

    appState.leaveStudyRoom(roomId);

    expect(appState.getStudyRoomById(roomId), isNull);
    expect(
      appState.taskModels.where((task) => task.sourceId == roomId),
      isEmpty,
    );
  });

  test('coin rewards use fixed score milestones with a daily cap', () {
    expect(AppState.coinDailyLimit, 15);
    expect(AppState.coinWeeklyLimit, 100);
    expect(AppState.coinMonthlyLimit, 400);
    expect(AppState.deadlineTaskMonthlyCoinLimit, 15);
    expect(AppState.scoreCoinMilestones, {20: 3, 40: 3, 60: 3, 80: 3, 100: 3});
  });

  test('score coin rewards respect weekly and monthly caps', () async {
    // AppState rolls its logical day over at 05:00, not at midnight.
    final now = DateTime.now().subtract(const Duration(hours: 5));
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final dailyEarned = <String, int>{};

    String keyFor(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    dailyEarned[keyFor(today)] = 10;
    dailyEarned[keyFor(weekStart)] =
        (dailyEarned[keyFor(weekStart)] ?? 0) + AppState.coinWeeklyLimit - 10;

    SharedPreferences.setMockInitialValues({
      'discipline_coins_setting': AppState.coinWeeklyLimit,
      'daily_coin_earned_setting': jsonEncode(dailyEarned),
      'last_daily_reset_date': keyFor(today),
      // Keep this cap test independent from default completed-task rewards
      // that loadAllLocalData synchronizes during hydration.
      'tasks': jsonEncode([]),
      'rewarded_task_keys_setting': AppState.scoreCoinMilestones.keys
          .map((threshold) => '${keyFor(today)}|score:$threshold')
          .toList(),
    });

    final appState = AppState();
    await appState.loadAllLocalData();

    final todayEarned = dailyEarned[keyFor(today)] ?? 0;
    expect(
      appState.todayCoinRemaining,
      (AppState.coinDailyLimit - todayEarned).clamp(0, AppState.coinDailyLimit),
    );
    expect(appState.currentWeekCoinRemaining, 0);
    expect(appState.scoreCoinRemaining, 0);
    expect(appState.nextScoreCoinMilestone, isNull);
  });

  test(
    'future deadline tasks do not affect weighted score or allow completion',
    () async {
      final appState = AppState();
      final future = DateTime.now().add(
        const Duration(days: AppState.deadlineTaskMinLeadDays),
      );
      final futureDate =
          '${future.year.toString().padLeft(4, '0')}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';

      appState.addTask('整理房間', '自定義', taskType: 'fixed');
      appState.addTask(
        '完成期末報告',
        '讀書',
        taskType: 'deadline',
        dueDate: futureDate,
        priority: '高',
      );

      final fixedIndex = appState.taskModels.indexWhere(
        (task) => task.title == '整理房間',
      );
      final deadlineIndex = appState.taskModels.indexWhere(
        (task) => task.title == '完成期末報告',
      );

      await appState.toggleTask(fixedIndex, true);
      await appState.toggleTask(deadlineIndex, true);

      final deadlineTask = appState.taskModels[deadlineIndex];
      expect(appState.todayWeightedDisciplineScore, 100);
      expect(appState.todayActionableTaskCompleted, 1);
      expect(appState.todayActionableTaskTotal, 1);
      expect(
        appState.todayActionableTaskModels.any(
          (task) => task.title == '完成期末報告',
        ),
        isFalse,
      );
      expect(deadlineTask.isDone, isFalse);
      expect(appState.taskPotentialScoreForTask(deadlineTask), 0);
    },
  );

  test('task completion does not mint coins or avatar XP before Cloud', () async {
    final appState = AppState();
    final now = DateTime.now();
    final todayDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    appState.addTask(
      '交出期末報告',
      '讀書',
      taskType: 'deadline',
      dueDate: todayDate,
      priority: '高',
    );

    final index = appState.taskModels.indexWhere(
      (task) => task.title == '交出期末報告',
    );
    final beforeCoins = appState.disciplineCoins;
    final beforeExperience = appState.avatarExperience;

    await appState.toggleTask(index, true);
    await appState.toggleTask(index, false);
    await appState.toggleTask(index, true);

    expect(appState.taskModels[index].isDone, isTrue);
    expect(appState.disciplineCoins - beforeCoins, 0);
    expect(appState.avatarExperience - beforeExperience, 0);
    expect(appState.todayCoinEarned, 0);
  });

  test(
    'task mutation re-resolves its identity after durable enqueue',
    () async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'user-1',
        username: 'user-1',
        nickname: '測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
      });
      final outbox = ActivityLedgerOutbox(
        gateway: CloudActivityLedgerGateway.withCallable(
          (_) async => {'status': 'settled'},
        ),
      );
      final appState = AppState(activityLedgerOutbox: outbox);
      await appState.loadAllLocalData();
      appState.addTask('任務 A', '讀書', taskType: 'fixed');
      appState.addTask('任務 B', '讀書', taskType: 'fixed');
      final firstIndex = appState.taskModels.indexWhere(
        (task) => task.title == '任務 A',
      );

      final mutation = appState.toggleTask(firstIndex, true);
      appState.deleteTask(firstIndex);
      final changed = await mutation;

      expect(changed, isFalse);
      expect(await outbox.pendingCount(), 0);
      expect(
        appState.taskModels.singleWhere((task) => task.title == '任務 B').isDone,
        isFalse,
      );
    },
  );

  test('repeated deadline tasks cannot mutate client reward counters', () async {
    final appState = AppState();
    final now = DateTime.now();
    final todayDate =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (var i = 0; i < 5; i++) {
      appState.addTask(
        '截止任務 $i',
        '讀書',
        taskType: 'deadline',
        dueDate: todayDate,
        priority: '高',
      );
    }

    final beforeCoins = appState.disciplineCoins;
    final deadlineIndexes = appState.taskModels.asMap().entries.where(
      (entry) => entry.value.title.startsWith('截止任務 '),
    );
    for (final entry in deadlineIndexes) {
      final i = entry.key;
      await appState.toggleTask(i, true);
    }

    expect(appState.disciplineCoins - beforeCoins, 0);
    expect(appState.todayCoinEarned, 0);
    expect(appState.currentMonthDeadlineCoinEarned, 0);
    expect(
      appState.currentMonthDeadlineCoinRemaining,
      AppState.deadlineTaskMonthlyCoinLimit,
    );
  });

  test('badges stay unlocked after the current condition drops', () async {
    final appState = AppState();

    appState.addTask('整理書桌', '家事', taskType: 'fixed');
    final taskIndex = appState.taskModels.indexWhere(
      (task) => task.title == '整理書桌',
    );

    await appState.toggleTask(taskIndex, true);
    final unlocked = appState.badgeRecords.firstWhere(
      (badge) => badge.badgeKey == 'task_starter',
    );

    await appState.toggleTask(taskIndex, false);
    final stillUnlocked = appState.badgeRecords.firstWhere(
      (badge) => badge.badgeKey == 'task_starter',
    );

    expect(unlocked.isUnlocked, isTrue);
    expect(stillUnlocked.isUnlocked, isTrue);
    expect(stillUnlocked.progress, stillUnlocked.target);
  });

  test(
    'daily summary stores weighted score coins and tracked sources',
    () async {
      final appState = AppState();

      appState.addTask(
        '睡眠 7 小時',
        '健康',
        taskType: 'fixed',
        priority: '高',
        isAutoTracked: true,
        sourceType: TaskSourceType.sleepHours,
        targetValue: 7,
        unitLabel: '小時',
      );
      appState.addTask('整理房間', '自定義', taskType: 'fixed');

      await appState.updateHealthData(
        isConnected: true,
        sleepHours: 7.5,
        steps: 0,
        exerciseMinutes: 0,
      );
      await appState.toggleTask(1, true);

      final summary = appState.dailySummaries.last;

      expect(summary.disciplineScore, appState.todayWeightedDisciplineScore);
      expect(summary.coinsEarned, 0);
      expect(summary.autoTrackedCompleted, 1);
      expect(summary.healthCompleted, 1);
      expect(summary.autoTrackedSources, contains('睡眠'));
    },
  );

  test(
    'health projection stays unchanged when durable Ledger enqueue fails',
    () async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'health-user-1',
        username: 'health-user-1',
        nickname: '健康測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
      });
      final appState = AppState(
        healthSnapshotOutbox: _RejectingHealthSnapshotOutbox(),
      );
      await appState.loadAllLocalData();
      appState.addTask(
        '睡眠 7 小時',
        '健康',
        taskType: 'fixed',
        isAutoTracked: true,
        sourceType: TaskSourceType.sleepHours,
        targetValue: 7,
        unitLabel: '小時',
      );
      final taskIndex = appState.taskModels.indexWhere(
        (task) => task.title == '睡眠 7 小時',
      );
      final snapshot = HealthActivitySnapshot(
        provider: HealthSnapshotProvider.appleHealth,
        activityType: ActivityType.sleep,
        metricValue: 7.5,
        metricUnit: 'hours',
        localDate: '2026-08-02',
        periodStart: DateTime.utc(2026, 8, 1, 16),
        periodEnd: DateTime.utc(2026, 8, 2, 0),
        observedAt: DateTime.utc(2026, 8, 2, 0),
        dataOrigins: const ['com.apple.health'],
      );

      final accepted = await appState.updateHealthData(
        isConnected: true,
        sleepHours: 7.5,
        steps: 0,
        exerciseMinutes: 0,
        snapshots: [snapshot],
      );

      expect(accepted, isFalse);
      expect(appState.isHealthConnected, isFalse);
      expect(appState.sleepHours, 0);
      expect(appState.taskModels[taskIndex].isDone, isFalse);
    },
  );

  test(
    'health projection stays unchanged when Cloud rejects Ledger ingestion',
    () async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'health-user-cloud-rejected',
        username: 'health-user-cloud-rejected',
        nickname: '健康拒絕測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
      });
      final outbox = _CloudRejectedHealthSnapshotOutbox();
      final appState = AppState(healthSnapshotOutbox: outbox);
      await appState.loadAllLocalData();
      final snapshot = HealthActivitySnapshot(
        provider: HealthSnapshotProvider.appleHealth,
        activityType: ActivityType.sleep,
        metricValue: 7.5,
        metricUnit: 'hours',
        localDate: '2026-08-02',
        periodStart: DateTime.utc(2026, 8, 1, 16),
        periodEnd: DateTime.utc(2026, 8, 2, 0),
        observedAt: DateTime.utc(2026, 8, 2, 0),
        dataOrigins: const ['com.apple.health'],
      );

      final accepted = await appState.updateHealthData(
        isConnected: true,
        sleepHours: 7.5,
        steps: 0,
        exerciseMinutes: 0,
        snapshots: [snapshot],
      );

      expect(outbox.enqueued, 1);
      expect(accepted, isFalse);
      expect(appState.isHealthConnected, isFalse);
      expect(appState.sleepHours, 0);
    },
  );

  test(
    'signed-in health metrics require snapshots before projection',
    () async {
      final now = DateTime.now();
      final user = UserModel(
        id: 'health-user-missing-snapshot',
        username: 'health-user-missing-snapshot',
        nickname: '健康缺資料測試者',
        signature: '',
        createdAt: now,
        updatedAt: now,
      );
      SharedPreferences.setMockInitialValues({
        'current_user_setting': jsonEncode(user.toJson()),
      });
      final appState = AppState();
      await appState.loadAllLocalData();

      final accepted = await appState.updateHealthData(
        isConnected: true,
        sleepHours: 7.5,
        steps: 0,
        exerciseMinutes: 0,
      );

      expect(accepted, isFalse);
      expect(appState.isHealthConnected, isFalse);
      expect(appState.sleepHours, 0);
    },
  );
}
