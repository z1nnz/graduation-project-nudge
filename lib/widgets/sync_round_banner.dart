import 'package:flutter/material.dart';

import '../services/room_focus_round.dart';
import '../theme/game_ui.dart';

/// The room's shared 25 + 5 round: start one, or join the one running.
class SyncRoundBanner extends StatelessWidget {
  const SyncRoundBanner({
    super.key,
    required this.state,
    required this.busy,
    required this.problem,
    required this.joined,
    required this.onStart,
    required this.onJoin,
  });

  final FocusRoundState state;
  final bool busy;
  final String problem;
  final bool joined;
  final VoidCallback onStart;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final r = state.remaining;
    final clock =
        '${r.inMinutes.toString().padLeft(2, '0')}:${(r.inSeconds % 60).toString().padLeft(2, '0')}';
    final (String? action, VoidCallback? onTap) = switch (state.phase) {
      FocusRoundPhase.idle => ('發起一起專注', busy ? null : onStart),
      FocusRoundPhase.focus => joined ? (null, null) : ('加入這一輪', onJoin),
      FocusRoundPhase.rest => (null, null),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xE6201008),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GamePalette.gold, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_rounded, color: GamePalette.gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              problem.isNotEmpty
                  ? problem
                  : state.phase == FocusRoundPhase.idle
                  ? '同步番茄鐘 25 + 5'
                  : '${FocusRoundClock.label(state.phase)} $clock',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 6),
            TextButton(
              key: const Key('room-sync-round-action'),
              onPressed: onTap,
              style: TextButton.styleFrom(
                backgroundColor: GamePalette.gold,
                foregroundColor: const Color(0xFF2A1600),
                shape: const StadiumBorder(),
              ),
              child: Text(
                action,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
