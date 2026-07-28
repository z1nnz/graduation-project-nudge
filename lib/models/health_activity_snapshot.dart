import 'activity_ledger.dart';

enum HealthSnapshotProvider { appleHealth, healthConnect }

extension HealthSnapshotProviderCloudName on HealthSnapshotProvider {
  String get cloudName => switch (this) {
    HealthSnapshotProvider.appleHealth => 'appleHealth',
    HealthSnapshotProvider.healthConnect => 'healthConnect',
  };
}

class HealthActivitySnapshot {
  final HealthSnapshotProvider provider;
  final ActivityType activityType;
  final double metricValue;
  final String metricUnit;
  final String localDate;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime observedAt;
  final List<String> dataOrigins;
  final List<String> roomIds;

  const HealthActivitySnapshot({
    required this.provider,
    required this.activityType,
    required this.metricValue,
    required this.metricUnit,
    required this.localDate,
    required this.periodStart,
    required this.periodEnd,
    required this.observedAt,
    required this.dataOrigins,
    this.roomIds = const [],
  });

  HealthActivitySnapshot copyWith({List<String>? roomIds}) {
    return HealthActivitySnapshot(
      provider: provider,
      activityType: activityType,
      metricValue: metricValue,
      metricUnit: metricUnit,
      localDate: localDate,
      periodStart: periodStart,
      periodEnd: periodEnd,
      observedAt: observedAt,
      dataOrigins: dataOrigins,
      roomIds: roomIds ?? this.roomIds,
    );
  }

  Map<String, dynamic> toCloudJson() => {
    'activityType': activityType.name,
    'metricValue': metricValue,
    'metricUnit': metricUnit,
    'localDate': localDate,
    'periodStart': periodStart.toUtc().toIso8601String(),
    'periodEnd': periodEnd.toUtc().toIso8601String(),
    'observedAt': observedAt.toUtc().toIso8601String(),
    'dataOrigins': dataOrigins,
    'roomIds': roomIds,
  };

  Map<String, dynamic> toOutboxJson() => {
    'provider': provider.cloudName,
    ...toCloudJson(),
  };

  factory HealthActivitySnapshot.fromPlatformMap(
    Map<Object?, Object?> raw, {
    required HealthSnapshotProvider provider,
  }) {
    return _fromMap(Map<String, dynamic>.from(raw), provider: provider);
  }

  factory HealthActivitySnapshot.fromOutboxJson(Map<Object?, Object?> raw) {
    final data = Map<String, dynamic>.from(raw);
    final providerName = data.remove('provider');
    final provider = HealthSnapshotProvider.values.firstWhere(
      (value) => value.cloudName == providerName,
      orElse: () =>
          throw const FormatException('Unsupported health snapshot provider.'),
    );
    return _fromMap(data, provider: provider);
  }

  static HealthActivitySnapshot _fromMap(
    Map<String, dynamic> data, {
    required HealthSnapshotProvider provider,
  }) {
    final activityTypeName = data['activityType'];
    final activityType = const {
      'steps': ActivityType.steps,
      'sleep': ActivityType.sleep,
      'exercise': ActivityType.exercise,
    }[activityTypeName];
    if (activityType == null) {
      throw const FormatException('Unsupported health activity type.');
    }
    final expectedUnit = switch (activityType) {
      ActivityType.steps => 'steps',
      ActivityType.sleep => 'hours',
      ActivityType.exercise => 'minutes',
      _ => throw const FormatException('Unsupported health activity type.'),
    };
    if (data['metricUnit'] != expectedUnit) {
      throw const FormatException('Health activity metric unit is invalid.');
    }
    final origins = data['dataOrigins'];
    final rooms = data['roomIds'];
    if (origins is! List || origins.any((origin) => origin is! String)) {
      throw const FormatException('Health data origins are invalid.');
    }
    if (rooms != null &&
        (rooms is! List || rooms.any((room) => room is! String))) {
      throw const FormatException('Health room IDs are invalid.');
    }
    return HealthActivitySnapshot(
      provider: provider,
      activityType: activityType,
      metricValue: (data['metricValue'] as num).toDouble(),
      metricUnit: expectedUnit,
      localDate: data['localDate'] as String,
      periodStart: DateTime.parse(data['periodStart'] as String).toUtc(),
      periodEnd: DateTime.parse(data['periodEnd'] as String).toUtc(),
      observedAt: DateTime.parse(data['observedAt'] as String).toUtc(),
      dataOrigins: List<String>.unmodifiable(origins.cast<String>()),
      roomIds: List<String>.unmodifiable(
        rooms == null ? const <String>[] : rooms.cast<String>(),
      ),
    );
  }
}
