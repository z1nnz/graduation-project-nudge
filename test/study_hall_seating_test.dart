import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/study_hall_seating.dart';
import 'package:nudge/models/study_room_models.dart';

StudyMemberData _m(
  String id,
  StudyMemberStatus status, {
  bool approved = true,
}) => StudyMemberData(
  memberId: id,
  name: id,
  roomNickname: id,
  status: status,
  sessionSeconds: 0,
  todayFocusSeconds: 0,
  avatarColor: Colors.purple,
  isApproved: approved,
);

void main() {
  test('me first, then studying, resting, offline', () {
    final seating = StudyHallSeating.assign([
      _m('c', StudyMemberStatus.offline),
      _m('b', StudyMemberStatus.resting),
      _m('me', StudyMemberStatus.offline),
      _m('a', StudyMemberStatus.studying),
    ], myId: 'me');
    expect(seating.seats.map((m) => m.memberId), ['me', 'a', 'b', 'c']);
    expect(seating.overflow, 0);
    expect(seating.activeCount, 2);
  });

  test('eight seats, the rest overflow; pending members are not seated', () {
    final members = [
      for (var i = 0; i < 11; i++) _m('m$i', StudyMemberStatus.studying),
      _m('pending', StudyMemberStatus.studying, approved: false),
    ];
    final seating = StudyHallSeating.assign(members, myId: 'nobody');
    expect(seating.seats, hasLength(8));
    expect(seating.overflow, 3);
    expect(seating.activeCount, 11);
    expect(seating.seats.any((m) => m.memberId == 'pending'), isFalse);
  });

  test('brightness grows with the share of active members', () {
    expect(StudyHallSeating.assign(const [], myId: 'x').brightness, 0);
    final half = StudyHallSeating.assign([
      _m('a', StudyMemberStatus.studying),
      _m('b', StudyMemberStatus.offline),
    ], myId: 'x');
    expect(half.brightness, closeTo(0.5, 0.001));
  });
}
