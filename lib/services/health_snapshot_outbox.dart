import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_ledger.dart';
import '../models/health_activity_snapshot.dart';
import 'activity_ingestion.dart';
import 'cloud_activity_ledger_gateway.dart';
import 'cloud_health_snapshot_gateway.dart';

class HealthSnapshotFlushReport {
  final List<ActivityRecordResult> succeeded;
  final int permanentlyRejected;
  final bool retryBlocked;

  const HealthSnapshotFlushReport({
    required this.succeeded,
    required this.permanentlyRejected,
    required this.retryBlocked,
  });
}

class _HealthOutboxEntry {
  final HealthActivitySnapshot snapshot;
  final DateTime queuedAt;
  final int attempts;
  final String? lastError;

  const _HealthOutboxEntry({
    required this.snapshot,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
  });

  String get identity => jsonEncode(snapshot.toOutboxJson());

  _HealthOutboxEntry failed(Object error) => _HealthOutboxEntry(
    snapshot: snapshot,
    queuedAt: queuedAt,
    attempts: attempts + 1,
    lastError: error.toString(),
  );

  Map<String, dynamic> toJson() => {
    'snapshot': snapshot.toOutboxJson(),
    'queuedAt': queuedAt.toUtc().toIso8601String(),
    'attempts': attempts,
    'lastError': lastError,
  };

  factory _HealthOutboxEntry.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid health outbox entry.');
    }
    final data = Map<String, dynamic>.from(raw);
    return _HealthOutboxEntry(
      snapshot: HealthActivitySnapshot.fromOutboxJson(
        Map<Object?, Object?>.from(data['snapshot'] as Map),
      ),
      queuedAt: DateTime.parse(data['queuedAt'] as String).toUtc(),
      attempts: data['attempts'] as int? ?? 0,
      lastError: data['lastError'] as String?,
    );
  }
}

class HealthSnapshotOutbox {
  static const _pendingKey = 'health_snapshot_outbox_v1';
  static const _deadLetterKey = 'health_snapshot_dead_letters_v1';

  final CloudHealthSnapshotGateway gateway;
  final DateTime Function() _clock;
  Future<void> _operationTail = Future<void>.value();
  Future<HealthSnapshotFlushReport>? _activeFlush;

  HealthSnapshotOutbox({required this.gateway, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

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

  Future<void> enqueueAll(List<HealthActivitySnapshot> snapshots) {
    return _runExclusive(() async {
      final pending = await _loadPending();
      final identities = pending.map((entry) => entry.identity).toSet();
      for (final snapshot in snapshots) {
        final entry = _HealthOutboxEntry(
          snapshot: snapshot,
          queuedAt: _clock().toUtc(),
        );
        if (identities.add(entry.identity)) pending.add(entry);
      }
      await _savePending(pending);
    });
  }

  Future<HealthSnapshotFlushReport> flush() {
    final active = _activeFlush;
    if (active != null) return active;
    late final Future<HealthSnapshotFlushReport> operation;
    operation = _flushInternal().whenComplete(() {
      if (identical(_activeFlush, operation)) _activeFlush = null;
    });
    _activeFlush = operation;
    return operation;
  }

  Future<HealthSnapshotFlushReport> _flushInternal() async {
    final succeeded = <ActivityRecordResult>[];
    var permanentlyRejected = 0;
    while (true) {
      final pending = await _runExclusive(_loadPending);
      if (pending.isEmpty) {
        return HealthSnapshotFlushReport(
          succeeded: List.unmodifiable(succeeded),
          permanentlyRejected: permanentlyRejected,
          retryBlocked: false,
        );
      }
      final provider = pending.first.snapshot.provider;
      final batch = pending
          .where((entry) => entry.snapshot.provider == provider)
          .take(12)
          .toList();
      var retainedBatch = <_HealthOutboxEntry>[];
      var retryBlocked = false;
      try {
        succeeded.addAll(
          await gateway.ingest(
            batch.map((entry) => entry.snapshot).toList(growable: false),
          ),
        );
      } on ActivityCloudRetryableException catch (error) {
        retainedBatch = batch.map((entry) => entry.failed(error)).toList();
        retryBlocked = true;
      } on ActivityAuthorizationException catch (error) {
        await _deadLetterAll(batch, error);
        permanentlyRejected += batch.length;
      } on ActivityValidationException catch (error) {
        await _deadLetterAll(batch, error);
        permanentlyRejected += batch.length;
      } on ActivityCloudProtocolException catch (error) {
        await _deadLetterAll(batch, error);
        permanentlyRejected += batch.length;
      } catch (error) {
        retainedBatch = batch.map((entry) => entry.failed(error)).toList();
        retryBlocked = true;
      }
      await _runExclusive(() async {
        final current = await _loadPending();
        final batchIdentities = batch.map((entry) => entry.identity).toSet();
        final remaining = current
            .where((entry) => !batchIdentities.contains(entry.identity))
            .toList();
        await _savePending([...retainedBatch, ...remaining]);
      });
      if (retryBlocked) {
        return HealthSnapshotFlushReport(
          succeeded: List.unmodifiable(succeeded),
          permanentlyRejected: permanentlyRejected,
          retryBlocked: true,
        );
      }
    }
  }

  Future<List<_HealthOutboxEntry>> _loadPending() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_pendingKey);
    if (encoded == null || encoded.isEmpty) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return [];
    return decoded.map(_HealthOutboxEntry.fromJson).toList();
  }

  Future<void> _savePending(List<_HealthOutboxEntry> entries) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _pendingKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<void> _deadLetterAll(
    List<_HealthOutboxEntry> entries,
    Object error,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_deadLetterKey);
    final decoded = encoded == null || encoded.isEmpty
        ? <dynamic>[]
        : jsonDecode(encoded) as List;
    for (final entry in entries) {
      decoded.add({
        ...entry.failed(error).toJson(),
        'failedAt': _clock().toUtc().toIso8601String(),
      });
    }
    if (decoded.length > 100) {
      decoded.removeRange(0, decoded.length - 100);
    }
    await preferences.setString(_deadLetterKey, jsonEncode(decoded));
  }
}
