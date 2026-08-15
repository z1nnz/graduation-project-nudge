import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_resonance.dart';

Map<String, dynamic> signal({
  String roomId = 'room-study',
  String ownerUserId = 'alice',
  String status = 'active',
  String? withdrawnAt,
}) => {
  'schemaVersion': 1,
  'signalId': '$roomId--$ownerUserId',
  'roomId': roomId,
  'ownerUserId': ownerUserId,
  'generationId': 'resonance-publish-001',
  'cueKey': 'gentle_restart',
  'status': status,
  'visibility': 'room_members_only',
  'acknowledgementCount': 2,
  'createdAt': '2026-08-15T10:00:00.000Z',
  'updatedAt': '2026-08-15T10:00:00.000Z',
  'expiresAt': '2026-08-16T10:00:00.000Z',
  'withdrawnAt': withdrawnAt,
};

void main() {
  test('parses one bounded room resonance cue', () {
    final parsed = RoomResonanceSignal.fromMap(
      signal(),
      expectedRoomId: 'room-study',
    );
    expect(parsed.cue, RoomResonanceCue.gentleRestart);
    expect(parsed.acknowledgementCount, 2);
    expect(
      parsed.isVisibleAt(DateTime.parse('2026-08-15T12:00:00.000Z')),
      isTrue,
    );
  });

  test('rejects cross-room and malformed visibility', () {
    expect(
      () => RoomResonanceSignal.fromMap(signal(), expectedRoomId: 'other-room'),
      throwsFormatException,
    );
    expect(
      () => RoomResonanceSignal.fromMap({
        ...signal(),
        'visibility': 'public',
      }, expectedRoomId: 'room-study'),
      throwsFormatException,
    );
  });

  test('withdrawn cue requires a withdrawal timestamp', () {
    expect(
      () => RoomResonanceSignal.fromMap(
        signal(status: 'withdrawn'),
        expectedRoomId: 'room-study',
      ),
      throwsFormatException,
    );
    final parsed = RoomResonanceSignal.fromMap(
      signal(status: 'withdrawn', withdrawnAt: '2026-08-15T11:00:00.000Z'),
      expectedRoomId: 'room-study',
    );
    expect(parsed.isVisibleAt(DateTime.parse('2026-08-15T12:00:00Z')), false);
  });
}
