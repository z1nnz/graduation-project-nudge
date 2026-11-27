import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character_catalog.dart';
import '../state/app_state.dart';
import '../theme/game_ui.dart';
import '../widgets/home_decor_sheet.dart';
import '../widgets/player_avatar.dart';
import '../widgets/scene_room.dart';
import '../widgets/sprite_animation.dart';
import '../widgets/world_life.dart';
import 'avatar_shop_page.dart';
import 'character_page.dart';
import 'coin_wallet_page.dart';
import 'dressing_room_page.dart';
import 'tasks_page.dart';

/// The general store. Each object opens an existing, Cloud-backed page; the
/// room itself never changes coins or items.
class StoreScenePage extends StatefulWidget {
  const StoreScenePage({super.key});

  static const art = 'assets/scenes/store/store.webp';

  @override
  State<StoreScenePage> createState() => _StoreScenePageState();
}

class _StoreScenePageState extends State<StoreScenePage>
    with PlayerWalkMixin<StoreScenePage> {
  int _catPets = 0;

  /// Chestnut's reaction bubble (waves hello, shows an item, waves goodbye).
  WorldEmoteKind? _npcEmote = WorldEmoteKind.star;
  bool _catAwake = false;

  static const _tall = {
    'clothes': Rect.fromLTWH(0.03, 0.235, 0.3, 0.225),
    'furniture': Rect.fromLTWH(0.35, 0.235, 0.265, 0.23),
    'cabinet': Rect.fromLTWH(0.65, 0.19, 0.215, 0.27),
    'cashbox': Rect.fromLTWH(0.06, 0.49, 0.15, 0.085),
    'cat': Rect.fromLTWH(0.29, 0.51, 0.25, 0.065),
    'mirror': Rect.fromLTWH(0.75, 0.48, 0.24, 0.3),
  };
  static const _wide = {
    'clothes': Rect.fromLTWH(0.05, 0.2, 0.24, 0.45),
    'furniture': Rect.fromLTWH(0.33, 0.2, 0.24, 0.35),
    'cabinet': Rect.fromLTWH(0.59, 0.17, 0.16, 0.46),
    'cashbox': Rect.fromLTWH(0.26, 0.5, 0.09, 0.12),
    'cat': Rect.fromLTWH(0.43, 0.55, 0.1, 0.07),
    'mirror': Rect.fromLTWH(0.76, 0.33, 0.23, 0.42),
  };

  @override
  void initState() {
    super.initState();
    loadPlayerLook();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _npcEmote = null);
    });
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  /// Walk to the object, Chestnut shows it, then the feature opens; when
  /// the customer comes back, Chestnut waves.
  Future<void> _go(BuildContext c, String id, [Widget? page]) async {
    await walkBelow((isWideRoom(c) ? _wide : _tall)[id]!, floorTop: 0.68);
    if (!c.mounted) return;
    setState(() => _npcEmote = WorldEmoteKind.surprise);
    if (page == null) return;
    await Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    setState(() {
      _npcEmote = WorldEmoteKind.heart;
      _catAwake = true;
      playerAnim = PlayerAnimation.happy;
    });
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _npcEmote = null);
    });
  }

  Future<void> _tryOn(BuildContext c) async {
    await _go(c, 'mirror');
    if (!c.mounted) return;
    var look = playerLook;
    await showDialog<void>(
      context: c,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          backgroundColor: GamePalette.parchment,
          title: const Text('鏡子：試穿看看'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: const Key('store-mirror'),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA9C0DE),
                    border: Border.all(color: GamePalette.goldDeep, width: 6),
                  ),
                  child: Transform.flip(
                    flipX: true,
                    child: PlayerAvatar(
                      key: ValueKey(look),
                      look: look,
                      animation: PlayerAnimation.turn,
                      scale: 1,
                      fallback: const Icon(Icons.checkroom, size: 96),
                    ),
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final o in playerParts[PlayerLayer.outfit]!)
                      ActionChip(
                        key: Key('try-${o.id}'),
                        label: Text(o.name),
                        onPressed: () => set(
                          () => look = look.withPart(PlayerLayer.outfit, o.id),
                        ),
                      ),
                  ],
                ),
                const Text(
                  '試穿不會花錢，也不會換掉你身上的衣服。',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('離開鏡子'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _push(c, const DressingRoomPage());
              },
              child: const Text('去更衣室'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coins = context.select<AppState, int>((s) => s.disciplineCoins);
    return Scaffold(
      body: SceneRoom(
        art: StoreScenePage.art,
        wide: const SceneWideLayout(
          art: 'assets/scenes/store/store_wide.webp',
          npcAt: Offset(0.17, 0.9),
          rects: {
            'clothes': Rect.fromLTWH(0.05, 0.2, 0.24, 0.45),
            'furniture': Rect.fromLTWH(0.33, 0.2, 0.24, 0.35),
            'cabinet': Rect.fromLTWH(0.59, 0.17, 0.16, 0.46),
            'cashbox': Rect.fromLTWH(0.26, 0.5, 0.09, 0.12),
            'cat': Rect.fromLTWH(0.43, 0.55, 0.1, 0.07),
            'mirror': Rect.fromLTWH(0.76, 0.33, 0.23, 0.42),
          },
          effects: [
            SceneEffect.flicker([
              Offset(0.43, 0.13),
              Offset(0.62, 0.13),
              Offset(0.59, 0.54),
            ]),
            SceneEffect.sparkle([
              Offset(0.63, 0.3),
              Offset(0.7, 0.28),
              Offset(0.65, 0.5),
            ]),
            SceneEffect.dust(count: 22),
          ],
          walkers: [
            SceneWalker(GameCharacters.letty, [
              Offset(0.4, 0.9),
              Offset(0.62, 0.86),
              Offset(0.72, 0.95),
            ]),
          ],
        ),
        title: '小鎮雜貨店',
        npc: GameCharacters.chestnut,
        npcAt: const Offset(0.3, 0.88),
        trailing: _Purse(coins: coins),
        greeting: () => ['歡迎光臨！你的錢箱裡有 $coins 枚自律幣。'],
        tips: const [
          '左邊的衣服架可以買新的服裝和配件。',
          '中間的木架擺的是小屋家具，買了就能回家布置。',
          '右邊發亮的玻璃櫃裡，收著可以一起冒險的角色。',
          '站到鏡子前面，就能進更衣室換裝。',
          '金幣只能靠真實的任務和專注賺到，我這裡不打折，但絕對不會多扣。',
          '那隻橘貓叫「麻糬」，牠只在你摸牠的時候才會醒來。',
        ],
        objects: [
          SceneObject(
            id: 'clothes',
            label: '衣服架',
            hint: '服裝與配件',
            rect: const Rect.fromLTWH(0.03, 0.235, 0.3, 0.225),
            onTap: (c, _) => _go(c, 'clothes', const AvatarShopPage()),
          ),
          SceneObject(
            id: 'furniture',
            label: '家具架',
            hint: '小屋家具',
            rect: const Rect.fromLTWH(0.35, 0.235, 0.265, 0.23),
            onTap: (c, _) async {
              await _go(c, 'furniture');
              if (c.mounted) await showHomeDecorSheet(c);
            },
          ),
          SceneObject(
            id: 'cabinet',
            label: '玻璃櫃',
            hint: '角色',
            rect: const Rect.fromLTWH(0.65, 0.19, 0.215, 0.27),
            onTap: (c, _) => _go(c, 'cabinet', const CharacterPage()),
          ),
          SceneObject(
            id: 'cashbox',
            label: '錢箱',
            hint: '自律幣錢包',
            rect: const Rect.fromLTWH(0.06, 0.49, 0.15, 0.085),
            onTap: (c, room) async {
              await _go(c, 'cashbox');
              if (!c.mounted) return;
              room.burst(BurstKind.coin, from: 'cashbox', count: 5);
              _push(
                c,
                CoinWalletPage(onOpenTasks: () => _push(c, const TasksPage())),
              );
            },
          ),
          SceneObject(
            id: 'cat',
            label: '麻糬',
            hint: '摸摸貓',
            rect: const Rect.fromLTWH(0.29, 0.51, 0.25, 0.065),
            onTap: (c, room) async {
              await _go(c, 'cat');
              setState(() {
                _catPets++;
                _catAwake = true;
                playerAnim = PlayerAnimation.wave;
              });
              room.burst(
                BurstKind.heart,
                from: 'cat',
                count: 4 + (_catPets.clamp(0, 4)),
                announce: _catPets > 3 ? '麻糬翻了個身，呼嚕呼嚕。' : '麻糬呼嚕了一聲。',
              );
              if (_catPets == 5) {
                room.say(const ['麻糬很少讓客人摸這麼久，牠很喜歡你喔！']);
              }
            },
          ),
          SceneObject(
            id: 'mirror',
            label: '鏡子',
            hint: '進更衣室換裝',
            rect: const Rect.fromLTWH(0.75, 0.48, 0.24, 0.3),
            onTap: (c, _) => _tryOn(c),
          ),
        ],
        effects: const [
          SceneEffect.glow([
            Offset(0.42, 0.125),
            Offset(0.67, 0.125),
            Offset(0.58, 0.5),
            Offset(0.02, 0.83),
          ]),
          SceneEffect.sparkle([
            Offset(0.72, 0.28),
            Offset(0.8, 0.25),
            Offset(0.7, 0.38),
            Offset(0.82, 0.36),
            Offset(0.74, 0.43),
            Offset(0.83, 0.44),
          ]),
          SceneEffect.dust(),
        ],
        overlay: (context, art, wide) => [
          walkingPlayer(
            art,
            fallback: CharacterSprite(
              character: GameCharacters.companion,
              size: 112,
            ),
          ),
          if (_catAwake)
            Positioned(
              left:
                  art.left +
                  ((wide ? _wide : _tall)['cat']!.center.dx) * art.width -
                  15,
              top:
                  art.top +
                  ((wide ? _wide : _tall)['cat']!.top) * art.height -
                  34,
              child: const IgnorePointer(
                child: WorldEmote(
                  WorldEmoteKind.surprise,
                  key: Key('store-cat-awake'),
                ),
              ),
            ),
          if (_npcEmote case final e?)
            Positioned(
              left: art.left + (wide ? 0.17 : 0.3) * art.width - 15,
              top: art.top + (wide ? 0.9 : 0.88) * art.height - 168,
              child: IgnorePointer(
                child: WorldEmote(e, key: const Key('store-npc-emote')),
              ),
            ),
          Positioned.fromRect(
            rect: art,
            child: IgnorePointer(
              child: WorldClock(
                builder: (_, f, _) => CustomPaint(
                  key: const Key('store-near'),
                  painter: WorldNearPainter(
                    frame: f,
                    count: 14,
                    plants: const [WorldPlant(0.99, size: 0.14)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Purse extends StatelessWidget {
  const _Purse({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '自律幣 $coins 枚',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: GamePalette.parchment,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: GamePalette.woodDeep, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 12, color: GamePalette.goldDeep),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(
              fontFamily: 'Cubic11',
              fontSize: 18,
              color: GamePalette.inkDark,
            ),
          ),
        ],
      ),
    ),
  );
}
