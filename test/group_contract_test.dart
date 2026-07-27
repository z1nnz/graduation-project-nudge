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
  });
}
