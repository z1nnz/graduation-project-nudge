import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/privacy_consent.dart';
import 'package:nudge/services/cloud_privacy_consent_gateway.dart';

void main() {
  test('current Cloud consent enables health ingestion', () {
    final consent = PrivacyConsentRecord.fromMap({
      'status': 'accepted',
      'policyVersion': currentPrivacyPolicyVersion,
      'scopes': {'healthIngestion': true},
      'acceptedAt': '2026-07-29T00:00:00.000Z',
      'updatedAt': '2026-07-29T00:00:00.000Z',
    });

    expect(consent.isCurrentHealthConsent, true);
    expect(consent.acceptedAt, DateTime.utc(2026, 7, 29));
  });

  test('gateway sends versioned consent and validates audit result', () async {
    Map<String, dynamic>? captured;
    final gateway = CloudPrivacyConsentGateway.withCallable((payload) async {
      captured = payload;
      return {
        'replayed': false,
        'auditEventId': 'privacy-consent--user--request',
        'consent': {
          'status': 'accepted',
          'policyVersion': currentPrivacyPolicyVersion,
          'scopes': {'healthIngestion': true},
          'acceptedAt': '2026-07-29T00:00:00.000Z',
          'updatedAt': '2026-07-29T00:00:00.000Z',
        },
      };
    });

    final result = await gateway.update(
      accepted: true,
      clientRequestId: 'privacy-request-001',
    );

    expect(captured?['action'], 'accept');
    expect(captured?['policyVersion'], currentPrivacyPolicyVersion);
    expect(result.consent.isCurrentHealthConsent, true);
  });
}
