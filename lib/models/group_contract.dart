enum GroupStatus { active, archived }

class GroupContract {
  const GroupContract({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.status,
  });

  final String id;
  final String name;
  final String ownerId;
  final Set<String> memberIds;
  final GroupStatus status;

  factory GroupContract.fromMap(String id, Map<String, dynamic> map) {
    return GroupContract(
      id: id,
      name: map['name'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      memberIds: Set<String>.from(
        (map['memberIds'] as List?) ?? const <String>[],
      ),
      status: map['status'] == 'active'
          ? GroupStatus.active
          : GroupStatus.archived,
    );
  }

  bool isMember(String userId) {
    return status == GroupStatus.active && memberIds.contains(userId);
  }

  bool isManager(String userId) {
    return isMember(userId) && ownerId == userId;
  }
}

class GroupPublicationContract {
  const GroupPublicationContract._();

  static Map<String, dynamic> buildChallenge({
    required GroupContract group,
    required String publisherId,
    required String challengeId,
    required String type,
    required int days,
    required String reward,
    required DateTime now,
  }) {
    _requireManager(group, publisherId);
    final normalizedType = _requireText(type, '挑戰類型');
    final normalizedReward = _requireText(reward, '挑戰獎勵');
    if (days < 1 || days > 365) {
      throw ArgumentError('挑戰天數必須介於 1 到 365 天');
    }
    return {
      'schemaVersion': 2,
      'challengeId': _requireText(challengeId, '挑戰識別碼'),
      'groupId': group.id,
      'groupName': group.name,
      'type': normalizedType,
      'days': days,
      'reward': normalizedReward,
      'status': 'active',
      'publishedBy': publisherId,
      'updatedAt': now.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> buildStudySchedule({
    required GroupContract group,
    required String publisherId,
    required String title,
    required String meta,
    required DateTime now,
  }) {
    _requireManager(group, publisherId);
    return {
      'schemaVersion': 1,
      'groupId': group.id,
      'title': _requireText(title, '時段名稱'),
      'meta': _requireText(meta, '時段說明'),
      'status': 'scheduled',
      'publishedBy': publisherId,
      'createdAt': now.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> buildTemplate({
    required GroupContract group,
    required String publisherId,
    required String type,
    required int days,
    required String effort,
    required String strategy,
    required DateTime now,
  }) {
    _requireManager(group, publisherId);
    if (days < 1 || days > 365) {
      throw ArgumentError('模板天數必須介於 1 到 365 天');
    }
    return {
      'schemaVersion': 1,
      'groupId': group.id,
      'type': _requireText(type, '模板類型'),
      'days': days,
      'effort': _requireText(effort, '核心任務'),
      'strategy': _requireText(strategy, '準備策略'),
      'status': 'active',
      'publishedBy': publisherId,
      'updatedAt': now.toUtc().toIso8601String(),
    };
  }

  static void _requireManager(GroupContract group, String publisherId) {
    if (!group.isManager(publisherId)) {
      throw StateError('只有目前團體的管理者可以發布團體內容');
    }
  }

  static String _requireText(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) throw ArgumentError('$label不可空白');
    return normalized;
  }
}

class GroupChallengeParticipationContract {
  const GroupChallengeParticipationContract._();

  static Map<String, dynamic> buildJoined({
    required GroupContract group,
    required Map<String, dynamic> challenge,
    required String memberId,
    required DateTime now,
  }) {
    _requireCurrentMember(group, memberId);
    final challengeId = _requireActiveChallenge(group, challenge);
    final totalDays = _challengeDays(challenge);
    final timestamp = now.toUtc().toIso8601String();
    return {
      'schemaVersion': 1,
      'groupId': group.id,
      'challengeId': challengeId,
      'memberId': memberId,
      'status': 'joined',
      'completedDays': 0,
      'totalDays': totalDays,
      'joinedAt': timestamp,
      'updatedAt': timestamp,
    };
  }

  static Map<String, dynamic> buildProgress({
    required GroupContract group,
    required Map<String, dynamic> challenge,
    required Map<String, dynamic> existing,
    required String memberId,
    required int completedDays,
    required DateTime now,
  }) {
    _requireCurrentMember(group, memberId);
    final challengeId = _requireActiveChallenge(group, challenge);
    final totalDays = _challengeDays(challenge);
    if (existing['groupId'] != group.id ||
        existing['challengeId'] != challengeId ||
        existing['memberId'] != memberId) {
      throw StateError('挑戰參與紀錄與目前成員或挑戰不一致');
    }
    if (completedDays < 0 || completedDays > totalDays) {
      throw ArgumentError('完成天數必須介於 0 到挑戰總天數');
    }
    if (existing['status'] == 'completed' && completedDays < totalDays) {
      throw StateError('已完成的挑戰不可回退進度');
    }

    final timestamp = now.toUtc().toIso8601String();
    final completed = completedDays == totalDays;
    return {
      'schemaVersion': 1,
      'groupId': group.id,
      'challengeId': challengeId,
      'memberId': memberId,
      'status': completed ? 'completed' : 'joined',
      'completedDays': completedDays,
      'totalDays': totalDays,
      'joinedAt': existing['joinedAt']?.toString() ?? timestamp,
      'updatedAt': timestamp,
      if (completed)
        'completedAt': existing['completedAt']?.toString() ?? timestamp,
    };
  }

  static String _requireActiveChallenge(
    GroupContract group,
    Map<String, dynamic> challenge,
  ) {
    if (challenge['schemaVersion'] != 2 ||
        challenge['groupId'] != group.id ||
        challenge['status'] != 'active') {
      throw StateError('請使用目前團體已發布的新版有效挑戰');
    }
    final challengeId = challenge['challengeId']?.toString().trim() ?? '';
    if (challengeId.isEmpty) {
      throw StateError('挑戰缺少唯一識別碼，請由管理者重新發布');
    }
    return challengeId;
  }

  static int _challengeDays(Map<String, dynamic> challenge) {
    final days = (challenge['days'] as num?)?.toInt() ?? 0;
    if (days < 1 || days > 365) {
      throw ArgumentError('挑戰天數必須介於 1 到 365 天');
    }
    return days;
  }

  static void _requireCurrentMember(GroupContract group, String memberId) {
    if (!group.isMember(memberId)) {
      throw StateError('只有目前團體成員可以參與挑戰');
    }
  }
}

class GroupChallengeTaskPlan {
  const GroupChallengeTaskPlan._();

  static List<Map<String, dynamic>> missingTasks({
    required String challengeId,
    required String groupName,
    required String type,
    required int days,
    required List<Map<String, dynamic>> existingTasks,
    required DateTime now,
    required String userId,
  }) {
    if (challengeId.trim().isEmpty || days < 1 || days > 365) {
      throw ArgumentError('挑戰任務規劃需要有效識別碼與天數');
    }
    final existingIds = existingTasks
        .map((task) => task['id']?.toString())
        .whereType<String>()
        .toSet();
    final timestamp = now.toUtc().toIso8601String();
    final category = _categoryForType(type);
    final tasks = <Map<String, dynamic>>[];
    for (var day = 1; day <= days; day++) {
      final taskId = 'group_challenge_${challengeId}_day_$day';
      if (existingIds.contains(taskId)) continue;
      final suffix = day == 1
          ? '（啟動）'
          : day == days
          ? '（完成衝刺）'
          : '';
      final availableAt = now.toUtc().add(Duration(days: day - 1));
      tasks.add({
        'id': taskId,
        'userId': userId,
        'title': '【$groupName】$type — 第$day天$suffix',
        'done': false,
        'isDone': false,
        'category': category,
        'taskType': 'flexible',
        'dueDate': null,
        'priority': '中',
        'isSystemTask': false,
        'isAutoTracked': false,
        'sourceType': null,
        'targetValue': null,
        'unitLabel': null,
        'sourceId': challengeId,
        'sourceKind': 'groupChallenge',
        'challengeDay': day,
        'availableAt': availableAt.toIso8601String(),
        'createdAt': timestamp,
        'updatedAt': timestamp,
        'completedAt': null,
      });
    }
    return tasks;
  }

  static int completedDays({
    required String challengeId,
    required List<Map<String, dynamic>> tasks,
  }) {
    return tasks.where((task) {
      return task['sourceKind'] == 'groupChallenge' &&
          task['sourceId'] == challengeId &&
          (task['done'] == true || task['isDone'] == true);
    }).length;
  }

  static bool isGroupChallengeTask(Map<String, dynamic> task) =>
      task['sourceKind'] == 'groupChallenge';

  static bool isAvailable(Map<String, dynamic> task, {required DateTime now}) {
    if (!isGroupChallengeTask(task)) return true;
    final availableAt = DateTime.tryParse(
      task['availableAt']?.toString() ?? '',
    );
    return availableAt != null && !now.toUtc().isBefore(availableAt.toUtc());
  }

  static String _categoryForType(String type) {
    if (type.contains('睡')) return '睡眠';
    if (type.contains('步') || type.contains('運動') || type.contains('健身')) {
      return '健康';
    }
    return '學習';
  }
}

class GroupMembershipContract {
  const GroupMembershipContract._();

  static Map<String, dynamic> buildMemberRemoval({
    required GroupContract group,
    required String managerId,
    required String memberId,
    required DateTime now,
  }) {
    _requireManager(group, managerId);
    if (memberId == group.ownerId) {
      throw ArgumentError('團體管理者不可移除自己，請先轉移管理權');
    }
    if (!group.isMember(memberId)) {
      throw ArgumentError('指定使用者不是目前團體成員');
    }
    return {
      'memberIds': group.memberIds.where((id) => id != memberId).toList(),
      'lastMembershipChange': {
        'type': 'member_removed',
        'memberId': memberId,
        'by': managerId,
        'at': now.toUtc().toIso8601String(),
      },
      'updatedAt': now.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> buildOwnershipTransfer({
    required GroupContract group,
    required String managerId,
    required String nextManagerId,
    required DateTime now,
  }) {
    _requireManager(group, managerId);
    if (nextManagerId == managerId) {
      throw ArgumentError('指定成員已經是團體管理者');
    }
    if (!group.isMember(nextManagerId)) {
      throw ArgumentError('管理權只能轉移給目前團體成員');
    }
    return {
      'ownerId': nextManagerId,
      'lastMembershipChange': {
        'type': 'ownership_transferred',
        'fromMemberId': managerId,
        'toMemberId': nextManagerId,
        'by': managerId,
        'at': now.toUtc().toIso8601String(),
      },
      'updatedAt': now.toUtc().toIso8601String(),
    };
  }

  static void _requireManager(GroupContract group, String managerId) {
    if (!group.isManager(managerId)) {
      throw StateError('只有目前團體的管理者可以異動成員資格');
    }
  }
}

class GroupResultSummaryContract {
  const GroupResultSummaryContract({
    required this.memberId,
    required this.displayName,
    required this.disciplineScore,
    required this.completedTasks,
    required this.totalTasks,
    required this.focusMinutes,
    required this.steps,
    required this.sleepHours,
    required this.updatedAt,
  });

  final String memberId;
  final String displayName;
  final int disciplineScore;
  final int completedTasks;
  final int totalTasks;
  final int focusMinutes;
  final int steps;
  final double sleepHours;
  final DateTime? updatedAt;

  double get completionRate =>
      totalTasks <= 0 ? 0 : completedTasks / totalTasks;

  factory GroupResultSummaryContract.fromMap(Map<String, dynamic> map) {
    final summary = Map<String, dynamic>.from(
      map['summary'] as Map? ?? const <String, dynamic>{},
    );
    return GroupResultSummaryContract(
      memberId: map['memberId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '團體成員',
      disciplineScore: (summary['disciplineScore'] as num?)?.toInt() ?? 0,
      completedTasks: (summary['completedTasks'] as num?)?.toInt() ?? 0,
      totalTasks: (summary['totalTasks'] as num?)?.toInt() ?? 0,
      focusMinutes: (summary['focusMinutes'] as num?)?.toInt() ?? 0,
      steps: (summary['steps'] as num?)?.toInt() ?? 0,
      sleepHours: (summary['sleepHours'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  static Map<String, dynamic> buildPayload({
    required GroupContract group,
    required String memberId,
    required String displayName,
    required int disciplineScore,
    required int completedTasks,
    required int totalTasks,
    required int focusMinutes,
    required int steps,
    required double sleepHours,
    required DateTime now,
  }) {
    if (!group.isMember(memberId)) {
      throw StateError('只有目前團體成員可以分享成果摘要');
    }
    if (displayName.trim().isEmpty || displayName.trim().length > 40) {
      throw ArgumentError('團體顯示名稱不可空白且不可超過 40 字');
    }
    if (disciplineScore < 0 ||
        disciplineScore > 100 ||
        completedTasks < 0 ||
        totalTasks < 0 ||
        completedTasks > totalTasks ||
        totalTasks > 10000 ||
        focusMinutes < 0 ||
        focusMinutes > 1440 ||
        steps < 0 ||
        steps > 1000000 ||
        !sleepHours.isFinite ||
        sleepHours < 0 ||
        sleepHours > 24) {
      throw ArgumentError('團體成果摘要包含無效數值');
    }
    return {
      'schemaVersion': 1,
      'groupId': group.id,
      'memberId': memberId,
      'displayName': displayName.trim(),
      'status': 'shared',
      'summary': {
        'disciplineScore': disciplineScore,
        'completedTasks': completedTasks,
        'totalTasks': totalTasks,
        'focusMinutes': focusMinutes,
        'steps': steps,
        'sleepHours': sleepHours,
      },
      'updatedAt': now.toUtc().toIso8601String(),
    };
  }
}
