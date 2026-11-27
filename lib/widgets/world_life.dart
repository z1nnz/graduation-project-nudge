import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import '../models/avatar_profile.dart';
import '../models/companion_pose.dart';
import '../state/app_state.dart';
import 'companion_sprite.dart';
import 'player_avatar.dart';
import 'sprite_animation.dart';

/// Living-scene pieces shared by the App rooms (J3/J4…), the same rules as
/// the Web's world_life.js: a live pixel sky (far), swaying plants and
/// falling motes (near), a 12 fps world clock that stops with
/// `MediaQuery.disableAnimations` (one full still frame) and with the route
/// ([TickerMode]), pixel emotes, and pets.
///
/// Suggested for the shared components (scene_room.dart) once it settles.

// ---------------------------------------------------------------- time

enum WorldPhase { night, dawn, day, dusk }

WorldPhase worldPhaseAt(double hour) {
  final h = ((hour % 24) + 24) % 24;
  if (h >= 19.5 || h < 5) return WorldPhase.night;
  if (h < 7) return WorldPhase.dawn;
  if (h < 17) return WorldPhase.day;
  return WorldPhase.dusk;
}

/// 0 at night, 1 at noon.
double worldDaylight(double hour) {
  final h = ((hour % 24) + 24) % 24;
  if (h < 5 || h >= 20) return 0;
  if (h < 7) return (h - 5) / 2;
  if (h < 17) return 1;
  return math.max(0, 1 - (h - 17) / 3);
}

double hourOf(DateTime t) => t.hour + t.minute / 60;

const Map<WorldPhase, List<Color>> worldSky = {
  WorldPhase.night: [Color(0xFF160F2E), Color(0xFF2A1D52), Color(0xFF4A2F6E)],
  WorldPhase.dawn: [Color(0xFF3B2F6B), Color(0xFFB2729E), Color(0xFFF4B98A)],
  WorldPhase.day: [Color(0xFF5F9EE0), Color(0xFF8FC3EE), Color(0xFFD8ECF4)],
  WorldPhase.dusk: [Color(0xFF2F2460), Color(0xFF8A4C8C), Color(0xFFF08A6A)],
};

/// What the companion does at [hour] (same table as the Web cabin).
enum CompanionRoutine { sleep, stretch, read, snack, look, sit }

CompanionRoutine routineAt(double hour) {
  final h = ((hour % 24) + 24) % 24;
  if (h < 6.5) return CompanionRoutine.sleep;
  if (h < 8) return CompanionRoutine.stretch;
  if (h < 12) return CompanionRoutine.read;
  if (h < 13.5) return CompanionRoutine.snack;
  if (h < 18) return CompanionRoutine.read;
  if (h < 21) return CompanionRoutine.look;
  if (h < 23) return CompanionRoutine.sit;
  return CompanionRoutine.sleep;
}

double _hash(int i) {
  final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
  return x - x.floorToDouble();
}

// ---------------------------------------------------------------- clock

/// A 12 fps frame counter for pixel motion. Frame stays 0 when animations
/// are disabled, so painters draw one complete still picture.
class WorldClock extends StatefulWidget {
  const WorldClock({super.key, required this.builder, this.fps = 12});

  final Widget Function(BuildContext context, int frame, bool still) builder;
  final int fps;

  @override
  State<WorldClock> createState() => _WorldClockState();
}

class _WorldClockState extends State<WorldClock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  )..addListener(_tick);
  int _frame = 0;
  bool _still = false;

  void _tick() {
    final f =
        (_c.lastElapsedDuration?.inMilliseconds ?? 0) * widget.fps ~/ 1000;
    if (f != _frame) setState(() => _frame = f);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_still) {
      _c.stop();
      _frame = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _still ? 0 : _frame, _still);
}

// ---------------------------------------------------------------- painters

Paint _px(Color c) => Paint()
  ..color = c
  ..isAntiAlias = false;

/// Far layer: banded sky, stars, sun or moon, drifting clouds, birds.
/// Drawn on a coarse grid of [pixel] logical px so it stays pixel art.
class WorldSkyPainter extends CustomPainter {
  WorldSkyPainter({
    required this.frame,
    required this.hour,
    this.pixel = 3,
    this.hills,
  });

  final int frame;
  final double hour;
  final double pixel;

  /// Horizon of distant hills, fraction of the height; null for none.
  final double? hills;

  @override
  void paint(Canvas canvas, Size size) {
    final w = (size.width / pixel).ceil(), h = (size.height / pixel).ceil();
    canvas.save();
    canvas.scale(pixel);
    final phase = worldPhaseAt(hour);
    final c = worldSky[phase]!;
    final bands = [c[0], c[0], c[1], c[1], c[2]];
    final bh = (h / bands.length).ceil();
    for (var i = 0; i < bands.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * bh.toDouble(), w.toDouble(), bh + 1.0),
        _px(bands[i]),
      );
      if (i + 1 < bands.length && bands[i + 1] != bands[i]) {
        for (var x = i % 2; x < w; x += 2) {
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), (i + 1) * bh - 1.0, 1, 1),
            _px(bands[i + 1]),
          );
        }
      }
    }
    if (phase != WorldPhase.day) {
      for (var i = 0; i < 50; i++) {
        if ((frame ~/ 6 + i) % 9 == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            (_hash(i) * w).floorToDouble(),
            (_hash(i + 99) * h * 0.8).floorToDouble(),
            1,
            1,
          ),
          _px(i % 7 == 0 ? const Color(0xFFFFE7A8) : const Color(0xFFF6F0FF)),
        );
      }
    }
    final sun = hour >= 6 && hour < 19;
    final t = sun
        ? (hour - 6) / 13
        : ((hour >= 19 ? hour - 19 : hour + 5) / 11);
    final bx = (0.1 + 0.8 * t) * w,
        by = (0.15 + (1 - math.sin(math.pi * t)) * 0.6) * h;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(bx, by), width: 6, height: 4),
      _px(sun ? const Color(0xFFFFD56B) : const Color(0xFFF6F0D8)),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(bx, by), width: 4, height: 6),
      _px(sun ? const Color(0xFFFFD56B) : const Color(0xFFF6F0D8)),
    );
    if (!sun) {
      canvas.drawRect(
        Rect.fromLTWH(bx.floorToDouble(), by - 3, 3, 5),
        _px(c[0]),
      );
    }
    final cloud = switch (phase) {
      WorldPhase.day => const Color(0xFFFFFFFF),
      WorldPhase.night => const Color(0xFF3C2D66),
      _ => const Color(0xFFF2B2C4),
    };
    for (var i = 0; i < 4; i++) {
      final speed = 0.004 + _hash(i + 5) * 0.004;
      final cx = ((_hash(i + 11) + frame * speed / 10) % 1.3) - 0.15;
      final cy = 0.15 + _hash(i + 21) * 0.6;
      final cw = math.max(6.0, (w * (0.18 + _hash(i) * 0.12)).floorToDouble());
      final x0 = (cx * w).floorToDouble(), y0 = (cy * h).floorToDouble();
      canvas.drawRect(Rect.fromLTWH(x0, y0, cw, 2), _px(cloud));
      canvas.drawRect(Rect.fromLTWH(x0 + 2, y0 - 1, cw - 4, 1), _px(cloud));
      canvas.drawRect(
        Rect.fromLTWH(x0 + cw / 3, y0 - 2, cw / 3, 1),
        _px(cloud),
      );
    }
    if (hills case final hy?) {
      final col = phase == WorldPhase.day
          ? const Color(0xFF6F8FB8)
          : const Color(0xFF2B2050);
      for (var x = 0; x < w; x++) {
        final y =
            hy * h -
            (3 + 2 * math.sin(x / 9) + 1.5 * math.sin(x / 4 + 2)).round();
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y, 1, h - y), _px(col));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(WorldSkyPainter old) =>
      old.frame != frame || old.hour != hour || old.pixel != pixel;
}

enum WorldFall { dust, petals, leaves, snow, fireflies }

class WorldPlant {
  const WorldPlant(
    this.x, {
    this.y = 1,
    this.size = 0.16,
    this.hanging = false,
    this.bloom,
  });
  final double x, y, size;
  final bool hanging;
  final Color? bloom;
}

/// Near layer: falling motes and swaying plant fronds in front of the room.
class WorldNearPainter extends CustomPainter {
  WorldNearPainter({
    required this.frame,
    this.fall = WorldFall.dust,
    this.count = 16,
    this.plants = const [],
    this.pixel = 3,
  });

  final int frame;
  final WorldFall fall;
  final int count;
  final List<WorldPlant> plants;
  final double pixel;

  static const _colors = {
    WorldFall.dust: [Color(0xFFFFE7A8), Color(0xFFFFF3CF)],
    WorldFall.petals: [Color(0xFFF6A7C1), Color(0xFFF9C9D8)],
    WorldFall.leaves: [Color(0xFFD9793A), Color(0xFFC9A227)],
    WorldFall.snow: [Color(0xFFFFFFFF), Color(0xFFE4ECFF)],
    WorldFall.fireflies: [Color(0xFFE9FF8A), Color(0xFFFFE36B)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / pixel, h = size.height / pixel;
    canvas.save();
    canvas.scale(pixel);
    final cols = _colors[fall]!;
    for (var i = 0; i < count; i++) {
      final sp = 0.6 + _hash(i) * 0.8;
      final y =
          ((_hash(i + 3) * h +
                  frame * sp * (fall == WorldFall.snow ? 0.5 : 0.35)) %
              (h + 10)) -
          5;
      final x =
          (_hash(i + 7) * w +
              math.sin(frame / 25 + i) * 6 +
              (fall == WorldFall.dust ? 0 : frame * 0.15)) %
          w;
      final p = _px(cols[i % cols.length]);
      if (fall == WorldFall.fireflies) {
        if ((frame + i * 5) % 30 < 14) {
          canvas.drawRect(
            Rect.fromLTWH(
              x.floorToDouble(),
              (h * 0.4 + y % (h * 0.6)).floorToDouble(),
              1,
              1,
            ),
            p,
          );
        }
      } else {
        final flip = (frame + i * 4) % 16 < 8;
        canvas.drawRect(
          Rect.fromLTWH(
            x.floorToDouble(),
            y.floorToDouble(),
            flip ? 2 : 1,
            flip || fall == WorldFall.dust ? 1 : 2,
          ),
          p,
        );
      }
    }
    for (final pl in plants) {
      _plant(canvas, w, h, pl);
    }
    canvas.restore();
  }

  void _plant(Canvas canvas, double w, double h, WorldPlant p) {
    final px = p.x * w, py = p.y * h, size = p.size * h;
    final fronds = p.hanging ? 4 : 6;
    for (var i = 0; i < fronds; i++) {
      final spread = (i / (fronds - 1) - 0.5) * (p.hanging ? 0.6 : 1.6);
      final sway = math.sin(frame / 18 + i * 0.9 + p.x * 10) * 0.08;
      final ang = (p.hanging ? math.pi / 2 : -math.pi / 2) + spread + sway;
      final len = size * (0.6 + 0.4 * _hash(i + (p.x * 50).round()));
      for (var s = 0.0; s < len; s += 1) {
        final bend =
            math.pow(s / len, 2) *
            (spread > 0 ? 0.5 : -0.5) *
            (p.hanging ? -1 : 1);
        final x = px + math.cos(ang + bend) * s,
            y = py + math.sin(ang + bend) * s;
        final paint = _px(
          s % 4 < 2 ? const Color(0xFF1F3A2A) : const Color(0xFF2F5A3A),
        );
        canvas.drawRect(
          Rect.fromLTWH(x.floorToDouble(), y.floorToDouble(), 1, 1),
          paint,
        );
        if (s.toInt() % 3 == 0 && s > 2) {
          final dy = p.hanging ? 1.0 : -1.0;
          canvas.drawRect(
            Rect.fromLTWH(x.floorToDouble() + 1, y.floorToDouble() + dy, 1, 1),
            paint,
          );
          canvas.drawRect(
            Rect.fromLTWH(x.floorToDouble() - 1, y.floorToDouble() + dy, 1, 1),
            paint,
          );
        }
      }
      if (p.bloom != null && i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(
            px + math.cos(ang) * len - 1,
            py + math.sin(ang) * len - 1,
            2,
            2,
          ),
          _px(p.bloom!),
        );
      }
    }
  }

  @override
  bool shouldRepaint(WorldNearPainter old) =>
      old.frame != frame || old.fall != fall;
}

/// A wall clock whose hands follow [now].
class PixelClockPainter extends CustomPainter {
  PixelClockPainter(this.now);
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2;
    final c = size.center(Offset.zero);
    canvas.drawRect(
      Rect.fromCircle(center: c, radius: r).deflate(r * 0.08),
      _px(const Color(0xFF3A2216)),
    );
    canvas.drawRect(
      Rect.fromCircle(center: c, radius: r).deflate(r * 0.22),
      _px(const Color(0xFFF6E7C8)),
    );
    void hand(double turns, double len, Color col, double width) {
      final a = turns * 2 * math.pi;
      final p = Paint()
        ..color = col
        ..strokeWidth = width
        ..isAntiAlias = false;
      canvas.drawLine(c, c + Offset(math.sin(a), -math.cos(a)) * len, p);
    }

    hand(
      ((now.hour % 12) + now.minute / 60) / 12,
      r * 0.4,
      const Color(0xFF2A1A14),
      r * 0.14,
    );
    hand(
      (now.minute + now.second / 60) / 60,
      r * 0.62,
      const Color(0xFF2A1A14),
      r * 0.1,
    );
    hand(now.second / 60, r * 0.66, const Color(0xFFD8452E), r * 0.06);
  }

  @override
  bool shouldRepaint(PixelClockPainter old) => old.now.second != now.second;
}

// ---------------------------------------------------------------- emotes

enum WorldEmoteKind { surprise, question, heart, note, sleepy, star, dots }

/// A small pixel bubble that pops above an actor.
class WorldEmote extends StatelessWidget {
  const WorldEmote(this.kind, {super.key, this.size = 30});
  final WorldEmoteKind kind;
  final double size;

  static const _glyph = {
    WorldEmoteKind.surprise: '!',
    WorldEmoteKind.question: '?',
    WorldEmoteKind.heart: '♥',
    WorldEmoteKind.note: '♪',
    WorldEmoteKind.sleepy: 'z',
    WorldEmoteKind.star: '★',
    WorldEmoteKind.dots: '…',
  };

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E4),
          border: Border.all(color: const Color(0xFF2A1A14), width: 2),
        ),
        child: Text(
          _glyph[kind]!,
          style: TextStyle(
            fontSize: size * 0.55,
            height: 1,
            fontWeight: FontWeight.w900,
            color: kind == WorldEmoteKind.heart
                ? const Color(0xFFE05A86)
                : const Color(0xFF4B2FA8),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- pets

const String petAssetBase = 'assets/characters/pets/';
const double petFrame = 32;

enum PetSpecies { owl, fox, slime }

enum PetStage { baby, teen, adult }

enum PetAnimation {
  idle,
  walkDown,
  walkLeft,
  walkRight,
  walkUp,
  happy,
  sleep,
  cuddle,
}

/// Mirrors assets/characters/pets/pets.json (test/pet_sprite_test.dart).
const Map<PetAnimation, (int frames, double fps, bool loop)> petClips = {
  PetAnimation.idle: (8, 8, true),
  PetAnimation.walkDown: (6, 10, true),
  PetAnimation.walkLeft: (6, 10, true),
  PetAnimation.walkRight: (6, 10, true),
  PetAnimation.walkUp: (6, 10, true),
  PetAnimation.happy: (6, 10, false),
  PetAnimation.sleep: (8, 8, true),
  PetAnimation.cuddle: (8, 8, true),
};

const Map<PetSpecies, (String name, List<String> stages)> petNames = {
  PetSpecies.owl: ('小貓頭鷹', ['毛球雛鳥', '見習夜梟', '星夜貓頭鷹']),
  PetSpecies.fox: ('小狐狸', ['小奶狐', '蓬尾狐', '晚霞狐']),
  PetSpecies.slime: ('小史萊姆', ['小水滴', '發芽史萊姆', '王冠史萊姆']),
};

const int petTeenMinutes = 300;
const int petAdultMinutes = 1500;

/// Growth from existing Cloud-confirmed focus minutes; nothing is written.
PetStage petStageFor(num minutes) => minutes >= petAdultMinutes
    ? PetStage.adult
    : minutes >= petTeenMinutes
    ? PetStage.teen
    : PetStage.baby;

int petMinutesToNext(num minutes) => minutes < petTeenMinutes
    ? (petTeenMinutes - minutes).ceil()
    : minutes < petAdultMinutes
    ? (petAdultMinutes - minutes).ceil()
    : 0;

String petSheet(PetSpecies s, PetStage st) =>
    '$petAssetBase${s.name}_${st.name}.webp';

/// The chosen pet, kept on this device (same key as the Web).
abstract final class PetChoiceStore {
  static const key = 'nudge.pet.v1';

  static Future<PetSpecies?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = jsonDecode(prefs.getString(key) ?? 'null');
      final id = v is Map ? v['species'] : null;
      return PetSpecies.values.where((s) => s.name == id).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(PetSpecies s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode({'species': s.name}));
  }
}

/// Last growth stage worked out from the records, so rooms show it at once.
abstract final class PetStageCache {
  static const key = 'nudge.pet.stage.v1';

  static Future<PetStage> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(key);
    return PetStage.values.where((s) => s.name == v).firstOrNull ??
        PetStage.baby;
  }

  static Future<void> save(PetStage s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, s.name);
  }
}

class PetSprite extends StatelessWidget {
  const PetSprite({
    super.key,
    required this.species,
    this.stage = PetStage.baby,
    this.animation = PetAnimation.idle,
    this.scale = 2,
    this.onEnd,
    this.semanticLabel,
  });

  final PetSpecies species;
  final PetStage stage;
  final PetAnimation animation;
  final double scale;
  final VoidCallback? onEnd;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final (frames, fps, loop) = petClips[animation]!;
    return SpriteAnimation(
      key: ValueKey('pet-${species.name}-${stage.name}-${animation.name}'),
      image: AssetImage(petSheet(species, stage)),
      frames: frames,
      row: animation.index,
      fps: fps,
      loop: loop,
      frameWidth: petFrame,
      width: petFrame * scale,
      onEnd: onEnd,
      semanticLabel: semanticLabel,
    );
  }
}

// ---------------------------------------------------------------- walking

/// The player walks below an object before its feature opens. Mix into a
/// room page's State; put [walkingPlayer] in the room overlay.
mixin PlayerWalkMixin<T extends StatefulWidget> on State<T> {
  Offset playerAt = const Offset(0.5, 0.88);
  PlayerAnimation playerAnim = PlayerAnimation.idle;
  Duration _walkTime = Duration.zero;
  PlayerLook playerLook = PlayerLook.standard;

  bool get worldStill => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void loadPlayerLook() => PlayerLookStore.load().then((l) {
    if (mounted) setState(() => playerLook = l);
  });

  bool isWideRoom(BuildContext c) {
    final s = MediaQuery.sizeOf(c);
    return s.width >= 840 && s.width / math.max(1, s.height) >= 1.05;
  }

  /// Walks to just below [rect] (art fractions); resolves on arrival.
  Future<void> walkBelow(
    Rect rect, {
    double floorTop = 0.64,
    double floorBottom = 0.94,
  }) async {
    final target = Offset(
      rect.center.dx.clamp(0.06, 0.94),
      (rect.bottom + 0.05).clamp(floorTop, floorBottom),
    );
    final d = (target - playerAt).distance;
    final ms = worldStill ? 0 : math.min(1400, (d / 0.32 * 1000).round());
    final dx = target.dx - playerAt.dx, dy = target.dy - playerAt.dy;
    setState(() {
      _walkTime = Duration(milliseconds: ms);
      playerAnim = ms == 0
          ? PlayerAnimation.idle
          : PlayerAnimation.walk(
              dx.abs() > dy.abs()
                  ? (dx > 0 ? AxisDirection.right : AxisDirection.left)
                  : (dy > 0 ? AxisDirection.down : AxisDirection.up),
            );
      playerAt = target;
    });
    if (ms > 0) await Future<void>.delayed(Duration(milliseconds: ms));
    if (mounted) setState(() => playerAnim = PlayerAnimation.idle);
  }

  void act(PlayerAnimation a) => setState(() => playerAnim = a);

  Widget walkingPlayer(
    Rect art, {
    Widget? fallback,
    Key key = const Key('room-player'),
  }) {
    final ps = (art.width / 400).roundToDouble().clamp(2.0, 3.0);
    final p = Offset(
      art.left + playerAt.dx * art.width,
      art.top + playerAt.dy * art.height,
    );
    // Rooms show the user's own companion; the layered character is for
    // the dressing room and try-on mirrors.
    final size = playerFrameHeight * ps * 1.1;
    return AnimatedPositioned(
      key: key,
      duration: _walkTime,
      left: p.dx - size / 2,
      top: p.dy - size,
      child: IgnorePointer(
        child: CompanionActor(animation: playerAnim, size: size),
      ),
    );
  }
}

// ---------------------------------------------------------------- companion

/// The user's own companion (their chosen character, CompanionSprite) acting
/// out a scene action. Rooms use this; the layered [PlayerAvatar] is for the
/// dressing room and try-on mirrors. Walking steps through the walk frames.
class CompanionActor extends StatelessWidget {
  const CompanionActor({
    super.key,
    this.animation = PlayerAnimation.idle,
    this.size = 112,
    this.profile,
  });

  final PlayerAnimation animation;
  final double size;

  /// Overrides the profile read from [AppState] (tests, previews).
  final AvatarProfile? profile;

  static CompanionPose poseFor(PlayerAnimation a) => switch (a) {
    PlayerAnimation.walkDown ||
    PlayerAnimation.walkLeft ||
    PlayerAnimation.walkRight ||
    PlayerAnimation.walkUp ||
    PlayerAnimation.runDown ||
    PlayerAnimation.runLeft ||
    PlayerAnimation.runRight ||
    PlayerAnimation.runUp => CompanionPose.walk,
    PlayerAnimation.read || PlayerAnimation.think => CompanionPose.read,
    PlayerAnimation.sleep => CompanionPose.sleep,
    PlayerAnimation.happy || PlayerAnimation.wave => CompanionPose.cheer,
    PlayerAnimation.stretch => CompanionPose.exercise,
    _ => CompanionPose.idle,
  };

  @override
  Widget build(BuildContext context) {
    AvatarProfile p;
    try {
      p = profile ?? context.read<AppState>().avatarProfile;
    } catch (_) {
      p = AvatarProfile.initial();
    }
    final pose = poseFor(animation);
    final left =
        animation == PlayerAnimation.walkLeft ||
        animation == PlayerAnimation.runLeft;
    if (pose != CompanionPose.walk) {
      return CompanionSprite(profile: p, pose: pose, size: size);
    }
    return WorldClock(
      fps: 8,
      builder: (_, f, still) => CompanionSprite(
        profile: p,
        pose: pose,
        size: size,
        facingLeft: left,
        stepPhase: still ? 0 : (f % 4) / 4,
      ),
    );
  }
}
