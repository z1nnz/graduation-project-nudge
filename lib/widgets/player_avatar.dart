import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The layered player character (J1): body, outfit, headwear and accessory
/// sheets in `assets/characters/player/`, stacked in that order and stepped
/// by one [AnimationController] so every layer shows the same frame.
///
/// Mirrors `assets/characters/player/player.json`
/// (test/player_avatar_test.dart keeps them equal). Cells are
/// [playerFrameWidth] x [playerFrameHeight] px, feet on [playerPivot].
const double playerFrameWidth = 64;
const double playerFrameHeight = 80;
const int playerColumns = 12;
const Offset playerPivot = Offset(32, 76);
const String playerAssetBase = 'assets/characters/player/';

class PlayerClip {
  const PlayerClip(this.name, this.frames, this.fps, {this.loop = true});

  final String name;
  final int frames;
  final double fps;
  final bool loop;

  Duration get duration => Duration(microseconds: (frames * 1e6 / fps).round());
}

const List<PlayerClip> playerClips = [
  PlayerClip('idle', 12, 8),
  PlayerClip('look', 12, 8),
  PlayerClip('turn', 4, 8),
  PlayerClip('walk_down', 6, 10),
  PlayerClip('walk_left', 6, 10),
  PlayerClip('walk_right', 6, 10),
  PlayerClip('walk_up', 6, 10),
  PlayerClip('run_down', 6, 12),
  PlayerClip('run_left', 6, 12),
  PlayerClip('run_right', 6, 12),
  PlayerClip('run_up', 6, 12),
  PlayerClip('sit', 8, 8),
  PlayerClip('read', 12, 8),
  PlayerClip('sleep', 12, 8),
  PlayerClip('happy', 6, 10, loop: false),
  PlayerClip('wave', 6, 8, loop: false),
  PlayerClip('think', 8, 8),
  PlayerClip('stretch', 8, 8, loop: false),
  PlayerClip('snack', 8, 8),
  PlayerClip('talk', 4, 8),
];

/// Every animation the player sheets carry.
enum PlayerAnimation {
  idle,
  look,
  turn,
  walkDown,
  walkLeft,
  walkRight,
  walkUp,
  runDown,
  runLeft,
  runRight,
  runUp,
  sit,
  read,
  sleep,
  happy,
  wave,
  think,
  stretch,
  snack,
  talk;

  String get rowName =>
      name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

  int get row => playerClips.indexWhere((c) => c.name == rowName);
  PlayerClip get clip => playerClips[row];

  static PlayerAnimation walk(AxisDirection dir, {bool run = false}) =>
      switch (dir) {
        AxisDirection.up => run ? runUp : walkUp,
        AxisDirection.down => run ? runDown : walkDown,
        AxisDirection.left => run ? runLeft : walkLeft,
        AxisDirection.right => run ? runRight : walkRight,
      };
}

class PlayerPart {
  const PlayerPart(this.id, this.name);
  final String id;
  final String name;
}

enum PlayerLayer { body, outfit, headwear, accessory }

const Map<PlayerLayer, List<PlayerPart>> playerParts = {
  PlayerLayer.body: [
    PlayerPart('navy', '夜空藍髮'),
    PlayerPart('chestnut', '栗子棕髮'),
    PlayerPart('rose', '莓果粉髮'),
  ],
  PlayerLayer.outfit: [
    PlayerPart('adventurer', '冒險外套'),
    PlayerPart('gardener', '園丁吊帶褲'),
    PlayerPart('stargown', '星夜法袍'),
    PlayerPart('scholar', '書院學者'),
    PlayerPart('sporty', '晨跑運動服'),
    PlayerPart('raincoat', '雨天黃雨衣'),
  ],
  PlayerLayer.headwear: [
    PlayerPart('starclip', '星星髮夾'),
    PlayerPart('strawhat', '向陽草帽'),
    PlayerPart('wizard', '星光巫師帽'),
    PlayerPart('catears', '貓耳髮箍'),
    PlayerPart('beanie', '暖暖毛線帽'),
    PlayerPart('flowers', '春日花冠'),
  ],
  PlayerLayer.accessory: [
    PlayerPart('scarf', '白色長圍巾'),
    PlayerPart('glasses', '圓框眼鏡'),
    PlayerPart('satchel', '皮革斜背包'),
    PlayerPart('backpack', '星星背包'),
  ],
};

/// What the player wears. Headwear and accessory may be empty.
@immutable
class PlayerLook {
  const PlayerLook({
    this.body = 'navy',
    this.outfit = 'adventurer',
    this.headwear = 'starclip',
    this.accessory = 'scarf',
  });

  static const PlayerLook standard = PlayerLook();

  final String body;
  final String outfit;
  final String? headwear;
  final String? accessory;

  String? idOf(PlayerLayer layer) => switch (layer) {
    PlayerLayer.body => body,
    PlayerLayer.outfit => outfit,
    PlayerLayer.headwear => headwear,
    PlayerLayer.accessory => accessory,
  };

  /// Sheet asset of [layer], or null when that slot is empty.
  String? sheetOf(PlayerLayer layer) {
    final id = idOf(layer);
    return id == null ? null : '$playerAssetBase${layer.name}_$id.webp';
  }

  List<String> get sheets => [for (final l in PlayerLayer.values) ?sheetOf(l)];

  PlayerLook copyWith({
    String? body,
    String? outfit,
    String? Function()? headwear,
    String? Function()? accessory,
  }) => PlayerLook(
    body: body ?? this.body,
    outfit: outfit ?? this.outfit,
    headwear: headwear != null ? headwear() : this.headwear,
    accessory: accessory != null ? accessory() : this.accessory,
  );

  PlayerLook withPart(PlayerLayer layer, String? id) => switch (layer) {
    PlayerLayer.body => copyWith(body: id ?? body),
    PlayerLayer.outfit => copyWith(outfit: id ?? outfit),
    PlayerLayer.headwear => copyWith(headwear: () => id),
    PlayerLayer.accessory => copyWith(accessory: () => id),
  };

  static String? _known(PlayerLayer l, Object? v) =>
      playerParts[l]!.any((p) => p.id == v) ? v as String : null;

  /// Unknown ids fall back to the standard look; an explicit null keeps an
  /// empty headwear or accessory slot.
  factory PlayerLook.fromJson(Map<String, dynamic> json) => PlayerLook(
    body: _known(PlayerLayer.body, json['body']) ?? standard.body,
    outfit: _known(PlayerLayer.outfit, json['outfit']) ?? standard.outfit,
    headwear: json.containsKey('headwear') && json['headwear'] == null
        ? null
        : _known(PlayerLayer.headwear, json['headwear']) ?? standard.headwear,
    accessory: json.containsKey('accessory') && json['accessory'] == null
        ? null
        : _known(PlayerLayer.accessory, json['accessory']) ??
              standard.accessory,
  );

  Map<String, dynamic> toJson() => {
    'body': body,
    'outfit': outfit,
    'headwear': headwear,
    'accessory': accessory,
  };

  @override
  bool operator ==(Object other) =>
      other is PlayerLook &&
      other.body == body &&
      other.outfit == outfit &&
      other.headwear == headwear &&
      other.accessory == accessory;

  @override
  int get hashCode => Object.hash(body, outfit, headwear, accessory);
}

/// The chosen look, kept on this device (same key as the Web player).
abstract final class PlayerLookStore {
  static const key = 'nudge.player.look.v1';

  static Future<PlayerLook> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return PlayerLook.standard;
    try {
      return PlayerLook.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return PlayerLook.standard;
    }
  }

  static Future<void> save(PlayerLook look) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(look.toJson()));
  }
}

/// Frame shown after [elapsed]; a one-shot clip holds its last frame.
int playerFrameAt(Duration elapsed, PlayerClip clip) {
  if (clip.frames <= 1 || elapsed <= Duration.zero) return 0;
  final step = (elapsed.inMicroseconds * clip.fps / 1e6).floor();
  return clip.loop ? step % clip.frames : step.clamp(0, clip.frames - 1);
}

/// The player character wearing [look] and playing [animation].
///
/// [scale] should be a whole number so the pixel grid stays crisp. With
/// `MediaQuery.disableAnimations` it shows frame 0 (never blank) and a
/// one-shot clip reports [onEnd] straight away. [holdFrame] shows one frame
/// of the clip without animating (e.g. facing a direction with `turn`).
class PlayerAvatar extends StatefulWidget {
  const PlayerAvatar({
    super.key,
    this.look = PlayerLook.standard,
    this.animation = PlayerAnimation.idle,
    this.scale = 2,
    this.playing = true,
    this.holdFrame,
    this.onEnd,
    this.semanticLabel,
  });

  final PlayerLook look;
  final PlayerAnimation animation;
  final double scale;
  final bool playing;
  final int? holdFrame;
  final VoidCallback? onEnd;
  final String? semanticLabel;

  Size get size => Size(playerFrameWidth * scale, playerFrameHeight * scale);

  @override
  State<PlayerAvatar> createState() => PlayerAvatarState();
}

class PlayerAvatarState extends State<PlayerAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this)
    ..addListener(_onTick)
    ..addStatusListener(_onStatus);
  final Map<PlayerLayer, ui.Image> _images = {};
  final Map<PlayerLayer, (ImageStream, ImageStreamListener)> _streams = {};
  bool _still = false;
  bool _ended = false;
  int _frame = 0;

  /// The frame being shown (tests and callers that sync effects).
  int get frame => _frame;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveAll();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still != _still || (!_clock.isAnimating && !_ended)) {
      _still = still;
      _restart();
    }
  }

  @override
  void didUpdateWidget(PlayerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.look != widget.look) _resolveAll();
    if (old.animation != widget.animation ||
        old.playing != widget.playing ||
        old.holdFrame != widget.holdFrame) {
      _restart();
    }
  }

  void _restart() {
    _ended = false;
    _frame = (widget.holdFrame ?? 0).clamp(0, widget.animation.clip.frames - 1);
    _clock
      ..stop()
      ..value = 0;
    final clip = widget.animation.clip;
    if (!widget.playing || widget.holdFrame != null || _still) {
      if (!clip.loop || widget.holdFrame != null) _finishSoon();
      return;
    }
    _clock.duration = clip.duration;
    clip.loop ? _clock.repeat() : _clock.forward();
  }

  void _onTick() {
    final clip = widget.animation.clip;
    final f = !clip.loop && _clock.value >= 1
        ? clip.frames - 1
        : playerFrameAt(clip.duration * _clock.value, clip);
    if (f != _frame && mounted) setState(() => _frame = f);
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && !widget.animation.clip.loop) {
      _finish();
    }
  }

  void _finishSoon() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());

  void _finish() {
    if (_ended || !mounted) return;
    _ended = true;
    widget.onEnd?.call();
  }

  void _resolveAll() {
    final config = createLocalImageConfiguration(context);
    for (final layer in PlayerLayer.values) {
      final asset = widget.look.sheetOf(layer);
      final old = _streams.remove(layer);
      if (asset == null) {
        if (old != null) old.$1.removeListener(old.$2);
        _images.remove(layer);
        continue;
      }
      final stream = AssetImage(asset).resolve(config);
      if (old != null && old.$1.key == stream.key) {
        _streams[layer] = old;
        continue;
      }
      if (old != null) old.$1.removeListener(old.$2);
      _images.remove(layer);
      final listener = ImageStreamListener((info, _) {
        if (mounted) setState(() => _images[layer] = info.image);
      }, onError: (e, _) => debugPrint('PlayerAvatar: $asset: $e'));
      stream.addListener(listener);
      _streams[layer] = (stream, listener);
    }
  }

  @override
  void dispose() {
    for (final s in _streams.values) {
      s.$1.removeListener(s.$2);
    }
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      size: widget.size,
      painter: _LayersPainter(
        images: [
          for (final l in PlayerLayer.values)
            if (widget.look.idOf(l) != null) _images[l],
        ],
        src: Rect.fromLTWH(
          _frame * playerFrameWidth,
          widget.animation.row * playerFrameHeight,
          playerFrameWidth,
          playerFrameHeight,
        ),
      ),
    );
    final label = widget.semanticLabel;
    return label == null
        ? ExcludeSemantics(child: paint)
        : Semantics(label: label, image: true, child: paint);
  }
}

class _LayersPainter extends CustomPainter {
  _LayersPainter({required this.images, required this.src});

  final List<ui.Image?> images;
  final Rect src;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (final img in images) {
      if (img != null) canvas.drawImageRect(img, src, Offset.zero & size, p);
    }
  }

  @override
  bool shouldRepaint(_LayersPainter old) =>
      old.src != src ||
      old.images.length != images.length ||
      [
        for (var i = 0; i < images.length; i++) old.images[i] != images[i],
      ].any((x) => x);
}
