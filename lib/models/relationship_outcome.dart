import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parseDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is! Map) return const <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

class RelationshipOutcome {
  const RelationshipOutcome({
    required this.outcomeId,
    required this.scopeType,
    required this.scopeId,
    required this.scopeName,
    required this.status,
    required this.growthKind,
    required this.growthXp,
    required this.growthLevel,
    required this.currentLevelXp,
    required this.nextLevelXp,
    required this.milestoneKeys,
    required this.metrics,
    required this.characterKind,
    required this.characterStage,
    required this.characterTitle,
    required this.characterDescription,
    required this.updatedAt,
  });

  final String outcomeId;
  final String scopeType;
  final String scopeId;
  final String scopeName;
  final String status;
  final String growthKind;
  final int growthXp;
  final int growthLevel;
  final int currentLevelXp;
  final int? nextLevelXp;
  final List<String> milestoneKeys;
  final Map<String, int> metrics;
  final String characterKind;
  final int characterStage;
  final String characterTitle;
  final String characterDescription;
  final DateTime? updatedAt;

  double get levelProgress {
    final next = nextLevelXp;
    if (next == null || next <= 0) return 1;
    final span = next - currentLevelXp;
    if (span <= 0) return 1;
    return ((growthXp - currentLevelXp) / span).clamp(0, 1).toDouble();
  }

  int metric(String key) => metrics[key] ?? 0;

  factory RelationshipOutcome.fromMap(Map<String, dynamic> map) {
    final growth = _stringMap(map['growth']);
    final rawMetrics = _stringMap(map['metrics']);
    final character = _stringMap(map['characterOutcome']);
    return RelationshipOutcome(
      outcomeId: map['outcomeId']?.toString() ?? '',
      scopeType: map['scopeType']?.toString() ?? '',
      scopeId: map['scopeId']?.toString() ?? '',
      scopeName: map['scopeName']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      growthKind: growth['kind']?.toString() ?? '',
      growthXp: (growth['xp'] as num?)?.toInt() ?? 0,
      growthLevel: (growth['level'] as num?)?.toInt() ?? 1,
      currentLevelXp: (growth['currentLevelXp'] as num?)?.toInt() ?? 0,
      nextLevelXp: (growth['nextLevelXp'] as num?)?.toInt(),
      milestoneKeys:
          (growth['milestoneKeys'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const <String>[],
      metrics: rawMetrics.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      characterKind: character['kind']?.toString() ?? '',
      characterStage: (character['stage'] as num?)?.toInt() ?? 1,
      characterTitle: character['title']?.toString() ?? '',
      characterDescription: character['description']?.toString() ?? '',
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }
}

class RelationshipMemory {
  const RelationshipMemory({
    required this.id,
    required this.scopeId,
    required this.memoryType,
    required this.sourceId,
    required this.actorId,
    required this.title,
    required this.points,
    required this.happenedAt,
  });

  final String id;
  final String scopeId;
  final String memoryType;
  final String sourceId;
  final String actorId;
  final String title;
  final int points;
  final DateTime? happenedAt;

  factory RelationshipMemory.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return RelationshipMemory(
      id: documentId ?? map['memoryId']?.toString() ?? '',
      scopeId: map['scopeId']?.toString() ?? '',
      memoryType: map['memoryType']?.toString() ?? '',
      sourceId: map['sourceId']?.toString() ?? '',
      actorId: map['actorId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
      happenedAt: _parseDateTime(map['happenedAt']),
    );
  }
}

class RelationshipOutcomeRefreshResult {
  const RelationshipOutcomeRefreshResult({
    required this.outcome,
    required this.memories,
  });

  final RelationshipOutcome outcome;
  final List<RelationshipMemory> memories;

  factory RelationshipOutcomeRefreshResult.fromMap(Map<String, dynamic> map) {
    final rawOutcome = _stringMap(map['outcome']);
    final rawMemories = map['memories'] as List? ?? const <dynamic>[];
    return RelationshipOutcomeRefreshResult(
      outcome: RelationshipOutcome.fromMap(rawOutcome),
      memories: rawMemories
          .whereType<Map>()
          .map(
            (memory) => RelationshipMemory.fromMap(
              memory.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
    );
  }
}
