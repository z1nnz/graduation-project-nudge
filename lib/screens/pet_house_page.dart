import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character_catalog.dart';
import '../state/app_state.dart';
import '../widgets/npc_dialog.dart';
import '../widgets/player_avatar.dart';
import '../widgets/scene_room.dart';
import '../widgets/sprite_animation.dart';
import '../widgets/world_life.dart';

/// Pet house (J3), same scene as the Web's: walk to a pet to pick it, put a
/// treat in the bowl, pat it on the cushion, read the growth board. The
/// choice stays on this device; growth reads existing focus minutes; treats
/// and pats change no numbers.
class PetHousePage extends StatefulWidget {
  const PetHousePage({super.key, this.focusMinutes});

  /// Overrides the minutes read from [AppState] (tests).
  final int? focusMinutes;

  @override
  State<PetHousePage> createState() => _PetHousePageState();
}

class _Spot {
  const _Spot(this.tall, this.wide);
  final Rect tall, wide;
  Rect of(bool w) => w ? wide : tall;
}

const _spots = {
  'house': _Spot(
    Rect.fromLTWH(0.05, 0.55, 0.26, 0.12),
    Rect.fromLTWH(0.08, 0.54, 0.12, 0.2),
  ),
  'bowl': _Spot(
    Rect.fromLTWH(0.08, 0.84, 0.1, 0.035),
    Rect.fromLTWH(0.2, 0.82, 0.05, 0.05),
  ),
  'cushion': _Spot(
    Rect.fromLTWH(0.24, 0.84, 0.16, 0.04),
    Rect.fromLTWH(0.31, 0.83, 0.08, 0.06),
  ),
  'board': _Spot(
    Rect.fromLTWH(0.44, 0.6, 0.14, 0.09),
    Rect.fromLTWH(0.57, 0.62, 0.07, 0.13),
  ),
  'pick_owl': _Spot(
    Rect.fromLTWH(0.1, 0.69, 0.1, 0.06),
    Rect.fromLTWH(0.23, 0.62, 0.045, 0.08),
  ),
  'pick_fox': _Spot(
    Rect.fromLTWH(0.23, 0.73, 0.1, 0.06),
    Rect.fromLTWH(0.3, 0.68, 0.045, 0.08),
  ),
  'pick_slime': _Spot(
    Rect.fromLTWH(0.35, 0.68, 0.1, 0.06),
    Rect.fromLTWH(0.37, 0.62, 0.045, 0.08),
  ),
};

class _PetHousePageState extends State<PetHousePage> {
  PetSpecies? _choice;
  PlayerLook _look = PlayerLook.standard;
  Offset _at = const Offset(0.5, 0.9);
  PlayerAnimation _anim = PlayerAnimation.idle;
  Duration _walk = Duration.zero;
  PetAnimation _petAnim = PetAnimation.idle;
  String? _petAt;
  bool _bowlFull = false;
  String? _note;
  PetStage? _savedStage;

  @override
  void initState() {
    super.initState();
    PetChoiceStore.load().then(
      (c) => mounted ? setState(() => _choice = c) : null,
    );
    PlayerLookStore.load().then(
      (l) => mounted ? setState(() => _look = l) : null,
    );
  }

  int _minutes(BuildContext context) {
    if (widget.focusMinutes != null) return widget.focusMinutes!;
    final state = context.read<AppState>();
    return state.dailySummaries.fold<int>(0, (s, d) => s + d.focusMinutes);
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// The player walks below [id] first; the feature follows on arrival.
  Future<void> _walkTo(String id, bool wide) async {
    final r = _spots[id]!.of(wide);
    final target = Offset(
      (r.center.dx).clamp(0.06, 0.94),
      (r.bottom + 0.04).clamp(0.62, 0.95),
    );
    final d = (target - _at).distance;
    final ms = _still ? 0 : math.min(1400, (d / 0.32 * 1000).round());
    final dx = target.dx - _at.dx, dy = target.dy - _at.dy;
    setState(() {
      _walk = Duration(milliseconds: ms);
      _anim = ms == 0
          ? PlayerAnimation.idle
          : PlayerAnimation.walk(
              dx.abs() > dy.abs()
                  ? (dx > 0 ? AxisDirection.right : AxisDirection.left)
                  : (dy > 0 ? AxisDirection.down : AxisDirection.up),
            );
      _at = target;
    });
    if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
    if (mounted) setState(() => _anim = PlayerAnimation.idle);
  }

  void _choose(PetSpecies s) {
    PetChoiceStore.save(s);
    setState(() {
      _choice = s;
      _petAnim = PetAnimation.happy;
      _petAt = 'cushion';
      _note = '${petNames[s]!.$1}成為你的寵物了！';
    });
  }

  SceneObject _obj(
    String id,
    String label,
    String hint,
    Future<void> Function(BuildContext, bool) act,
  ) => SceneObject(
    id: id,
    label: label,
    hint: hint,
    rect: _spots[id]!.tall,
    onTap: (c, room) async {
      final wide =
          MediaQuery.sizeOf(c).width >= 840 &&
          MediaQuery.sizeOf(c).width /
                  math.max(1, MediaQuery.sizeOf(c).height) >=
              1.05;
      await _walkTo(id, wide);
      if (c.mounted) await act(c, wide);
    },
  );

  @override
  Widget build(BuildContext context) {
    final minutes = _minutes(context);
    final stage = petStageFor(minutes);
    if (stage != _savedStage) {
      _savedStage = stage;
      PetStageCache.save(stage);
    }
    final name = _choice == null ? null : petNames[_choice]!.$1;
    return Scaffold(
      body: SceneRoom(
        art: 'assets/scenes/garden/garden.webp',
        title: '寵物小屋',
        npc: GameCharacters.sprout,
        npcAt: const Offset(0.75, 0.93),
        greeting: () => [
          name == null ? '這三個小傢伙在等一個家，走過去看看誰跟你最合得來？' : '$name今天也很有精神！',
        ],
        tips: const ['點心只是一起玩，不會改變任何數字。', '專注分鐘累積起來，寵物就會慢慢長大。'],
        objects: [
          for (final s in PetSpecies.values)
            _obj('pick_${s.name}', petNames[s]!.$1, '就是牠了嗎？', (c, _) async {
              setState(() => _anim = PlayerAnimation.wave);
              await NpcDialog.show(
                c,
                speaker: GameCharacters.sprout,
                lines: ['${petNames[s]!.$1}歪著頭看你，好像在問「要帶我回家嗎？」'],
                actions: [
                  NpcDialogAction('帶${petNames[s]!.$1}回家', () => _choose(s)),
                ],
              );
            }),
          _obj('bowl', '飯碗', '放一塊點心', (c, _) async {
            if (_choice == null) {
              setState(() => _note = '先選一隻寵物，牠才會來吃點心喔。');
              return;
            }
            setState(() {
              _anim = PlayerAnimation.snack;
              _bowlFull = true;
              _petAt = 'bowl';
              _petAnim = PetAnimation.happy;
              _note = '喀滋喀滋！點心只是互動，不會改變任何數字。';
            });
            unawaited(
              Future<void>.delayed(const Duration(milliseconds: 2400), () {
                if (mounted) setState(() => _bowlFull = false);
              }),
            );
          }),
          _obj('cushion', '坐墊', '摸摸牠', (c, _) async {
            if (_choice == null) {
              setState(() => _note = '坐墊上還沒有人，先挑一隻寵物吧。');
              return;
            }
            setState(() {
              _anim = PlayerAnimation.sit;
              _petAt = 'cushion';
              _petAnim = PetAnimation.cuddle;
              _note = '牠蹭了蹭你的手。';
            });
          }),
          _obj('board', '成長板', '牠長大了多少', (c, _) async {
            setState(() => _anim = PlayerAnimation.think);
            await showDialog<void>(
              context: c,
              builder: (_) => _GrowthBoard(
                species: _choice ?? PetSpecies.owl,
                minutes: minutes,
              ),
            );
          }),
          _obj('house', '寵物屋', '看看牠', (c, _) async {
            setState(
              () =>
                  _note = name == null ? '先在屋前挑一隻吧！' : '$name的家，屋頂上的星星是牠最喜歡的。',
            );
          }),
        ],
        wide: SceneWideLayout(
          art: 'assets/scenes/garden/garden_wide.webp',
          npcAt: const Offset(0.62, 0.92),
          rects: {for (final e in _spots.entries) e.key: e.value.wide},
          effects: const [
            SceneEffect.fireflies(count: 16, top: 0.3, band: 0.5),
          ],
        ),
        effects: const [SceneEffect.fireflies(count: 12, top: 0.35, band: 0.5)],
        overlay: (context, art, wide) => _overlay(art, wide, stage),
        footer: _note == null
            ? null
            : Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('pet-house-note'),
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xEEF6E7C8),
                  child: Text(_note!, textAlign: TextAlign.center),
                ),
              ),
      ),
    );
  }

  List<Widget> _overlay(Rect art, bool wide, PetStage stage) {
    Rect at(String id) {
      final r = _spots[id]!.of(wide);
      return Rect.fromLTWH(
        art.left + r.left * art.width,
        art.top + r.top * art.height,
        r.width * art.width,
        r.height * art.height,
      );
    }

    Widget prop(String id, String file) => Positioned.fromRect(
      rect: at(id),
      child: IgnorePointer(
        child: Image.asset(
          'assets/scenes/pet_house/$file',
          key: Key('pet-prop-$id'),
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
    final petScale = (art.width / 340).roundToDouble().clamp(2.0, 4.0);
    final player = Offset(
      art.left + _at.dx * art.width,
      art.top + _at.dy * art.height,
    );
    final ps = (art.width / 400).roundToDouble().clamp(2.0, 3.0);
    return [
      prop('house', 'house.png'),
      prop('bowl', _bowlFull ? 'bowl_full.png' : 'bowl.png'),
      prop('cushion', 'cushion.png'),
      Positioned.fromRect(
        rect: at('board'),
        child: IgnorePointer(child: _BoardSign(stage: stage)),
      ),
      for (final s in PetSpecies.values)
        if (_choice == null || _choice == s)
          Positioned(
            left:
                (_choice == s && _petAt != null
                        ? at(_petAt!)
                        : at('pick_${s.name}'))
                    .center
                    .dx -
                16 * petScale,
            top:
                (_choice == s && _petAt != null
                        ? at(_petAt!)
                        : at('pick_${s.name}'))
                    .bottom -
                30 * petScale,
            child: IgnorePointer(
              child: PetSprite(
                key: Key('pet-${s.name}'),
                species: s,
                stage: stage,
                animation: _choice == s ? _petAnim : PetAnimation.idle,
                scale: petScale,
                onEnd: () => setState(() => _petAnim = PetAnimation.idle),
              ),
            ),
          ),
      AnimatedPositioned(
        key: const Key('pet-house-player'),
        duration: _walk,
        left: player.dx - playerFrameWidth * ps / 2,
        top: player.dy - playerPivot.dy * ps,
        child: IgnorePointer(
          child: PlayerAvatar(
            look: _look,
            animation: _anim,
            scale: ps,
            onEnd: () => setState(() => _anim = PlayerAnimation.idle),
            fallback: CharacterSprite(
              character: GameCharacters.companion,
              size: playerFrameHeight * ps,
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: art,
        child: IgnorePointer(
          child: WorldClock(
            builder: (_, f, _) => CustomPaint(
              key: const Key('pet-house-near'),
              painter: WorldNearPainter(
                frame: f,
                fall: WorldFall.petals,
                count: 12,
                plants: const [
                  WorldPlant(0.02, size: 0.16, bloom: Color(0xFFE27AA6)),
                  WorldPlant(0.98, size: 0.14),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _BoardSign extends StatelessWidget {
  const _BoardSign({required this.stage});
  final PetStage stage;

  @override
  Widget build(BuildContext context) {
    final lvl = stage.index;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF8A5A34),
        border: Border.all(color: const Color(0xFF3A2216), width: 2),
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Icon(
                  Icons.star,
                  size: 10,
                  color: i <= lvl
                      ? const Color(0xFFFFC54D)
                      : const Color(0xFF3A2216),
                ),
            ],
          ),
          Expanded(
            child: FractionallySizedBox(
              heightFactor: (lvl + 1) / 3,
              alignment: Alignment.bottomCenter,
              child: Container(width: 5, color: const Color(0xFF6FBF5A)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthBoard extends StatelessWidget {
  const _GrowthBoard({required this.species, required this.minutes});
  final PetSpecies species;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final stage = petStageFor(minutes);
    final next = petMinutesToNext(minutes);
    final names = petNames[species]!.$2;
    return AlertDialog(
      backgroundColor: const Color(0xFFF6E7C8),
      title: const Text('成長板'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final st in PetStage.values)
            Opacity(
              opacity: st.index <= stage.index ? 1 : 0.45,
              child: ListTile(
                leading: PetSprite(species: species, stage: st, scale: 1.5),
                title: Text(names[st.index]),
                trailing: Text(switch (st) {
                  PetStage.baby => '一開始',
                  PetStage.teen => '專注 $petTeenMinutes 分',
                  PetStage.adult => '專注 $petAdultMinutes 分',
                }),
              ),
            ),
          Text(
            next == 0
                ? '專注共 $minutes 分鐘，已經長到最大了！'
                : '專注共 $minutes 分鐘，再 $next 分鐘長大。',
            key: const Key('pet-growth-text'),
          ),
          const SizedBox(height: 6),
          const Text(
            '只讀你已確認的專注紀錄；寵物不會發放經驗值或自律幣。',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('關閉'),
        ),
      ],
    );
  }
}
