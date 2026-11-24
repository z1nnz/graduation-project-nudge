import 'package:flutter/material.dart';

import '../theme/game_ui.dart';

/// One study room in the lobby, drawn as a wooden door on a parchment sign.
/// The door window glows when someone in the room is studying right now.
class RoomDoorCard extends StatelessWidget {
  const RoomDoorCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.typeLabel,
    required this.typeIcon,
    required this.approvedCount,
    required this.memberLimit,
    required this.activeCount,
    required this.progress,
    required this.trackedValueText,
    required this.onTap,
    this.leaderLine,
    this.locked = false,
    this.needsApproval = false,
    this.nearFull = false,
    this.hasPending = false,
    this.isJoining = false,
  });

  final String name;
  final String subtitle;
  final Color accent;
  final String typeLabel;
  final IconData typeIcon;
  final int approvedCount;
  final int memberLimit;
  final int activeCount;
  final double progress;
  final String trackedValueText;
  final String? leaderLine;
  final bool locked;
  final bool needsApproval;
  final bool nearFull;
  final bool hasPending;
  final bool isJoining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    final lit = activeCount > 0;
    final isFull = approvedCount >= memberLimit;

    return Semantics(
      button: true,
      label:
          '$name，$approvedCount/$memberLimit 人${lit ? '，$activeCount 人在讀' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isJoining ? null : onTap,
        child: GamePanel(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Door(accent: accent, lit: lit, icon: typeIcon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cubic11',
                              fontSize: 19,
                              color: p.ink,
                            ),
                          ),
                        ),
                        if (isJoining)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: p.inkMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        GameChip(label: typeLabel, tone: GameTone.violet),
                        GameChip(label: '$approvedCount/$memberLimit 人'),
                        if (lit)
                          GameChip(
                            label: '$activeCount 人在讀',
                            tone: GameTone.green,
                          ),
                        if (isFull)
                          const GameChip(label: '已滿', tone: GameTone.red)
                        else if (nearFull)
                          const GameChip(label: '快滿', tone: GameTone.gold),
                        if (locked)
                          const GameChip(label: '需密碼', tone: GameTone.violet),
                        if (needsApproval) const GameChip(label: '需審核'),
                        if (hasPending)
                          const GameChip(label: '有待審', tone: GameTone.gold),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GoalBar(progress: progress, text: '今日 $trackedValueText'),
                    if (leaderLine != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        leaderLine!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: p.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({required this.accent, required this.lit, required this.icon});

  final Color accent;
  final bool lit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DoorPainter(accent: accent)),
          ),
          Positioned(
            top: 14,
            child: Container(
              key: ValueKey(lit ? 'door-light-on' : 'door-light-off'),
              width: 26,
              height: 20,
              decoration: BoxDecoration(
                color: lit ? const Color(0xFFFFE08A) : const Color(0xFF2B2440),
                border: Border.all(color: const Color(0xFF3A1D0C), width: 2),
                boxShadow: lit
                    ? const [
                        BoxShadow(
                          color: Color(0xAAFFC54D),
                          blurRadius: 14,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Icon(
              icon,
              size: 20,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoorPainter extends CustomPainter {
  _DoorPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()..color = const Color(0xFF5A3826);
    final door = Paint()
      ..color = Color.lerp(accent, const Color(0xFF3A1D0C), 0.35)!;
    final plank = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 2;
    final knob = Paint()..color = GamePalette.gold;

    final arch = Radius.circular(size.width / 2);
    final outer = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: arch,
      topRight: arch,
    );
    canvas.drawRRect(outer, frame);
    final innerRect = Rect.fromLTRB(5, 5, size.width - 5, size.height);
    final innerArch = Radius.circular(innerRect.width / 2);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        innerRect,
        topLeft: innerArch,
        topRight: innerArch,
      ),
      door,
    );
    for (final x in [size.width * 0.36, size.width * 0.64]) {
      canvas.drawLine(Offset(x, 40), Offset(x, size.height), plank);
    }
    canvas.drawCircle(Offset(size.width - 13, size.height * 0.62), 3, knob);
  }

  @override
  bool shouldRepaint(_DoorPainter old) => old.accent != accent;
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.progress, required this.text});

  final double progress;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    final value = progress.clamp(0.0, 1.0);
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: p.wood.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: p.panelBorder, width: 2),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: GamePalette.gold,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Center(
            child: Text(
              '$text · ${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
