import 'package:cloud_firestore/cloud_firestore.dart';

const currentPrivacyPolicyVersion = '2026-07-29';

DateTime? _parsePrivacyTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class PrivacyConsentRecord {
  const PrivacyConsentRecord({
    required this.status,
    required this.policyVersion,
    required this.healthIngestion,
    required this.acceptedAt,
    required this.revokedAt,
    required this.updatedAt,
  });

  final String status;
  final String policyVersion;
  final bool healthIngestion;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;
  final DateTime? updatedAt;

  bool get isCurrentHealthConsent =>
      status == 'accepted' &&
      policyVersion == currentPrivacyPolicyVersion &&
      healthIngestion;

  factory PrivacyConsentRecord.fromMap(Map<String, dynamic> map) {
    final scopes = Map<String, dynamic>.from(
      map['scopes'] as Map? ?? const <String, dynamic>{},
    );
    return PrivacyConsentRecord(
      status: map['status']?.toString() ?? 'revoked',
      policyVersion: map['policyVersion']?.toString() ?? '',
      healthIngestion: scopes['healthIngestion'] as bool? ?? false,
      acceptedAt: _parsePrivacyTimestamp(map['acceptedAt']),
      revokedAt: _parsePrivacyTimestamp(map['revokedAt']),
      updatedAt: _parsePrivacyTimestamp(map['updatedAt']),
    );
  }
}

class PrivacyConsentUpdateResult {
  const PrivacyConsentUpdateResult({
    required this.consent,
    required this.auditEventId,
    required this.replayed,
  });

  final PrivacyConsentRecord consent;
  final String auditEventId;
  final bool replayed;

  factory PrivacyConsentUpdateResult.fromMap(Map<String, dynamic> map) {
    return PrivacyConsentUpdateResult(
      consent: PrivacyConsentRecord.fromMap(
        Map<String, dynamic>.from(
          map['consent'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      auditEventId: map['auditEventId']?.toString() ?? '',
      replayed: map['replayed'] as bool? ?? false,
    );
  }
}
