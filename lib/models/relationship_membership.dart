import 'family_link_contract.dart';
import 'group_contract.dart';

enum RelationshipScope { family, group }

enum RelationshipRole { guardian, child, manager, member }

enum RelationshipMembershipStatus { active, ended }

class RelationshipMembership {
  const RelationshipMembership({
    required this.id,
    required this.scope,
    required this.scopeId,
    required this.scopeName,
    required this.userId,
    required this.role,
    required this.status,
  });

  final String id;
  final RelationshipScope scope;
  final String scopeId;
  final String scopeName;
  final String userId;
  final RelationshipRole role;
  final RelationshipMembershipStatus status;

  bool get isActive => status == RelationshipMembershipStatus.active;
  bool get isManager =>
      role == RelationshipRole.manager || role == RelationshipRole.guardian;

  factory RelationshipMembership.fromMap(
    String documentId,
    Map<String, dynamic> map, {
    String? expectedUserId,
  }) {
    if (map['schemaVersion'] != 1) {
      throw const FormatException(
        'Unsupported relationship membership schema.',
      );
    }
    final scope = switch (map['scopeType']) {
      'family' => RelationshipScope.family,
      'group' => RelationshipScope.group,
      _ => throw const FormatException('Invalid relationship scope.'),
    };
    final role = switch (map['role']) {
      'guardian' => RelationshipRole.guardian,
      'child' => RelationshipRole.child,
      'manager' => RelationshipRole.manager,
      'member' => RelationshipRole.member,
      _ => throw const FormatException('Invalid relationship role.'),
    };
    final status = switch (map['status']) {
      'active' => RelationshipMembershipStatus.active,
      'ended' => RelationshipMembershipStatus.ended,
      _ => throw const FormatException('Invalid relationship status.'),
    };
    final scopeId = map['scopeId'] as String? ?? '';
    final scopeName = map['scopeName'] as String? ?? '';
    final userId = map['userId'] as String? ?? '';
    final membershipId = map['membershipId'] as String? ?? '';
    final expectedDocumentId = RelationshipMembership.documentId(
      scope: scope,
      scopeId: scopeId,
      userId: userId,
    );
    final roleMatchesScope = scope == RelationshipScope.family
        ? role == RelationshipRole.guardian || role == RelationshipRole.child
        : role == RelationshipRole.manager || role == RelationshipRole.member;
    if (scopeName.trim().isEmpty ||
        membershipId != documentId ||
        expectedDocumentId != documentId ||
        (expectedUserId != null && userId != expectedUserId) ||
        !roleMatchesScope) {
      throw const FormatException('Invalid relationship membership identity.');
    }
    return RelationshipMembership(
      id: documentId,
      scope: scope,
      scopeId: scopeId,
      scopeName: scopeName,
      userId: userId,
      role: role,
      status: status,
    );
  }

  RelationshipMembership copyWith({
    RelationshipRole? role,
    RelationshipMembershipStatus? status,
  }) {
    return RelationshipMembership(
      id: id,
      scope: scope,
      scopeId: scopeId,
      scopeName: scopeName,
      userId: userId,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }

  static String documentId({
    required RelationshipScope scope,
    required String scopeId,
    required String userId,
  }) {
    final normalizedScopeId = scopeId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedScopeId.isEmpty ||
        normalizedUserId.isEmpty ||
        normalizedScopeId.contains('/') ||
        normalizedUserId.contains('/')) {
      throw ArgumentError('Membership scope and user ids must be valid.');
    }
    return '${scope.name}--$normalizedScopeId--$normalizedUserId';
  }

  factory RelationshipMembership.fromFamilyLink({
    required FamilyLinkContract link,
    required String userId,
  }) {
    if (!link.participantIds.contains(userId)) {
      throw ArgumentError('User is not a participant in this family link.');
    }
    final role = link.guardianId == userId
        ? RelationshipRole.guardian
        : RelationshipRole.child;
    final shortId = link.id.length <= 8
        ? link.id
        : link.id.substring(link.id.length - 8);
    return RelationshipMembership(
      id: documentId(
        scope: RelationshipScope.family,
        scopeId: link.id,
        userId: userId,
      ),
      scope: RelationshipScope.family,
      scopeId: link.id,
      scopeName: '家庭連結 $shortId',
      userId: userId,
      role: role,
      status: link.status == FamilyLinkStatus.active
          ? RelationshipMembershipStatus.active
          : RelationshipMembershipStatus.ended,
    );
  }

  factory RelationshipMembership.fromGroup({
    required GroupContract group,
    required String userId,
  }) {
    if (!group.memberIds.contains(userId)) {
      throw ArgumentError('User is not a member of this group.');
    }
    return RelationshipMembership(
      id: documentId(
        scope: RelationshipScope.group,
        scopeId: group.id,
        userId: userId,
      ),
      scope: RelationshipScope.group,
      scopeId: group.id,
      scopeName: group.name,
      userId: userId,
      role: group.ownerId == userId
          ? RelationshipRole.manager
          : RelationshipRole.member,
      status: group.status == GroupStatus.active
          ? RelationshipMembershipStatus.active
          : RelationshipMembershipStatus.ended,
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'membershipId': id,
    'scopeType': scope.name,
    'scopeId': scopeId,
    'scopeName': scopeName,
    'userId': userId,
    'role': role.name,
    'status': status.name,
  };

  Map<String, dynamic> toFirestoreMap({
    required DateTime now,
    String? endedBy,
  }) {
    final timestamp = now.toUtc().toIso8601String();
    return {
      ...toMap(),
      'createdAt': timestamp,
      'updatedAt': timestamp,
      if (status == RelationshipMembershipStatus.active)
        'activeFrom': timestamp,
      if (status == RelationshipMembershipStatus.ended) ...{
        'activeUntil': timestamp,
        'endedBy': endedBy ?? userId,
      },
    };
  }
}
