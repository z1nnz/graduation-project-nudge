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
    final events = List<ActivityEvidence>.from(_pendingEvents);
    for (final evidence in events) {
      _confirmedResults.add(_ingestion.recordActivity(evidence));
      _pendingEvents.remove(evidence);
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
    return ActivityEvidence(
      eventId: '$deviceId-event-$_eventSequence',
      sourceRecordId: '$deviceId:$sessionId:${eventType.name}',
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
    if (_isOnline) {
      _confirmedResults.add(_ingestion.recordActivity(evidence));
      return;
    }
    _pendingEvents.add(evidence);
  }
}
