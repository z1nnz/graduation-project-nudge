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
