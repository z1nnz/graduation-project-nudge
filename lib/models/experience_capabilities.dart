enum ExperienceRole { personal, child, guardian, groupMember, groupManager }

class ExperienceCapabilities {
  const ExperienceCapabilities({
    required this.role,
    required this.isFamilyLinked,
    required this.hasGroup,
  });

  final ExperienceRole role;
  final bool isFamilyLinked;
  final bool hasGroup;

  static const Set<String> _groupRoles = {
    'group',
    'enterprise',
    'tutor',
    'school',
  };

  factory ExperienceCapabilities.resolve({
    required String rawRole,
    required bool isGroupOwner,
    required bool hasGroup,
    required bool isGuardianLinked,
  }) {
    final normalizedRole = rawRole.trim().toLowerCase();
    final ExperienceRole role;

    if (normalizedRole == 'guardian') {
      role = ExperienceRole.guardian;
    } else if (normalizedRole == 'child') {
      role = ExperienceRole.child;
    } else if (_groupRoles.contains(normalizedRole)) {
      role = isGroupOwner
          ? ExperienceRole.groupManager
          : ExperienceRole.groupMember;
    } else {
      role = ExperienceRole.personal;
    }

    return ExperienceCapabilities(
      role: role,
      isFamilyLinked: isGuardianLinked,
      hasGroup: hasGroup,
    );
  }

  bool get isGuardian => role == ExperienceRole.guardian;
  bool get isChild => role == ExperienceRole.child;
  bool get isGroupExperience =>
      role == ExperienceRole.groupMember || role == ExperienceRole.groupManager;

  bool get requiresFamilyBinding => (isGuardian || isChild) && !isFamilyLinked;
  bool get requiresGroupBinding => isGroupExperience && !hasGroup;

  bool get canSendFamilyEncouragement => isGuardian && isFamilyLinked;
  bool get canViewConsentedChildInsights => isGuardian && isFamilyLinked;
  bool get canManageOwnFamilyLink => isChild;
  bool get canManageGroup => role == ExperienceRole.groupManager && hasGroup;
  bool get canParticipateInGroup => isGroupExperience && hasGroup;
  bool get showsPersonalTools =>
      role == ExperienceRole.personal || role == ExperienceRole.child;

  String get homeTitle {
    switch (role) {
      case ExperienceRole.guardian:
        return '家長陪伴端';
      case ExperienceRole.child:
        return '孩子自律端';
      case ExperienceRole.groupManager:
        return '團體管理端';
      case ExperienceRole.groupMember:
        return '團體成員端';
      case ExperienceRole.personal:
        return '個人首頁';
    }
  }

  String get groupSurfaceTitle => canManageGroup ? '團體管理控制台' : '團體任務與共同進度';

  String get groupSurfaceDescription => canManageGroup
      ? '建立挑戰與排程，成員則各自開始、紀錄並完成自己的自律活動。'
      : '查看共同目標與同儕進度；每位成員自行開始、暫停與完成，不需等待管理者。';
}
