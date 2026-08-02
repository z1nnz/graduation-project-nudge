import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/cloud_reward_purchase_gateway.dart';

void main() {
  test('reward purchase gateway validates the Cloud debit result', () async {
    final gateway = CloudRewardPurchaseGateway.withCallable((payload) async {
      expect(payload['category'], 'faceShape');
      expect(payload['index'], 12);
      expect(payload['sourceSurface'], 'app');
      return {
        'rewardEntryId': 'purchase-1',
        'itemKey': 'faceShape:12',
        'disciplineCoins': 0,
        'unlockedAvatarItems': ['faceShape:12'],
        'alreadyUnlocked': false,
        'replayed': false,
      };
    });

    final result = await gateway.purchase(
      category: 'faceShape',
      index: 12,
      catalogItemId: null,
      clientRequestId: 'purchase-1',
    );

    expect(result.itemKey, 'faceShape:12');
    expect(result.disciplineCoins, 0);
    expect(result.unlockedAvatarItems, ['faceShape:12']);
  });

  test('reward purchase gateway rejects a mismatched item result', () async {
    final gateway = CloudRewardPurchaseGateway.withCallable(
      (_) async => {
        'rewardEntryId': 'purchase-2',
        'itemKey': 'faceShape:15',
        'disciplineCoins': 0,
        'unlockedAvatarItems': ['faceShape:15'],
        'alreadyUnlocked': false,
        'replayed': false,
      },
    );

    expect(
      () => gateway.purchase(
        category: 'faceShape',
        index: 12,
        catalogItemId: null,
        clientRequestId: 'purchase-2',
      ),
      throwsA(isA<RewardPurchaseException>()),
    );
  });
}
