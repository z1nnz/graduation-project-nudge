import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_ledger.dart';
import 'activity_ingestion.dart';
import 'cloud_activity_ledger_gateway.dart';

class ActivityLedgerFlushReport {
  final List<ActivityRecordResult> succeeded;
  final int permanentlyRejected;
  final bool retryBlocked;

  const ActivityLedgerFlushReport({
    required this.succeeded,
    required this.permanentlyRejected,
    required this.retryBlocked,
  });
}

class _OutboxEntry {
  final ActivityEvidence evidence;
  final DateTime queuedAt;
  final int attempts;
  final String? lastError;

  const _OutboxEntry({
    required this.evidence,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
  });

  String get identity => jsonEncode([
    evidence.actorUserId.trim(),
    evidence.source.name,
    evidence.eventId.trim(),
  ]);

  _OutboxEntry failed(Object error) => _OutboxEntry(
    evidence: evidence,
    queuedAt: queuedAt,
    attempts: attempts + 1,
    lastError: error.toString(),
  );

  Map<String, dynamic> toJson() => {
    'evidence': evidence.toOutboxJson(),
    'queuedAt': queuedAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };

  factory _OutboxEntry.fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid outbox entry');
    final data = Map<String, dynamic>.from(raw);
    return _OutboxEntry(
      evidence: ActivityEvidence.fromOutboxJson(
        Map<Object?, Object?>.from(data['evidence'] as Map),
      ),
      queuedAt: DateTime.parse(data['queuedAt'] as String).toUtc(),
      attempts: data['attempts'] as int? ?? 0,
      lastError: data['lastError'] as String?,
    );
  }
}

class ActivityLedgerOutbox {
  static const _pendingKey = 'activity_ledger_outbox_v1';
  static const _deadLetterKey = 'activity_ledger_dead_letters_v1';

  final CloudActivityLedgerGateway gateway;
  final DateTime Function() _clock;
  final String? Function()? _getActorId;
  Future<ActivityLedgerFlushReport>? _activeFlush;
  Future<void> _operationTail = Future<void>.value();

  ActivityLedgerOutbox({
    required this.gateway,
    DateTime Function()? clock,
    String? Function()? getActorId,
  }) : _clock = clock ?? DateTime.now,
       _getActorId = getActorId;

  Future<T> _runExclusive<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<int> pendingCount() {
    return _runExclusive(() async => (await _loadPending()).length);
  }

  Future<void> cancel(ActivityEvidence evidence) {
    final identity = _OutboxEntry(
      evidence: evidence,
      queuedAt: _clock().toUtc(),
    ).identity;
    return _runExclusive(() async {
      final pending = await _loadPending();
      await _savePending(
        pending.where((entry) => entry.identity != identity).toList(),
      );
    });
  }

  bool _belongsToCurrentActor(_OutboxEntry entry) {
    final actorId = _getActorId?.call()?.trim();
    return _getActorId == null ||
        (actorId != null &&
            actorId.isNotEmpty &&
            entry.evidence.actorUserId == actorId &&
            entry.evidence.submittedByUserId == actorId);
  }

  Future<void> enqueue(ActivityEvidence evidence) {
    if (evidence.source != ActivitySource.app &&
        evidence.source != ActivitySource.web) {
      return Future<void>.error(
        const ActivityValidationException(
          'The user outbox only accepts App or Web activity evidence.',
        ),
      );
    }
    return _runExclusive(() async {
      final pending = await _loadPending();
      final entry = _OutboxEntry(
        evidence: evidence,
        queuedAt: _clock().toUtc(),
      );
      if (pending.any((item) => item.identity == entry.identity)) {
        return;
      }
      pending.add(entry);
      await _savePending(pending);
    });
  }

  Future<ActivityLedgerFlushReport> flush() {
    final active = _activeFlush;
    if (active != null) return active;
    late final Future<ActivityLedgerFlushReport> operation;
    operation = _flushInternal().whenComplete(() {
      if (identical(_activeFlush, operation)) {
        _activeFlush = null;
      }
    });
    _activeFlush = operation;
    return operation;
  }

  Future<ActivityLedgerFlushReport> _flushInternal() async {
    final succeeded = <ActivityRecordResult>[];
    var permanentlyRejected = 0;
    while (true) {
      final pending = await _runExclusive(_loadPending);
      if (pending.isEmpty) {
        return ActivityLedgerFlushReport(
          succeeded: List.unmodifiable(succeeded),
          permanentlyRejected: permanentlyRejected,
          retryBlocked: false,
        );
      }

      final batch = _getActorId == null
          ? pending
          : pending.where(_belongsToCurrentActor).toList();
      if (batch.isEmpty) {
        return ActivityLedgerFlushReport(
          succeeded: List.unmodifiable(succeeded),
          permanentlyRejected: permanentlyRejected,
          retryBlocked: false,
        );
      }

      final retained = <_OutboxEntry>[];
      var retryBlocked = false;
      for (var index = 0; index < batch.length; index++) {
        final entry = batch[index];
        try {
          succeeded.add(await gateway.recordActivity(entry.evidence));
        } on ActivityCloudRetryableException catch (error) {
          retained.add(entry.failed(error));
          retained.addAll(batch.skip(index + 1));
          retryBlocked = true;
          break;
        } on ActivityAuthorizationException catch (error) {
          if (!_belongsToCurrentActor(entry)) {
            retained.add(entry.failed(error));
            retained.addAll(batch.skip(index + 1));
            break;
          }
          await _deadLetter(entry, error);
          permanentlyRejected++;
        } on ActivityValidationException catch (error) {
          await _deadLetter(entry, error);
          permanentlyRejected++;
        } on ActivityCloudProtocolException catch (error) {
          await _deadLetter(entry, error);
          permanentlyRejected++;
        } catch (error) {
          retained.add(entry.failed(error));
          retained.addAll(batch.skip(index + 1));
          retryBlocked = true;
          break;
        }
      }
      await _runExclusive(() async {
        final current = await _loadPending();
        final flushedIdentities = batch.map((entry) => entry.identity).toSet();
        final queuedDuringFlush = current
            .where((entry) => !flushedIdentities.contains(entry.identity))
            .toList();
        await _savePending([...retained, ...queuedDuringFlush]);
      });
      if (retryBlocked) {
        return ActivityLedgerFlushReport(
          succeeded: List.unmodifiable(succeeded),
          permanentlyRejected: permanentlyRejected,
          retryBlocked: true,
        );
      }
    }
  }

  Future<List<_OutboxEntry>> _loadPending() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_pendingKey);
    if (encoded == null || encoded.isEmpty) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return [];
    return decoded.map(_OutboxEntry.fromJson).toList();
  }

  Future<void> _savePending(List<_OutboxEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _deadLetter(_OutboxEntry entry, Object error) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_deadLetterKey);
    final decoded = encoded == null || encoded.isEmpty
        ? <dynamic>[]
        : jsonDecode(encoded) as List;
    decoded.add({
      ...entry.failed(error).toJson(),
      'failedAt': _clock().toUtc().toIso8601String(),
    });
    if (decoded.length > 100) {
      decoded.removeRange(0, decoded.length - 100);
    }
    await preferences.setString(_deadLetterKey, jsonEncode(decoded));
  }
}
