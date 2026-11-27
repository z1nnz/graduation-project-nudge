import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/pet_house_page.dart';
import 'package:nudge/widgets/world_life.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/disk_asset_bundle.dart';

Future<void> _pump(
  WidgetTester tester,
  Size size, {
  bool still = false,
  int minutes = 480,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: DiskAssetBundle(),
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: still),
          child: PetHousePage(focusMinutes: minutes),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  // SceneRoom keeps its glow pulsing, so step time instead of settling.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the App pet table matches pets.json', () {
    final m =
        jsonDecode(File('assets/characters/pets/pets.json').readAsStringSync())
            as Map<String, dynamic>;
    final rows = (m['animations'] as List).cast<Map<String, dynamic>>();
    expect(rows.length, PetAnimation.values.length);
    for (final a in PetAnimation.values) {
      final r = rows[a.index];
      final (frames, fps, loop) = petClips[a]!;
      expect(
        [r['frames'], r['fps'], r['loop']],
        [frames, fps, loop],
        reason: a.name,
      );
      expect(frames, greaterThanOrEqualTo(4));
      expect(fps, inInclusiveRange(8, 12));
    }
    final species = (m['species'] as List).cast<Map<String, dynamic>>();
    for (final s in PetSpecies.values) {
      final j = species.firstWhere((x) => x['id'] == s.name);
      expect(j['name'], petNames[s]!.$1);
      expect((j['stages'] as List).map((x) => x['name']), petNames[s]!.$2);
      for (final st in PetStage.values) {
        expect(File(petSheet(s, st)).existsSync(), isTrue);
      }
    }
    expect(m['growth'], {
      'unit': 'focusMinutes',
      'teen': petTeenMinutes,
      'adult': petAdultMinutes,
    });
  });

  test('growth and the day follow existing records and the clock', () {
    expect(petStageFor(0), PetStage.baby);
    expect(petStageFor(300), PetStage.teen);
    expect(petStageFor(1500), PetStage.adult);
    expect(petMinutesToNext(1200), 300);
    expect(routineAt(7), CompanionRoutine.stretch);
    expect(routineAt(12.5), CompanionRoutine.snack);
    expect(routineAt(19), CompanionRoutine.look);
    expect(routineAt(2), CompanionRoutine.sleep);
    expect(worldPhaseAt(12), WorldPhase.day);
    expect(worldDaylight(0), 0);
  });

  test('the chosen pet stays on this device', () async {
    expect(await PetChoiceStore.load(), isNull);
    await PetChoiceStore.save(PetSpecies.fox);
    expect(await PetChoiceStore.load(), PetSpecies.fox);
    await PetStageCache.save(PetStage.adult);
    expect(await PetStageCache.load(), PetStage.adult);
  });

  for (final size in const [Size(390, 844), Size(1280, 800)]) {
    testWidgets('pet house objects and pets on a ${size.width}px screen', (
      tester,
    ) async {
      await _pump(tester, size);
      for (final id in ['house', 'bowl', 'cushion']) {
        expect(find.byKey(Key('pet-prop-$id')), findsOneWidget, reason: id);
      }
      for (final s in PetSpecies.values) {
        expect(find.byKey(Key('pet-${s.name}')), findsOneWidget);
      }
      expect(find.byKey(const Key('pet-house-player')), findsOneWidget);
      expect(find.byKey(const Key('pet-house-near')), findsOneWidget);
    });
  }

  testWidgets('picking a pet walks over, then asks; the bowl only plays', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844), still: true);
    await tester.tap(find.bySemanticsLabel(RegExp('小狐狸')).first);
    await _settle(tester);
    await tester.tap(find.text('帶小狐狸回家'));
    await _settle(tester);
    expect(await PetChoiceStore.load(), PetSpecies.fox);
    expect(find.byKey(const Key('pet-owl')), findsNothing);
    await tester.tap(find.bySemanticsLabel(RegExp('飯碗')).first);
    await _settle(tester);
    expect(find.textContaining('不會改變任何數字'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3)); // the bowl empties again
  });

  testWidgets('the growth board shows real minutes', (tester) async {
    await _pump(tester, const Size(390, 844), still: true, minutes: 1200);
    await tester.tap(find.bySemanticsLabel(RegExp('成長板')).first);
    await _settle(tester);
    expect(find.byKey(const Key('pet-growth-text')), findsOneWidget);
    expect(find.textContaining('再 300 分鐘長大'), findsOneWidget);
  });

  testWidgets('reduced motion: the near layer is a still frame', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 844), still: true);
    await tester.pump(const Duration(seconds: 1));
    final p =
        tester
                .widget<CustomPaint>(find.byKey(const Key('pet-house-near')))
                .painter!
            as WorldNearPainter;
    expect(p.frame, 0);
  });
}
