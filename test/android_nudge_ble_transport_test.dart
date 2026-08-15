import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/android_nudge_ble_transport.dart';

void main() {
  test('transport validates native BLE events and commands', () async {
    final calls = <String>[];
    final controller = StreamController<Object?>();
    final transport = AndroidNudgeBleTransport.withChannels(
      invokeMethod: (method, arguments) async {
        calls.add(method);
        if (method == 'readPendingEvent') {
          return '{"messageType":"activity_event"}';
        }
        return true;
      },
      nativeEvents: controller.stream,
    );

    final first = expectLater(
      transport.events,
      emits(
        isA<NudgeBleTransportEvent>()
            .having((event) => event.type, 'type', NudgeBleEventType.connected)
            .having((event) => event.deviceId, 'deviceId', 'nudge-a1b2c3'),
      ),
    );
    controller.add({'type': 'connected', 'deviceId': 'nudge-a1b2c3'});
    await first;

    await transport.scanAndConnect();
    expect(await transport.readPendingEvent(), contains('activity_event'));
    await transport.writeCommand('{"type":"ack"}');
    await transport.disconnect();
    expect(calls, [
      'scanAndConnect',
      'readPendingEvent',
      'writeCommand',
      'disconnect',
    ]);
    await controller.close();
  });

  test('transport rejects malformed native state', () {
    expect(
      () => NudgeBleTransportEvent.fromMap({
        'type': 'state',
        'deviceId': 'nudge-a1b2c3',
        'payload': 42,
      }),
      throwsFormatException,
    );
  });
}
