import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/group_contract.dart';

void main() {
  group('GroupContract', () {
    const group = GroupContract(
      id: 'GRP-TEST',
      name: '自律同行團',
      ownerId: 'manager-1',
      memberIds: {'manager-1', 'member-1'},
      status: GroupStatus.active,
    );

    test('derives manager and member roles from the canonical group', () {
      expect(group.isManager('manager-1'), isTrue);
      expect(group.isMember('manager-1'), isTrue);
      expect(group.isManager('member-1'), isFalse);
      expect(group.isMember('member-1'), isTrue);
      expect(group.isMember('stranger'), isFalse);
    });

    test('builds a canonical challenge publication', () {
      final payload = GroupPublicationContract.buildChallenge(
        group: group,
        publisherId: 'manager-1',
        type: '步數挑戰',
        days: 7,
        reward: '限定徽章',
        now: DateTime.utc(2026, 7, 27),
      );

      expect(payload['groupId'], 'GRP-TEST');
      expect(payload['groupName'], '自律同行團');
      expect(payload['publishedBy'], 'manager-1');
      expect(payload['status'], 'active');
      expect(payload['days'], 7);
    });

    test('rejects publication by a non-manager', () {
      expect(
        () => GroupPublicationContract.buildTemplate(
          group: group,
          publisherId: 'member-1',
          type: '期末考',
          days: 14,
          effort: '複習錯題',
          strategy: '每天自主安排',
          now: DateTime.utc(2026, 7, 27),
        ),
        throwsStateError,
      );
    });

    test('builds atomic member removal and ownership transfer changes', () {
      final removal = GroupMembershipContract.buildMemberRemoval(
        group: group,
        managerId: 'manager-1',
        memberId: 'member-1',
        now: DateTime.utc(2026, 7, 27),
      );
      expect(removal['memberIds'], ['manager-1']);
      expect(
        (removal['lastMembershipChange'] as Map)['type'],
        'member_removed',
      );

      final transfer = GroupMembershipContract.buildOwnershipTransfer(
        group: group,
        managerId: 'manager-1',
        nextManagerId: 'member-1',
        now: DateTime.utc(2026, 7, 27),
      );
      expect(transfer['ownerId'], 'member-1');
      expect(
        (transfer['lastMembershipChange'] as Map)['type'],
        'ownership_transferred',
      );
    });

    test('member controls a validated group result summary', () {
      final payload = GroupResultSummaryContract.buildPayload(
        group: group,
        memberId: 'member-1',
        displayName: '小樹',
        disciplineScore: 82,
        completedTasks: 4,
        totalTasks: 5,
        focusMinutes: 60,
        steps: 8000,
        sleepHours: 7.5,
        now: DateTime.utc(2026, 7, 27),
      );
      final parsed = GroupResultSummaryContract.fromMap(payload);

      expect(payload['status'], 'shared');
      expect(parsed.memberId, 'member-1');
      expect(parsed.completionRate, 0.8);
      expect(parsed.sleepHours, 7.5);
    });

    test('manager cannot publish a result summary for another member', () {
      expect(
        () => GroupResultSummaryContract.buildPayload(
          group: group,
          memberId: 'stranger',
          displayName: '陌生人',
          disciplineScore: 0,
          completedTasks: 0,
          totalTasks: 0,
          focusMinutes: 0,
          steps: 0,
          sleepHours: 0,
          now: DateTime.utc(2026, 7, 27),
        ),
        throwsStateError,
      );
    });
  });
}
