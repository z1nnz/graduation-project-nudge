import 'package:cloud_functions/cloud_functions.dart';

import '../models/discipline_identity_snapshot.dart';

typedef DisciplineIdentityCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class DisciplineIdentityException implements Exception {
  const DisciplineIdentityException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DisciplineIdentityException($code): $message';
}

class CloudDisciplineIdentityGateway {
  const CloudDisciplineIdentityGateway.withCallable(
    DisciplineIdentityCallable call,
  ) : _call = call;

  final DisciplineIdentityCallable _call;

  factory CloudDisciplineIdentityGateway.firebase({
    FirebaseFunctions? functions,
  }) {
    return CloudDisciplineIdentityGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('refreshDisciplineIdentity');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<DisciplineIdentitySnapshot> refresh({
    required String expectedUserId,
  }) async {
    if (expectedUserId.trim().isEmpty) {
      throw const DisciplineIdentityException(
        'invalid-argument',
        '必須先登入才能更新自律人格。',
      );
    }
    try {
      final response = await _call(const <String, dynamic>{});
      if (response is! Map || response['snapshot'] is! Map) {
        throw const DisciplineIdentityException(
          'protocol-error',
          '自律人格服務回傳了無效資料。',
        );
      }
      final snapshot = (response['snapshot'] as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return DisciplineIdentitySnapshot.fromMap(
        snapshot,
        expectedUserId: expectedUserId.trim(),
      );
    } on FirebaseFunctionsException catch (error) {
      throw DisciplineIdentityException(
        error.code,
        error.message ?? '無法更新自律人格。',
      );
    } on DisciplineIdentityException {
      rethrow;
    } catch (_) {
      throw const DisciplineIdentityException(
        'protocol-error',
        '自律人格資料不完整或無法解析。',
      );
    }
  }
}
