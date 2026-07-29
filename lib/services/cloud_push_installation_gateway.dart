import 'package:cloud_functions/cloud_functions.dart';

import '../models/push_installation.dart';

typedef PushInstallationCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class PushInstallationException implements Exception {
  const PushInstallationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PushInstallationException($code): $message';
}

class CloudPushInstallationGateway {
  const CloudPushInstallationGateway.withCallable(PushInstallationCallable call)
    : _call = call;

  final PushInstallationCallable _call;

  factory CloudPushInstallationGateway.firebase({
    FirebaseFunctions? functions,
  }) {
    return CloudPushInstallationGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('updatePushInstallation');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<PushInstallationUpdateResult> register({
    required String installationId,
    required String platform,
    required String token,
    required String clientRequestId,
  }) {
    return _update({
      'action': 'register',
      'installationId': installationId,
      'platform': platform,
      'token': token,
      'clientRequestId': clientRequestId,
    });
  }

  Future<PushInstallationUpdateResult> revoke({
    required String installationId,
    required String clientRequestId,
  }) {
    return _update({
      'action': 'revoke',
      'installationId': installationId,
      'clientRequestId': clientRequestId,
    });
  }

  Future<PushInstallationUpdateResult> _update(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _call(payload);
      if (response is! Map) {
        throw const PushInstallationException(
          'protocol-error',
          '裝置推播服務回傳了無效資料。',
        );
      }
      final result = PushInstallationUpdateResult.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (result.installationId != payload['installationId'] ||
          result.action != payload['action'] ||
          result.auditEventId.isEmpty) {
        throw const PushInstallationException(
          'protocol-error',
          '裝置推播結果缺少必要的稽核資料。',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw PushInstallationException(
        error.code,
        error.message ?? '無法更新裝置推播設定。',
      );
    }
  }
}
