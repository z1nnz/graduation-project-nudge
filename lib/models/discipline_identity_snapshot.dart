enum DisciplinePersonaKey {
  startingSeed,
  comebackBuilder,
  steadyBuilder,
  balancedRhythm,
  focusSprinter,
  pathfinder,
}

enum DisciplineRecoveryState { starting, gentleReturn, returning, steady }

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected a map.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

DateTime _dateTime(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw const FormatException('Invalid timestamp.');
  return parsed.toUtc();
}

int _integer(Object? value) {
  if (value is! num || !value.isFinite || value.toInt() != value) {
    throw const FormatException('Expected an integer.');
  }
  return value.toInt();
}

class DisciplineIdentitySnapshot {
  const DisciplineIdentitySnapshot({
    required this.userId,
    required this.personaKey,
    required this.personaTitle,
    required this.personaDescription,
    required this.recoveryState,
    required this.recommendedFocusMinutes,
    required this.recoveryMessage,
    required this.activeDays,
    required this.completedSessions,
    required this.focusMinutes,
    required this.exerciseMinutes,
    required this.activityKinds,
    required this.lastActiveDay,
    required this.windowStartedAt,
    required this.windowEndedAt,
    required this.updatedAt,
  });

  final String userId;
  final DisciplinePersonaKey personaKey;
  final String personaTitle;
  final String personaDescription;
  final DisciplineRecoveryState recoveryState;
  final int recommendedFocusMinutes;
  final String recoveryMessage;
  final int activeDays;
  final int completedSessions;
  final int focusMinutes;
  final int exerciseMinutes;
  final List<String> activityKinds;
  final String? lastActiveDay;
  final DateTime windowStartedAt;
  final DateTime windowEndedAt;
  final DateTime updatedAt;

  bool get needsGentleReturn =>
      recoveryState == DisciplineRecoveryState.starting ||
      recoveryState == DisciplineRecoveryState.gentleReturn;

  factory DisciplineIdentitySnapshot.fromMap(
    Map<String, dynamic> map, {
    required String expectedUserId,
  }) {
    final userId = map['userId']?.toString() ?? '';
    final snapshotId = map['snapshotId']?.toString() ?? '';
    if (map['schemaVersion'] != 1 ||
        expectedUserId.trim().isEmpty ||
        userId != expectedUserId ||
        snapshotId != userId ||
        map['visibility'] != 'private') {
      throw const FormatException('Invalid discipline identity ownership.');
    }
    final window = _stringMap(map['window']);
    final persona = _stringMap(map['persona']);
    final recovery = _stringMap(map['recovery']);
    final metrics = _stringMap(map['metrics']);
    final windowDays = _integer(window['days']);
    final windowStartedAt = _dateTime(window['startedAt']);
    final windowEndedAt = _dateTime(window['endedAt']);
    final updatedAt = _dateTime(map['updatedAt']);
    final personaKey = switch (persona['key']) {
      'starting_seed' => DisciplinePersonaKey.startingSeed,
      'comeback_builder' => DisciplinePersonaKey.comebackBuilder,
      'steady_builder' => DisciplinePersonaKey.steadyBuilder,
      'balanced_rhythm' => DisciplinePersonaKey.balancedRhythm,
      'focus_sprinter' => DisciplinePersonaKey.focusSprinter,
      'pathfinder' => DisciplinePersonaKey.pathfinder,
      _ => throw const FormatException('Invalid discipline persona.'),
    };
    final recoveryState = switch (recovery['state']) {
      'starting' => DisciplineRecoveryState.starting,
      'gentle_return' => DisciplineRecoveryState.gentleReturn,
      'returning' => DisciplineRecoveryState.returning,
      'steady' => DisciplineRecoveryState.steady,
      _ => throw const FormatException('Invalid recovery state.'),
    };
    final personaTitle = persona['title']?.toString().trim() ?? '';
    final personaDescription = persona['description']?.toString().trim() ?? '';
    final recommendedFocusMinutes = _integer(
      recovery['recommendedFocusMinutes'],
    );
    final recoveryMessage = recovery['message']?.toString().trim() ?? '';
    final activeDays = _integer(metrics['activeDays']);
    final completedSessions = _integer(metrics['completedSessions']);
    final focusMinutes = _integer(metrics['focusMinutes']);
    final exerciseMinutes = _integer(metrics['exerciseMinutes']);
    final activityKinds = (metrics['activityKinds'] as List?)
        ?.map((value) => value.toString())
        .toList(growable: false);
    final lastActiveDay = metrics['lastActiveDay']?.toString();
    const supportedKinds = {
      'focus',
      'study',
      'exercise',
      'steps',
      'sleep',
      'task',
    };
    final validLastActiveDay =
        lastActiveDay == null ||
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(lastActiveDay);
    if (windowDays != 28 ||
        windowStartedAt.isAfter(windowEndedAt) ||
        updatedAt != windowEndedAt ||
        personaTitle.isEmpty ||
        personaDescription.isEmpty ||
        recommendedFocusMinutes < 1 ||
        recommendedFocusMinutes > 120 ||
        recoveryMessage.isEmpty ||
        activeDays < 0 ||
        activeDays > windowDays ||
        completedSessions < activeDays ||
        focusMinutes < 0 ||
        exerciseMinutes < 0 ||
        activityKinds == null ||
        activityKinds.toSet().length != activityKinds.length ||
        activityKinds.any((kind) => !supportedKinds.contains(kind)) ||
        !validLastActiveDay ||
        (activeDays == 0 && lastActiveDay != null) ||
        (activeDays > 0 && lastActiveDay == null)) {
      throw const FormatException('Invalid discipline identity snapshot.');
    }
    return DisciplineIdentitySnapshot(
      userId: userId,
      personaKey: personaKey,
      personaTitle: personaTitle,
      personaDescription: personaDescription,
      recoveryState: recoveryState,
      recommendedFocusMinutes: recommendedFocusMinutes,
      recoveryMessage: recoveryMessage,
      activeDays: activeDays,
      completedSessions: completedSessions,
      focusMinutes: focusMinutes,
      exerciseMinutes: exerciseMinutes,
      activityKinds: List.unmodifiable(activityKinds),
      lastActiveDay: lastActiveDay,
      windowStartedAt: windowStartedAt,
      windowEndedAt: windowEndedAt,
      updatedAt: updatedAt,
    );
  }
}
