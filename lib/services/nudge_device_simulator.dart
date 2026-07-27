import '../models/activity_ledger.dart';
import 'activity_ingestion.dart';

class DeviceTransportException implements Exception {
  final String message;

  const DeviceTransportException(this.message);

  @override
  String toString() => 'DeviceTransportException: $message';
}

class DeviceProtocolException implements Exception {
  final String message;

  const DeviceProtocolException(this.message);

  @override
  String toString() => 'DeviceProtocolException: $message';
}

class DeviceFailedEvent {
  final ActivityEvidence evidence;
  final Object error;

  const DeviceFailedEvent({required this.evidence, required this.error});
}

class NudgeDeviceSimulator {
  static final Map<String, int> _eventSequencesByDevice = {};

  final String deviceId;
  final String assignedUserId;
  final ActivityIngestion _ingestion;
  final DateTime Function() _clock;
  final List<ActivityEvidence> _pendingEvents = [];
  final List<ActivityRecordResult> _confirmedResults = [];
  final List<DeviceFailedEvent> _failedEvents = [];

  bool _isOnline;
  Object? _lastSyncError;

  NudgeDeviceSimulator({
    required this.deviceId,
    required this.assignedUserId,
    required ActivityIngestion ingestion,
    DateTime Function()? clock,
    bool startsOnline = true,
  }) : _ingestion = ingestion,
       _clock = clock ?? DateTime.now,
       _isOnline = startsOnline;

  bool get isOnline => _isOnline;

  int get pendingEventCount => _pendingEvents.length;

  Object? get lastSyncError => _lastSyncError;

  List<DeviceFailedEvent> get failedEvents => List.unmodifiable(_failedEvents);

  List<ActivityRecordResult> get confirmedResults =>
      List.unmodifiable(_confirmedResults);

  void setOnline(bool value) {
    _isOnline = value;
    if (value) {
      flush();
    }
  }

  void startActivity({
    required String sessionId,
    String? activityCorrelationId,
    required List<String> roomIds,
    required ActivityType activityType,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
        activityCorrelationId: activityCorrelationId,
        roomIds: roomIds,
        activityType: activityType,
        eventType: ActivityEventType.started,
        metricValue: 0,
        metricUnit: metricUnit,
      ),
    );
  }

  void completeActivity({
    required String sessionId,
    String? activityCorrelationId,
    required List<String> roomIds,
    required ActivityType activityType,
    required double metricValue,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
        activityCorrelationId: activityCorrelationId,
        roomIds: roomIds,
        activityType: activityType,
        eventType: ActivityEventType.completed,
        metricValue: metricValue,
        metricUnit: metricUnit,
      ),
    );
  }

  void pauseActivity({
    required String sessionId,
    String? activityCorrelationId,
    required List<String> roomIds,
    required ActivityType activityType,
    required double metricValue,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
        activityCorrelationId: activityCorrelationId,
        roomIds: roomIds,
        activityType: activityType,
        eventType: ActivityEventType.paused,
        metricValue: metricValue,
        metricUnit: metricUnit,
      ),
    );
  }

  void resumeActivity({
    required String sessionId,
    String? activityCorrelationId,
    required List<String> roomIds,
    required ActivityType activityType,
    required double metricValue,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
        activityCorrelationId: activityCorrelationId,
        roomIds: roomIds,
        activityType: activityType,
        eventType: ActivityEventType.resumed,
        metricValue: metricValue,
        metricUnit: metricUnit,
      ),
    );
  }

  void flush() {
    if (!_isOnline || _pendingEvents.isEmpty) return;
    while (_pendingEvents.isNotEmpty) {
      final evidence = _pendingEvents.first;
      try {
        final result = _ingestion.recordActivity(evidence);
        _validateAcknowledgement(evidence, result);
        _confirmedResults.add(result);
        _pendingEvents.removeAt(0);
        _lastSyncError = null;
      } on DeviceTransportException catch (error) {
        _lastSyncError = error;
        break;
      } on ActivityAuthorizationException catch (error) {
        _moveHeadToFailed(error);
      } on ActivityValidationException catch (error) {
        _moveHeadToFailed(error);
      } on DeviceProtocolException catch (error) {
        _moveHeadToFailed(error);
      } on Object catch (error) {
        _lastSyncError = error;
        break;
      }
    }
  }

  ActivityEvidence _buildEvidence({
    required String sessionId,
    required String? activityCorrelationId,
    required List<String> roomIds,
    required ActivityType activityType,
    required ActivityEventType eventType,
    required double metricValue,
    required String metricUnit,
  }) {
    final eventSequence = (_eventSequencesByDevice[deviceId] ?? 0) + 1;
    _eventSequencesByDevice[deviceId] = eventSequence;
    final eventId = '$deviceId:$sessionId:${eventType.name}:$eventSequence';
    return ActivityEvidence(
      eventId: eventId,
      sourceRecordId: eventId,
      sessionId: sessionId,
      activityCorrelationId: activityCorrelationId,
      submittedByUserId: 'device:$deviceId',
      actorUserId: assignedUserId,
      roomIds: List.unmodifiable(roomIds),
      activityType: activityType,
      source: ActivitySource.device,
      eventType: eventType,
      metricValue: metricValue,
      metricUnit: metricUnit,
      occurredAt: _clock(),
      deviceId: deviceId,
    );
  }

  void _submitOrQueue(ActivityEvidence evidence) {
    _pendingEvents.add(evidence);
    if (_isOnline) {
      flush();
    }
  }

  void _validateAcknowledgement(
    ActivityEvidence evidence,
    ActivityRecordResult result,
  ) {
    final isSettlement =
        evidence.eventType == ActivityEventType.completed ||
        evidence.eventType == ActivityEventType.metricSynced;
    if (isSettlement) {
      final receipt = result.receipt;
      if (result.status != ActivityRecordStatus.settled ||
          receipt == null ||
          result.acknowledgedEventId != evidence.eventId ||
          result.acknowledgedSourceRecordId != evidence.sourceRecordId ||
          receipt.actorUserId != evidence.actorUserId ||
          receipt.activityType != evidence.activityType ||
          receipt.sessionId != result.canonicalSessionId) {
        throw const DeviceProtocolException(
          'A terminal activity requires a matching settlement receipt.',
        );
      }
      return;
    }
    if (result.status != ActivityRecordStatus.accepted ||
        result.receipt != null ||
        result.acknowledgedEventId != evidence.eventId ||
        result.acknowledgedSourceRecordId != evidence.sourceRecordId) {
      throw const DeviceProtocolException(
        'A lifecycle event requires a non-settlement acknowledgement.',
      );
    }
  }

  void _moveHeadToFailed(Object error) {
    final evidence = _pendingEvents.removeAt(0);
    _failedEvents.add(DeviceFailedEvent(evidence: evidence, error: error));
    _lastSyncError = error;
  }
}
