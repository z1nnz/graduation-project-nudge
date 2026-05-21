enum StudySessionType {
  focus,
  rest,
}

enum StudySessionStatus {
  running,
  completed,
  cancelled,
}

class StudySession {
  final String id;
  final String userId;
  final String? roomId;
  final StudySessionType sessionType;
  final StudySessionStatus status;
  final DateTime startAt;
  final DateTime? endAt;
  final int durationSeconds;
  final DateTime createdAt;

  const StudySession({
    required this.id,
    required this.userId,
    this.roomId,
    required this.sessionType,
    required this.status,
    required this.startAt,
    this.endAt,
    this.durationSeconds = 0,
    required this.createdAt,
  });

  StudySession copyWith({
    String? id,
    String? userId,
    String? roomId,
    bool clearRoomId = false,
    StudySessionType? sessionType,
    StudySessionStatus? status,
    DateTime? startAt,
    DateTime? endAt,
    bool clearEndAt = false,
    int? durationSeconds,
    DateTime? createdAt,
  }) {
    return StudySession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roomId: clearRoomId ? null : (roomId ?? this.roomId),
      sessionType: sessionType ?? this.sessionType,
      status: status ?? this.status,
      startAt: startAt ?? this.startAt,
      endAt: clearEndAt ? null : (endAt ?? this.endAt),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'roomId': roomId,
      'sessionType': sessionType.name,
      'status': status.name,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final sessionTypeRaw = json['sessionType'] as String? ?? 'focus';
    final statusRaw = json['status'] as String? ?? 'running';

    return StudySession(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      roomId: json['roomId'] as String?,
      sessionType: StudySessionType.values.firstWhere(
        (e) => e.name == sessionTypeRaw,
        orElse: () => StudySessionType.focus,
      ),
      status: StudySessionStatus.values.firstWhere(
        (e) => e.name == statusRaw,
        orElse: () => StudySessionStatus.running,
      ),
      startAt: DateTime.tryParse(json['startAt'] as String? ?? '') ??
          DateTime.now(),
      endAt: json['endAt'] == null
          ? null
          : DateTime.tryParse(json['endAt'] as String),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}