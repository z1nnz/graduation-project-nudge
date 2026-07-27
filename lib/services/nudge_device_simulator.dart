import '../models/activity_ledger.dart';
import 'activity_ingestion.dart';

class NudgeDeviceSimulator {
  final String deviceId;
  final String assignedUserId;
  final ActivityIngestion _ingestion;
  final DateTime Function() _clock;
  final List<ActivityEvidence> _pendingEvents = [];
  final List<ActivityRecordResult> _confirmedResults = [];

  bool _isOnline;
  int _eventSequence = 0;
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
    required List<String> roomIds,
    required ActivityType activityType,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
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
    required List<String> roomIds,
    required ActivityType activityType,
    required double metricValue,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
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
    required List<String> roomIds,
    required ActivityType activityType,
    required double metricValue,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
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
    required List<String> roomIds,
    required ActivityType activityType,
    required double metricValue,
    required String metricUnit,
  }) {
    _submitOrQueue(
      _buildEvidence(
        sessionId: sessionId,
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
        _confirmedResults.add(_ingestion.recordActivity(evidence));
        _pendingEvents.removeAt(0);
        _lastSyncError = null;
      } on Object catch (error) {
        _lastSyncError = error;
        break;
      }
    }
  }

  ActivityEvidence _buildEvidence({
    required String sessionId,
    required List<String> roomIds,
    required ActivityType activityType,
    required ActivityEventType eventType,
    required double metricValue,
    required String metricUnit,
  }) {
    _eventSequence++;
    final eventId = '$deviceId:$sessionId:${eventType.name}:$_eventSequence';
    return ActivityEvidence(
      eventId: eventId,
      sourceRecordId: eventId,
      sessionId: sessionId,
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
}
