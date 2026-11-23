import 'package:cloud_functions/cloud_functions.dart';

import '../models/home_decor_catalog.dart';

typedef HomeDecorCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class HomeDecorException implements Exception {
  const HomeDecorException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'HomeDecorException($code): $message';
}

/// Calls the Cloud `arrangeHomeDecor` callable, the only writer of
/// `users.homeDecor`.
class CloudHomeDecorGateway {
  const CloudHomeDecorGateway.withCallable(HomeDecorCallable call)
    : _call = call;

  final HomeDecorCallable _call;

  factory CloudHomeDecorGateway.firebase({FirebaseFunctions? functions}) {
    return CloudHomeDecorGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('arrangeHomeDecor');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<Map<String, int>> arrange(
    Map<String, int> arrangement, {
    required String clientRequestId,
  }) async {
    try {
      final response = await _call({
        'arrangement': arrangement,
        'clientRequestId': clientRequestId,
        'sourceSurface': 'app',
      });
      final decor = response is Map ? response['homeDecor'] : null;
      if (decor is! Map) {
        throw const HomeDecorException('protocol-error', '家具服務回傳了無效資料。');
      }
      final parsed = HomeDecorCatalog.parseHomeDecor(decor);
      for (final slot in HomeDecorCatalog.slotOrder) {
        if (parsed[slot] != arrangement[slot]) {
          throw const HomeDecorException('protocol-error', '家具擺放結果無法驗證。');
        }
      }
      return parsed;
    } on FirebaseFunctionsException catch (error) {
      throw HomeDecorException(error.code, error.message ?? '無法更新家具擺放。');
    }
  }
}
