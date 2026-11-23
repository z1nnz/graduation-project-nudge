import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/companion_device_link.dart';

Map<String, dynamic> _session(
  String source,
  String status, {
  String kind = 'focus',
  String actor = 'me',
}) => {
  'actorUserId': actor,
  'source': source,
  'status': status,
  'activityKind': kind,
};

void main() {
  test('no device sessions means no device in the cabin', () {
    final link = CompanionDeviceLink.fromSessions([
      _session('app', 'active'),
    ], actorUserId: 'me');
    expect(link.hasDevice, isFalse);
    expect(link.deviceFocusing, isFalse);
  });

  test('a finished device session shows the device, resting', () {
    final link = CompanionDeviceLink.fromSessions([
      _session('device', 'completed'),
    ], actorUserId: 'me');
    expect(link.hasDevice, isTrue);
    expect(link.deviceFocusing, isFalse);
  });

  test('an active device focus session means the device is focusing', () {
    final link = CompanionDeviceLink.fromSessions([
      _session('device', 'completed'),
      _session('device', 'active'),
    ], actorUserId: 'me');
    expect(link.deviceFocusing, isTrue);
  });

  test('paused, non-focus or other people\'s sessions do not count', () {
    for (final s in [
      _session('device', 'paused'),
      _session('device', 'active', kind: 'sleep'),
      _session('device', 'active', actor: 'someone-else'),
    ]) {
      final link = CompanionDeviceLink.fromSessions([s], actorUserId: 'me');
      expect(link.deviceFocusing, isFalse, reason: '$s');
    }
    final other = CompanionDeviceLink.fromSessions([
      _session('device', 'completed', actor: 'someone-else'),
    ], actorUserId: 'me');
    expect(other.hasDevice, isFalse);
  });
}
