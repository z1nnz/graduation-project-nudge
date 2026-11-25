import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../widgets/scene_room.dart';
import 'privacy_data_page.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// 資料保險箱: the privacy and data-rights page behind the vault door.
class VaultPage extends StatelessWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      art: 'assets/scenes/vault/vault.webp',
      wide: const SceneWideLayout(
        art: 'assets/scenes/vault/vault_wide.webp',
        npcAt: Offset(0.3, 0.9),
        rects: {
          'door': Rect.fromLTWH(0.4, 0.15, 0.4, 0.53),
          'seal': Rect.fromLTWH(0.81, 0.43, 0.16, 0.39),
        },
        effects: [
          SceneEffect.flicker([
            Offset(0.37, 0.16),
            Offset(0.81, 0.16),
          ], radius: 0.04),
          SceneEffect.sparkle([
            Offset(0.86, 0.46),
            Offset(0.94, 0.48),
            Offset(0.72, 0.4),
          ]),
          SceneEffect.dust(count: 16),
        ],
      ),
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
