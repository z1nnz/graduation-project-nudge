enum RoomActivityKind { focus, sleep, exercise, steps, custom }

enum RoomActivitySource { app, web, health, device }

enum RoomActivitySessionStatus { active, paused, completed, cancelled }

class RoomActivitySession {
  static const int schemaVersion = 1;

  final String sessionId;
  final String roomId;
  final String actorId;
  final RoomActivityKind activityKind;
  final String metricUnit;
  final double targetValue;
  final double metricValue;
  final RoomActivitySource source;
  final RoomActivitySessionStatus status;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? endedAt;

  const RoomActivitySession({
    required this.sessionId,
    required this.roomId,
    required this.actorId,
    required this.activityKind,
    required this.metricUnit,
    required this.targetValue,
    required this.metricValue,
    required this.source,
    required this.status,
    required this.startedAt,
    required this.updatedAt,
    this.endedAt,
  });

  factory RoomActivitySession.start({
    required String sessionId,
    required String roomId,
    required String actorId,
    required RoomActivityKind activityKind,
    required String metricUnit,
    required double targetValue,
    required RoomActivitySource source,
    required DateTime now,
  }) {
    final safeSessionId = sessionId.trim();
    final safeRoomId = roomId.trim();
    final safeActorId = actorId.trim();
    final safeMetricUnit = metricUnit.trim();
    if (safeSessionId.isEmpty ||
        safeRoomId.isEmpty ||
        safeActorId.isEmpty ||
        safeMetricUnit.isEmpty) {
      throw ArgumentError('Room session identity and metric unit are required');
    }
    if (!targetValue.isFinite || targetValue <= 0) {
      throw ArgumentError.value(targetValue, 'targetValue');
    }
    return RoomActivitySession(
      sessionId: safeSessionId,
      roomId: safeRoomId,
      actorId: safeActorId,
      activityKind: activityKind,
      metricUnit: safeMetricUnit,
      targetValue: targetValue,
      metricValue: 0,
      source: source,
      status: RoomActivitySessionStatus.active,
      startedAt: now.toUtc(),
      updatedAt: now.toUtc(),
    );
  }

  bool get isTerminal =>
      status == RoomActivitySessionStatus.completed ||
      status == RoomActivitySessionStatus.cancelled;

  RoomActivitySession transition({
    required String actorId,
    required RoomActivitySessionStatus nextStatus,
    required double metricValue,
    required DateTime now,
  }) {
    if (actorId != this.actorId) {
      throw StateError('Only the session actor controls its lifecycle');
    }
    if (isTerminal) {
      throw StateError('A terminal room session cannot transition');
    }
    if (!metricValue.isFinite ||
        metricValue < 0 ||
        metricValue < this.metricValue) {
      throw ArgumentError.value(metricValue, 'metricValue');
    }
    final allowed = switch (status) {
      RoomActivitySessionStatus.active => {
        RoomActivitySessionStatus.paused,
        RoomActivitySessionStatus.completed,
        RoomActivitySessionStatus.cancelled,
      },
      RoomActivitySessionStatus.paused => {
        RoomActivitySessionStatus.active,
        RoomActivitySessionStatus.completed,
        RoomActivitySessionStatus.cancelled,
      },
      RoomActivitySessionStatus.completed ||
      RoomActivitySessionStatus.cancelled =>
        const <RoomActivitySessionStatus>{},
    };
    if (!allowed.contains(nextStatus)) {
      throw StateError('Invalid room session transition');
    }
    final changedAt = now.toUtc();
    return RoomActivitySession(
      sessionId: sessionId,
      roomId: roomId,
      actorId: this.actorId,
      activityKind: activityKind,
      metricUnit: metricUnit,
      targetValue: targetValue,
      metricValue: metricValue,
      source: source,
      status: nextStatus,
      startedAt: startedAt,
      updatedAt: changedAt,
      endedAt:
          nextStatus == RoomActivitySessionStatus.completed ||
              nextStatus == RoomActivitySessionStatus.cancelled
          ? changedAt
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'sessionId': sessionId,
    'roomId': roomId,
    'actorId': actorId,
    'activityKind': activityKind.name,
    'metricUnit': metricUnit,
    'targetValue': targetValue,
    'metricValue': metricValue,
    'source': source.name,
    'status': status.name,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
  };

  factory RoomActivitySession.fromJson(Map<String, dynamic> json) {
    RoomActivityKind parseKind(String value) =>
        RoomActivityKind.values.firstWhere((item) => item.name == value);
    RoomActivitySource parseSource(String value) =>
        RoomActivitySource.values.firstWhere((item) => item.name == value);
    RoomActivitySessionStatus parseStatus(String value) =>
        RoomActivitySessionStatus.values.firstWhere(
          (item) => item.name == value,
        );

    return RoomActivitySession(
      sessionId: json['sessionId'] as String,
      roomId: json['roomId'] as String,
      actorId: json['actorId'] as String,
      activityKind: parseKind(json['activityKind'] as String),
      metricUnit: json['metricUnit'] as String,
      targetValue: (json['targetValue'] as num).toDouble(),
      metricValue: (json['metricValue'] as num).toDouble(),
      source: parseSource(json['source'] as String),
      status: parseStatus(json['status'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String).toUtc(),
    );
  }

  factory RoomActivitySession.fromCanonicalLedger(
    Map<String, dynamic> json, {
    required String expectedRoomId,
  }) {
    final roomIds = (json['roomIds'] as List? ?? const <dynamic>[])
        .whereType<String>()
        .toSet();
    if (!roomIds.contains(expectedRoomId)) {
      throw const FormatException(
        'Canonical activity session does not belong to this room.',
      );
    }

    T parseNamed<T extends Enum>(List<T> values, Object? raw, String label) {
      final value = raw?.toString() ?? '';
      try {
        return values.firstWhere((item) => item.name == value);
      } catch (_) {
        throw FormatException('Invalid canonical $label.');
      }
    }

    final targetValue = (json['roomTargetValue'] as num?)?.toDouble();
    if (targetValue == null || !targetValue.isFinite || targetValue <= 0) {
      throw const FormatException(
        'Canonical room target must be a positive number.',
      );
    }
    final canonicalStatus = json['status']?.toString();
    final status = canonicalStatus == 'discarded'
        ? RoomActivitySessionStatus.cancelled
        : parseNamed(
            RoomActivitySessionStatus.values,
            canonicalStatus,
            'room session status',
          );
    final startedAt = DateTime.tryParse(json['startedAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    final endedAt = json['endedAt'] == null
        ? null
        : DateTime.tryParse(json['endedAt'].toString());
    final sessionId = json['activitySessionId']?.toString().trim() ?? '';
    final actorId = json['actorUserId']?.toString().trim() ?? '';
    final metricUnit = json['metricUnit']?.toString().trim() ?? '';
    final metricValue = (json['metricValue'] as num?)?.toDouble();
    if (sessionId.isEmpty ||
        actorId.isEmpty ||
        metricUnit.isEmpty ||
        startedAt == null ||
        updatedAt == null ||
        metricValue == null ||
        !metricValue.isFinite ||
        metricValue < 0 ||
        (endedAt == null) != !status.isTerminal) {
      throw const FormatException(
        'Canonical room activity session is invalid.',
      );
    }

    return RoomActivitySession(
      sessionId: sessionId,
      roomId: expectedRoomId,
      actorId: actorId,
      activityKind: parseNamed(
        RoomActivityKind.values,
        json['activityType'],
        'activity type',
      ),
      metricUnit: metricUnit,
      targetValue: targetValue,
      metricValue: metricValue,
      source: parseNamed(
        RoomActivitySource.values,
        json['source'],
        'activity source',
      ),
      status: status,
      startedAt: startedAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      endedAt: endedAt?.toUtc(),
    );
  }
}

extension on RoomActivitySessionStatus {
  bool get isTerminal =>
      this == RoomActivitySessionStatus.completed ||
      this == RoomActivitySessionStatus.cancelled;
}
