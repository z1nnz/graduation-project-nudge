import 'dart:async';

import 'package:flutter/services.dart';

enum NudgeBleEventType { scanning, connected, disconnected, state, error }

class NudgeBleTransportEvent {
  const NudgeBleTransportEvent({
    required this.type,
    this.deviceId,
    this.payload,
    this.message,
  });

  final NudgeBleEventType type;
  final String? deviceId;
  final String? payload;
  final String? message;

  factory NudgeBleTransportEvent.fromMap(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid native BLE event.');
    final map = Map<String, dynamic>.from(raw);
    final type = switch (map['type']) {
      'scanning' => NudgeBleEventType.scanning,
      'connected' => NudgeBleEventType.connected,
      'disconnected' => NudgeBleEventType.disconnected,
      'state' => NudgeBleEventType.state,
      'error' => NudgeBleEventType.error,
      _ => throw const FormatException('Unsupported native BLE event.'),
    };
    String? stringValue(String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! String || value.trim() != value || value.isEmpty) {
        throw FormatException('Invalid native BLE $key.');
      }
      return value;
    }

    final deviceId = stringValue('deviceId');
    final payload = stringValue('payload');
    final message = stringValue('message');
    if ([NudgeBleEventType.connected, NudgeBleEventType.state].contains(type) &&
        deviceId == null) {
      throw const FormatException('Native BLE event requires deviceId.');
    }
    if (type == NudgeBleEventType.state && payload == null) {
      throw const FormatException('Native BLE state requires payload.');
    }
    if (type == NudgeBleEventType.error && message == null) {
      throw const FormatException('Native BLE error requires message.');
    }
    return NudgeBleTransportEvent(
      type: type,
      deviceId: deviceId,
      payload: payload,
      message: message,
    );
  }
}

abstract interface class NudgeBleTransport {
  Stream<NudgeBleTransportEvent> get events;
  Future<void> scanAndConnect();
  Future<String> readPendingEvent();
  Future<void> writeCommand(String commandJson);
  Future<void> disconnect();
}

typedef NudgeBleMethodInvoker =
    Future<Object?> Function(String method, Object? arguments);

class AndroidNudgeBleTransport implements NudgeBleTransport {
  AndroidNudgeBleTransport.withChannels({
    required NudgeBleMethodInvoker invokeMethod,
    required Stream<Object?> nativeEvents,
  }) : _invokeMethod = invokeMethod,
       _events = nativeEvents.map(NudgeBleTransportEvent.fromMap);

  factory AndroidNudgeBleTransport.platform() {
    const methods = MethodChannel('nudge/device_ble');
    const events = EventChannel('nudge/device_ble_events');
    return AndroidNudgeBleTransport.withChannels(
      invokeMethod: methods.invokeMethod<Object?>,
      nativeEvents: events.receiveBroadcastStream(),
    );
  }

  final NudgeBleMethodInvoker _invokeMethod;
  final Stream<NudgeBleTransportEvent> _events;

  @override
  Stream<NudgeBleTransportEvent> get events => _events;

  Future<void> _voidMethod(String method, [Object? arguments]) async {
    final result = await _invokeMethod(method, arguments);
    if (result != true) {
      throw PlatformException(
        code: 'ble-operation-failed',
        message: 'Android BLE operation $method was not accepted.',
      );
    }
  }

  @override
  Future<void> scanAndConnect() => _voidMethod('scanAndConnect');

  @override
  Future<String> readPendingEvent() async {
    final result = await _invokeMethod('readPendingEvent', null);
    if (result is! String) {
      throw const FormatException('Android BLE event payload is invalid.');
    }
    return result;
  }

  @override
  Future<void> writeCommand(String commandJson) =>
      _voidMethod('writeCommand', {'commandJson': commandJson});

  @override
  Future<void> disconnect() => _voidMethod('disconnect');
}
