import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/widgets/player_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _manifest() =>
    jsonDecode(File('assets/characters/player/player.json').readAsStringSync())
        as Map<String, dynamic>;

Future<PlayerAvatarState> _pump(
  WidgetTester tester, {
  PlayerAnimation animation = PlayerAnimation.idle,
  PlayerLook look = PlayerLook.standard,
  bool still = false,
  Size screen = const Size(390, 844),
  VoidCallback? onEnd,
}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screen, disableAnimations: still),
        child: Center(
          child: PlayerAvatar(
            look: look,
            animation: animation,
            scale: 3,
            onEnd: onEnd,
          ),
        ),
      ),
    ),
  );
  return tester.state<PlayerAvatarState>(find.byType(PlayerAvatar));
}

void main() {
  test('the App catalog matches player.json', () {
    final m = _manifest();
    expect(m['frameWidth'], playerFrameWidth);
    expect(m['frameHeight'], playerFrameHeight);
    expect(m['columns'], playerColumns);
    expect(m['pivot'], [playerPivot.dx, playerPivot.dy]);
    final rows = (m['animations'] as List).cast<Map<String, dynamic>>();
    expect(rows.map((r) => r['name']), playerClips.map((c) => c.name));
    for (var i = 0; i < rows.length; i++) {
      expect(rows[i]['frames'], playerClips[i].frames, reason: rows[i]['name']);
      expect(rows[i]['fps'], playerClips[i].fps, reason: rows[i]['name']);
      expect(rows[i]['loop'], playerClips[i].loop, reason: rows[i]['name']);
    }
    final layers = m['layers'] as Map<String, dynamic>;
    for (final l in PlayerLayer.values) {
      expect(
        (layers[l.name] as List).map((p) => p['id']),
        playerParts[l]!.map((p) => p.id),
      );
      expect(
        (layers[l.name] as List).map((p) => p['name']),
        playerParts[l]!.map((p) => p.name),
      );
    }
    final d = m['default'] as Map<String, dynamic>;
    expect(PlayerLook.fromJson(d), PlayerLook.standard);
  });

  test('every animation maps to a row with 4+ frames at 8–12 fps', () {
    for (final a in PlayerAnimation.values) {
      expect(a.row, isNonNegative, reason: a.name);
      expect(a.clip.frames, inInclusiveRange(4, playerColumns));
      expect(a.clip.fps, inInclusiveRange(8, 12));
    }
    expect(PlayerAnimation.walkDown.rowName, 'walk_down');
    expect(
      PlayerAnimation.walk(AxisDirection.left, run: true),
      PlayerAnimation.runLeft,
    );
    expect(playerParts[PlayerLayer.outfit]!.length, greaterThanOrEqualTo(6));
    expect(playerParts[PlayerLayer.headwear]!.length, greaterThanOrEqualTo(6));
  });

  test('every part ships its sheet, the same bytes as the Web copy', () {
    for (final l in PlayerLayer.values) {
      for (final p in playerParts[l]!) {
        final app = File('assets/characters/player/${l.name}_${p.id}.webp');
        final web = File(
          'web_dashboard/assets/characters/player/${l.name}_${p.id}.webp',
        );
        expect(app.existsSync(), isTrue, reason: app.path);
        expect(app.readAsBytesSync(), web.readAsBytesSync(), reason: app.path);
      }
    }
  });

  test('looks normalize unknown ids and keep empty slots', () {
    final look = PlayerLook.fromJson({
      'body': 'rose',
      'outfit': 'nope',
      'headwear': null,
      'accessory': 'glasses',
    });
    expect(look.body, 'rose');
    expect(look.outfit, 'adventurer');
    expect(look.headwear, isNull);
    expect(look.sheets, [
      'assets/characters/player/body_rose.webp',
      'assets/characters/player/outfit_adventurer.webp',
      'assets/characters/player/accessory_glasses.webp',
    ]);
    expect(PlayerLook.fromJson(look.toJson()), look);
    expect(look.withPart(PlayerLayer.headwear, 'wizard').headwear, 'wizard');
  });

  test('the look is saved on this device', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await PlayerLookStore.load(), PlayerLook.standard);
    const look = PlayerLook(outfit: 'raincoat', headwear: null);
    await PlayerLookStore.save(look);
    expect(await PlayerLookStore.load(), look);
    SharedPreferences.setMockInitialValues({PlayerLookStore.key: '{bad'});
    expect(await PlayerLookStore.load(), PlayerLook.standard);
  });

  for (final screen in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('steps through frames on a ${screen.width}px screen', (
      tester,
    ) async {
      final s = await _pump(
        tester,
        animation: PlayerAnimation.walkLeft,
        screen: screen,
      );
      expect(tester.getSize(find.byType(PlayerAvatar)), const Size(144, 168));
      expect(s.frame, 0);
      await tester.pump(const Duration(milliseconds: 250));
      expect(s.frame, 2);
    });
  }

  testWidgets('reduced motion holds frame 0 and ends one-shots at once', (
    tester,
  ) async {
    var ended = 0;
    final s = await _pump(
      tester,
      animation: PlayerAnimation.happy,
      still: true,
      onEnd: () => ended++,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(s.frame, 0);
    expect(ended, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a one-shot clip stops on its last frame', (tester) async {
    var ended = 0;
    final s = await _pump(
      tester,
      animation: PlayerAnimation.wave,
      onEnd: () => ended++,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(s.frame, PlayerAnimation.wave.clip.frames - 1);
    expect(ended, 1);
  });
}
