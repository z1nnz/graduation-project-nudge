import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../widgets/scene_room.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'ai_assistant_page.dart';
import 'calendar_page.dart';
import 'nudge_device_page.dart';
import 'privacy_data_page.dart';
import 'reminder_center_page.dart';
import 'settings_page.dart';
import 'tasks_page.dart';
import 'today_advice_page.dart';

// Game rooms in front of existing, Cloud-backed pages. Each object opens a
// real page; the rooms themselves never read or write user data.

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

/// 工作室: settings as objects on a workbench.
class WorkshopPage extends StatelessWidget {
  const WorkshopPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      art: 'assets/scenes/workshop/workshop.webp',
      title: '工作室',
      npc: GameCharacters.chestnut,
      npcAt: const Offset(0.2, 0.95),
      greeting: () => ['這裡是你的工作室，桌上的東西都能調整。'],
      tips: const ['鈴鐺管提醒，地球儀管一般設定，鑰匙是帳號，盾牌通往資料保險箱。', '窗邊可以看看關於 Nudge 的故事。'],
      objects: [
        SceneObject(
          id: 'bell',
          label: '鈴鐺',
          hint: '提醒與通知',
          rect: _r(0.2, 0.36, 0.14, 0.15),
          onTap: (c, _) => _push(c, const ReminderCenterPage()),
        ),
        SceneObject(
          id: 'globe',
          label: '地球儀',
          hint: '一般設定',
          rect: _r(0.35, 0.36, 0.13, 0.15),
          onTap: (c, _) => _push(c, const SettingsPage()),
        ),
        SceneObject(
          id: 'key',
          label: '鑰匙',
          hint: '帳號',
          rect: _r(0.56, 0.32, 0.13, 0.19),
          onTap: (c, _) => _push(c, const AccountPage()),
        ),
        SceneObject(
          id: 'shield',
          label: '盾牌',
          hint: '資料保險箱',
          rect: _r(0.7, 0.36, 0.15, 0.15),
          onTap: (c, _) => _push(c, const VaultPage()),
        ),
        SceneObject(
          id: 'window',
          label: '窗戶',
          hint: '關於 Nudge',
          rect: _r(0.75, 0.1, 0.22, 0.23),
          onTap: (c, _) => _push(c, const AboutPage()),
        ),
      ],
      effects: const [
        SceneEffect.stars(count: 12, band: 0.3),
        SceneEffect.flicker([Offset(0.53, 0.06), Offset(0.03, 0.4)]),
        SceneEffect.dust(),
      ],
    ),
  );
}

/// 資料保險箱: the privacy and data-rights page behind the vault door.
class VaultPage extends StatelessWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      art: 'assets/scenes/vault/vault.webp',
      title: '資料保險箱',
      npc: GameCharacters.bell,
      npcAt: const Offset(0.2, 0.95),
      greeting: () => ['我是保險箱的守門人鐘鐘。你的資料怎麼用，由你決定。'],
      tips: const ['大門後面是匯出和刪除申請；封蠟台是健康資料同意。', '清除本機快取不等於刪除雲端資料，我們不會騙你。'],
      objects: [
        SceneObject(
          id: 'door',
          label: '保險箱大門',
          hint: '匯出與刪除',
          rect: _r(0.28, 0.15, 0.5, 0.4),
          onTap: (c, _) => _push(c, const PrivacyDataPage()),
        ),
        SceneObject(
          id: 'seal',
          label: '同意封蠟',
          hint: '健康資料同意',
          rect: _r(0.72, 0.43, 0.27, 0.37),
          onTap: (c, _) => _push(c, const PrivacyDataPage()),
        ),
      ],
      effects: const [
        SceneEffect.flicker([
          Offset(0.24, 0.13),
          Offset(0.84, 0.13),
        ], radius: 0.05),
        SceneEffect.sparkle([
          Offset(0.76, 0.32),
          Offset(0.72, 0.4),
          Offset(0.88, 0.47),
        ]),
        SceneEffect.dust(),
      ],
    ),
  );
}

/// 裝置工作台: the Nudge device page on a desk.
class DeviceBenchPage extends StatelessWidget {
  const DeviceBenchPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      art: 'assets/scenes/workbench/workbench.webp',
      title: '裝置工作台',
      npc: GameCharacters.stella,
      npcAt: const Offset(0.2, 0.95),
      greeting: () => ['桌上那顆就是你的 Nudge 裝置，點它就能連線、看燈環。'],
      tips: const ['天線閃爍時代表正在找訊號。', '筆記本裡有裝置的使用說明。'],
      objects: [
        SceneObject(
          id: 'device',
          label: 'Nudge 裝置',
          hint: '連線與狀態',
          rect: _r(0.42, 0.36, 0.2, 0.15),
          onTap: (c, _) => _push(c, const NudgeDevicePage()),
        ),
        SceneObject(
          id: 'notebook',
          label: '筆記本',
          hint: '使用說明',
          rect: _r(0.82, 0.37, 0.16, 0.14),
          onTap: (c, _) => _push(c, const NudgeDevicePage()),
        ),
      ],
      effects: const [
        SceneEffect.stars(count: 16, band: 0.35),
        SceneEffect.flicker([
          Offset(0.5, 0.42),
          Offset(0.63, 0.34),
          Offset(0.35, 0.33),
        ], radius: 0.03),
        SceneEffect.dust(),
      ],
    ),
  );
}
