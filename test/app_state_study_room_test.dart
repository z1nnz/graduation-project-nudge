import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/models/task_model.dart';
import 'package:nudge/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    () {
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

  test('room messages and events are persisted on the room model', () {
    final appState = AppState();

    appState.createStudyRoom(
      name: '測試互動房',
      description: '一起加油',
      accentColor: const Color(0xFF7C6AE6),
    );

    final roomId = appState.studyRooms.first.id;

    appState.addStudyRoomMessage(roomId: roomId, text: '加油');
    appState.addStudyRoomMessage(
      roomId: roomId,
      text: '穩住',
      type: StudyRoomMessageType.sticker,
    );
    appState.addStudyRoomEvent(
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

  test('approval room requests can be accepted or rejected by owner', () {
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

    appState.approveStudyRoomJoinRequest(
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

    appState.rejectStudyRoomJoinRequest(roomId: roomId, memberId: 'friend_hua');

    room = appState.getStudyRoomById(roomId)!;
    expect(room.members.any((m) => m.memberId == 'friend_hua'), isFalse);
    expect(room.events.first.text, contains('加入申請已拒絕'));
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
    final now = DateTime.now();
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
    () {
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

      appState.toggleTask(fixedIndex, true);
      appState.toggleTask(deadlineIndex, true);

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

  test('ready deadline tasks award a one-time bonus coin reward', () {
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

    appState.toggleTask(index, true);
    appState.toggleTask(index, false);
    appState.toggleTask(index, true);

    expect(appState.taskModels[index].isDone, isTrue);
    expect(
      appState.disciplineCoins - beforeCoins,
      AppState.deadlineTaskBonusCoins,
    );
    expect(appState.todayCoinEarned, 0);
  });

  test('deadline task bonus rewards have a monthly cap', () {
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
      appState.toggleTask(i, true);
    }

    expect(
      appState.disciplineCoins - beforeCoins,
      AppState.deadlineTaskMonthlyCoinLimit,
    );
    expect(appState.todayCoinEarned, 0);
    expect(
      appState.currentMonthDeadlineCoinEarned,
      AppState.deadlineTaskMonthlyCoinLimit,
    );
    expect(appState.currentMonthDeadlineCoinRemaining, 0);
  });

  test('badges stay unlocked after the current condition drops', () {
    final appState = AppState();

    appState.addTask('整理書桌', '家事', taskType: 'fixed');
    final taskIndex = appState.taskModels.indexWhere(
      (task) => task.title == '整理書桌',
    );

    appState.toggleTask(taskIndex, true);
    final unlocked = appState.badgeRecords.firstWhere(
      (badge) => badge.badgeKey == 'task_starter',
    );

    appState.toggleTask(taskIndex, false);
    final stillUnlocked = appState.badgeRecords.firstWhere(
      (badge) => badge.badgeKey == 'task_starter',
    );

    expect(unlocked.isUnlocked, isTrue);
    expect(stillUnlocked.isUnlocked, isTrue);
    expect(stillUnlocked.progress, stillUnlocked.target);
  });

  test('daily summary stores weighted score coins and tracked sources', () {
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

    appState.updateHealthData(
      isConnected: true,
      sleepHours: 7.5,
      steps: 0,
      exerciseMinutes: 0,
    );
    appState.toggleTask(1, true);

    final summary = appState.dailySummaries.last;

    expect(summary.disciplineScore, appState.todayWeightedDisciplineScore);
    expect(summary.coinsEarned, AppState.coinDailyLimit);
    expect(summary.autoTrackedCompleted, 1);
    expect(summary.healthCompleted, 1);
    expect(summary.autoTrackedSources, contains('睡眠'));
  });
}
