import 'package:cloud_functions/cloud_functions.dart';

typedef RewardPurchaseCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class RewardPurchaseException implements Exception {
  const RewardPurchaseException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RewardPurchaseException($code): $message';
}

class RewardPurchaseResult {
  const RewardPurchaseResult({
    required this.rewardEntryId,
    required this.itemKey,
    required this.disciplineCoins,
    required this.unlockedAvatarItems,
    required this.alreadyUnlocked,
    required this.replayed,
  });

  final String rewardEntryId;
  final String itemKey;
  final int disciplineCoins;
  final List<String> unlockedAvatarItems;
  final bool alreadyUnlocked;
  final bool replayed;

  factory RewardPurchaseResult.fromMap(Map<String, dynamic> data) {
    return RewardPurchaseResult(
      rewardEntryId: data['rewardEntryId'] as String? ?? '',
      itemKey: data['itemKey'] as String? ?? '',
      disciplineCoins: data['disciplineCoins'] as int? ?? -1,
      unlockedAvatarItems: (data['unlockedAvatarItems'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      alreadyUnlocked: data['alreadyUnlocked'] as bool? ?? false,
      replayed: data['replayed'] as bool? ?? false,
    );
  }
}

class CloudRewardPurchaseGateway {
  const CloudRewardPurchaseGateway.withCallable(RewardPurchaseCallable call)
    : _call = call;

  final RewardPurchaseCallable _call;

  factory CloudRewardPurchaseGateway.firebase({FirebaseFunctions? functions}) {
    return CloudRewardPurchaseGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('purchaseRewardItem');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<RewardPurchaseResult> purchase({
    required String category,
    required int index,
    required String? catalogItemId,
    required String clientRequestId,
  }) async {
    try {
      final response = await _call({
        'category': category,
        'index': index,
        'catalogItemId': catalogItemId,
        'clientRequestId': clientRequestId,
        'sourceSurface': 'app',
      });
      if (response is! Map) {
        throw const RewardPurchaseException('protocol-error', '商城服務回傳了無效資料。');
      }
      final result = RewardPurchaseResult.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
      final expectedItemKey = '$category:$index';
      if (result.rewardEntryId.isEmpty ||
          result.itemKey != expectedItemKey ||
          result.disciplineCoins < 0 ||
          !result.unlockedAvatarItems.contains(expectedItemKey)) {
        throw const RewardPurchaseException('protocol-error', '商城扣款結果無法驗證。');
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw RewardPurchaseException(error.code, error.message ?? '無法完成商城購買。');
    }
  }
}
