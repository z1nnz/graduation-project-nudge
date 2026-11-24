import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/cabin_parcels.dart';
import 'package:nudge/models/user_notification.dart';

UserNotification _n(
  String id,
  String kind, {
  String status = 'unread',
  int minute = 0,
}) => UserNotification(
  id: id,
  recipientUserId: 'me',
  category: 'social',
  kind: kind,
  sourceType: 'x',
  sourceId: id,
  actorUserId: 'mom',
  title: '你收到一封家庭鼓勵信',
  body: '加油！',
  route: '',
  status: status,
  createdAt: DateTime.utc(2026, 11, 24, 9, minute),
  updatedAt: null,
  readAt: null,
);

void main() {
  test('only unread letters and cards become parcels, newest first', () {
    final parcels = CabinParcels.from([
      _n('a', 'family_scheduled_encouragement', minute: 1),
      _n('b', 'room_chat_mention', minute: 2),
      _n('c', 'friend_cabin_letter', minute: 3),
      _n('d', 'growth_capsule_due', status: 'read', minute: 4),
      _n('e', 'growth_capsule_due', minute: 5),
    ]);
    expect(parcels.map((n) => n.id), ['e', 'c', 'a']);
  });

  test('each parcel kind has a friendly label', () {
    expect(CabinParcels.labelFor('family_scheduled_encouragement'), '家人的鼓勵信');
    expect(CabinParcels.labelFor('friend_cabin_letter'), '朋友留下的信');
    expect(CabinParcels.labelFor('growth_capsule_due'), '時光膠囊');
  });
}
