import 'package:cloud_functions/cloud_functions.dart';

import '../models/relationship_outcome.dart';

typedef RelationshipOutcomeCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class RelationshipOutcomeException implements Exception {
  const RelationshipOutcomeException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RelationshipOutcomeException($code): $message';
}

class CloudRelationshipOutcomeGateway {
  const CloudRelationshipOutcomeGateway.withCallable(
    RelationshipOutcomeCallable call,
  ) : _call = call;

  final RelationshipOutcomeCallable _call;

  factory CloudRelationshipOutcomeGateway.firebase({
    FirebaseFunctions? functions,
  }) {
    return CloudRelationshipOutcomeGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('refreshRelationshipOutcome');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<RelationshipOutcomeRefreshResult> refresh({
    required String scopeType,
    required String scopeId,
  }) async {
    if (!const {'family', 'group'}.contains(scopeType) ||
        scopeId.trim().isEmpty) {
      throw const RelationshipOutcomeException(
        'invalid-argument',
        '必須指定有效的家庭或團體關係。',
      );
    }
    try {
      final response = await _call({
        'scopeType': scopeType,
        'scopeId': scopeId.trim(),
      });
      if (response is! Map) {
        throw const RelationshipOutcomeException(
          'protocol-error',
          '關係成果服務回傳了無效資料。',
        );
      }
      final result = RelationshipOutcomeRefreshResult.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (!result.outcome.isValidFor(
            expectedScopeType: scopeType,
            expectedScopeId: scopeId.trim(),
          ) ||
          (scopeType == 'family' &&
              result.memories.any(
                (memory) => !memory.isValidForFamily(scopeId.trim()),
              )) ||
          (scopeType == 'group' && result.memories.isNotEmpty)) {
        throw const RelationshipOutcomeException(
          'protocol-error',
          '關係成果資料不完整或與目前選取的關係不一致。',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw RelationshipOutcomeException(
        error.code,
        error.message ?? '無法更新關係成果。',
      );
    } on RelationshipOutcomeException {
      rethrow;
    } catch (_) {
      throw const RelationshipOutcomeException(
        'protocol-error',
        '關係成果服務回傳了無法解析的資料。',
      );
    }
  }
}
