import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/character_catalog.dart';
import '../models/garden_growth.dart';
import '../state/app_state.dart';
import '../theme/game_ui.dart';
import '../widgets/npc_dialog.dart';
import '../widgets/scene_room.dart';

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

/// 星光花園: each soil bed is one plant, one sprout per week (newest right),
/// grown from the account's own daily records. Opens at level 10, like Web.
class GardenScenePage extends StatelessWidget {
  const GardenScenePage({super.key});

  // Soil inside each bed, measured from the art.
  static const _tallBeds = [
    Rect.fromLTWH(0.136, 0.357, 0.235, 0.089),
    Rect.fromLTWH(0.403, 0.356, 0.212, 0.088),
    Rect.fromLTWH(0.654, 0.356, 0.226, 0.081),
    Rect.fromLTWH(0.082, 0.468, 0.275, 0.107),
  ];
  static const _wideBeds = [
    Rect.fromLTWH(0.31, 0.339, 0.13, 0.098),
    Rect.fromLTWH(0.462, 0.335, 0.134, 0.113),
    Rect.fromLTWH(0.62, 0.334, 0.128, 0.102),
    Rect.fromLTWH(0.291, 0.475, 0.145, 0.119),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final level = state.avatarLevel;
    final open = level >= GardenGrowth.minLevel;
    final now = DateTime.now();
    final weeks = {
      for (final p in GardenPlant.all)
        p: GardenGrowth.weeksFor(p, state.dailySummaries, now),
    };
    return Scaffold(
      body: SceneRoom(
        art: 'assets/scenes/garden/garden.webp',
        title: '星光花園',
        npc: GameCharacters.sprout,
        npcAt: const Offset(0.4, 0.86),
        greeting: () => [
          open
              ? '我是園丁苗苗。每一畦土是一種植物，一週長一株，越右邊越新。'
              : '花園要角色 Lv ${GardenGrowth.minLevel} 才開門（目前 Lv $level）。等級只來自真實的行動喔。',
        ],
        tips: const [
          '星光百合靠專注長大，蘋果樹靠運動，月鈴花靠睡眠，向日葵靠走路。',
          '水井的水只是讓植物開心，不會改變任何紀錄喔。',
        ],
        objects: [
          SceneObject(
            id: 'well',
            label: '水井',
            hint: '澆水',
            rect: _r(0.76, 0.15, 0.2, 0.17),
            onTap: (c, room) => room.burst(
              BurstKind.leaf,
              from: 'well',
              count: 8,
              announce: '你幫花園澆了水。澆水只是互動，不會改變任何紀錄。',
            ),
          ),
          SceneObject(
            id: 'greenhouse',
            label: '溫室',
            hint: '植物怎麼長',
            rect: _r(0.03, 0.1, 0.3, 0.22),
            onTap: (c, _) => NpcDialog.show(
              c,
              speaker: GameCharacters.sprout,
              lines: [
                for (final p in GardenPlant.all)
                  '${p.name}：一週${p.verb}累積 ${p.thresholds.map((t) => t.toStringAsFixed(0)).join('／')} ${p.unit}，依序長到第 1–5 階段。',
              ],
            ),
          ),
        ],
        wide: const SceneWideLayout(
          art: 'assets/scenes/garden/garden_wide.webp',
          npcAt: Offset(0.22, 0.8),
          rects: {
            'well': Rect.fromLTWH(0.79, 0.15, 0.11, 0.23),
            'greenhouse': Rect.fromLTWH(0.1, 0.1, 0.18, 0.26),
          },
          effects: [
            SceneEffect.stars(count: 24, band: 0.1),
            SceneEffect.fireflies(count: 20, top: 0.25, band: 0.6),
          ],
          walkers: [
            SceneWalker(GameCharacters.companion, [
              Offset(0.52, 0.96),
              Offset(0.52, 0.64),
            ]),
          ],
        ),
        effects: const [
          SceneEffect.stars(count: 18, band: 0.08),
          SceneEffect.fireflies(count: 16, top: 0.3, band: 0.55),
          SceneEffect.flutter(count: 5, top: 0.05, band: 0.3),
        ],
        walkers: const [
          SceneWalker(GameCharacters.companion, [
            Offset(0.5, 0.97),
            Offset(0.5, 0.62),
          ]),
        ],
        overlay: (context, art, wide) {
          if (!open) return const [];
          final beds = wide ? _wideBeds : _tallBeds;
          return [
            for (final (i, plant) in GardenPlant.all.indexed)
              Positioned(
                left: art.left + beds[i].left * art.width,
                top: art.top + beds[i].top * art.height,
                width: beds[i].width * art.width,
                height: beds[i].height * art.height,
                child: _Bed(plant: plant, weeks: weeks[plant]!),
              ),
          ];
        },
      ),
    );
  }
}

class _Bed extends StatelessWidget {
  const _Bed({required this.plant, required this.weeks});
  final GardenPlant plant;
  final List<GardenWeek> weeks;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = math.max(
        28.0,
        math.min(box.maxWidth / 3.2, box.maxHeight * 1.5),
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (i, w) in weeks.indexed)
            Semantics(
              key: ValueKey('garden-${plant.id}-$i'),
              button: true,
              label:
                  '${plant.name}，${w.start.month}/${w.start.day} 那週，${w.stage == 0 ? '空土' : '第 ${w.stage} 階段'}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => NpcDialog.show(
                  context,
                  speaker: GameCharacters.sprout,
                  lines: [
                    w.stage == 0
                        ? '${w.start.month}/${w.start.day} 那週還沒有${plant.verb}紀錄，這裡是空土。'
                        : '${plant.name}在 ${w.start.month}/${w.start.day} 那週${plant.verb}了 ${w.total.toStringAsFixed(plant.id == 'moonflower' ? 1 : 0)} ${plant.unit}，長到第 ${w.stage} 階段！',
                  ],
                ),
                child: Transform.translate(
                  offset: Offset(0, -size * 0.3),
                  child: SizedBox.square(
                    dimension: i == weeks.length - 1 ? size * 1.25 : size,
                    child: w.stage == 0
                        ? const Center(
                            child: Text(
                              '·',
                              style: TextStyle(
                                color: Color(0xFFD9C29A),
                                fontSize: 20,
                              ),
                            ),
                          )
                        : _PlantSprite(row: plant.row, col: w.stage - 1),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _PlantSprite extends StatelessWidget {
  const _PlantSprite({required this.row, required this.col});
  final int row, col;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => ClipRect(
      child: OverflowBox(
        maxWidth: box.maxWidth * 5,
        maxHeight: box.maxHeight * 5,
        alignment: Alignment(-1 + col * 0.5, -1 + row * 0.5),
        child: Image.asset(
          'assets/scenes/garden/plants.webp',
          width: box.maxWidth * 5,
          height: box.maxHeight * 5,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        ),
      ),
    ),
  );
}

/// 遊樂園: the park map. The four mini games run on the Web arcade (free
/// plays every day), so each ride opens it in the browser.
class ParkScenePage extends StatelessWidget {
  const ParkScenePage({super.key});

  static final arcade = Uri.parse(
    'https://z1nnz.github.io/graduation-project-nudge/arcade.html',
  );

  Future<void> _ride(BuildContext context) async {
    final ok = await launchUrl(arcade, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      await NpcDialog.show(
        context,
        speaker: GameCharacters.bounce,
        lines: const ['現在打不開遊樂園，等等再試一次吧！'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SceneObject ride(String id, String label, String hint, Rect rect) =>
        SceneObject(
          id: id,
          label: label,
          hint: hint,
          rect: rect,
          onTap: (c, _) => _ride(c),
        );
    return Scaffold(
      body: SceneRoom(
        art: 'assets/scenes/park/park.webp',
        title: '遊樂園',
        npc: GameCharacters.bounce,
        npcAt: const Offset(0.24, 0.95),
        greeting: () => ['我是跳跳！每天可以免費玩 3 次，四個遊樂設施隨你挑～'],
        tips: const ['專注 25 分鐘以上，還能多拿獎勵券喔。', '跳房子是免費的，跳幾下活動一下筋骨吧～'],
        objects: [
          ride('wheel', '摩天輪', '接星星', _r(0.05, 0.03, 0.4, 0.29)),
          ride('stall', '撈魚攤', '星光釣魚', _r(0.02, 0.4, 0.43, 0.2)),
          ride('stage', '舞台', '鐘塔節奏', _r(0.66, 0.4, 0.3, 0.16)),
          ride('carousel', '旋轉木馬', '記憶配對', _r(0.65, 0.1, 0.32, 0.25)),
          SceneObject(
            id: 'hopscotch',
            label: '跳房子',
            hint: '跳一跳',
            rect: _r(0.66, 0.57, 0.26, 0.15),
            onTap: (c, room) => room.burst(
              BurstKind.star,
              from: 'hopscotch',
              announce: '跳了一格！',
            ),
          ),
        ],
        effects: const [
          SceneEffect.clouds(top: 0.0, band: 0.05, count: 3),
          SceneEffect.birds(top: 0.05, count: 4),
          SceneEffect.sparkle([
            Offset(0.24, 0.05),
            Offset(0.09, 0.15),
            Offset(0.39, 0.15),
            Offset(0.8, 0.13),
            Offset(0.7, 0.2),
          ]),
          SceneEffect.glow([
            Offset(0.27, 0.8),
            Offset(0.73, 0.8),
            Offset(0.6, 0.66),
          ]),
        ],
        walkers: const [
          SceneWalker(GameCharacters.companion, [
            Offset(0.5, 0.97),
            Offset(0.5, 0.62),
            Offset(0.47, 0.42),
          ]),
          SceneWalker(GameCharacters.sprout, [
            Offset(0.3, 0.66),
            Offset(0.45, 0.68),
          ], speed: 0.03),
        ],
        wide: const SceneWideLayout(
          art: 'assets/scenes/park/park_wide.webp',
          npcAt: Offset(0.42, 0.9),
          rects: {
            'wheel': Rect.fromLTWH(0.18, 0.05, 0.19, 0.3),
            'carousel': Rect.fromLTWH(0.7, 0.12, 0.2, 0.26),
            'stall': Rect.fromLTWH(0.17, 0.37, 0.24, 0.21),
            'stage': Rect.fromLTWH(0.7, 0.38, 0.18, 0.18),
            'hopscotch': Rect.fromLTWH(0.72, 0.57, 0.18, 0.15),
          },
          effects: [
            SceneEffect.clouds(top: 0.0, band: 0.07, count: 5),
            SceneEffect.birds(top: 0.06),
            SceneEffect.sparkle([
              Offset(0.28, 0.06),
              Offset(0.2, 0.13),
              Offset(0.35, 0.13),
              Offset(0.79, 0.14),
            ]),
          ],
          walkers: [
            SceneWalker(GameCharacters.companion, [
              Offset(0.535, 0.97),
              Offset(0.535, 0.62),
              Offset(0.44, 0.48),
            ]),
          ],
        ),
        footer: Center(
          child: Text(
            '遊戲在網頁版遊樂園進行，App 會幫你打開。',
            style: TextStyle(
              color: GamePalette.inkLight.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
