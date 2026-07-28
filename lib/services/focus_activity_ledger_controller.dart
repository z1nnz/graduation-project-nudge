import '../models/activity_ledger.dart';

typedef FocusActivityLedgerEventSink =
    Future<void> Function({
      required String sessionId,
      required ActivityEventType eventType,
      required int elapsedSeconds,
      required DateTime occurredAt,
    });

class FocusActivityLedgerController {
  final FocusActivityLedgerEventSink _eventSink;
  final DateTime Function() _clock;
  final String Function(DateTime now) _sessionIdFactory;

  String? _sessionId;
  bool _isPaused = false;

  FocusActivityLedgerController({
    required FocusActivityLedgerEventSink eventSink,
    DateTime Function()? clock,
    String Function(DateTime now)? sessionIdFactory,
  }) : _eventSink = eventSink,
       _clock = clock ?? DateTime.now,
       _sessionIdFactory =
           sessionIdFactory ??
           ((now) => 'focus_${now.toUtc().microsecondsSinceEpoch}');

  bool get hasActiveSession => _sessionId != null;
  String? get sessionId => _sessionId;

  Future<void> startOrResume({required int elapsedSeconds}) {
    final now = _clock().toUtc();
    if (_sessionId == null) {
      _sessionId = _sessionIdFactory(now);
      _isPaused = false;
      return _emit(
        sessionId: _sessionId!,
        eventType: ActivityEventType.started,
        elapsedSeconds: 0,
        occurredAt: now,
      );
    }
    if (!_isPaused) return Future<void>.value();
    _isPaused = false;
    return _emit(
      sessionId: _sessionId!,
      eventType: ActivityEventType.resumed,
      elapsedSeconds: elapsedSeconds,
      occurredAt: now,
    );
  }

  Future<void> pause({required int elapsedSeconds}) {
    final sessionId = _sessionId;
    if (sessionId == null || _isPaused) return Future<void>.value();
    _isPaused = true;
    return _emit(
      sessionId: sessionId,
      eventType: ActivityEventType.paused,
      elapsedSeconds: elapsedSeconds,
      occurredAt: _clock().toUtc(),
    );
  }

  Future<void> complete({required int elapsedSeconds}) {
    return _finish(
      eventType: ActivityEventType.completed,
      elapsedSeconds: elapsedSeconds,
    );
  }

  Future<void> discard({required int elapsedSeconds}) {
    return _finish(
      eventType: ActivityEventType.discarded,
      elapsedSeconds: elapsedSeconds,
    );
  }

  Future<void> _finish({
    required ActivityEventType eventType,
    required int elapsedSeconds,
  }) {
    final sessionId = _sessionId;
    if (sessionId == null) return Future<void>.value();
    _sessionId = null;
    _isPaused = false;
    return _emit(
      sessionId: sessionId,
      eventType: eventType,
      elapsedSeconds: elapsedSeconds,
      occurredAt: _clock().toUtc(),
    );
  }

  Future<void> _emit({
    required String sessionId,
    required ActivityEventType eventType,
    required int elapsedSeconds,
    required DateTime occurredAt,
  }) {
    return _eventSink(
      sessionId: sessionId,
      eventType: eventType,
      elapsedSeconds: elapsedSeconds < 0 ? 0 : elapsedSeconds,
      occurredAt: occurredAt,
    );
  }
}
