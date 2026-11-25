import 'package:flutter/material.dart';

import '../models/avatar_profile.dart';
import '../models/character_catalog.dart';
import '../models/companion_pose.dart';
import '../models/study_hall_layout.dart';
import '../models/study_hall_seating.dart';
import '../models/study_room_models.dart';
import 'companion_sprite.dart';
import 'npc_dialog.dart';
import 'sprite_animation.dart';

/// The study room as a pixel hall: members sit at their seats doing what
/// they are doing, so "who is here" is visible instead of counted. The room
/// gets brighter as more members are active; the lantern shows the shared
/// goal. Offline members leave their seat empty.
class StudyHallScene extends StatelessWidget {
  const StudyHallScene({
    super.key,
    required this.roomType,
    required this.seating,
    required this.myId,
    required this.lanternStage,
    required this.onMemberTap,
    this.reactions = const {},
    this.fullBleed = false,
    this.bannerTop = 12,
  });

  final StudyRoomType roomType;
  final StudyHallSeating seating;
  final String myId;

  /// 0 unlit, 1 half, 2 fully lit.
  final int lanternStage;
  final ValueChanged<StudyMemberData> onMemberTap;

  /// Short-lived reaction glyphs above members, keyed by member id.
  final Map<String, String> reactions;

  /// Fills its parent edge to edge (full-screen room) instead of a rounded card.
  final bool fullBleed;

  /// Distance of the head-count banner from the top, to clear overlays.
  final double bannerTop;

  @override
  Widget build(BuildContext context) {
    final hall = StudyHallLayout.forType(roomType);
    final (lx, ly, lw, lh) = StudyHallLayout.lanternRect;
    return ClipRRect(
      borderRadius: BorderRadius.circular(fullBleed ? 0 : 22),
      child: AspectRatio(
        aspectRatio: StudyHallLayout.aspect,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(hall.image, fit: BoxFit.fill),
                // Dim the room when few members are active.
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    color: Colors.black.withValues(
                      alpha: 0.38 * (1 - seating.brightness),
                    ),
                  ),
                ),
                Positioned(
                  left: lx * w,
                  top: ly * h,
                  width: lw * w,
                  height: lh * h,
                  child: Image.asset(
                    StudyHallLayout.lanterns[lanternStage.clamp(0, 2)],
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Semantics(
                    label: '問問墨墨',
                    button: true,
                    child: InkWell(
                      onTap: () => NpcDialog.show(
                        context,
                        speaker: GameCharacters.inky,
                        lines: const ['看看座位就知道誰在專注，想一起讀書就點牆上的番茄鐘。'],
                      ),
                      child: const CharacterSprite(
                        character: GameCharacters.inky,
                        size: 48,
                      ),
                    ),
                  ),
                ),
                for (var i = 0; i < seating.seats.length; i++)
                  _seat(context, hall.seats[i], seating.seats[i], w, h),
                Positioned(
                  left: 12,
                  right: 12,
                  top: bannerTop,
                  child: Center(
                    child: _Banner(text: '現在有 ${seating.activeCount} 人在房間裡'),
                  ),
                ),
                if (seating.overflow > 0)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _Banner(text: '+${seating.overflow}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _seat(
    BuildContext context,
    HallSeat seat,
    StudyMemberData member,
    double w,
    double h,
  ) {
    final pose = CompanionPose.forMember(member.status, roomType);
    final size = seat.height * h;
    final mine = member.memberId == myId;
    final tapWidth = size < 44 ? 44.0 : size;
    return Positioned(
      left: seat.centerX * w - tapWidth / 2,
      top: (seat.bottom - seat.height) * h - 18,
      width: tapWidth,
      height: size + 42,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 450),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: pose == null
            ? const SizedBox.shrink(key: ValueKey('empty'))
            : Semantics(
                key: ValueKey('${member.memberId}-${pose.name}'),
                button: true,
                label:
                    '${mine ? '你' : _name(member)}，${_status(member.status)}',
                child: GestureDetector(
                  key: Key('hall-member-${member.memberId}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onMemberTap(member),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 18,
                        child: reactions[member.memberId] == null
                            ? null
                            : Text(
                                reactions[member.memberId]!,
                                style: const TextStyle(fontSize: 14),
                              ),
                      ),
                      CompanionSprite(
                        profile:
                            member.avatarProfile ?? AvatarProfile.initial(),
                        pose: pose,
                        size: size,
                        characterAnimation: switch (pose) {
                          CompanionPose.read => CharacterAnimation.think,
                          CompanionPose.sleep => CharacterAnimation.sleep,
                          _ => null,
                        },
                      ),
                      _NameTag(text: mine ? '你' : _name(member), mine: mine),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  static String _name(StudyMemberData m) =>
      m.roomNickname.isEmpty ? m.name : m.roomNickname;

  static String _status(StudyMemberStatus s) => switch (s) {
    StudyMemberStatus.studying => '正在進行',
    StudyMemberStatus.resting => '休息中',
    StudyMemberStatus.offline => '離線',
  };
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xB3201008),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x40FFDCAA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _NameTag extends StatelessWidget {
  const _NameTag({required this.text, required this.mine});

  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFFFFCF5A) : const Color(0xCC201008),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: mine ? const Color(0xFF3A1D00) : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
