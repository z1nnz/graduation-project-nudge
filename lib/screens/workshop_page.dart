import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../widgets/scene_room.dart';
import 'about_page.dart';
import 'account_page.dart';
import 'reminder_center_page.dart';
import 'settings_page.dart';
import 'vault_page.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// 工作室: settings as objects on a workbench.
class WorkshopPage extends StatelessWidget {
  const WorkshopPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      art: 'assets/scenes/workshop/workshop.webp',
      wide: const SceneWideLayout(
        art: 'assets/scenes/workshop/workshop_wide.webp',
        npcAt: Offset(0.2, 0.92),
        rects: {
          'bell': Rect.fromLTWH(0.31, 0.42, 0.08, 0.17),
          'globe': Rect.fromLTWH(0.45, 0.41, 0.1, 0.18),
          'key': Rect.fromLTWH(0.6, 0.38, 0.08, 0.2),
          'shield': Rect.fromLTWH(0.7, 0.39, 0.11, 0.2),
          'window': Rect.fromLTWH(0.8, 0.07, 0.13, 0.33),
        },
        effects: [
          SceneEffect.stars(count: 10, band: 0.3),
          SceneEffect.flicker([
            Offset(0.58, 0.08),
            Offset(0.07, 0.38),
            Offset(0.95, 0.68),
          ]),
          SceneEffect.dust(count: 20),
        ],
      ),
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
