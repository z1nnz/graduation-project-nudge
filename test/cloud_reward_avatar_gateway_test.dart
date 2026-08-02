import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/avatar_profile.dart';
import 'package:nudge/services/cloud_reward_avatar_gateway.dart';

void main() {
  test('reward avatar gateway validates Cloud-owned equipment', () async {
    final profile = AvatarProfile.initial().copyWith(
      faceShapeIndex: 12,
      avatarIconIndex: 12,
    );
    final gateway = CloudRewardAvatarGateway.withCallable((payload) async {
      expect(payload['faceCatalogItemId'], isNull);
      expect(payload['sourceSurface'], 'app');
      return {
        'rewardEntryId': 'equipment-1',
        'avatarProfile': profile.toJson(),
        'avatarSeries': '月影忍者',
        'backgroundTheme': 'softGlow',
        'replayed': false,
      };
    });

    final result = await gateway.equip(
      avatarProfile: profile,
      backgroundTheme: 'softGlow',
      faceCatalogItemId: null,
      iconCatalogItemId: null,
      clientRequestId: 'equip-1',
    );

    expect(result.avatarProfile.faceShapeIndex, 12);
    expect(result.avatarSeries, '月影忍者');
  });

  test('reward avatar gateway rejects mismatched equipment', () async {
    final profile = AvatarProfile.initial().copyWith(faceShapeIndex: 12);
    final gateway = CloudRewardAvatarGateway.withCallable(
      (_) async => {
        'rewardEntryId': 'equipment-2',
        'avatarProfile': AvatarProfile.initial().toJson(),
        'avatarSeries': '星辰旅人',
        'backgroundTheme': 'softGlow',
        'replayed': false,
      },
    );

    expect(
      () => gateway.equip(
        avatarProfile: profile,
        backgroundTheme: 'softGlow',
        faceCatalogItemId: null,
        iconCatalogItemId: null,
        clientRequestId: 'equip-2',
      ),
      throwsA(isA<RewardAvatarException>()),
    );
  });
}
