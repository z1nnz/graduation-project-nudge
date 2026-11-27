import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/character_catalog.dart';
import '../state/app_state.dart';
import '../theme/game_ui.dart';
import '../widgets/player_avatar.dart';
import '../widgets/scene_room.dart';
import '../widgets/sprite_animation.dart';
import '../widgets/world_life.dart';
import 'ai_assistant_page.dart';
import 'calendar_page.dart';
import 'reminder_center_page.dart';
import 'tasks_page.dart';
import 'today_advice_page.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// 委託所: the task board, the reading nook (問阿紙), the clock and the map.
class CommissionHallPage extends StatefulWidget {
  const CommissionHallPage({super.key, this.tasks});

  /// Overrides [AppState.tasks] (tests).
  final List<Map<String, dynamic>>? tasks;

  @override
  State<CommissionHallPage> createState() => _CommissionHallPageState();
}

class _CommissionHallPageState extends State<CommissionHallPage>
    with PlayerWalkMixin<CommissionHallPage> {
  static const _tall = {
    'board': Rect.fromLTWH(0.12, 0.17, 0.63, 0.36),
    'desk': Rect.fromLTWH(0.52, 0.63, 0.44, 0.2),
    'clock': Rect.fromLTWH(0.0, 0.0, 0.18, 0.13),
    'map': Rect.fromLTWH(0.76, 0.29, 0.22, 0.22),
  };
  static const _wide = {
    'board': Rect.fromLTWH(0.21, 0.18, 0.47, 0.4),
    'desk': Rect.fromLTWH(0.63, 0.6, 0.3, 0.24),
    'clock': Rect.fromLTWH(0.08, 0.02, 0.1, 0.16),
    'map': Rect.fromLTWH(0.73, 0.25, 0.18, 0.3),
  };
  bool _tearing = false;
  List<String> _pinned = const [];

  @override
  void initState() {
    super.initState();
    loadPlayerLook();
    PinnedNotes.load().then(
      (n) => mounted ? setState(() => _pinned = n) : null,
    );
  }

  /// Walk over, act it out, then open the page.
  Future<void> _go(BuildContext c, String id, Widget page) async {
    await walkBelow((isWideRoom(c) ? _wide : _tall)[id]!, floorTop: 0.7);
    if (!c.mounted) return;
    if (id == 'board') {
      setState(() => _tearing = true);
      await Future<void>.delayed(Duration(milliseconds: worldStill ? 0 : 600));
      if (!mounted) return;
      setState(() => _tearing = false);
    }
    act(id == 'desk' ? PlayerAnimation.read : PlayerAnimation.think);
    if (!c.mounted) return;
    await Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page));
    final n = await PinnedNotes.load();
    if (mounted) setState(() => _pinned = n);
  }

  List<Map<String, dynamic>> _tasks(BuildContext context) {
    if (widget.tasks != null) return widget.tasks!;
    try {
      return context.watch<AppState>().tasks;
    } catch (_) {
      return const [];
    }
  }

  List<Widget> _overlay(BuildContext context, Rect art, bool wide) {
    final tasks = _tasks(context);
    final r = wide ? _wide : _tall;
    Rect abs(Rect q) => Rect.fromLTWH(
      art.left + q.left * art.width,
      art.top + q.top * art.height,
      q.width * art.width,
      q.height * art.height,
    );
    final board = abs(r['board']!).deflate(art.width * 0.02);
    final map = abs(r['map']!).deflate(art.width * 0.01);
    final notes = [
      for (final t in tasks.take(6))
        (t['title']?.toString() ?? '委託', t['done'] == true),
      for (final p in _pinned.take(math.max(0, 6 - tasks.length))) (p, false),
    ];
    final done = tasks.where((t) => t['done'] == true).length;
    final steps = math.max(3, math.min(8, tasks.length));
    return [
      Positioned.fromRect(
        rect: board,
        child: IgnorePointer(
          child: GridView.count(
            key: const Key('hall-notes'),
            crossAxisCount: 3,
            childAspectRatio: wide ? 1.6 : 1.1,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(6),
            children: [
              for (final (i, (title, isDone)) in notes.indexed)
                AnimatedSlide(
                  duration: Duration(milliseconds: worldStill ? 0 : 500),
                  curve: const Threshold(0.3),
                  offset: _tearing && i == 0
                      ? const Offset(0.2, 0.6)
                      : Offset.zero,
                  child: AnimatedRotation(
                    duration: Duration(milliseconds: worldStill ? 0 : 500),
                    turns: _tearing && i == 0
                        ? 0.04
                        : (i.isEven ? -0.008 : 0.008),
                    child: CommissionNote(
                      text: title,
                      stamped: isDone,
                      compact: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      Positioned.fromRect(
        rect: map,
        child: IgnorePointer(
          child: CustomPaint(
            key: const Key('hall-path'),
            painter: AdventurePathPainter(steps: steps, flags: done),
            child: Align(
              alignment: Alignment(
                -0.85 + 1.7 * (math.min(done, steps - 1) / (steps - 1)),
                0.2,
              ),
              child: PlayerAvatar(
                look: playerLook,
                scale: 1,
                animation: done > 0
                    ? PlayerAnimation.happy
                    : PlayerAnimation.idle,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
      walkingPlayer(
        art,
        fallback: CharacterSprite(
          character: GameCharacters.companion,
          size: 112,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      overlay: _overlay,
      art: 'assets/scenes/board/board.webp',
      wide: const SceneWideLayout(
        art: 'assets/scenes/board/board_wide.webp',
        npcAt: Offset(0.36, 0.92),
        rects: {
          'board': Rect.fromLTWH(0.21, 0.18, 0.47, 0.4),
          'desk': Rect.fromLTWH(0.63, 0.6, 0.3, 0.24),
          'clock': Rect.fromLTWH(0.08, 0.02, 0.1, 0.16),
          'map': Rect.fromLTWH(0.73, 0.25, 0.18, 0.3),
        },
        effects: [
          SceneEffect.flicker([
            Offset(0.5, 0.07),
            Offset(0.94, 0.22),
            Offset(0.72, 0.63),
          ]),
          SceneEffect.flutter(count: 6, top: 0.2, band: 0.4),
          SceneEffect.dust(count: 20),
        ],
        walkers: [
          SceneWalker(GameCharacters.chestnut, [
            Offset(0.25, 0.8),
            Offset(0.55, 0.75),
            Offset(0.45, 0.88),
          ], speed: 0.03),
        ],
      ),
      title: '委託所',
      npc: GameCharacters.scroll,
      npcAt: const Offset(0.2, 0.95),
      tips: const [
        '告示板上釘的是你自己的委託，點一張就能開始。',
        '桌子那邊是閱讀角，想問什麼都可以問我。',
        '牆上的掛鐘是提醒中心，什麼時候該做什麼都在那裡。',
        '右邊的冒險地圖是行事曆，每天的足跡都記在上面。',
      ],
      objects: [
        SceneObject(
          id: 'board',
          label: '告示板',
          hint: '今天的委託',
          rect: _r(0.12, 0.17, 0.63, 0.36),
          onTap: (c, _) => _go(c, 'board', const TasksPage()),
        ),
        SceneObject(
          id: 'desk',
          label: '問阿紙',
          hint: 'AI 助理',
          rect: _r(0.52, 0.63, 0.44, 0.2),
          onTap: (c, _) => _go(c, 'desk', const AskScrollPage()),
        ),
        SceneObject(
          id: 'clock',
          label: '掛鐘',
          hint: '提醒中心',
          rect: _r(0.0, 0.0, 0.18, 0.13),
          onTap: (c, _) => _go(c, 'clock', const ReminderCenterPage()),
        ),
        SceneObject(
          id: 'map',
          label: '冒險地圖',
          hint: '行事曆',
          rect: _r(0.76, 0.29, 0.22, 0.22),
          onTap: (c, _) => _go(c, 'map', const CalendarPage()),
        ),
      ],
      effects: const [
        SceneEffect.flicker([
          Offset(0.47, 0.07),
          Offset(0.67, 0.67),
          Offset(0.92, 0.2),
        ]),
        SceneEffect.flutter(count: 5, top: 0.18, band: 0.35),
        SceneEffect.dust(),
      ],
      walkers: const [
        SceneWalker(GameCharacters.chestnut, [
          Offset(0.3, 0.8),
          Offset(0.6, 0.78),
          Offset(0.45, 0.9),
        ], speed: 0.04),
      ],
    ),
  );
}

/// 閱讀角: 阿紙 answers questions (the existing AI assistant) and today's advice.
class AskScrollPage extends StatelessWidget {
  const AskScrollPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      art: 'assets/scenes/board/study_nook.webp',
      wide: const SceneWideLayout(
        art: 'assets/scenes/board/study_nook_wide.webp',
        npcAt: Offset(0.2, 0.92),
        rects: {
          'book': Rect.fromLTWH(0.32, 0.5, 0.26, 0.16),
          'chalkboard': Rect.fromLTWH(0.4, 0.1, 0.28, 0.24),
        },
        effects: [
          SceneEffect.steam([
            Offset(0.455, 0.46),
            Offset(0.39, 0.5),
            Offset(0.52, 0.5),
          ]),
          SceneEffect.flicker([
            Offset(0.75, 0.15),
            Offset(0.19, 0.42),
            Offset(0.86, 0.55),
          ]),
          SceneEffect.dust(count: 20),
        ],
      ),
      title: '問阿紙',
      npc: GameCharacters.scroll,
      npcAt: const Offset(0.22, 0.92),
      greeting: () => ['坐下來喝杯茶吧！翻開桌上的書，就能問我任何事。'],
      tips: const ['黑板上寫著今天給你的建議。', '我的回答只是建議，真正的決定權在你。'],
      objects: [
        SceneObject(
          id: 'book',
          label: '翻開書',
          hint: '問阿紙問題',
          rect: _r(0.27, 0.38, 0.41, 0.2),
          onTap: (c, _) => _push(c, const AIAssistantPage()),
        ),
        SceneObject(
          id: 'chalkboard',
          label: '黑板',
          hint: '今日建議',
          rect: _r(0.5, 0.1, 0.35, 0.22),
          onTap: (c, _) => _push(c, const TodayAdvicePage()),
        ),
      ],
      effects: const [
        SceneEffect.steam([Offset(0.45, 0.42), Offset(0.6, 0.44)]),
        SceneEffect.flicker([Offset(0.82, 0.68), Offset(0.88, 0.1)]),
        SceneEffect.dust(),
      ],
    ),
  );
}

/// Commission notes 阿紙 pinned to the board from answers (on this device).
abstract final class PinnedNotes {
  static const key = 'nudge.board.notes.v1';

  static Future<List<String>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return List<String>.from(jsonDecode(p.getString(key) ?? '[]') as List);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(String text) async {
    final p = await SharedPreferences.getInstance();
    final list = [
      text.length > 60 ? '${text.substring(0, 60)}…' : text,
      ...await load(),
    ].take(12).toList();
    await p.setString(key, jsonEncode(list));
  }
}

/// A commission note: parchment with a red pin; a finished one is stamped.
class CommissionNote extends StatelessWidget {
  const CommissionNote({
    super.key,
    required this.text,
    this.stamped = false,
    this.compact = false,
    this.tilt = 0,
    this.onPin,
  });
  final String text;
  final bool stamped, compact;
  final double tilt;
  final VoidCallback? onPin;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        margin: compact
            ? EdgeInsets.zero
            : const EdgeInsets.only(bottom: 12, top: 6),
        constraints: compact
            ? null
            : BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        padding: EdgeInsets.fromLTRB(
          compact ? 4 : 14,
          compact ? 8 : 16,
          compact ? 4 : 14,
          compact ? 4 : 10,
        ),
        decoration: const BoxDecoration(
          color: GamePalette.parchment,
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFF8A5A34), width: 2),
          ),
          boxShadow: [
            BoxShadow(color: Color(0xFF3A2216), offset: Offset(2, 3)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  maxLines: compact ? 3 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: compact ? 9 : 14,
                    height: 1.4,
                    color: GamePalette.inkDark,
                  ),
                ),
                if (onPin != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('pin-note'),
                      onPressed: onPin,
                      icon: const Icon(Icons.push_pin, size: 16),
                      label: const Text('釘上告示板'),
                    ),
                  ),
              ],
            ),
            Positioned(
              top: compact ? -7 : -13,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: compact ? 6 : 10,
                  height: compact ? 6 : 10,
                  color: const Color(0xFFD8452E),
                ),
              ),
            ),
            if (stamped)
              Positioned(
                right: 0,
                bottom: 0,
                child: Transform.rotate(
                  angle: -0.25,
                  child: Container(
                    key: const Key('note-stamp'),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFD8452E),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '完成',
                      style: TextStyle(
                        color: const Color(0xFFD8452E),
                        fontSize: compact ? 8 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The weekly commission chain as a little path: one flag per finished step.
class AdventurePathPainter extends CustomPainter {
  AdventurePathPainter({required this.steps, required this.flags});
  final int steps, flags;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    Offset at(int i) => Offset(
      size.width * (0.075 + 0.85 * i / (steps - 1)),
      size.height * (0.6 + 0.2 * math.sin(i * 1.3)),
    );
    for (var i = 0; i + 1 < steps; i++) {
      final a = at(i), b = at(i + 1);
      for (var k = 0; k < 6; k++) {
        final q = Offset.lerp(a, b, k / 6)!;
        canvas.drawRect(
          Rect.fromCenter(center: q, width: 3, height: 3),
          p..color = const Color(0xFF8A5A34),
        );
      }
    }
    for (var i = 0; i < steps; i++) {
      final c = at(i);
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 8, height: 8),
        p..color = const Color(0xFFF6E7C8),
      );
      canvas.drawRect(
        Rect.fromCenter(center: c, width: 6, height: 6),
        p..color = const Color(0xFF8A5A34),
      );
      if (i < flags) {
        canvas.drawRect(
          Rect.fromLTWH(c.dx, c.dy - 18, 2, 16),
          p..color = const Color(0xFF3A2216),
        );
        canvas.drawRect(
          Rect.fromLTWH(c.dx + 2, c.dy - 18, 8, 5),
          p..color = const Color(0xFFD8452E),
        );
      }
    }
  }

  @override
  bool shouldRepaint(AdventurePathPainter old) =>
      old.steps != steps || old.flags != flags;
}
