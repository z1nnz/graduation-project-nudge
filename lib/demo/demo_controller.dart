import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/android_nudge_ble_transport.dart';
import 'generated_demo_contract.dart';

enum DemoDevice { orbit, station }

enum DemoConnection { disconnected, connecting, connected }

class DemoAcceptance {
  const DemoAcceptance({
    this.armed = false,
    this.orbitP0b = false,
    this.stationP0b = false,
    this.visuals = false,
    this.tenReplays = false,
  });
  factory DemoAcceptance.build() => const DemoAcceptance(
    armed: bool.fromEnvironment('NUDGE_DEMO_BLE'),
    orbitP0b: bool.fromEnvironment('NUDGE_DEMO_ORBIT_P0B'),
    stationP0b: bool.fromEnvironment('NUDGE_DEMO_STATION_P0B'),
    visuals: bool.fromEnvironment('NUDGE_DEMO_VISUALS'),
    tenReplays: bool.fromEnvironment('NUDGE_DEMO_TEN_REPLAYS'),
  );
  final bool armed, orbitP0b, stationP0b, visuals, tenReplays;
  bool get allowed => armed && orbitP0b && stationP0b && visuals && tenReplays;
}

class DemoReportedState {
  const DemoReportedState(this.device, this.index);
  final DemoDevice device;
  final int index;
  String get scene => demoSceneNames[index];
  String get pose => demoScenePoses[index];

  factory DemoReportedState.parse(String raw) {
    if (utf8.encode(raw).length > 96) {
      throw const FormatException('Oversize Demo state');
    }
    final value = jsonDecode(raw);
    if (RegExp(r'"([^"\\]+)"\s*:').allMatches(raw).length != 5) {
      throw const FormatException('Invalid Demo keys');
    }
    if (value is! Map ||
        value.length != 5 ||
        !value.keys.toSet().containsAll([
          'v',
          'mode',
          'device',
          'scene',
          'index',
        ]) ||
        value['v'] is! int ||
        value['v'] != 1 ||
        value['mode'] != 'demo') {
      throw const FormatException('Invalid Demo state');
    }
    final device = switch (value['device']) {
      'orbit' => DemoDevice.orbit,
      'station' => DemoDevice.station,
      _ => throw const FormatException('Unknown Demo device'),
    };
    final index = value['index'];
    if (index is! int ||
        index < 0 ||
        index >= demoSceneNames.length ||
        demoSceneNames[index] != value['scene']) {
      throw const FormatException('Invalid Demo scene');
    }
    return DemoReportedState(device, index);
  }
}

abstract interface class DemoTransport {
  Stream<NudgeBleTransportEvent> get events;
  Future<void> connect(DemoDevice device);
  Future<void> write(String payload);
  Future<void> disconnect();
}

class PlatformDemoTransport implements DemoTransport {
  PlatformDemoTransport();
  static const _methods = MethodChannel('nudge/demo_ble');
  static const _events = EventChannel('nudge/demo_ble_events');
  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  @override
  Stream<NudgeBleTransportEvent> get events => _supported
      ? _events.receiveBroadcastStream().map(NudgeBleTransportEvent.fromMap)
      : const Stream.empty();
  Future<void> _call(String method, [Object? args]) async {
    if (!_supported) throw UnsupportedError('Android Demo BLE only');
    if (await _methods.invokeMethod<Object?>(method, args) != true) {
      throw StateError('Demo transport did not accept the operation');
    }
  }

  @override
  Future<void> connect(DemoDevice device) =>
      _call('scanAndConnect', {'device': device.name});
  @override
  Future<void> write(String payload) =>
      _call('writeCommand', {'commandJson': payload});
  @override
  Future<void> disconnect() async {
    if (_supported) await _call('disconnect');
  }
}

class DemoController extends ChangeNotifier {
  DemoController({
    required DemoTransport transport,
    required this.acceptance,
    this.timeout = const Duration(seconds: 18),
  }) : _transport = transport {
    _subscription = _transport.events.listen(
      _onEvent,
      onError: (Object error) {
        unawaited(_fallback());
      },
    );
  }
  final DemoTransport _transport;
  final DemoAcceptance acceptance;
  final Duration timeout;
  StreamSubscription<NudgeBleTransportEvent>? _subscription;
  Timer? _connectionTimer;
  bool _disposed = false;
  int _operation = 0;
  DemoDevice? device;
  DemoConnection connection = DemoConnection.disconnected;
  DemoReportedState? reported;
  bool busy = false;
  String message = '固定原型資料 · 實機連動稍後驗收';
  bool get canSend =>
      acceptance.allowed && connection == DemoConnection.connected && !busy;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int operation) => !_disposed && _operation == operation;

  Future<void> connect(DemoDevice target) async {
    if (_disposed || busy || connection != DemoConnection.disconnected) return;
    if (!acceptance.allowed) {
      message = '連動尚待驗收，改用裝置自動展示';
      _changed();
      return;
    }
    final operation = ++_operation;
    device = target;
    reported = null;
    connection = DemoConnection.connecting;
    message = '正在尋找 ${demoDeviceNames[target.name]}';
    _changed();
    _connectionTimer = Timer(timeout, () {
      if (_current(operation)) unawaited(_fallback());
    });
    try {
      await _transport.connect(target).timeout(timeout);
    } catch (_) {
      if (_current(operation)) await _fallback();
    }
  }

  void _onEvent(NudgeBleTransportEvent event) {
    if (_disposed ||
        device == null ||
        !acceptance.allowed ||
        connection == DemoConnection.disconnected) {
      return;
    }
    if (event.deviceId != null && event.deviceId != device!.name) return;
    switch (event.type) {
      case NudgeBleEventType.state:
        try {
          final state = DemoReportedState.parse(event.payload!);
          if (state.device != device) {
            throw const FormatException('Wrong device');
          }
          if (connection == DemoConnection.disconnected) return;
          reported = state;
          connection = DemoConnection.connected;
          _connectionTimer?.cancel();
          message = '已連線 · DEMO';
          _changed();
        } catch (_) {
          unawaited(_fallback());
        }
      case NudgeBleEventType.disconnected:
      case NudgeBleEventType.error:
        unawaited(_fallback());
      case NudgeBleEventType.scanning:
      case NudgeBleEventType.connected:
        // A GATT connection alone is not proof of the requested Demo contract.
        // Keep controls disabled until a valid state arrives from that device.
        break;
    }
  }

  Future<void> send(String action) async {
    if (!demoActions.contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    if (!canSend) return;
    final operation = _operation;
    busy = true;
    _changed();
    try {
      await _transport
          .write(jsonEncode({'v': 1, 'type': 'demo', 'action': action}))
          .timeout(timeout);
      if (_current(operation)) message = '指令已傳送 · 以裝置回報與畫面確認';
    } catch (_) {
      if (_current(operation)) await _fallback();
    } finally {
      if (_current(operation)) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> _fallback() async {
    if (_disposed) return;
    ++_operation;
    _connectionTimer?.cancel();
    busy = false;
    connection = DemoConnection.disconnected;
    reported = null;
    message = '改用裝置自動展示';
    _changed();
    try {
      await _transport.disconnect().timeout(const Duration(seconds: 2));
    } catch (_) {
      /* Local controls remain available. */
    }
  }

  Future<void> disconnect() => _fallback();

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    _connectionTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_transport.disconnect().catchError((Object _) {}));
    super.dispose();
  }
}
