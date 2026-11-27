import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/character_catalog.dart';
import '../state/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/scene_room.dart';
import '../widgets/sprite_animation.dart';
import '../widgets/world_life.dart';
import 'avatar_codex_page.dart';
import 'avatar_editor_page.dart';
import 'avatar_evolution_page.dart';
import 'avatar_experience_page.dart';
import 'avatar_icon_picker_page.dart';
import 'avatar_wardrobe_page.dart';
import 'character_page.dart';

/// Dressing room (J2): every character page lives behind an object here.
/// Walk to the rack and slide garments along it, put one on and turn in
/// the mirror (the reflection is the live character), flip the name card,
/// and step into the light pillar to evolve. The layered look is kept on
/// this device; data pages keep their own Cloud calls.
class DressingRoomPage extends StatefulWidget {
  const DressingRoomPage({super.key, this.nickname, this.level, this.openPage});

  /// Overrides for tests; otherwise read from [AppState].
  final String? nickname;
  final int? level;

  /// Opens a character page; defaults to pushing it (tests record it).
  final void Function(BuildContext context, Widget page)? openPage;

  @override
  State<DressingRoomPage> createState() => _DressingRoomPageState();
}

class _Place {
  const _Place(this.tall, this.wide);
  final Rect tall, wide;
  Rect of(bool w) => w ? wide : tall;
}

const _places = {
  'mirror': _Place(
    Rect.fromLTWH(0.64, 0.46, 0.24, 0.22),
    Rect.fromLTWH(0.66, 0.42, 0.08, 0.3),
  ),
  'rack': _Place(
    Rect.fromLTWH(0.1, 0.56, 0.42, 0.1),
    Rect.fromLTWH(0.2, 0.55, 0.22, 0.15),
  ),
  'card': _Place(
    Rect.fromLTWH(0.43, 0.37, 0.18, 0.1),
    Rect.fromLTWH(0.42, 0.39, 0.17, 0.13),
  ),
  'shelf': _Place(
    Rect.fromLTWH(0.12, 0.29, 0.25, 0.2),
    Rect.fromLTWH(0.23, 0.34, 0.14, 0.2),
  ),
  'pillar': _Place(
    Rect.fromLTWH(0.42, 0.62, 0.18, 0.1),
    Rect.fromLTWH(0.47, 0.66, 0.1, 0.14),
  ),
  'door_l': _Place(
    Rect.fromLTWH(0.0, 0.3, 0.12, 0.34),
    Rect.fromLTWH(0.05, 0.29, 0.14, 0.41),
  ),
  'door_r': _Place(
    Rect.fromLTWH(0.88, 0.3, 0.12, 0.34),
    Rect.fromLTWH(0.81, 0.29, 0.14, 0.41),
  ),
};

const _tabs = [
  (PlayerLayer.outfit, '衣服'),
  (PlayerLayer.headwear, '頭飾'),
  (PlayerLayer.accessory, '配件'),
  (PlayerLayer.body, '髮色'),
];

class _DressingRoomPageState extends State<DressingRoomPage> {
  PlayerLook _look = PlayerLook.standard;
  Offset _at = const Offset(0.5, 0.86);
  PlayerAnimation _anim = PlayerAnimation.idle;
  Duration _walk = Duration.zero;
  PlayerLayer _tab = PlayerLayer.outfit;
  bool _pillar = false;
  int _spin = 0;

  @override
  void initState() {
    super.initState();
    PlayerLookStore.load().then(
      (l) => mounted ? setState(() => _look = l) : null,
    );
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool _wide(BuildContext c) {
    final s = MediaQuery.sizeOf(c);
    return s.width >= 840 && s.width / math.max(1, s.height) >= 1.05;
  }

  Future<void> _walkTo(String id, bool wide) async {
    final r = _places[id]!.of(wide);
    final target = Offset(
      r.center.dx.clamp(0.08, 0.92),
      (r.bottom + 0.05).clamp(0.66, 0.92),
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

  void _wear(PlayerLayer layer, String? id) {
    final next = _look.withPart(layer, id);
    PlayerLookStore.save(next);
    setState(() {
      _look = next;
      _anim = PlayerAnimation.turn;
      _spin++;
    });
  }

  SceneObject _obj(
    String id,
    String label,
    String hint,
    Future<void> Function(BuildContext c) then,
  ) => SceneObject(
    id: id,
    label: label,
    hint: hint,
    rect: _places[id]!.tall,
    onTap: (c, room) async {
      await _walkTo(id, _wide(c));
      if (c.mounted) await then(c);
    },
  );

  Future<void> _open(BuildContext c, Widget page) async {
    if (widget.openPage != null) return widget.openPage!(c, page);
    await Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _showRack(BuildContext c) => _panel(
    c,
    '衣架',
    StatefulBuilder(
      builder: (context, set) => _Rack(
        look: _look,
        tab: _tab,
        onTab: (t) {
          setState(() => _tab = t);
          set(() {});
        },
        onWear: (layer, id) {
          _wear(layer, id);
          set(() {});
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
    alignment: Alignment.bottomCenter,
  );

  Future<void> _showCard(BuildContext c, String name, int level) {
    var flipped = false;
    return _panel(
      c,
      '名片',
      StatefulBuilder(
        builder: (context, set) => _FlipCard(
          flipped: flipped,
          look: _look,
          name: name,
          level: level,
          onFlip: () => set(() => flipped = !flipped),
          onClose: () => Navigator.of(context).pop(),
          onEditIcon: () => _open(c, const AvatarIconPickerPage()),
          onEditLook: () => _open(c, const AvatarEditorPage()),
          onWardrobe: () => _open(c, const AvatarWardrobePage()),
        ),
      ),
    );
  }

  /// A panel that rises out of the room (above the NPC and title bar).
  Future<void> _panel(
    BuildContext c,
    String label,
    Widget child, {
    Alignment alignment = Alignment.center,
  }) => showGeneralDialog<void>(
    context: c,
    barrierDismissible: true,
    barrierLabel: '關閉$label',
    barrierColor: const Color(0x66140A05),
    transitionDuration: Duration(milliseconds: _still ? 0 : 320),
    pageBuilder: (_, _, _) => SafeArea(
      child: Align(
        alignment: alignment,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
    transitionBuilder: (context, a, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: const Threshold(0.0))),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    AppState? state;
    try {
      state = context.watch<AppState>();
    } catch (_) {
      state = null;
    }
    final name =
        widget.nickname ??
        (state?.profileNickname.isNotEmpty == true
            ? state!.profileNickname
            : '你的名片');
    final level = widget.level ?? state?.avatarLevel ?? 1;
    return Scaffold(
      body: SceneRoom(
        art: 'assets/home/room_base.png',
        aspect: 720 / 1279,
        title: '更衣室',
        npc: GameCharacters.letty,
        npcAt: const Offset(0.2, 0.93),
        greeting: () => ['歡迎來到更衣室！站到鏡子前，衣架上的衣服都可以換上看看。'],
        tips: const [
          '換上新衣服時，你會在鏡子前轉一圈。',
          '踩進地上的光圈，可以看看進化。',
          '左右的門通往角色圖鑑和經驗紀錄。',
        ],
        objects: [
          _obj('rack', '衣架', '換衣服', _showRack),
          _obj(
            'mirror',
            '立鏡',
            '照照鏡子',
            (_) async => setState(() {
              _anim = PlayerAnimation.turn;
              _spin++;
            }),
          ),
          _obj('card', '名片', '翻面', (c) => _showCard(c, name, level)),
          _obj('shelf', '書架', '角色圖鑑', (c) => _open(c, const AvatarCodexPage())),
          _obj('pillar', '光圈', '進化', (c) async {
            setState(() {
              _pillar = true;
              _anim = PlayerAnimation.happy;
            });
            await Future<void>.delayed(
              Duration(milliseconds: _still ? 0 : 1600),
            );
            if (!c.mounted) return;
            setState(() => _pillar = false);
            await _open(c, const AvatarEvolutionPage());
          }),
          _obj(
            'door_l',
            '經驗之門',
            '經驗紀錄',
            (c) => _open(c, const AvatarExperiencePage()),
          ),
          _obj(
            'door_r',
            '角色之門',
            '角色資料',
            (c) => _open(c, const CharacterPage()),
          ),
        ],
        wide: SceneWideLayout(
          art: 'assets/scenes/workbench/cabin_wide.webp',
          npcAt: const Offset(0.12, 0.92),
          rects: {for (final e in _places.entries) e.key: e.value.wide},
          effects: const [SceneEffect.dust(count: 18)],
        ),
        effects: const [SceneEffect.dust(count: 14)],
        overlay: (context, art, wide) =>
            _overlay(context, art, wide, name, level),
      ),
    );
  }

  Rect _abs(Rect art, Rect r) => Rect.fromLTWH(
    art.left + r.left * art.width,
    art.top + r.top * art.height,
    r.width * art.width,
    r.height * art.height,
  );

  List<Widget> _overlay(
    BuildContext context,
    Rect art,
    bool wide,
    String name,
    int level,
  ) {
    final mirror = _abs(art, _places['mirror']!.of(wide));
    final rack = _abs(art, _places['rack']!.of(wide));
    final pillar = _abs(art, _places['pillar']!.of(wide));
    final ps = (art.width / 600).roundToDouble().clamp(1.0, 2.0);
    final glass = Rect.fromLTWH(
      mirror.left + mirror.width * 0.18,
      mirror.top + mirror.height * 0.09,
      mirror.width * 0.64,
      mirror.height * 0.72,
    );
    final rs = math.max(
      1.0,
      (glass.height / playerFrameHeight).floorToDouble(),
    );
    final player = Offset(
      art.left + _at.dx * art.width,
      art.top + _at.dy * art.height,
    );
    Widget pixel(String a, String k) => Image.asset(
      a,
      key: Key(k),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return [
      Positioned.fromRect(
        rect: glass,
        child: IgnorePointer(
          child: ClipRect(
            child: ColoredBox(
              color: const Color(0xFFA9C0DE),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Transform.flip(
                  flipX: true,
                  child: PlayerAvatar(
                    key: ValueKey('dressing-reflection-$_spin'),
                    look: _look,
                    animation: _anim == PlayerAnimation.turn
                        ? PlayerAnimation.turn
                        : PlayerAnimation.idle,
                    scale: rs,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      Positioned.fromRect(
        rect: mirror,
        child: IgnorePointer(
          child: pixel('assets/scenes/dressing/mirror.png', 'dressing-mirror'),
        ),
      ),
      Positioned.fromRect(
        rect: rack,
        child: IgnorePointer(
          child: pixel('assets/scenes/dressing/rack.png', 'dressing-rack'),
        ),
      ),
      Positioned.fromRect(
        rect: pillar,
        child: IgnorePointer(
          child: WorldClock(
            builder: (_, f, still) => CustomPaint(
              key: const Key('dressing-pillar'),
              painter: _RingPainter(f),
            ),
          ),
        ),
      ),
      AnimatedPositioned(
        key: const Key('dressing-player'),
        duration: _walk,
        left: player.dx - playerFrameWidth * ps / 2,
        top: player.dy - playerPivot.dy * ps,
        child: IgnorePointer(
          child: PlayerAvatar(
            key: ValueKey('dressing-player-$_spin'),
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
      if (_pillar)
        Positioned.fill(
          child: IgnorePointer(child: _LightPillar(look: _look)),
        ),
    ];
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frame);
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    final c = size.center(Offset.zero);
    for (var i = 0; i < 12; i++) {
      final a = (i / 12 + frame / 96) * 2 * math.pi;
      p.color = i.isEven ? const Color(0xCCFFE7A8) : const Color(0x998B6CF0);
      canvas.drawRect(
        Rect.fromCenter(
          center:
              c +
              Offset(
                math.cos(a) * size.width * 0.42,
                math.sin(a) * size.height * 0.36,
              ),
          width: 4,
          height: 4,
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.frame != frame;
}

/// Evolution: the character stands in a column of light, full screen.
class _LightPillar extends StatelessWidget {
  const _LightPillar({required this.look});
  final PlayerLook look;

  @override
  Widget build(BuildContext context) {
    return WorldClock(
      builder: (context, f, still) => CustomPaint(
        key: const Key('dressing-light-pillar'),
        painter: _PillarPainter(f),
        child: Center(
          child: PlayerAvatar(
            look: look,
            animation: PlayerAnimation.happy,
            scale: 3,
            fallback: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _PillarPainter extends CustomPainter {
  _PillarPainter(this.frame);
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xAA140A22),
    );
    final w = size.width * (0.22 + 0.04 * math.sin(frame / 3));
    final x = size.width / 2;
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTRB(
          x - w / 2 + i * w / 10,
          0,
          x + w / 2 - i * w / 10,
          size.height,
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0x338B6CF0),
            const Color(0xCCFFF3CF),
            i / 3,
          )!,
      );
    }
    final p = Paint()..isAntiAlias = false;
    for (var i = 0; i < 40; i++) {
      final y = ((i * 97 + frame * (6 + i % 5)) % size.height);
      p.color = i.isEven ? const Color(0xFFFFE7A8) : const Color(0xFFFFFFFF);
      canvas.drawRect(
        Rect.fromLTWH(x + math.sin(i * 1.7) * w * 0.7, size.height - y, 4, 4),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_PillarPainter old) => old.frame != frame;
}

class _Rack extends StatelessWidget {
  const _Rack({
    required this.look,
    required this.tab,
    required this.onTab,
    required this.onWear,
    required this.onClose,
  });
  final PlayerLook look;
  final PlayerLayer tab;
  final ValueChanged<PlayerLayer> onTab;
  final void Function(PlayerLayer, String?) onWear;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final parts = <PlayerPart?>[
      if (tab == PlayerLayer.headwear || tab == PlayerLayer.accessory) null,
      ...playerParts[tab]!,
    ];
    return Material(
      key: const Key('dressing-rack-panel'),
      color: const Color(0xFFF6E7C8),
      shape: const Border.fromBorderSide(
        BorderSide(color: Color(0xFF5A3A26), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final (layer, label) in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: tab == layer,
                      onSelected: (_) => onTab(layer),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: '收起衣架',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Container(height: 6, color: const Color(0xFF8A5A34)),
            SizedBox(
              height: 150,
              child: ListView(
                key: const Key('dressing-rail'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in parts)
                    Semantics(
                      button: true,
                      selected: look.idOf(tab) == p?.id,
                      label: p?.name ?? '不戴',
                      child: InkWell(
                        key: Key('wear-${tab.name}-${p?.id ?? 'none'}'),
                        onTap: () => onWear(tab, p?.id),
                        child: Container(
                          width: 96,
                          margin: const EdgeInsets.only(right: 8, top: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFAF0),
                            border: Border.all(
                              color: look.idOf(tab) == p?.id
                                  ? const Color(0xFFC4710B)
                                  : const Color(0xFF5A3A26),
                              width: 3,
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ExcludeSemantics(
                                  child: FittedBox(
                                    child: PlayerAvatar(
                                      look: look.withPart(tab, p?.id),
                                      playing: false,
                                      scale: 2,
                                      fallback: const Icon(Icons.checkroom),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                p?.name ?? '不戴',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The name card turns over: the front shows you, the back edits.
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.flipped,
    required this.look,
    required this.name,
    required this.level,
    required this.onFlip,
    required this.onClose,
    required this.onEditIcon,
    required this.onEditLook,
    required this.onWardrobe,
  });

  final bool flipped;
  final PlayerLook look;
  final String name;
  final int level;
  final VoidCallback onFlip, onClose, onEditIcon, onEditLook, onWardrobe;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? 1 : 0),
      duration: Duration(milliseconds: still ? 0 : 480),
      builder: (context, t, _) {
        final stepped = (t * 6).round() / 6;
        final back = stepped > 0.5;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(stepped * math.pi),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(back ? math.pi : 0),
            child: Container(
              key: Key(back ? 'name-card-back' : 'name-card-front'),
              width: 300,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6E7C8),
                border: Border.all(color: const Color(0xFF8A5A34), width: 4),
              ),
              child: back
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '名片背面',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: onEditIcon,
                          child: const Text('換頭像框'),
                        ),
                        FilledButton(
                          onPressed: onEditLook,
                          child: const Text('換完整角色'),
                        ),
                        FilledButton(
                          onPressed: onWardrobe,
                          child: const Text('角色衣櫃'),
                        ),
                        TextButton(
                          onPressed: onFlip,
                          child: const Text('↺ 翻回正面'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PlayerAvatar(
                          look: look,
                          animation: PlayerAnimation.wave,
                          scale: 2,
                          fallback: const Icon(Icons.face, size: 64),
                        ),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text('Lv $level 小鎮居民'),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton(
                              key: const Key('name-card-flip'),
                              onPressed: onFlip,
                              child: const Text('翻到背面 ↻'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: onClose,
                              child: const Text('收好'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
