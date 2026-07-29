import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? _parsePrivacyTimestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

class PrivacyDataRequest {
  const PrivacyDataRequest({
    required this.requestId,
    required this.userId,
    required this.type,
    required this.status,
    required this.sourceSurface,
    required this.reason,
    required this.storagePath,
    required this.requestedAt,
    required this.updatedAt,
    required this.reviewAfter,
    required this.expiresAt,
    required this.generatedAt,
    required this.cancelledAt,
    required this.completedAt,
    required this.assignedStaffUserId,
    required this.resolutionNote,
    required this.caseId,
    required this.exportBytes,
    required this.truncatedCollections,
  });

  final String requestId;
  final String userId;
  final String type;
  final String status;
  final String sourceSurface;
  final String reason;
  final String storagePath;
  final DateTime? requestedAt;
  final DateTime? updatedAt;
  final DateTime? reviewAfter;
  final DateTime? expiresAt;
  final DateTime? generatedAt;
  final DateTime? cancelledAt;
  final DateTime? completedAt;
  final String assignedStaffUserId;
  final String resolutionNote;
  final String caseId;
  final int exportBytes;
  final List<String> truncatedCollections;

  bool get isExport => type == 'export';
  bool get isAccountDeletion => type == 'account_deletion';
  bool get canDownload =>
      isExport &&
      status == 'ready' &&
      expiresAt != null &&
      expiresAt!.isAfter(DateTime.now());
  bool get canCancel =>
      isAccountDeletion && const {'pending', 'in_review'}.contains(status);

  factory PrivacyDataRequest.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    if ((map['schemaVersion'] as num?)?.toInt() != 1) {
      throw const FormatException('Unsupported privacy request schema');
    }
    final requestId = documentId ?? map['requestId']?.toString() ?? '';
    final userId = map['userId']?.toString() ?? '';
    final type = map['type']?.toString() ?? '';
    final status = map['status']?.toString() ?? '';
    if (requestId.isEmpty ||
        userId.isEmpty ||
        !const {'export', 'account_deletion'}.contains(type) ||
        !const {
          'processing',
          'ready',
          'expired',
          'failed',
          'pending',
          'in_review',
          'cancelled',
          'rejected',
          'completed',
        }.contains(status)) {
      throw const FormatException('Incomplete privacy request');
    }
    return PrivacyDataRequest(
      requestId: requestId,
      userId: userId,
      type: type,
      status: status,
      sourceSurface: map['sourceSurface']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      storagePath: map['storagePath']?.toString() ?? '',
      requestedAt: _parsePrivacyTimestamp(map['requestedAt']),
      updatedAt: _parsePrivacyTimestamp(map['updatedAt']),
      reviewAfter: _parsePrivacyTimestamp(map['reviewAfter']),
      expiresAt: _parsePrivacyTimestamp(map['expiresAt']),
      generatedAt: _parsePrivacyTimestamp(map['generatedAt']),
      cancelledAt: _parsePrivacyTimestamp(map['cancelledAt']),
      completedAt: _parsePrivacyTimestamp(map['completedAt']),
      assignedStaffUserId: map['assignedStaffUserId']?.toString() ?? '',
      resolutionNote: map['resolutionNote']?.toString() ?? '',
      caseId: map['caseId']?.toString() ?? '',
      exportBytes: (map['exportBytes'] as num?)?.toInt() ?? 0,
      truncatedCollections: List<String>.unmodifiable(
        (map['truncatedCollections'] as List? ?? const []).map(
          (value) => value.toString(),
        ),
      ),
    );
  }
}

class PrivacyDataRequestResult {
  const PrivacyDataRequestResult({
    required this.request,
    required this.auditEventId,
    required this.replayed,
  });

  final PrivacyDataRequest request;
  final String auditEventId;
  final bool replayed;

  factory PrivacyDataRequestResult.fromMap(Map<String, dynamic> map) {
    final request = PrivacyDataRequest.fromMap(
      Map<String, dynamic>.from(map['request'] as Map? ?? const {}),
    );
    final auditEventId = map['auditEventId']?.toString() ?? '';
    if (auditEventId.isEmpty) {
      throw const FormatException('Privacy request audit is missing');
    }
    return PrivacyDataRequestResult(
      request: request,
      auditEventId: auditEventId,
      replayed: map['replayed'] as bool? ?? false,
    );
  }
}

class PrivacyExportDownload {
  const PrivacyExportDownload({
    required this.requestId,
    required this.downloadUrl,
    required this.expiresAt,
    required this.auditEventId,
  });

  final String requestId;
  final Uri downloadUrl;
  final DateTime? expiresAt;
  final String auditEventId;

  factory PrivacyExportDownload.fromMap(Map<String, dynamic> map) {
    final requestId = map['requestId']?.toString() ?? '';
    final url = Uri.tryParse(map['downloadUrl']?.toString() ?? '');
    final auditEventId = map['auditEventId']?.toString() ?? '';
    if (requestId.isEmpty ||
        url == null ||
        url.scheme != 'https' ||
        auditEventId.isEmpty) {
      throw const FormatException('Privacy export download is invalid');
    }
    return PrivacyExportDownload(
      requestId: requestId,
      downloadUrl: url,
      expiresAt: _parsePrivacyTimestamp(map['expiresAt']),
      auditEventId: auditEventId,
    );
  }
}
