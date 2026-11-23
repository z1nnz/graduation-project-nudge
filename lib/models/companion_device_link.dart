/// Whether the user's physical Nudge companion shows up in the cabin, read
/// from the Cloud activity sessions it reported (source `device`).
class CompanionDeviceLink {
  const CompanionDeviceLink({
    required this.hasDevice,
    required this.deviceFocusing,
  });

  static const none = CompanionDeviceLink(
    hasDevice: false,
    deviceFocusing: false,
  );

  /// The device has reported at least one session for this user.
  final bool hasDevice;

  /// The device is running a focus session right now.
  final bool deviceFocusing;

  factory CompanionDeviceLink.fromSessions(
    Iterable<Map<String, dynamic>> sessions, {
    required String actorUserId,
  }) {
    var hasDevice = false;
    var focusing = false;
    for (final s in sessions) {
      if (s['actorUserId'] != actorUserId || s['source'] != 'device') continue;
      hasDevice = true;
      if (s['status'] == 'active' && s['activityKind'] == 'focus') {
        focusing = true;
      }
    }
    return CompanionDeviceLink(hasDevice: hasDevice, deviceFocusing: focusing);
  }
}
