import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/privacy_data_request.dart';
import 'package:nudge/services/cloud_privacy_data_gateway.dart';

void main() {
  test('privacy request model distinguishes export and deletion states', () {
    final export = PrivacyDataRequest.fromMap({
      'schemaVersion': 1,
      'requestId': 'user-one--privacy-data-001',
      'userId': 'user-one',
      'type': 'export',
      'status': 'ready',
      'storagePath': 'privacy_exports/user-one/export.json',
      'expiresAt': '2026-08-05T03:00:00.000Z',
      'exportBytes': 2048,
      'truncatedCollections': <String>[],
    });
    expect(export.isExport, isTrue);
    expect(
      export.canDownloadAt(DateTime.parse('2026-08-01T03:00:00.000Z')),
      isTrue,
    );
    expect(
      export.canDownloadAt(DateTime.parse('2026-08-06T03:00:00.000Z')),
      isFalse,
    );
    expect(export.exportBytes, 2048);

    final deletion = PrivacyDataRequest.fromMap({
      'schemaVersion': 1,
      'requestId': 'user-one--privacy-delete-001',
      'userId': 'user-one',
      'type': 'account_deletion',
      'status': 'in_review',
      'requestedAt': '2026-07-29T03:00:00.000Z',
    });
    expect(deletion.isAccountDeletion, isTrue);
    expect(deletion.canCancel, isTrue);

    final failed = PrivacyDataRequest.fromMap({
      'schemaVersion': 1,
      'requestId': 'user-one--privacy-data-failed',
      'userId': 'user-one',
      'type': 'export',
      'status': 'failed',
      'caseId': 'CASE-2026-0001',
    });
    expect(failed.canDownload, isFalse);
    expect(failed.caseId, 'CASE-2026-0001');
  });

  test('privacy gateway verifies Cloud request and download contracts', () async {
    final calls = <String>[];
    final gateway = CloudPrivacyDataGateway.withAdapters(
      call: (name, payload) async {
        calls.add(name);
        if (name == 'getPrivacyExportDownload') {
          return {
            'requestId': payload['requestId'],
            'downloadUrl':
                'https://firebasestorage.googleapis.com/export.json?token=secret',
            'expiresAt': '2026-08-05T03:00:00.000Z',
            'auditEventId': 'privacy-download-audit-001',
          };
        }
        return {
          'request': {
            'schemaVersion': 1,
            'requestId': 'user-one--privacy-data-001',
            'userId': 'user-one',
            'type': 'export',
            'status': 'ready',
            'expiresAt': '2026-08-05T03:00:00.000Z',
          },
          'auditEventId': 'privacy-request-audit-001',
          'replayed': false,
        };
      },
      watch: (_) => const Stream.empty(),
    );

    final requested = await gateway.requestExport(
      clientRequestId: 'privacy-data-001',
    );
    expect(
      requested.request.canDownloadAt(
        DateTime.parse('2026-08-01T03:00:00.000Z'),
      ),
      isTrue,
    );
    expect(requested.auditEventId, isNotEmpty);

    final download = await gateway.getExportDownload(
      requestId: requested.request.requestId,
      clientRequestId: 'privacy-download-001',
    );
    expect(download.downloadUrl.scheme, 'https');
    expect(download.auditEventId, isNotEmpty);
    expect(calls, ['requestPrivacyDataAction', 'getPrivacyExportDownload']);
  });
}
