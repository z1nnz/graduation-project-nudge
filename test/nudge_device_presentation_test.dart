import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/nudge_device_presentation.dart';

void main() {
  const character = NudgeDeviceCharacterContext(
    name: 'Nudgie',
    level: 12,
    stage: 3,
  );

  test(
    'filters rooms through assignment and preserves an allowed selection',
    () {
      const candidate = NudgeDevicePresentation(
        rooms: [
          NudgeDeviceRoomContext(
            id: 'room-a',
            label: 'Study',
            goalLabel: '25 min',
          ),
          NudgeDeviceRoomContext(
            id: 'room-b',
            label: 'Walk',
            goalLabel: '6000 steps',
          ),
        ],
        selectedRoomId: 'room-b',
        personalGoalLabel: 'Focus 25 min',
        character: character,
      );

      final canonical = candidate.forAllowedRooms({'room-b'});
      final command = jsonDecode(canonical.encodeCommand()) as Map;

      expect(canonical.rooms.map((room) => room.id), ['room-b']);
      expect(canonical.selectedRoomId, 'room-b');
      expect(command['type'], 'context');
      expect(command['contextVersion'], 1);
      expect((command['rooms'] as List).single['id'], 'room-b');
    },
  );

  test('falls back to personal mode when no room is assigned', () {
    const candidate = NudgeDevicePresentation(
      rooms: [
        NudgeDeviceRoomContext(
          id: 'room-a',
          label: 'Study',
          goalLabel: '25 min',
        ),
      ],
      selectedRoomId: 'room-a',
      personalGoalLabel: 'Focus 25 min',
      character: character,
    );

    final canonical = candidate.forAllowedRooms({});
    expect(canonical.rooms, isEmpty);
    expect(canonical.selectedRoomId, isNull);
    expect(canonical.encodeCommand(), contains('"selectedRoomId":""'));
  });

  test('UTF-8 labels are byte bounded for one BLE frame', () {
    expect(
      nudgeDeviceLabel('超級無敵長的專注共讀房', maximumBytes: 24, fallback: 'ROOM'),
      '超級無敵長的專注',
    );
  });

  test(
    'uses the canonical room identifier and three-stage character route',
    () {
      const dottedRoom = NudgeDevicePresentation(
        rooms: [
          NudgeDeviceRoomContext(
            id: 'room.study-1',
            label: 'Study',
            goalLabel: '25 min',
          ),
        ],
        selectedRoomId: 'room.study-1',
        personalGoalLabel: 'Focus 25 min',
        character: character,
      );
      expect(dottedRoom.encodeCommand(), contains('room.study-1'));

      const invalidStage = NudgeDevicePresentation(
        rooms: [],
        selectedRoomId: null,
        personalGoalLabel: 'Focus',
        character: NudgeDeviceCharacterContext(
          name: 'Nudgie',
          level: 12,
          stage: 4,
        ),
      );
      expect(invalidStage.encodeCommand, throwsFormatException);
    },
  );
}
