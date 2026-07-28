import 'package:cloud_functions/cloud_functions.dart';

import '../models/activity_ledger.dart';
import '../models/health_activity_snapshot.dart';
import 'activity_ingestion.dart';
import 'cloud_activity_ledger_gateway.dart';

typedef HealthSnapshotCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class CloudHealthSnapshotGateway {
  final HealthSnapshotCallable _call;

  const CloudHealthSnapshotGateway.withCallable(HealthSnapshotCallable call)
    : _call = call;

  factory CloudHealthSnapshotGateway.firebase({FirebaseFunctions? functions}) {
    return CloudHealthSnapshotGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('ingestHealthSnapshots');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<List<ActivityRecordResult>> ingest(
    List<HealthActivitySnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty || snapshots.length > 12) {
      throw const ActivityValidationException(
        'Health ingestion requires between 1 and 12 snapshots.',
      );
    }
    final provider = snapshots.first.provider;
    if (snapshots.any((snapshot) => snapshot.provider != provider)) {
      throw const ActivityValidationException(
        'One health batch cannot mix providers.',
      );
    }
    try {
      final response = await _call({
        'provider': provider.cloudName,
        'snapshots': snapshots
            .map((snapshot) => snapshot.toCloudJson())
            .toList(),
      });
      if (response is! Map || response['results'] is! List) {
        throw const ActivityCloudProtocolException(
          'ingestHealthSnapshots returned an invalid response.',
        );
      }
      final results = (response['results'] as List)
          .map((raw) {
            if (raw is! Map) {
              throw const ActivityCloudProtocolException(
                'ingestHealthSnapshots returned a non-object result.',
              );
            }
            return ActivityRecordResult.fromCloudJson(raw);
          })
          .toList(growable: false);
      if (results.length != snapshots.length) {
        throw const ActivityCloudProtocolException(
          'ingestHealthSnapshots returned an incomplete response.',
        );
      }
      return results;
    } on FirebaseFunctionsException catch (error) {
      switch (error.code) {
        case 'unauthenticated':
        case 'permission-denied':
          throw ActivityAuthorizationException(
            error.message ?? 'Health ingestion is not authorized.',
          );
        case 'invalid-argument':
        case 'failed-precondition':
          throw ActivityValidationException(
            error.message ?? 'Health snapshots were rejected.',
          );
        case 'aborted':
        case 'deadline-exceeded':
        case 'resource-exhausted':
        case 'unavailable':
          throw ActivityCloudRetryableException(
            error.code,
            error.message ?? 'Health ingestion should be retried.',
          );
        default:
          throw ActivityCloudProtocolException(
            error.message ?? 'Health ingestion failed unexpectedly.',
          );
      }
    }
  }
}
