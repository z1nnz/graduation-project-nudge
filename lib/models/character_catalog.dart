/// The animated characters shared by every scene: the player's companion and
/// the eight town NPCs. Mirrors `assets/characters/characters.json`
/// (test/character_catalog_test.dart keeps them equal); each character has
/// one sprite sheet at `assets/characters/<id>/sheet.webp`, one row per
/// animation, [frameSize] px square frames.
library;

const int characterFrameSize = 128;

/// One row of a sheet.
class SpriteClip {
  const SpriteClip(this.name, this.frames, this.fps, {this.loop = true});

  final String name;
  final int frames;
  final double fps;
  final bool loop;
}

const List<SpriteClip> _companionRows = [
  SpriteClip('idle', 4, 6),
  SpriteClip('walk_down', 4, 8),
  SpriteClip('walk_left', 4, 8),
  SpriteClip('walk_right', 4, 8),
  SpriteClip('walk_up', 4, 8),
  SpriteClip('happy', 6, 10, loop: false),
  SpriteClip('wave', 4, 8, loop: false),
  SpriteClip('think', 4, 6),
  SpriteClip('sleep', 4, 4),
];

const List<SpriteClip> _npcRows = [
  SpriteClip('idle', 4, 6),
  SpriteClip('talk', 4, 8),
  SpriteClip('walk_down', 4, 8),
  SpriteClip('walk_left', 4, 8),
  SpriteClip('walk_right', 4, 8),
  SpriteClip('walk_up', 4, 8),
];

const Map<String, List<SpriteClip>> characterLayouts = {
  'companion': _companionRows,
  'npc': _npcRows,
};

/// The animations every catalog character can play.
enum CharacterAnimation {
  idle,
  talk,
  walkDown,
  walkLeft,
  walkRight,
  walkUp,
  happy,
  wave,
  think,
  sleep;

  String get rowName => switch (this) {
    walkDown => 'walk_down',
    walkLeft => 'walk_left',
    walkRight => 'walk_right',
    walkUp => 'walk_up',
    _ => name,
  };
}

class GameCharacter {
  const GameCharacter(this.id, this.name, this.role, this.layout);

  final String id;
  final String name;
  final String role;
  final String layout;

  String get sheet => 'assets/characters/$id/sheet.webp';
  List<SpriteClip> get rows => characterLayouts[layout]!;
  int get columns => rows.map((r) => r.frames).reduce((a, b) => a > b ? a : b);

  /// Row index of [animation]; animations this character lacks fall back to
  /// idle (NPCs have no sleep, the companion talks with its idle row).
  int rowOf(CharacterAnimation animation) {
    final i = rows.indexWhere((r) => r.name == animation.rowName);
    return i < 0 ? 0 : i;
  }

  SpriteClip clipOf(CharacterAnimation animation) => rows[rowOf(animation)];
}

abstract final class GameCharacters {
  static const companion = GameCharacter(
    'companion',
    '夥伴',
    '玩家角色',
    'companion',
  );
  static const chestnut = GameCharacter('chestnut', '栗子', '雜貨店老闆', 'npc');
  static const scroll = GameCharacter('scroll', '阿紙', '委託所告示員', 'npc');
  static const bounce = GameCharacter('bounce', '跳跳', '遊樂園管理員', 'npc');
  static const sprout = GameCharacter('sprout', '苗苗', '花園園丁', 'npc');
  static const inky = GameCharacter('inky', '墨墨', '圖書館員', 'npc');
  static const bell = GameCharacter('bell', '鐘鐘', '塔的守門人', 'npc');
  static const letty = GameCharacter('letty', '小信', '郵差', 'npc');
  static const stella = GameCharacter('stella', '星婆', '天文學者', 'npc');

  static const all = [
    companion,
    chestnut,
    scroll,
    bounce,
    sprout,
    inky,
    bell,
    letty,
    stella,
  ];

  static GameCharacter byId(String id) => all.firstWhere(
    (c) => c.id == id,
    orElse: () => throw ArgumentError.value(id, 'id', 'unknown character'),
  );
}
