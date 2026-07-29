class PushInstallationUpdateResult {
  const PushInstallationUpdateResult({
    required this.action,
    required this.installationId,
    required this.configured,
    required this.activeInstallationCount,
    required this.auditEventId,
    required this.replayed,
  });

  final String action;
  final String installationId;
  final bool configured;
  final int activeInstallationCount;
  final String auditEventId;
  final bool replayed;

  factory PushInstallationUpdateResult.fromMap(Map<String, dynamic> map) {
    return PushInstallationUpdateResult(
      action: map['action']?.toString() ?? '',
      installationId: map['installationId']?.toString() ?? '',
      configured: map['configured'] as bool? ?? false,
      activeInstallationCount:
          (map['activeInstallationCount'] as num?)?.toInt() ?? 0,
      auditEventId: map['auditEventId']?.toString() ?? '',
      replayed: map['replayed'] as bool? ?? false,
    );
  }
}
