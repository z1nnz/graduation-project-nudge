import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/activity_ledger_outbox.dart';
import 'package:nudge/services/android_nudge_ble_transport.dart';
import 'package:nudge/services/cloud_activity_ledger_gateway.dart';
import 'package:nudge/services/firestore_device_assignment_repository.dart';
import 'package:nudge/services/nudge_device_runtime.dart';
import 'package:nudge/screens/nudge_device_page.dart';

class _PageBleTransport implements NudgeBleTransport {
  final controller = StreamController<NudgeBleTransportEvent>.broadcast();
  int scans = 0;

  @override
  Stream<NudgeBleTransportEvent> get events => controller.stream;

  @override
  Future<void> scanAndConnect() async => scans++;

  @override
  Future<String> readPendingEvent() async => '';

  @override
  Future<void> writeCommand(String commandJson) async {}

  @override
  Future<void> disconnect() async {}
}

void main() {
  testWidgets('device page exposes an explicit assigned-device connection', (
    tester,
  ) async {
    final transport = _PageBleTransport();
    final runtime = NudgeDeviceRuntime(
      transport: transport,
      assignmentRepository: FirestoreDeviceAssignmentRepository.withReader(
        (_) async => null,
      ),
      activityLedgerOutbox: ActivityLedgerOutbox(
        gateway: CloudActivityLedgerGateway.withCallable((_) async => null),
      ),
      currentActorUserId: () => 'alice',
      prepareFocusCorrelation: () async => 'cloud-focus-1',
    );

    await tester.pumpWidget(
      MaterialApp(home: NudgeDevicePage(runtimeBuilder: () => runtime)),
    );

    expect(find.text('Nudge 專注裝置'), findsOneWidget);
    expect(find.text('尚未連線'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('只有指派給目前帳號'), 300);
    expect(find.textContaining('只有指派給目前帳號'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '搜尋並連線'),
      -300,
    );

    await tester.tap(find.widgetWithText(FilledButton, '搜尋並連線'));
    await tester.pumpAndSettle();

    expect(transport.scans, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
