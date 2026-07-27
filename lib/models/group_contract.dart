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
      'schemaVersion': 1,
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
