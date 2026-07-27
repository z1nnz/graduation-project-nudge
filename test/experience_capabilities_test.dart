import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/experience_capabilities.dart';

void main() {
  group('ExperienceCapabilities.resolve', () {
    test('keeps guardian and child family responsibilities separate', () {
      final guardian = ExperienceCapabilities.resolve(
        rawRole: 'guardian',
        isGroupOwner: false,
        hasGroup: false,
        isGuardianLinked: true,
      );
      final child = ExperienceCapabilities.resolve(
        rawRole: 'child',
        isGroupOwner: false,
        hasGroup: false,
        isGuardianLinked: true,
      );

      expect(guardian.role, ExperienceRole.guardian);
      expect(guardian.homeTitle, '家長陪伴端');
      expect(guardian.canSendFamilyEncouragement, isTrue);
      expect(guardian.canManageOwnFamilyLink, isFalse);

      expect(child.role, ExperienceRole.child);
      expect(child.homeTitle, '孩子自律端');
      expect(child.canSendFamilyEncouragement, isFalse);
      expect(child.canManageOwnFamilyLink, isTrue);
      expect(child.showsPersonalTools, isTrue);
    });

    test('separates group manager from group member', () {
      final manager = ExperienceCapabilities.resolve(
        rawRole: 'school',
        isGroupOwner: true,
        hasGroup: true,
        isGuardianLinked: false,
      );
      final member = ExperienceCapabilities.resolve(
        rawRole: 'group',
        isGroupOwner: false,
        hasGroup: true,
        isGuardianLinked: false,
      );

      expect(manager.role, ExperienceRole.groupManager);
      expect(manager.homeTitle, '團體管理端');
      expect(manager.groupSurfaceTitle, '團體管理控制台');
      expect(manager.canManageGroup, isTrue);

      expect(member.role, ExperienceRole.groupMember);
      expect(member.homeTitle, '團體成員端');
      expect(member.groupSurfaceTitle, '團體任務與共同進度');
      expect(member.canManageGroup, isFalse);
      expect(member.canParticipateInGroup, isTrue);
    });

    test('recognizes every supported organization role as a group role', () {
      for (final rawRole in ['group', 'enterprise', 'tutor', 'school']) {
        final capabilities = ExperienceCapabilities.resolve(
          rawRole: rawRole,
          isGroupOwner: false,
          hasGroup: false,
          isGuardianLinked: false,
        );

        expect(
          capabilities.isGroupExperience,
          isTrue,
          reason: '$rawRole should use the group experience',
        );
        expect(capabilities.requiresGroupBinding, isTrue);
      }
    });
  });
}
