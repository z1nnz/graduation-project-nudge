import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/activity_ledger.dart';
import 'android_nudge_ble_transport.dart';
import 'nudge_device_bridge.dart';
import 'nudge_device_presentation.dart';
import 'nudge_device_protocol.dart';

typedef ConnectedDeviceAssignmentValidator =
    Future<bool> Function(String deviceId);
typedef ConnectedDeviceAssignmentResolver =
    Future<DeviceAssignmentGrant?> Function(String deviceId);

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
    this.selectedRoomId,
    this.contextRevision = 0,
  });

  final NudgeDeviceConnectionStatus status;
  final String? deviceId;
  final String phase;
  final int remainingSeconds;
  final int pendingEvents;
  final String? errorMessage;
  final String? selectedRoomId;
  final int contextRevision;

  NudgeDeviceCoordinatorState copyWith({
    NudgeDeviceConnectionStatus? status,
    String? deviceId,
    String? phase,
    int? remainingSeconds,
    int? pendingEvents,
    String? errorMessage,
    String? selectedRoomId,
    int? contextRevision,
    bool clearDevice = false,
    bool clearError = false,
    bool clearSelectedRoom = false,
  }) => NudgeDeviceCoordinatorState(
    status: status ?? this.status,
    deviceId: clearDevice ? null : deviceId ?? this.deviceId,
    phase: phase ?? this.phase,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    pendingEvents: pendingEvents ?? this.pendingEvents,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    selectedRoomId: clearSelectedRoom
        ? null
        : selectedRoomId ?? this.selectedRoomId,
    contextRevision: contextRevision ?? this.contextRevision,
  );
}

class NudgeDeviceCoordinator extends ChangeNotifier {
  NudgeDeviceCoordinator({
    required NudgeBleTransport transport,
    required NudgeDeviceBridge bridge,
    ConnectedDeviceAssignmentValidator? validateAssignment,
    ConnectedDeviceAssignmentResolver? resolveAssignment,
    DateTime Function()? clock,
    Duration contextAckTimeout = const Duration(seconds: 5),
  }) : _transport = transport,
       _bridge = bridge,
       _validateAssignment = validateAssignment ?? ((_) async => true),
       _resolveAssignment = resolveAssignment,
       _clock = clock ?? DateTime.now,
       _contextAckTimeout = contextAckTimeout;

  final NudgeBleTransport _transport;
  final NudgeDeviceBridge _bridge;
  final ConnectedDeviceAssignmentValidator _validateAssignment;
  final ConnectedDeviceAssignmentResolver? _resolveAssignment;
  final DateTime Function() _clock;
  final Duration _contextAckTimeout;
  StreamSubscription<NudgeBleTransportEvent>? _subscription;
  Future<void> _eventTail = Future<void>.value();
  Future<void>? _closing;
  bool _draining = false;
  bool _disposed = false;
  bool _notifierDisposed = false;
  bool _hasObservedDeviceState = false;
  int _lastContextRevision = 0;
  final Map<int, Completer<void>> _contextAcknowledgements = {};
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
        _hasObservedDeviceState = false;
      case NudgeBleEventType.disconnected:
        _hasObservedDeviceState = false;
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
            'unconfigured',
            'idle',
            'running',
            'paused',
            'completed',
          }.contains(decoded['phase']) ||
          decoded['remaining'] is! int ||
          decoded['remaining'] < 0 ||
          decoded['pending'] is! int ||
          decoded['pending'] < 0 ||
          decoded['pending'] > 8 ||
          (decoded['contextRevision'] ?? 0) is! int ||
          (decoded['contextRevision'] ?? 0) < 0 ||
          (decoded['contextRevision'] ?? 0) > 0x7FFFFFFFFFFFFFFF) {
        throw const FormatException('Invalid compact device state.');
      }
      final selectedRoomValue = decoded['selectedRoomId'] ?? '';
      final contextRevision = (decoded['contextRevision'] ?? 0) as int;
      if (selectedRoomValue is! String ||
          (selectedRoomValue.isNotEmpty &&
              !isValidNudgeDeviceIdentifier(selectedRoomValue))) {
        throw const FormatException('Invalid selected device room.');
      }
      _setState(
        _state.copyWith(
          status: NudgeDeviceConnectionStatus.connected,
          deviceId: event.deviceId,
          phase: decoded['phase'] as String,
          remainingSeconds: decoded['remaining'] as int,
          pendingEvents: decoded['pending'] as int,
          selectedRoomId: selectedRoomValue,
          contextRevision: contextRevision,
          clearError: true,
        ),
      );
      _hasObservedDeviceState = true;
      if (_lastContextRevision < contextRevision) {
        _lastContextRevision = contextRevision;
      }
      final acknowledgement = _contextAcknowledgements[contextRevision];
      if (acknowledgement != null && !acknowledgement.isCompleted) {
        acknowledgement.complete();
      }
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
    String? roomContextId,
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
    if (roomContextId != null) {
      final assignment = await _resolveAssignment?.call(deviceId);
      if (assignment == null ||
          assignment.deviceId != deviceId ||
          !assignment.allowsActivityAt(_clock()) ||
          !assignment.allowedRoomIds.contains(roomContextId)) {
        throw StateError('選取的房間不在目前裝置指派範圍內。');
      }
    }
    await _transport.writeCommand(
      jsonEncode({
        'protocolVersion': nudgeDeviceProtocolVersion,
        'type': 'configure',
        'sessionId': sessionId,
        'activityCorrelationId': activityCorrelationId,
        'durationSeconds': durationSeconds,
        'clockEpochMs': _clock().toUtc().millisecondsSinceEpoch,
        ...?roomContextId == null
            ? null
            : <String, Object>{'roomContextId': roomContextId},
      }),
    );
  }

  Future<String?> syncPresentation(NudgeDevicePresentation candidate) async {
    final deviceId = _state.deviceId;
    final assignment = deviceId == null
        ? null
        : await _resolveAssignment?.call(deviceId);
    if (_state.status != NudgeDeviceConnectionStatus.connected ||
        assignment == null ||
        assignment.deviceId != deviceId ||
        !assignment.allowsActivityAt(_clock())) {
      throw StateError('目前沒有可同步畫面的有效裝置指派。');
    }
    final canonical = candidate.forAllowedRooms(
      assignment.allowedRoomIds.toSet(),
    );
    await _writeContextMutation(
      (revision) => canonical.encodeCommand(contextRevision: revision),
    );
    return canonical.selectedRoomId;
  }

  Future<void> syncSoundEnabled(bool enabled) async {
    final deviceId = _state.deviceId;
    final assignment = deviceId == null
        ? null
        : await _resolveAssignment?.call(deviceId);
    if (_state.status != NudgeDeviceConnectionStatus.connected ||
        assignment == null ||
        assignment.deviceId != deviceId ||
        !assignment.allowsActivityAt(_clock())) {
      throw StateError('目前沒有可同步提示音的有效裝置指派。');
    }
    await _writeContextMutation(
      (revision) => jsonEncode({
        'protocolVersion': nudgeDeviceProtocolVersion,
        'type': 'sound',
        'enabled': enabled,
        'contextRevision': revision,
      }),
    );
  }

  Future<void> _writeContextMutation(String Function(int) encode) async {
    if (!_hasObservedDeviceState) {
      throw StateError('尚未讀到裝置目前的持久化版本，請稍候再試。');
    }
    if (_contextAcknowledgements.isNotEmpty) {
      throw StateError('另一筆裝置畫面設定仍在等待確認。');
    }
    final clockRevision = _clock().toUtc().microsecondsSinceEpoch;
    final revision = clockRevision > _lastContextRevision
        ? clockRevision
        : _lastContextRevision + 1;
    if (revision > 0x7FFFFFFFFFFFFFFF) {
      throw StateError('裝置畫面版本已耗盡，請重設裝置。');
    }
    _lastContextRevision = revision;
    final acknowledgement = Completer<void>();
    _contextAcknowledgements[revision] = acknowledgement;
    try {
      await _transport.writeCommand(encode(revision));
      await acknowledgement.future.timeout(
        _contextAckTimeout,
        onTimeout: () => throw StateError('裝置未確認畫面已安全保存，已停止後續設定。'),
      );
    } finally {
      _contextAcknowledgements.remove(revision);
    }
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
    for (final acknowledgement in _contextAcknowledgements.values) {
      if (!acknowledgement.isCompleted) {
        acknowledgement.completeError(StateError(message));
      }
    }
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
