import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/character_catalog.dart';
import 'package:nudge/widgets/sprite_animation.dart';

Widget _host(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Center(child: child),
  ),
);

SpriteAnimationState _state(WidgetTester t) =>
    t.state<SpriteAnimationState>(find.byType(SpriteAnimation));

void main() {
  test('spriteFrameAt loops and holds one-shot clips', () {
    expect(spriteFrameAt(Duration.zero, 4, 8), 0);
    expect(spriteFrameAt(const Duration(milliseconds: 130), 4, 8), 1);
    expect(spriteFrameAt(const Duration(milliseconds: 500), 4, 8), 0);
    expect(spriteFrameAt(const Duration(seconds: 5), 6, 10, loop: false), 5);
  });

  testWidgets('steps through the row at the requested fps', (tester) async {
    await tester.pumpWidget(
      _host(
        const SpriteAnimation(
          image: AssetImage('assets/characters/chestnut/sheet.webp'),
          frames: 4,
          fps: 8,
        ),
      ),
    );
    expect(_state(tester).frame, 0);
    await tester.pump(const Duration(milliseconds: 130));
    expect(_state(tester).frame, 1);
    await tester.pump(const Duration(milliseconds: 250));
    expect(_state(tester).frame, 3);
    await tester.pump(const Duration(milliseconds: 125));
    expect(_state(tester).frame, 0, reason: 'loops');
  });

  testWidgets('a one-shot clip ends on its last frame and calls onEnd once', (
    tester,
  ) async {
    var ended = 0;
    await tester.pumpWidget(
      _host(
        SpriteAnimation(
          image: const AssetImage('assets/characters/companion/sheet.webp'),
          frames: 6,
          fps: 10,
          loop: false,
          onEnd: () => ended++,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(_state(tester).frame, 5);
    expect(ended, 1);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion shows frame 0 and does not animate', (
    tester,
  ) async {
    var ended = 0;
    await tester.pumpWidget(
      _host(
        CharacterSprite(
          character: GameCharacters.companion,
          animation: CharacterAnimation.happy,
          onEnd: () => ended++,
        ),
        still: true,
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(_state(tester).frame, 0);
    expect(ended, 1, reason: 'reactions still report they are over');
  });

  testWidgets('stops when the route is hidden (TickerMode off)', (
    tester,
  ) async {
    Widget sprite(bool on) => _host(
      TickerMode(
        enabled: on,
        child: const CharacterSprite(character: GameCharacters.bell),
      ),
    );
    await tester.pumpWidget(sprite(true));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(sprite(false));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('CharacterSprite plays the catalog row and is labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const CharacterSprite(
          character: GameCharacters.chestnut,
          animation: CharacterAnimation.walkUp,
          size: 96,
          semanticLabel: '栗子',
        ),
      ),
    );
    final anim = tester.widget<SpriteAnimation>(find.byType(SpriteAnimation));
    expect(anim.row, 5);
    expect(anim.frames, 4);
    expect(tester.getSize(find.byType(CustomPaint).last), const Size(96, 96));
    expect(
      tester.getSemantics(find.byType(SpriteAnimation)),
      matchesSemantics(label: '栗子', isImage: true),
    );
    handle.dispose();
  });

  test('NPCs fall back to idle for animations they do not have', () {
    expect(GameCharacters.scroll.rowOf(CharacterAnimation.sleep), 0);
    expect(GameCharacters.companion.rowOf(CharacterAnimation.talk), 0);
    expect(GameCharacters.companion.rowOf(CharacterAnimation.sleep), 8);
    expect(GameCharacters.companion.columns, 6);
    expect(() => GameCharacters.byId('nobody'), throwsArgumentError);
  });

  test('the Dart catalog matches assets/characters/characters.json', () {
    final json =
        jsonDecode(File('assets/characters/characters.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(json['frameSize'], characterFrameSize);
    final layouts = json['layouts'] as Map<String, dynamic>;
    expect(layouts.keys.toSet(), characterLayouts.keys.toSet());
    for (final entry in characterLayouts.entries) {
      final rows = layouts[entry.key] as List;
      expect(rows.length, entry.value.length, reason: entry.key);
      for (var i = 0; i < rows.length; i++) {
        final r = rows[i] as Map<String, dynamic>;
        final c = entry.value[i];
        expect(
          [r['name'], r['frames'], r['fps'], r['loop']],
          [c.name, c.frames, c.fps, c.loop],
          reason: '${entry.key} row $i',
        );
      }
    }
    final chars = (json['characters'] as List).cast<Map<String, dynamic>>();
    expect(
      chars.map((c) => [c['id'], c['name'], c['role'], c['layout']]).toList(),
      GameCharacters.all.map((c) => [c.id, c.name, c.role, c.layout]).toList(),
    );
    for (final c in GameCharacters.all) {
      expect(File(c.sheet).existsSync(), isTrue, reason: c.sheet);
    }
  });
}
