import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/demo/demo_controller.dart';
import 'package:nudge/demo/demo_controller_page.dart';
import 'package:nudge/demo/generated_demo_contract.dart';
import 'package:nudge/main_demo_controller.dart';
import 'package:nudge/services/android_nudge_ble_transport.dart';

const accepted = DemoAcceptance(
  armed: true,
  orbitP0b: true,
  stationP0b: true,
  visuals: true,
  tenReplays: true,
);

class FakeDemoTransport implements DemoTransport {
  final eventsController = StreamController<NudgeBleTransportEvent>.broadcast(
    sync: true,
  );
  final writes = <String>[];
  final scans = <DemoDevice>[];
  int disconnects = 0;
  bool failScan = false, failWrite = false;
  Completer<void>? pendingWrite;
  @override
  Stream<NudgeBleTransportEvent> get events => eventsController.stream;
  @override
  Future<void> connect(DemoDevice device) async {
    scans.add(device);
    if (failScan) throw StateError('radio unavailable');
  }

  @override
  Future<void> disconnect() async {
    ++disconnects;
    eventsController.add(
      const NudgeBleTransportEvent(type: NudgeBleEventType.disconnected),
    );
  }

  @override
  Future<void> write(String raw) async {
    writes.add(raw);
    if (failWrite) throw StateError('write rejected');
    if (pendingWrite != null) await pendingWrite!.future;
  }

  void report({
    String device = 'orbit',
    String scene = 'home',
    int index = 1,
  }) => eventsController.add(
    NudgeBleTransportEvent(
      type: NudgeBleEventType.state,
      deviceId: device,
      payload: jsonEncode({
        'v': 1,
        'mode': 'demo',
        'device': device,
        'scene': scene,
        'index': index,
      }),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('NUDGE_EXPORT_DEMO_VISUALS')) {
      const path = String.fromEnvironment('NUDGE_DEMO_PREVIEW_FONT');
      if (path.isNotEmpty) {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(File(path).readAsBytesSync().buffer.asByteData()),
          );
        await loader.load();
      }
    }
  });
  test('default P2 gate does not start scanning', () async {
    final radio = FakeDemoTransport();
    final c = DemoController(
      transport: radio,
      acceptance: const DemoAcceptance(),
    );
    await c.connect(DemoDevice.orbit);
    expect(radio.scans, isEmpty);
    expect(c.canSend, isFalse);
    expect(c.message, contains('自動展示'));
    c.dispose();
  });
  test(
    'one connection requires a valid state from the requested demo target',
    () async {
      final radio = FakeDemoTransport();
      final c = DemoController(transport: radio, acceptance: accepted);
      await c.connect(DemoDevice.orbit);
      await c.connect(DemoDevice.station);
      expect(radio.scans, [DemoDevice.orbit]);
      expect(c.connection, DemoConnection.connecting);
      radio.eventsController.add(
        const NudgeBleTransportEvent(
          type: NudgeBleEventType.connected,
          deviceId: 'orbit',
        ),
      );
      expect(c.canSend, isFalse);
      radio.report(device: 'station');
      expect(c.connection, DemoConnection.connecting);
      radio.report();
      expect(c.canSend, isTrue);
      await c.disconnect();
      await c.connect(DemoDevice.station);
      radio.report(device: 'station');
      expect(c.device, DemoDevice.station);
      expect(c.canSend, isTrue);
      c.dispose();
    },
  );
  test(
    '10 Next and 5 Restart encode one write each without retries or account data',
    () async {
      final radio = FakeDemoTransport();
      final c = DemoController(transport: radio, acceptance: accepted);
      await c.connect(DemoDevice.orbit);
      radio.report();
      for (var i = 0; i < 10; i++) {
        await c.send('next');
      }
      for (var i = 0; i < 5; i++) {
        await c.send('restart');
      }
      await c.send('startFocus');
      expect(radio.writes.length, 16);
      expect(
        radio.writes.where((v) => jsonDecode(v)['action'] == 'next').length,
        10,
      );
      for (final raw in radio.writes) {
        expect((jsonDecode(raw) as Map).keys.toSet(), {'v', 'type', 'action'});
      }
      expect(() => c.send('awardXp'), throwsArgumentError);
      c.dispose();
    },
  );
  test('a pending write blocks duplicate taps', () async {
    final radio = FakeDemoTransport()..pendingWrite = Completer<void>();
    final c = DemoController(transport: radio, acceptance: accepted);
    await c.connect(DemoDevice.orbit);
    radio.report();
    final pending = c.send('next');
    await c.send('next');
    expect(radio.writes.length, 1);
    expect(c.busy, isTrue);
    radio.pendingWrite!.complete();
    await pending;
    expect(c.busy, isFalse);
    c.dispose();
  });
  test(
    'scan/write failures and disconnect do not leave busy controls',
    () async {
      final radio = FakeDemoTransport()..failScan = true;
      final c = DemoController(transport: radio, acceptance: accepted);
      await c.connect(DemoDevice.orbit);
      expect(c.connection, DemoConnection.disconnected);
      expect(c.message, '改用裝置自動展示');
      radio.failScan = false;
      await c.connect(DemoDevice.orbit);
      radio.report();
      radio.failWrite = true;
      await c.send('next');
      expect(c.connection, DemoConnection.disconnected);
      expect(c.busy, isFalse);
      expect(radio.disconnects, lessThan(5));
      c.dispose();
    },
  );
  testWidgets('connection timeout returns to automatic demo fallback', (
    tester,
  ) async {
    final radio = FakeDemoTransport();
    final c = DemoController(
      transport: radio,
      acceptance: accepted,
      timeout: const Duration(seconds: 1),
    );
    await c.connect(DemoDevice.orbit);
    await tester.pump(const Duration(seconds: 2));
    expect(c.connection, DemoConnection.disconnected);
    expect(c.busy, isFalse);
    c.dispose();
  });
  test(
    'malformed or mismatched state is rejected and closes the session',
    () async {
      final radio = FakeDemoTransport();
      final c = DemoController(transport: radio, acceptance: accepted);
      await c.connect(DemoDevice.orbit);
      radio.report(scene: 'complete', index: 3);
      expect(c.connection, DemoConnection.disconnected);
      expect(c.reported, isNull);
      c.dispose();
    },
  );
  test(
    'protocol rejects duplicate/extra keys, unsupported version, private data and bad scene IDs',
    () {
      for (final raw in [
        '{"v":1,"v":1,"mode":"demo","device":"orbit","scene":"home","index":1}',
        '{"v":1.0,"mode":"demo","device":"orbit","scene":"home","index":1}',
        '{"v":2,"mode":"demo","device":"orbit","scene":"home","index":1}',
        '{"v":1,"mode":"demo","device":"orbit","scene":"home","index":8}',
        '{"v":1,"mode":"demo","device":"orbit","scene":"home","index":1,"userId":"real"}',
      ]) {
        expect(() => DemoReportedState.parse(raw), throwsFormatException);
      }
      for (var i = 0; i < 8; i++) {
        final state = DemoReportedState.parse(
          jsonEncode({
            'v': 1,
            'mode': 'demo',
            'device': 'orbit',
            'scene': demoSceneNames[i],
            'index': i,
          }),
        );
        expect(state.pose, demoScenePoses[i]);
      }
    },
  );
  testWidgets(
    'standalone controller opens without Firebase or authentication and exposes both cards',
    (tester) async {
      final radio = FakeDemoTransport();
      final c = DemoController(
        transport: radio,
        acceptance: const DemoAcceptance(),
      );
      await tester.pumpWidget(
        PrototypeDemoApp(home: DemoControllerPage(controller: c)),
      );
      expect(find.text('Prototype Demo Controller'), findsOneWidget);
      expect(find.text('Nudge Orbit Demo'), findsOneWidget);
      expect(find.text('Nudge Station Demo'), findsOneWidget);
      for (final action in demoActions) {
        expect(
          tester
              .widget<FilledButton>(find.byKey(Key('demo-$action')))
              .onPressed,
          isNull,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'connected controller buttons drive only the requested demo action',
    (tester) async {
      final radio = FakeDemoTransport();
      final c = DemoController(transport: radio, acceptance: accepted);
      await tester.pumpWidget(
        PrototypeDemoApp(home: DemoControllerPage(controller: c)),
      );
      await tester.tap(find.text('連線').first);
      await tester.pump();
      radio.report(scene: 'focus', index: 3);
      await tester.pump();
      await tester.tap(find.byKey(const Key('demo-next')));
      await tester.pump();
      expect(jsonDecode(radio.writes.single)['action'], 'next');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'controller tolerates small screens and large text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final radio = FakeDemoTransport();
      final c = DemoController(
        transport: radio,
        acceptance: const DemoAcceptance(),
      );
      await tester.pumpWidget(
        PrototypeDemoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: DemoControllerPage(controller: c),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets(
    'all six generated character poses render and can be exported as software evidence',
    (tester) async {
      await tester.pumpWidget(
        PrototypeDemoApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('visual-proof'),
              child: ColoredBox(
                color: Color(demoPalette['background']!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('SOFTWARE PREVIEW / DEMO'),
                    Wrap(
                      children: [
                        for (final pose in demoPoseMarks.keys)
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: Column(
                              children: [
                                DemoCharacter(pose: pose, size: 120),
                                Text(pose.toUpperCase()),
                                const Text('DEMO'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('NUDGE_EXPORT_DEMO_VISUALS')) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('visual-proof')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = Directory('build/demo-evidence')
            ..createSync(recursive: true);
          File(
            '${out.path}/app-poses.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
