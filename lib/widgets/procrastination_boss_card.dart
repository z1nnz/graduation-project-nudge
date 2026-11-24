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
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SlimePainter(
                            boss.species,
                            defeated: boss.defeated,
                          ),
                        ),
                      ),
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

/// A chunky pixel slime drawn on a 11x10 grid.
class _SlimePainter extends CustomPainter {
  _SlimePainter(this.species, {required this.defeated});

  final BossSpecies species;
  final bool defeated;

  static const _shape = [
    '...XXXXX...',
    '..XXXXXXX..',
    '.XXXXXXXXX.',
    '.XXXXXXXXX.',
    'XXXXXXXXXXX',
    'XXXXXXXXXXX',
    'XXXXXXXXXXX',
    'XXXXXXXXXXX',
    '.XXXXXXXXX.',
    '..XX.X.XX..',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 11;
    final top = (size.height - cell * 10) / 2;
    final body = Paint()
      ..color = defeated ? species.body.withValues(alpha: 0.55) : species.body;
    final dark = Paint()..color = species.dark;
    for (var y = 0; y < _shape.length; y++) {
      for (var x = 0; x < 11; x++) {
        if (_shape[y][x] != 'X') continue;
        final edge =
            y == 0 ||
            x == 0 ||
            x == 10 ||
            _shape[y - 1][x] != 'X' ||
            _shape[y][x - 1] != 'X' ||
            _shape[y][x + 1] != 'X';
        canvas.drawRect(
          Rect.fromLTWH(x * cell, top + y * cell, cell + 0.5, cell + 0.5),
          edge ? dark : body,
        );
      }
    }
    final eye = Paint()..color = const Color(0xFF1B1020);
    if (defeated) {
      for (final x in [3, 7]) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell, top + 4.5 * cell, cell, cell * 0.4),
          eye,
        );
      }
    } else {
      for (final x in [3, 7]) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell, top + 4 * cell, cell, cell * 1.4),
          eye,
        );
      }
      canvas.drawRect(
        Rect.fromLTWH(4.5 * cell, top + 6.6 * cell, cell * 2, cell * 0.5),
        eye,
      );
    }
  }

  @override
  bool shouldRepaint(_SlimePainter old) =>
      old.species != species || old.defeated != defeated;
}
