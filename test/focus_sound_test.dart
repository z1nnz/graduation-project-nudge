import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/focus_sound.dart';
import 'package:nudge/widgets/focus_sound_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBackend implements FocusSoundBackend {
  final calls = <String>[];

  @override
  Future<void> play(String asset, double volume) async =>
      calls.add('play $asset $volume');

  @override
  Future<void> setVolume(double volume) async => calls.add('volume $volume');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> dispose() async => calls.add('dispose');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('four original ambient loops ship with the app', () {
    expect(FocusSound.all.map((s) => s.id), [
      'rain',
      'fire',
      'stream',
      'brown',
    ]);
    for (final s in FocusSound.all) {
      expect(s.asset, 'audio/ambient/${s.id}.wav');
    }
  });

  test('choosing a sound plays it and remembers the choice', () async {
    final backend = _FakeBackend();
    final controller = FocusSoundController(backend: backend);
    await controller.select('rain');
    expect(controller.current?.id, 'rain');
    expect(backend.calls.last, 'play audio/ambient/rain.wav 0.6');

    final again = FocusSoundController(backend: _FakeBackend());
    await again.restore();
    expect(again.current?.id, 'rain');
  });

  test('turning the sound off stops playback and forgets it', () async {
    final backend = _FakeBackend();
    final controller = FocusSoundController(backend: backend);
    await controller.select('fire');
    await controller.select(null);
    expect(controller.current, isNull);
    expect(backend.calls.last, 'stop');

    final again = FocusSoundController(backend: _FakeBackend());
    await again.restore();
    expect(again.current, isNull);
  });

  test('volume is clamped and saved', () async {
    final backend = _FakeBackend();
    final controller = FocusSoundController(backend: backend);
    await controller.select('stream');
    await controller.setVolume(1.4);
    expect(controller.volume, 1.0);
    expect(backend.calls.last, 'volume 1.0');

    final again = FocusSoundController(backend: _FakeBackend());
    await again.restore();
    expect(again.volume, 1.0);
  });

  test('restore does not start playing by itself', () async {
    SharedPreferences.setMockInitialValues({'focus_sound_id': 'rain'});
    final backend = _FakeBackend();
    final controller = FocusSoundController(backend: backend);
    await controller.restore();
    expect(backend.calls, isEmpty);
    await controller.resume();
    expect(backend.calls.single, 'play audio/ambient/rain.wav 0.6');
  });

  test('music apps open their public web links', () {
    expect(MusicApp.all.map((a) => a.label), [
      'Spotify',
      'Apple Music',
      'YouTube Music',
      'KKBOX',
    ]);
    for (final app in MusicApp.all) {
      expect(app.uri.scheme, 'https');
    }
  });

  testWidgets('sheet lets you pick a sound and open a music app', (
    tester,
  ) async {
    final backend = _FakeBackend();
    final controller = FocusSoundController(backend: backend);
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FocusSoundPanel(
              controller: controller,
              onOpenMusicApp: (app) async => opened.add(app.label),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('sound-rain')));
    await tester.pumpAndSettle();
    expect(controller.current?.id, 'rain');
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('sound-rain-sem')))
          .properties
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('sound-off')));
    await tester.pumpAndSettle();
    expect(controller.current, isNull);

    await tester.tap(find.text('Spotify'));
    await tester.pumpAndSettle();
    expect(opened, ['Spotify']);
  });
}
