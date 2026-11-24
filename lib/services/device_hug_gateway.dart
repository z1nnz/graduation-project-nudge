import 'package:cloud_functions/cloud_functions.dart';

typedef DeviceHugCallable =
    Future<Object?> Function(Map<String, dynamic> payload);

/// Calls the Cloud `sendDeviceHug` callable: a hug to a mutual friend that
/// lights up their desk device.
class DeviceHugGateway {
  const DeviceHugGateway.withCallable(DeviceHugCallable call) : _call = call;

  final DeviceHugCallable _call;

  factory DeviceHugGateway.firebase({FirebaseFunctions? functions}) {
    return DeviceHugGateway.withCallable((payload) async {
      final callable =
          (functions ?? FirebaseFunctions.instanceFor(region: 'asia-east1'))
              .httpsCallable('sendDeviceHug');
      final response = await callable.call<dynamic>(payload);
      return response.data;
    });
  }

  /// Null when the hug was sent; otherwise a message to show the user.
  Future<String?> send(String toUserId) async {
    try {
      await _call({'toUserId': toUserId});
      return null;
    } on FirebaseFunctionsException catch (error) {
      return switch (error.code) {
        'resource-exhausted' => '剛剛才送過，10 分鐘後再送一次吧。',
        'permission-denied' => '對方現在無法收到擁抱。',
        _ => '擁抱沒有送出，請稍後再試。',
      };
    } catch (_) {
      return '擁抱沒有送出，請稍後再試。';
    }
  }
}
