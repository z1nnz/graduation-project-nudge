import 'package:cloud_functions/cloud_functions.dart';

import '../models/privacy_consent.dart';

typedef PrivacyConsentCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class PrivacyConsentException implements Exception {
  const PrivacyConsentException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PrivacyConsentException($code): $message';
}

class CloudPrivacyConsentGateway {
  const CloudPrivacyConsentGateway.withCallable(PrivacyConsentCallable call)
    : _call = call;

  final PrivacyConsentCallable _call;

  factory CloudPrivacyConsentGateway.firebase({FirebaseFunctions? functions}) {
    return CloudPrivacyConsentGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('recordPrivacyConsent');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<PrivacyConsentUpdateResult> update({
    required bool accepted,
    required String clientRequestId,
    String sourceSurface = 'app',
  }) async {
    try {
      final response = await _call({
        'action': accepted ? 'accept' : 'revoke',
        'policyVersion': currentPrivacyPolicyVersion,
        'clientRequestId': clientRequestId,
        'sourceSurface': sourceSurface,
      });
      if (response is! Map) {
        throw const PrivacyConsentException('protocol-error', '隱私同意服務回傳了無效資料。');
      }
      final result = PrivacyConsentUpdateResult.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (result.auditEventId.isEmpty ||
          result.consent.policyVersion != currentPrivacyPolicyVersion ||
          result.consent.isCurrentHealthConsent != accepted) {
        throw const PrivacyConsentException(
          'protocol-error',
          '隱私同意結果與本次操作不一致。',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw PrivacyConsentException(error.code, error.message ?? '無法更新隱私同意。');
    }
  }
}
