import 'dart:convert';

import 'nudge_device_protocol.dart';

class NudgeDeviceRoomContext {
  const NudgeDeviceRoomContext({
    required this.id,
    required this.label,
    required this.goalLabel,
  });

  final String id;
  final String label;
  final String goalLabel;

  Map<String, Object> toJson() => {'id': id, 'label': label, 'goal': goalLabel};
}

class NudgeDeviceCharacterContext {
  const NudgeDeviceCharacterContext({
    required this.name,
    required this.level,
    required this.stage,
  });

  final String name;
  final int level;
  final int stage;

  Map<String, Object> toJson() => {
    'name': name,
    'level': level,
    'stage': stage,
  };
}

class NudgeDevicePresentation {
  const NudgeDevicePresentation({
    required this.rooms,
    required this.selectedRoomId,
    required this.personalGoalLabel,
    required this.character,
    this.soundEnabled = true,
  });

  final List<NudgeDeviceRoomContext> rooms;
  final String? selectedRoomId;
  final String personalGoalLabel;
  final NudgeDeviceCharacterContext character;
  final bool soundEnabled;

  NudgeDevicePresentation forAllowedRooms(Set<String> allowedRoomIds) {
    final filtered = rooms
        .where((room) => allowedRoomIds.contains(room.id))
        .take(3)
        .toList(growable: false);
    String? selected;
    for (final room in filtered) {
      if (room.id == selectedRoomId) selected = room.id;
    }
    selected ??= filtered.isEmpty ? null : filtered.first.id;
    return NudgeDevicePresentation(
      rooms: filtered,
      selectedRoomId: selected,
      personalGoalLabel: personalGoalLabel,
      character: character,
      soundEnabled: soundEnabled,
    );
  }

  String encodeCommand({int contextRevision = 1}) {
    final roomIds = <String>{};
    if (contextRevision < 1 ||
        contextRevision > 0x7FFFFFFFFFFFFFFF ||
        rooms.length > 3 ||
        !_boundedUtf8(personalGoalLabel, 32, allowEmpty: true) ||
        !_boundedUtf8(character.name, 24) ||
        character.level < 1 ||
        character.level > 999 ||
        character.stage < 1 ||
        character.stage > 3) {
      throw const FormatException('Invalid Nudge presentation snapshot.');
    }
    for (final room in rooms) {
      if (!isValidNudgeDeviceIdentifier(room.id) ||
          !roomIds.add(room.id) ||
          !_boundedUtf8(room.label, 24) ||
          !_boundedUtf8(room.goalLabel, 32, allowEmpty: true)) {
        throw const FormatException('Invalid Nudge room presentation.');
      }
    }
    if (rooms.isEmpty
        ? selectedRoomId != null
        : selectedRoomId == null || !roomIds.contains(selectedRoomId)) {
      throw const FormatException(
        'Selected Nudge room is not in the snapshot.',
      );
    }
    final encoded = jsonEncode({
      'protocolVersion': nudgeDeviceProtocolVersion,
      'type': 'context',
      'contextVersion': 1,
      'contextRevision': contextRevision,
      'selectedRoomId': selectedRoomId ?? '',
      'personalGoal': personalGoalLabel,
      'soundEnabled': soundEnabled,
      'character': character.toJson(),
      'rooms': rooms.map((room) => room.toJson()).toList(growable: false),
    });
    if (utf8.encode(encoded).length > 512) {
      throw const FormatException('Nudge presentation exceeds one BLE frame.');
    }
    return encoded;
  }
}

bool _boundedUtf8(String value, int maximumBytes, {bool allowEmpty = false}) {
  return value == value.trim() &&
      (allowEmpty || value.isNotEmpty) &&
      utf8.encode(value).length <= maximumBytes;
}

String nudgeDeviceLabel(
  String value, {
  required int maximumBytes,
  required String fallback,
}) {
  final trimmed = value.trim();
  final output = StringBuffer();
  for (final rune in trimmed.runes) {
    final candidate = '${output.toString()}${String.fromCharCode(rune)}';
    if (utf8.encode(candidate).length > maximumBytes) break;
    output.writeCharCode(rune);
  }
  return output.isEmpty ? fallback : output.toString();
}
