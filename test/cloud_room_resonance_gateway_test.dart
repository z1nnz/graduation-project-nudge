import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_resonance.dart';
import 'package:nudge/services/cloud_room_resonance_gateway.dart';

Map<String, dynamic> signal() => {
  'schemaVersion': 1,
  'signalId': 'room-study--alice',
  'roomId': 'room-study',
  'ownerUserId': 'alice',
  'generationId': 'request-fixed-001',
  'cueKey': 'open_to_company',
  'status': 'active',
  'visibility': 'room_members_only',
  'acknowledgementCount': 0,
  'createdAt': '2026-08-15T10:00:00.000Z',
  'updatedAt': '2026-08-15T10:00:00.000Z',
  'expiresAt': '2026-08-16T10:00:00.000Z',
  'withdrawnAt': null,
};

void main() {
  test('publish sends only the bounded resonance contract', () async {
    Map<String, dynamic>? sent;
    final gateway = CloudRoomResonanceGateway.withCallable((payload) async {
      sent = payload;
      return {'signal': signal()};
    }, requestIdFactory: () => 'request-fixed-001');
    final result = await gateway.publish(
      roomId: 'room-study',
      cue: RoomResonanceCue.openToCompany,
    );
    expect(result.ownerUserId, 'alice');
    expect(sent, {
      'action': 'publish',
      'roomId': 'room-study',
      'sourceSurface': 'app',
      'clientRequestId': 'request-fixed-001',
      'cueKey': 'open_to_company',
    });
  });

  test('gateway rejects a public or cross-room signal', () async {
    final gateway = CloudRoomResonanceGateway.withCallable(
      (_) async => {
        'signal': {...signal(), 'visibility': 'public'},
      },
      requestIdFactory: () => 'request-fixed-002',
    );
    expect(
      () => gateway.publish(
        roomId: 'room-study',
        cue: RoomResonanceCue.gentleRestart,
      ),
      throwsA(isA<RoomResonanceException>()),
    );
  });
}
