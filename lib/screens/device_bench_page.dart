import 'package:flutter/material.dart';

import '../models/character_catalog.dart';
import '../widgets/scene_room.dart';
import 'nudge_device_page.dart';

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// 裝置工作台: the Nudge device page on a desk.
class DeviceBenchPage extends StatelessWidget {
  const DeviceBenchPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneRoom(
      art: 'assets/scenes/workbench/workbench.webp',
      wide: const SceneWideLayout(
        art: 'assets/scenes/workbench/workbench_wide.webp',
        npcAt: Offset(0.2, 0.92),
        rects: {
          'device': Rect.fromLTWH(0.53, 0.32, 0.13, 0.15),
          'notebook': Rect.fromLTWH(0.76, 0.38, 0.12, 0.14),
        },
        effects: [
          SceneEffect.stars(count: 16, band: 0.35),
          SceneEffect.flicker([
            Offset(0.6, 0.38),
            Offset(0.47, 0.3),
          ], radius: 0.03),
          SceneEffect.dust(count: 18),
        ],
      ),
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
