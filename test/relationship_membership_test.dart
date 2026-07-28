import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/family_link_contract.dart';
import 'package:nudge/models/group_contract.dart';
import 'package:nudge/models/relationship_membership.dart';

void main() {
  test('one user can hold independent family and group memberships', () {
    final now = DateTime.utc(2026, 7, 28);
    final family = FamilyLinkContract.fromAcceptedRequest(
      linkId: 'family-1',
      senderId: 'guardian-1',
      senderRole: 'guardian',
      receiverId: 'user-1',
      receiverRole: 'child',
      now: now,
    );
    const group = GroupContract(
      id: 'group-1',
      name: '晨光讀書會',
      ownerId: 'user-1',
      memberIds: {'user-1', 'member-2'},
      status: GroupStatus.active,
    );

    final memberships = [
      RelationshipMembership.fromFamilyLink(link: family, userId: 'user-1'),
      RelationshipMembership.fromGroup(group: group, userId: 'user-1'),
    ];

    expect(memberships.map((item) => item.scope).toSet(), {
      RelationshipScope.family,
      RelationshipScope.group,
    });
    expect(memberships[0].role, RelationshipRole.child);
    expect(memberships[1].role, RelationshipRole.manager);
    expect(memberships[0].id, 'family--family-1--user-1');
    expect(memberships[1].id, 'group--group-1--user-1');
    expect(
      memberships[1].toFirestoreMap(now: now),
      containsPair('activeFrom', now.toIso8601String()),
    );
  });

  test('membership rejects a user outside the canonical relationship', () {
    const group = GroupContract(
      id: 'group-1',
      name: '晨光讀書會',
      ownerId: 'manager-1',
      memberIds: {'manager-1'},
      status: GroupStatus.active,
    );

    expect(
      () => RelationshipMembership.fromGroup(group: group, userId: 'stranger'),
      throwsArgumentError,
    );
  });

  test('membership ids reject values that could escape a document path', () {
    expect(
      () => RelationshipMembership.documentId(
        scope: RelationshipScope.group,
        scopeId: 'group/1',
        userId: 'user-1',
      ),
      throwsArgumentError,
    );
  });

  test('ended membership keeps its scoped role and audit actor', () {
    const group = GroupContract(
      id: 'group-1',
      name: '晨光讀書會',
      ownerId: 'manager-1',
      memberIds: {'manager-1', 'member-1'},
      status: GroupStatus.active,
    );
    final ended = RelationshipMembership.fromGroup(
      group: group,
      userId: 'member-1',
    ).copyWith(status: RelationshipMembershipStatus.ended);

    final map = ended.toFirestoreMap(
      now: DateTime.utc(2026, 7, 28),
      endedBy: 'manager-1',
    );

    expect(map['status'], 'ended');
    expect(map['role'], 'member');
    expect(map['endedBy'], 'manager-1');
    expect(map['activeUntil'], '2026-07-28T00:00:00.000Z');
  });
}
