enum FamilyRole { guardian, child }

enum FamilyLinkStatus { active, ended }

enum FamilyBondEvent { acknowledgement, goalCompleted }

class FamilyConsentScopes {
  const FamilyConsentScopes({
    this.summary = false,
    this.weeklyReport = false,
    this.taskCategories = false,
    this.healthTrends = false,
  });

  final bool summary;
  final bool weeklyReport;
  final bool taskCategories;
  final bool healthTrends;

  FamilyConsentScopes copyWith({
    bool? summary,
    bool? weeklyReport,
    bool? taskCategories,
    bool? healthTrends,
  }) {
    return FamilyConsentScopes(
      summary: summary ?? this.summary,
      weeklyReport: weeklyReport ?? this.weeklyReport,
      taskCategories: taskCategories ?? this.taskCategories,
      healthTrends: healthTrends ?? this.healthTrends,
    );
  }

  factory FamilyConsentScopes.fromMap(Map<String, dynamic>? map) {
    return FamilyConsentScopes(
      summary: map?['summary'] as bool? ?? false,
      weeklyReport: map?['weeklyReport'] as bool? ?? false,
      taskCategories: map?['taskCategories'] as bool? ?? false,
      healthTrends: map?['healthTrends'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'summary': summary,
    'weeklyReport': weeklyReport,
    'taskCategories': taskCategories,
    'healthTrends': healthTrends,
  };
}

class FamilyBondPolicy {
  const FamilyBondPolicy._();

  static int pointsFor(FamilyBondEvent event) {
    return switch (event) {
      FamilyBondEvent.acknowledgement => 3,
      FamilyBondEvent.goalCompleted => 10,
    };
  }

  static int levelForXp(int xp) {
    if (xp >= 30) return 3;
    if (xp >= 10) return 2;
    return 1;
  }
}

class FamilyLinkContract {
  const FamilyLinkContract({
    required this.id,
    required this.guardianId,
    required this.childId,
    required this.participantIds,
    required this.status,
    required this.consent,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String guardianId;
  final String childId;
  final Set<String> participantIds;
  final FamilyLinkStatus status;
  final FamilyConsentScopes consent;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FamilyLinkContract.fromAcceptedRequest({
    required String linkId,
    required String senderId,
    required String senderRole,
    required String receiverId,
    required String receiverRole,
    required DateTime now,
  }) {
    final sender = _parseRole(senderRole);
    final receiver = _parseRole(receiverRole);
    if (sender == receiver) {
      throw ArgumentError('A family link requires one guardian and one child.');
    }

    final guardianId = sender == FamilyRole.guardian ? senderId : receiverId;
    final childId = sender == FamilyRole.child ? senderId : receiverId;
    return FamilyLinkContract(
      id: linkId,
      guardianId: guardianId,
      childId: childId,
      participantIds: {guardianId, childId},
      status: FamilyLinkStatus.active,
      consent: const FamilyConsentScopes(),
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );
  }

  factory FamilyLinkContract.fromMap(String id, Map<String, dynamic> map) {
    return FamilyLinkContract(
      id: id,
      guardianId: map['guardianId'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      participantIds: Set<String>.from(
        (map['participantIds'] as List?) ?? const [],
      ),
      status: map['status'] == 'ended'
          ? FamilyLinkStatus.ended
          : FamilyLinkStatus.active,
      consent: FamilyConsentScopes.fromMap(
        Map<String, dynamic>.from((map['consentScopes'] as Map?) ?? const {}),
      ),
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse(map['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'guardianId': guardianId,
    'childId': childId,
    'participantIds': participantIds.toList()..sort(),
    'status': status.name,
    'consentScopes': consent.toMap(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Map<String, dynamic> buildEncouragementPayload({
    required String guardianId,
    required String childId,
    required String title,
    required String message,
    required DateTime now,
  }) {
    return {
      'schemaVersion': 1,
      'senderId': guardianId,
      'recipientId': childId,
      'title': title.trim(),
      'message': message.trim(),
      'status': 'sent',
      'createdAt': now.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> buildSharedGoalPayload({
    required String guardianId,
    required String childId,
    required String title,
    required String message,
    required DateTime now,
  }) {
    return {
      'schemaVersion': 1,
      'title': title.trim(),
      'message': message.trim(),
      'status': 'proposed',
      'proposedBy': guardianId,
      'decisionBy': childId,
      'createdAt': now.toUtc().toIso8601String(),
      'updatedAt': now.toUtc().toIso8601String(),
    };
  }

  static FamilyRole _parseRole(String value) {
    return switch (value.trim().toLowerCase()) {
      'guardian' => FamilyRole.guardian,
      'child' => FamilyRole.child,
      _ => throw ArgumentError(
        'A family link requires one guardian and one child.',
      ),
    };
  }
}
