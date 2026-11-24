/// Pure rules shared with the Web voice room (`voice_room_core.js`), so App
/// and Web peers can talk to each other in the same room.
class VoiceCore {
  VoiceCore._();

  static const maxParticipants = 8;
  static const heartbeatTimeout = Duration(minutes: 2);
  static const heartbeatEvery = Duration(seconds: 25);
  static const connectTimeout = Duration(seconds: 15);

  /// The peer with the smaller uid (UTF-16 order, like JS `<`) sends the offer.
  static bool shouldOffer(String selfUid, String peerUid) =>
      selfUid.compareTo(peerUid) < 0;

  static bool heartbeatExpired(DateTime? updatedAt, DateTime now) =>
      updatedAt == null || now.difference(updatedAt) >= heartbeatTimeout;

  /// Same shape as JS `new Date().toISOString()`.
  static String joinedAtNow([DateTime? now]) => (now ?? DateTime.now())
      .toUtc()
      .toIso8601String()
      .replaceFirstMapped(RegExp(r'\.(\d{3})\d*Z$'), (m) => '.${m[1]}Z');

  static String status({
    required bool enabled,
    bool joining = false,
    bool joined = false,
    int peers = 0,
    int connected = 0,
    bool failed = false,
    String problem = '',
  }) {
    if (problem.isNotEmpty) return problem;
    if (!enabled) return '房主還沒開啟這間房的語音。';
    if (joining) return '正在加入語音…';
    if (!joined) return '加入時才會請求麥克風權限。';
    if (failed) return '無法建立語音連線。部分網路不支援直接連線。';
    if (connected > 0) return '已連線 · ${connected + 1} 人';
    if (peers > 0) return '正在建立語音連線…';
    return '已加入，等待其他夥伴。';
  }
}
