enum RoomResonanceCue {
  gentleRestart,
  openToCompany,
  startingSmall,
  completedStep,
}

enum RoomResonanceResponse { withYou, cheer, takeYourTime }

enum RoomResonanceStatus { active, withdrawn }

Map<String, dynamic> _resonanceMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected a map.');
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredResonanceString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  if (normalized.isEmpty) throw const FormatException('Expected a string.');
  return normalized;
}

DateTime _resonanceDate(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw const FormatException('Invalid timestamp.');
  return parsed.toUtc();
}

RoomResonanceCue _cue(Object? value) => switch (value) {
  'gentle_restart' => RoomResonanceCue.gentleRestart,
  'open_to_company' => RoomResonanceCue.openToCompany,
  'starting_small' => RoomResonanceCue.startingSmall,
  'completed_step' => RoomResonanceCue.completedStep,
  _ => throw const FormatException('Invalid resonance cue.'),
};

RoomResonanceResponse _response(Object? value) => switch (value) {
  'with_you' => RoomResonanceResponse.withYou,
  'cheer' => RoomResonanceResponse.cheer,
  'take_your_time' => RoomResonanceResponse.takeYourTime,
  _ => throw const FormatException('Invalid resonance response.'),
};

extension RoomResonanceCueCopy on RoomResonanceCue {
  String get wireKey => switch (this) {
    RoomResonanceCue.gentleRestart => 'gentle_restart',
    RoomResonanceCue.openToCompany => 'open_to_company',
    RoomResonanceCue.startingSmall => 'starting_small',
    RoomResonanceCue.completedStep => 'completed_step',
  };

  String get label => switch (this) {
    RoomResonanceCue.gentleRestart => '我正溫柔地重新開始',
    RoomResonanceCue.openToCompany => '想找人一起做一小段',
    RoomResonanceCue.startingSmall => '我準備從小步驟開始',
    RoomResonanceCue.completedStep => '我完成了一個小步驟',
  };
}

extension RoomResonanceResponseCopy on RoomResonanceResponse {
  String get wireKey => switch (this) {
    RoomResonanceResponse.withYou => 'with_you',
    RoomResonanceResponse.cheer => 'cheer',
    RoomResonanceResponse.takeYourTime => 'take_your_time',
  };

  String get label => switch (this) {
    RoomResonanceResponse.withYou => '我陪你',
    RoomResonanceResponse.cheer => '替你加油',
    RoomResonanceResponse.takeYourTime => '慢慢來也可以',
  };
}

class RoomResonancePreference {
  const RoomResonancePreference({
    required this.roomId,
    required this.userId,
    required this.enabled,
    required this.updatedAt,
  });

  final String roomId;
  final String userId;
  final bool enabled;
  final DateTime updatedAt;

  factory RoomResonancePreference.fromMap(
    Map<String, dynamic> map, {
    required String expectedRoomId,
    required String expectedUserId,
  }) {
    final roomId = _requiredResonanceString(map['roomId']);
    final userId = _requiredResonanceString(map['userId']);
    final preferenceId = _requiredResonanceString(map['preferenceId']);
    if (map['schemaVersion'] != 1 ||
        roomId != expectedRoomId ||
        userId != expectedUserId ||
        preferenceId != '$roomId--$userId' ||
        map['enabled'] is! bool ||
        map['audience'] != 'room_members_only' ||
        map['shareMode'] != 'cue_only') {
      throw const FormatException('Invalid resonance preference.');
    }
    return RoomResonancePreference(
      roomId: roomId,
      userId: userId,
      enabled: map['enabled'] as bool,
      updatedAt: _resonanceDate(map['updatedAt']),
    );
  }
}

class RoomResonanceSignal {
  const RoomResonanceSignal({
    required this.signalId,
    required this.roomId,
    required this.ownerUserId,
    required this.generationId,
    required this.cue,
    required this.status,
    required this.acknowledgementCount,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.withdrawnAt,
  });

  final String signalId;
  final String roomId;
  final String ownerUserId;
  final String generationId;
  final RoomResonanceCue cue;
  final RoomResonanceStatus status;
  final int acknowledgementCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime expiresAt;
  final DateTime? withdrawnAt;

  bool isVisibleAt(DateTime now) =>
      status == RoomResonanceStatus.active && expiresAt.isAfter(now.toUtc());

  factory RoomResonanceSignal.fromMap(
    Map<String, dynamic> map, {
    required String expectedRoomId,
  }) {
    final signalId = _requiredResonanceString(map['signalId']);
    final roomId = _requiredResonanceString(map['roomId']);
    final ownerUserId = _requiredResonanceString(map['ownerUserId']);
    final generationId = _requiredResonanceString(map['generationId']);
    final acknowledgementCount = map['acknowledgementCount'];
    final status = switch (map['status']) {
      'active' => RoomResonanceStatus.active,
      'withdrawn' => RoomResonanceStatus.withdrawn,
      _ => throw const FormatException('Invalid resonance status.'),
    };
    final createdAt = _resonanceDate(map['createdAt']);
    final updatedAt = _resonanceDate(map['updatedAt']);
    final expiresAt = _resonanceDate(map['expiresAt']);
    final withdrawnAt = map['withdrawnAt'] == null
        ? null
        : _resonanceDate(map['withdrawnAt']);
    if (map['schemaVersion'] != 1 ||
        roomId != expectedRoomId ||
        signalId != '$roomId--$ownerUserId' ||
        generationId.length < 8 ||
        map['visibility'] != 'room_members_only' ||
        acknowledgementCount is! int ||
        acknowledgementCount < 0 ||
        updatedAt.isBefore(createdAt) ||
        !expiresAt.isAfter(createdAt) ||
        (status == RoomResonanceStatus.active && withdrawnAt != null) ||
        (status == RoomResonanceStatus.withdrawn && withdrawnAt == null)) {
      throw const FormatException('Invalid resonance signal.');
    }
    return RoomResonanceSignal(
      signalId: signalId,
      roomId: roomId,
      ownerUserId: ownerUserId,
      generationId: generationId,
      cue: _cue(map['cueKey']),
      status: status,
      acknowledgementCount: acknowledgementCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      withdrawnAt: withdrawnAt,
    );
  }
}

class RoomResonanceAcknowledgement {
  const RoomResonanceAcknowledgement({
    required this.roomId,
    required this.signalId,
    required this.signalOwnerUserId,
    required this.actorUserId,
    required this.generationId,
    required this.response,
    required this.createdAt,
  });

  final String roomId;
  final String signalId;
  final String signalOwnerUserId;
  final String actorUserId;
  final String generationId;
  final RoomResonanceResponse response;
  final DateTime createdAt;

  factory RoomResonanceAcknowledgement.fromMap(
    Map<String, dynamic> map, {
    required String expectedRoomId,
    required String expectedActorUserId,
  }) {
    final roomId = _requiredResonanceString(map['roomId']);
    final signalId = _requiredResonanceString(map['signalId']);
    final ownerUserId = _requiredResonanceString(map['signalOwnerUserId']);
    final actorUserId = _requiredResonanceString(map['actorUserId']);
    final generationId = _requiredResonanceString(map['generationId']);
    if (map['schemaVersion'] != 1 ||
        roomId != expectedRoomId ||
        actorUserId != expectedActorUserId ||
        signalId != '$roomId--$ownerUserId' ||
        ownerUserId == actorUserId ||
        generationId.length < 8) {
      throw const FormatException('Invalid resonance acknowledgement.');
    }
    return RoomResonanceAcknowledgement(
      roomId: roomId,
      signalId: signalId,
      signalOwnerUserId: ownerUserId,
      actorUserId: actorUserId,
      generationId: generationId,
      response: _response(map['responseKey']),
      createdAt: _resonanceDate(map['createdAt']),
    );
  }
}

Map<String, dynamic> roomResonanceMap(Object? value) => _resonanceMap(value);
