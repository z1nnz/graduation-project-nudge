import 'user_notification.dart';

/// Letters and keepsakes other people sent you, shown as parcels waiting at
/// the cabin door until you open them.
class CabinParcels {
  CabinParcels._();

  static const _labels = {
    'family_scheduled_encouragement': '家人的鼓勵信',
    'friend_cabin_letter': '朋友留下的信',
    'growth_capsule_due': '時光膠囊',
  };

  static String labelFor(String kind) => _labels[kind] ?? '一份包裹';

  static List<UserNotification> from(Iterable<UserNotification> all) =>
      all.where((n) => n.isUnread && _labels.containsKey(n.kind)).toList()
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
}
