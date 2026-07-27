enum ExperienceRole { personal, child, guardian, groupMember, groupManager }

class ExperienceCapabilities {
  const ExperienceCapabilities({
    required this.role,
    required this.isFamilyLinked,
    required this.hasGroup,
    required this.isGuardian,
    required this.isChild,
    required this.isGroupOwner,
    required this.hasDeclaredFamilyRole,
    required this.hasDeclaredGroupRole,
  });

  final ExperienceRole role;
  final bool isFamilyLinked;
  final bool hasGroup;
  final bool isGuardian;
  final bool isChild;
  final bool isGroupOwner;
  final bool hasDeclaredFamilyRole;
  final bool hasDeclaredGroupRole;

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
    bool isFamilyGuardian = false,
    bool isFamilyChild = false,
  }) {
    final normalizedRole = rawRole.trim().toLowerCase();
    final hasDeclaredFamilyRole =
        normalizedRole == 'guardian' || normalizedRole == 'child';
    final hasDeclaredGroupRole = _groupRoles.contains(normalizedRole);
    final hasCanonicalFamilyRole =
        isGuardianLinked && (isFamilyGuardian || isFamilyChild);
    final effectiveGuardian = hasCanonicalFamilyRole
        ? isFamilyGuardian
        : normalizedRole == 'guardian';
    final effectiveChild = hasCanonicalFamilyRole
        ? isFamilyChild
        : normalizedRole == 'child';
    final ExperienceRole role;

    if (effectiveGuardian) {
      role = ExperienceRole.guardian;
    } else if (effectiveChild) {
      role = ExperienceRole.child;
    } else if (hasGroup || hasDeclaredGroupRole) {
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
      isGuardian: effectiveGuardian,
      isChild: effectiveChild,
      isGroupOwner: hasGroup && isGroupOwner,
      hasDeclaredFamilyRole: hasDeclaredFamilyRole,
      hasDeclaredGroupRole: hasDeclaredGroupRole,
    );
  }

  bool get isGroupExperience => hasGroup || hasDeclaredGroupRole;

  bool get requiresFamilyBinding => hasDeclaredFamilyRole && !isFamilyLinked;
  bool get requiresGroupBinding => hasDeclaredGroupRole && !hasGroup;

  bool get canSendFamilyEncouragement => isGuardian && isFamilyLinked;
  bool get canViewConsentedChildInsights => isGuardian && isFamilyLinked;
  bool get canManageOwnFamilyLink => isChild && isFamilyLinked;
  bool get canManageGroup => isGroupOwner;
  bool get canParticipateInGroup => hasGroup;
  bool get showsPersonalTools => !isGuardian;

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
