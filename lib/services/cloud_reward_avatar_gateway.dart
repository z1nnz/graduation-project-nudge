import 'package:cloud_functions/cloud_functions.dart';

import '../models/avatar_profile.dart';

typedef RewardAvatarCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

class RewardAvatarException implements Exception {
  const RewardAvatarException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'RewardAvatarException($code): $message';
}

class RewardAvatarResult {
  const RewardAvatarResult({
    required this.rewardEntryId,
    required this.avatarProfile,
    required this.avatarSeries,
    required this.backgroundTheme,
    required this.replayed,
  });

  final String rewardEntryId;
  final AvatarProfile avatarProfile;
  final String avatarSeries;
  final String backgroundTheme;
  final bool replayed;

  factory RewardAvatarResult.fromMap(Map<String, dynamic> data) {
    final rawProfile = data['avatarProfile'];
    return RewardAvatarResult(
      rewardEntryId: data['rewardEntryId'] as String? ?? '',
      avatarProfile: rawProfile is Map
          ? AvatarProfile.fromJson(
              rawProfile.map((key, value) => MapEntry(key.toString(), value)),
            )
          : AvatarProfile.initial(),
      avatarSeries: data['avatarSeries'] as String? ?? '',
      backgroundTheme: data['backgroundTheme'] as String? ?? '',
      replayed: data['replayed'] as bool? ?? false,
    );
  }
}

class CloudRewardAvatarGateway {
  const CloudRewardAvatarGateway.withCallable(RewardAvatarCallable call)
    : _call = call;

  final RewardAvatarCallable _call;

  factory CloudRewardAvatarGateway.firebase({FirebaseFunctions? functions}) {
    return CloudRewardAvatarGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('equipRewardAvatar');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  Future<RewardAvatarResult> equip({
    required AvatarProfile avatarProfile,
    required String backgroundTheme,
    required String? faceCatalogItemId,
    required String? iconCatalogItemId,
    required String clientRequestId,
  }) async {
    try {
      final response = await _call({
        'avatarProfile': avatarProfile.toJson(),
        'backgroundTheme': backgroundTheme,
        'faceCatalogItemId': faceCatalogItemId,
        'iconCatalogItemId': iconCatalogItemId,
        'clientRequestId': clientRequestId,
        'sourceSurface': 'app',
      });
      if (response is! Map) {
        throw const RewardAvatarException('protocol-error', '角色裝備服務回傳了無效資料。');
      }
      final result = RewardAvatarResult.fromMap(
        response.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (result.rewardEntryId.isEmpty ||
          result.avatarSeries.isEmpty ||
          result.backgroundTheme != backgroundTheme ||
          result.avatarProfile.faceShapeIndex != avatarProfile.faceShapeIndex ||
          result.avatarProfile.avatarIconIndex !=
              avatarProfile.avatarIconIndex) {
        throw const RewardAvatarException(
          'protocol-error',
          'Cloud 角色裝備結果無法驗證。',
        );
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      throw RewardAvatarException(error.code, error.message ?? '無法儲存角色裝備。');
    }
  }
}
