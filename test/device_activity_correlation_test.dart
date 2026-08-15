import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/activity_ledger_outbox.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:nudge/services/device_activity_correlation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists start before Cloud and returns canonical session', () async {
    final operations = <String>[];
    final outbox = ActivityLedgerOutbox(
      gateway: CloudActivityLedgerGateway.withCallable((request) async {
        operations.add('cloud');
        final evidence = request['evidence'] as Map<String, dynamic>;
        return {
          'status': 'accepted',
          'acknowledgedEventId': evidence['eventId'],
          'acknowledgedSourceRecordId': evidence['sourceRecordId'],
          'canonicalSessionId': 'canonical-device-focus',
          'wasDuplicate': false,
          'receipt': null,
          'contributions': const [],
          'session': null,
        };
      }),
      getActorId: () => 'alice',
      writePending: (encoded) async {
        operations.add('durable');
        return (await SharedPreferences.getInstance()).setString(
          'activity_ledger_outbox_v1',
          encoded,
        );
      },
    );
    final service = DeviceActivityCorrelationService(
      outbox: outbox,
      currentActorUserId: () => 'alice',
      existingCorrelationId: () => null,
      isExistingCorrelationCloudConfirmed: () => false,
      clock: () => DateTime.utc(2026, 8, 15, 12),
    );

    expect(await service.prepareFocusCorrelation(), 'canonical-device-focus');
    expect(operations.first, 'durable');
    expect(operations, contains('cloud'));
    expect(await outbox.pendingCount(), 0);
  });

  test('does not configure a device while Cloud is retry blocked', () async {
    final outbox = ActivityLedgerOutbox(
      gateway: CloudActivityLedgerGateway.withCallable((_) async {
        throw StateError('offline');
      }),
      getActorId: () => 'alice',
    );
    final service = DeviceActivityCorrelationService(
      outbox: outbox,
      currentActorUserId: () => 'alice',
      existingCorrelationId: () => null,
      isExistingCorrelationCloudConfirmed: () => false,
    );

    await expectLater(
      service.prepareFocusCorrelation(),
      throwsA(isA<DeviceActivityCorrelationException>()),
    );
    expect(await outbox.pendingCount(), 1);
  });

  test('reuses an active App correlation after flushing its outbox', () async {
    final outbox = ActivityLedgerOutbox(
      gateway: CloudActivityLedgerGateway.withCallable((_) async => null),
      getActorId: () => 'alice',
    );
    final service = DeviceActivityCorrelationService(
      outbox: outbox,
      currentActorUserId: () => 'alice',
      existingCorrelationId: () => 'app-focus-7',
      isExistingCorrelationCloudConfirmed: () => true,
    );

    expect(await service.prepareFocusCorrelation(), 'app-focus-7');
  });

  test(
    'rejects an active App correlation that Cloud never confirmed',
    () async {
      final service = DeviceActivityCorrelationService(
        outbox: ActivityLedgerOutbox(
          gateway: CloudActivityLedgerGateway.withCallable((_) async => null),
          getActorId: () => 'alice',
        ),
        currentActorUserId: () => 'alice',
        existingCorrelationId: () => 'app-focus-unconfirmed',
        isExistingCorrelationCloudConfirmed: () => false,
      );

      await expectLater(
        service.prepareFocusCorrelation(),
        throwsA(isA<DeviceActivityCorrelationException>()),
      );
    },
  );
}
