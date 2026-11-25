import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../widgets/scene_room.dart';
import 'ai_assistant_page.dart';
import 'calendar_page.dart';
import 'reminder_center_page.dart';
import 'tasks_page.dart';
import 'today_advice_page.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// 委託所: the task board, the reading nook (問阿紙), the clock and the map.
class CommissionHallPage extends StatelessWidget {
  const CommissionHallPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
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
          onTap: (c, _) => _push(c, const TasksPage()),
        ),
        SceneObject(
          id: 'desk',
          label: '問阿紙',
          hint: 'AI 助理',
          rect: _r(0.52, 0.63, 0.44, 0.2),
          onTap: (c, _) => _push(c, const AskScrollPage()),
        ),
        SceneObject(
          id: 'clock',
          label: '掛鐘',
          hint: '提醒中心',
          rect: _r(0.0, 0.0, 0.18, 0.13),
          onTap: (c, _) => _push(c, const ReminderCenterPage()),
        ),
        SceneObject(
          id: 'map',
          label: '冒險地圖',
          hint: '行事曆',
          rect: _r(0.76, 0.29, 0.22, 0.22),
          onTap: (c, _) => _push(c, const CalendarPage()),
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
