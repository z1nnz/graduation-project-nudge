import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/cloud_push_installation_gateway.dart';

void main() {
  test(
    'push gateway registers a token without weakening the response contract',
    () async {
      Map<String, dynamic>? captured;
      final gateway = CloudPushInstallationGateway.withCallable((
        payload,
      ) async {
        captured = payload;
        return {
          'action': 'register',
          'installationId': payload['installationId'],
          'configured': true,
          'activeInstallationCount': 1,
          'auditEventId': 'push-installation--user--request',
          'replayed': false,
        };
      });

      final result = await gateway.register(
        installationId: 'device_12345678',
        platform: 'android',
        token: 'fcm-token-that-is-never-returned-by-the-cloud',
        clientRequestId: 'push-request-001',
      );

      expect(captured?['action'], 'register');
      expect(captured?['platform'], 'android');
      expect(result.configured, true);
      expect(result.activeInstallationCount, 1);
    },
  );

  test('push gateway rejects a mismatched audited response', () async {
    final gateway = CloudPushInstallationGateway.withCallable((_) async {
      return {
        'action': 'register',
        'installationId': 'another-device',
        'configured': true,
        'activeInstallationCount': 1,
        'auditEventId': 'push-installation--user--request',
      };
    });

    await expectLater(
      gateway.revoke(
        installationId: 'device_12345678',
        clientRequestId: 'push-request-002',
      ),
      throwsA(isA<PushInstallationException>()),
    );
  });
}
