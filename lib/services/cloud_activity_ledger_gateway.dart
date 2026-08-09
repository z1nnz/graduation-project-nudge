import 'package:cloud_functions/cloud_functions.dart';

import '../models/activity_ledger.dart';
import 'activity_ingestion.dart';

typedef ActivityLedgerCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class ActivityCloudProtocolException implements Exception {
  final String message;

  const ActivityCloudProtocolException(this.message);

  @override
  String toString() => 'ActivityCloudProtocolException: $message';
}

class ActivityCloudRetryableException implements Exception {
  final String code;
  final String message;

  const ActivityCloudRetryableException(this.code, this.message);

  @override
  String toString() => 'ActivityCloudRetryableException($code): $message';
}

class CloudActivityLedgerGateway {
  final ActivityLedgerCallable _call;

  const CloudActivityLedgerGateway.withCallable(ActivityLedgerCallable call)
    : _call = call;

  factory CloudActivityLedgerGateway.firebase({FirebaseFunctions? functions}) {
    return CloudActivityLedgerGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('recordActivity');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<ActivityRecordResult> recordActivity(
    ActivityEvidence evidence, {
    Map<String, dynamic>? roomSession,
  }) async {
    try {
      final response = await _call({
        'evidence': {...evidence.toCloudJson(), 'roomSession': ?roomSession},
      });
      if (response is! Map) {
        throw const ActivityCloudProtocolException(
          'recordActivity returned a non-object response.',
        );
      }
      return ActivityRecordResult.fromCloudJson(response);
    } on FirebaseFunctionsException catch (error) {
      switch (error.code) {
        case 'unauthenticated':
        case 'permission-denied':
          throw ActivityAuthorizationException(
            error.message ?? 'Activity ingestion is not authorized.',
          );
        case 'invalid-argument':
        case 'failed-precondition':
          throw ActivityValidationException(
            error.message ?? 'Activity evidence was rejected.',
          );
        case 'aborted':
        case 'deadline-exceeded':
        case 'resource-exhausted':
        case 'unavailable':
          throw ActivityCloudRetryableException(
            error.code,
            error.message ?? 'Activity ingestion should be retried.',
          );
        default:
          throw ActivityCloudProtocolException(
            error.message ?? 'Activity ingestion failed unexpectedly.',
          );
      }
    }
  }
}
