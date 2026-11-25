import 'package:flutter/material.dart';

import '../models/procrastination_boss.dart';
import '../theme/game_ui.dart';

/// Small wooden card with this week's procrastination monster and its HP.
class ProcrastinationBossCard extends StatelessWidget {
  const ProcrastinationBossCard({super.key, required this.boss, this.onTap});

  final ProcrastinationBoss boss;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hpColor = boss.hpFraction > 0.5
        ? GamePalette.red
        : boss.hpFraction > 0.2
        ? GamePalette.gold
        : GamePalette.green;
    return Semantics(
      button: onTap != null,
      label:
          '${boss.species.name}，剩下 ${ProcrastinationBoss.clock(boss.hpSeconds)}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 168,
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xE6201008),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC9934F), width: 2),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 40,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _BossSprite(boss: boss)),
                      if (boss.defeated)
                        const Positioned(
                          key: Key('boss-defeated'),
                          right: 0,
                          top: 0,
                          child: Text(
                            'zZ',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        boss.species.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cubic11',
                          color: Color(0xFFFFE6A3),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: boss.hpFraction,
                          minHeight: 7,
                          color: hpColor,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        boss.defeated
                            ? '已打倒！'
                            : 'HP ${ProcrastinationBoss.clock(boss.hpSeconds)} / '
                                  '${ProcrastinationBoss.clock(boss.goalSeconds)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BossSprite extends StatefulWidget {
  const _BossSprite({required this.boss});

  final ProcrastinationBoss boss;

  @override
  State<_BossSprite> createState() => _BossSpriteState();
}

class _BossSpriteState extends State<_BossSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..value = 1;

  @override
  void didUpdateWidget(covariant _BossSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!MediaQuery.disableAnimationsOf(context) &&
        !widget.boss.defeated &&
        widget.boss.species == oldWidget.boss.species &&
        widget.boss.doneSeconds > oldWidget.boss.doneSeconds) {
      _hit.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _hit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const sprites = ['slime', 'ghost', 'goblin', 'snail'];
    final boss = widget.boss;
    final name = sprites[ProcrastinationBoss.roster.indexOf(boss.species)];
    return AnimatedBuilder(
      animation: _hit,
      builder: (context, _) {
        final moving =
            !MediaQuery.disableAnimationsOf(context) && _hit.value < 1;
        final pose = boss.defeated
            ? 'down'
            : moving
            ? 'hit'
            : 'idle';
        final tick = (_hit.value * 4).floor();
        return Transform.translate(
          offset: Offset(moving ? const [0.0, -3.0, 3.0, -1.0][tick] : 0, 0),
          child: Image.asset(
            'assets/scenes/study_hall/${name}_$pose.webp',
            filterQuality: FilterQuality.none,
            excludeFromSemantics: true,
            gaplessPlayback: true,
          ),
        );
      },
    );
  }
}
