import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/device_hug_gateway.dart';

void main() {
  test('sends the friend id and reports success', () async {
    Map<String, dynamic>? sent;
    final gateway = DeviceHugGateway.withCallable((payload) async {
      sent = payload;
      return {'sent': true};
    });
    expect(await gateway.send('bob'), isNull);
    expect(sent, {'toUserId': 'bob'});
  });

  test('cloud errors become friendly messages', () async {
    Future<String?> failWith(String code) => DeviceHugGateway.withCallable(
      (_) async => throw FirebaseFunctionsException(code: code, message: 'x'),
    ).send('bob');
    expect(await failWith('resource-exhausted'), '剛剛才送過，10 分鐘後再送一次吧。');
    expect(await failWith('permission-denied'), '對方現在無法收到擁抱。');
    expect(await failWith('unavailable'), '擁抱沒有送出，請稍後再試。');
  });
}
