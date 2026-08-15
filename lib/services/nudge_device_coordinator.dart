import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'android_nudge_ble_transport.dart';
import 'nudge_device_bridge.dart';
import 'nudge_device_protocol.dart';

typedef ConnectedDeviceAssignmentValidator =
    Future<bool> Function(String deviceId);

enum NudgeDeviceConnectionStatus {
  idle,
  scanning,
  connected,
  disconnected,
  error,
}

class NudgeDeviceCoordinatorState {
  const NudgeDeviceCoordinatorState({
    this.status = NudgeDeviceConnectionStatus.idle,
    this.deviceId,
    this.phase = 'idle',
    this.remainingSeconds = 0,
    this.pendingEvents = 0,
    this.errorMessage,
  });

  final NudgeDeviceConnectionStatus status;
  final String? deviceId;
  final String phase;
  final int remainingSeconds;
  final int pendingEvents;
  final String? errorMessage;

  NudgeDeviceCoordinatorState copyWith({
    NudgeDeviceConnectionStatus? status,
    String? deviceId,
    String? phase,
    int? remainingSeconds,
    int? pendingEvents,
    String? errorMessage,
    bool clearDevice = false,
    bool clearError = false,
  }) => NudgeDeviceCoordinatorState(
    status: status ?? this.status,
    deviceId: clearDevice ? null : deviceId ?? this.deviceId,
    phase: phase ?? this.phase,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    pendingEvents: pendingEvents ?? this.pendingEvents,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

class NudgeDeviceCoordinator extends ChangeNotifier {
  NudgeDeviceCoordinator({
    required NudgeBleTransport transport,
    required NudgeDeviceBridge bridge,
    ConnectedDeviceAssignmentValidator? validateAssignment,
    DateTime Function()? clock,
  }) : _transport = transport,
       _bridge = bridge,
       _validateAssignment = validateAssignment ?? ((_) async => true),
       _clock = clock ?? DateTime.now;

  final NudgeBleTransport _transport;
  final NudgeDeviceBridge _bridge;
  final ConnectedDeviceAssignmentValidator _validateAssignment;
  final DateTime Function() _clock;
  StreamSubscription<NudgeBleTransportEvent>? _subscription;
  Future<void> _eventTail = Future<void>.value();
  Future<void>? _closing;
  bool _draining = false;
  bool _disposed = false;
  bool _notifierDisposed = false;
  NudgeDeviceCoordinatorState _state = const NudgeDeviceCoordinatorState();

  NudgeDeviceCoordinatorState get state => _state;

  void _setState(NudgeDeviceCoordinatorState value) {
    _state = value;
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    _subscription ??= _transport.events.listen((event) {
      _eventTail = _eventTail
          .then((_) => _handleEvent(event))
          .catchError((Object error) => _fail(error.toString()));
    }, onError: (Object error) => _fail(error.toString()));
    _setState(
      _state.copyWith(
        status: NudgeDeviceConnectionStatus.scanning,
        clearError: true,
      ),
    );
    await _transport.scanAndConnect();
  }

  Future<void> _handleEvent(NudgeBleTransportEvent event) async {
    switch (event.type) {
      case NudgeBleEventType.scanning:
        _setState(
          _state.copyWith(
            status: NudgeDeviceConnectionStatus.scanning,
            clearError: true,
          ),
        );
      case NudgeBleEventType.connected:
        final deviceId = event.deviceId;
        if (deviceId == null || !await _validateAssignment(deviceId)) {
          await _transport.disconnect();
          _fail('這台 Nudge 裝置未指派給目前登入帳號。');
          return;
        }
        _setState(
          _state.copyWith(
            status: NudgeDeviceConnectionStatus.connected,
            deviceId: deviceId,
            clearError: true,
          ),
        );
      case NudgeBleEventType.disconnected:
        _setState(
          _state.copyWith(
            status: NudgeDeviceConnectionStatus.disconnected,
            pendingEvents: 0,
            clearDevice: true,
          ),
        );
      case NudgeBleEventType.error:
        _fail(event.message ?? 'BLE 裝置發生未知錯誤。');
      case NudgeBleEventType.state:
        await _applyDeviceState(event);
    }
  }

  Future<void> _applyDeviceState(NudgeBleTransportEvent event) async {
    try {
      if (_state.status != NudgeDeviceConnectionStatus.connected ||
          event.deviceId != _state.deviceId) {
        throw const FormatException(
          'Device state arrived before assignment validation.',
        );
      }
      final decoded = jsonDecode(event.payload!);
      if (decoded is! Map ||
          decoded['v'] != nudgeDeviceProtocolVersion ||
          !const {
            'idle',
            'running',
            'paused',
            'completed',
          }.contains(decoded['phase']) ||
          decoded['remaining'] is! int ||
          decoded['remaining'] < 0 ||
          decoded['pending'] is! int ||
          decoded['pending'] < 0 ||
          decoded['pending'] > 8) {
        throw const FormatException('Invalid compact device state.');
      }
      _setState(
        _state.copyWith(
          status: NudgeDeviceConnectionStatus.connected,
          deviceId: event.deviceId,
          phase: decoded['phase'] as String,
          remainingSeconds: decoded['remaining'] as int,
          pendingEvents: decoded['pending'] as int,
          clearError: true,
        ),
      );
      if (_state.pendingEvents > 0) await _drainPendingEvents();
    } catch (error) {
      _fail(error.toString());
    }
  }

  Future<void> _drainPendingEvents() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_state.pendingEvents > 0) {
        final eventJson = await _transport.readPendingEvent();
        if (eventJson.isEmpty) break;
        await _bridge.acceptEventJson(eventJson);
        _setState(
          _state.copyWith(
            pendingEvents: _state.pendingEvents - 1,
            clearError: true,
          ),
        );
      }
    } catch (error) {
      _fail(error.toString());
    } finally {
      _draining = false;
    }
  }

  Future<void> configureFocus({
    required String sessionId,
    required String activityCorrelationId,
    required int durationSeconds,
  }) async {
    final deviceId = _state.deviceId;
    if (_state.status != NudgeDeviceConnectionStatus.connected ||
        deviceId == null ||
        !await _validateAssignment(deviceId)) {
      throw StateError('目前沒有屬於此帳號的已連線 Nudge 裝置。');
    }
    if (durationSeconds < 60 || durationSeconds > 24 * 60 * 60) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    await _transport.writeCommand(
      jsonEncode({
        'protocolVersion': nudgeDeviceProtocolVersion,
        'type': 'configure',
        'sessionId': sessionId,
        'activityCorrelationId': activityCorrelationId,
        'durationSeconds': durationSeconds,
        'clockEpochMs': _clock().toUtc().millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> sendAction(String action) async {
    final deviceId = _state.deviceId;
    if (!const {'start', 'pause', 'resume', 'complete'}.contains(action) ||
        _state.status != NudgeDeviceConnectionStatus.connected ||
        deviceId == null) {
      throw StateError('目前無法傳送裝置動作。');
    }
    if (!await _validateAssignment(deviceId)) {
      await _transport.disconnect();
      _fail('裝置指派已失效，已中止控制並斷開連線。');
      throw StateError('裝置指派已失效，無法傳送裝置動作。');
    }
    await _transport.writeCommand(
      jsonEncode({
        'protocolVersion': nudgeDeviceProtocolVersion,
        'type': action,
      }),
    );
  }

  void _fail(String message) {
    _setState(
      _state.copyWith(
        status: NudgeDeviceConnectionStatus.error,
        errorMessage: message,
      ),
    );
  }

  Future<void> _closeResources() => _closing ??= () async {
    await _subscription?.cancel();
    await _eventTail;
    await _transport.disconnect();
  }();

  Future<void> close() async {
    _disposed = true;
    await _closeResources();
    if (!_notifierDisposed) {
      _notifierDisposed = true;
      super.dispose();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_closeResources());
    if (!_notifierDisposed) {
      _notifierDisposed = true;
      super.dispose();
    }
  }
}
