import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/room_voice/voice_core.dart';

void main() {
  test('matches the Web contract: 8 seats, 2 minute heartbeat', () {
    expect(VoiceCore.maxParticipants, 8);
    expect(VoiceCore.heartbeatTimeout, const Duration(minutes: 2));
  });

  test('only the smaller uid sends the offer, so peers never both offer', () {
    expect(VoiceCore.shouldOffer('alice', 'bob'), isTrue);
    expect(VoiceCore.shouldOffer('bob', 'alice'), isFalse);
    expect(VoiceCore.shouldOffer('Zed', 'abe'), isTrue); // code-unit order
  });

  test('heartbeat expires after two minutes or when missing', () {
    final now = DateTime.utc(2026, 11, 24, 12);
    expect(VoiceCore.heartbeatExpired(null, now), isTrue);
    expect(
      VoiceCore.heartbeatExpired(
        now.subtract(const Duration(seconds: 119)),
        now,
      ),
      isFalse,
    );
    expect(
      VoiceCore.heartbeatExpired(now.subtract(const Duration(minutes: 2)), now),
      isTrue,
    );
  });

  test('joinedAt uses the ISO shape the rules accept', () {
    final value = VoiceCore.joinedAtNow(
      DateTime.utc(2026, 11, 24, 3, 4, 5, 678),
    );
    expect(value, '2026-11-24T03:04:05.678Z');
    expect(
      RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z$').hasMatch(value),
      isTrue,
    );
  });

  group('status line', () {
    test('room without voice', () {
      expect(VoiceCore.status(enabled: false), '房主還沒開啟這間房的語音。');
    });
    test('before joining', () {
      expect(VoiceCore.status(enabled: true), '加入時才會請求麥克風權限。');
    });
    test('joining', () {
      expect(VoiceCore.status(enabled: true, joining: true), '正在加入語音…');
    });
    test('alone in the room', () {
      expect(VoiceCore.status(enabled: true, joined: true), '已加入，等待其他夥伴。');
    });
    test('connecting and connected', () {
      expect(
        VoiceCore.status(enabled: true, joined: true, peers: 2),
        '正在建立語音連線…',
      );
      expect(
        VoiceCore.status(enabled: true, joined: true, peers: 2, connected: 2),
        '已連線 · 3 人',
      );
    });
    test('failure and problems win', () {
      expect(
        VoiceCore.status(enabled: true, joined: true, peers: 1, failed: true),
        '無法建立語音連線。部分網路不支援直接連線。',
      );
      expect(
        VoiceCore.status(enabled: true, problem: '語音自習室已滿 8 人。'),
        '語音自習室已滿 8 人。',
      );
    });
  });
}
