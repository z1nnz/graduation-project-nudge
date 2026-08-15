import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/room_resonance.dart';
import 'package:nudge/widgets/room_resonance_panel.dart';

RoomResonanceSignal otherSignal() => RoomResonanceSignal.fromMap({
  'schemaVersion': 1,
  'signalId': 'room-study--bob',
  'roomId': 'room-study',
  'ownerUserId': 'bob',
  'generationId': 'resonance-publish-001',
  'cueKey': 'open_to_company',
  'status': 'active',
  'visibility': 'room_members_only',
  'acknowledgementCount': 1,
  'createdAt': '2026-08-15T10:00:00.000Z',
  'updatedAt': '2026-08-15T10:00:00.000Z',
  'expiresAt': '2099-08-16T10:00:00.000Z',
  'withdrawnAt': null,
}, expectedRoomId: 'room-study');

void main() {
  testWidgets('resonance explains opt-in privacy before sharing', (
    tester,
  ) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomResonancePanel(
            accent: Colors.purple,
            currentUserId: 'alice',
            available: true,
            sharingEnabled: false,
            signals: const [],
            memberNames: const {},
            onSharingChanged: (value) async => enabled = value,
            onPublish: (_) async {},
            onWithdraw: () async {},
            onAcknowledge: (_, _) async {},
          ),
        ),
      ),
    );
    expect(find.textContaining('看不到精確健康'), findsOneWidget);
    expect(find.text('我正溫柔地重新開始'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
  });

  testWidgets('approved peers respond with bounded support only', (
    tester,
  ) async {
    RoomResonanceResponse? response;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoomResonancePanel(
              accent: Colors.purple,
              currentUserId: 'alice',
              available: true,
              sharingEnabled: true,
              signals: [otherSignal()],
              memberNames: const {'bob': 'Bob'},
              onSharingChanged: (_) async {},
              onPublish: (_) async {},
              onWithdraw: () async {},
              onAcknowledge: (_, value) async => response = value,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('想找人一起做一小段'), findsNWidgets(2));
    expect(find.text('我陪你'), findsOneWidget);
    expect(find.textContaining('分鐘'), findsNothing);
    await tester.tap(find.text('我陪你'));
    await tester.pumpAndSettle();
    expect(response, RoomResonanceResponse.withYou);
  });

  testWidgets('unapproved or guest viewers cannot use stale resonance state', (
    tester,
  ) async {
    var published = false;
    var acknowledged = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoomResonancePanel(
              accent: Colors.purple,
              currentUserId: 'alice',
              available: false,
              sharingEnabled: true,
              signals: [otherSignal()],
              memberNames: const {'bob': 'Bob'},
              onSharingChanged: (_) async {},
              onPublish: (_) async => published = true,
              onWithdraw: () async {},
              onAcknowledge: (_, _) async => acknowledged = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('我正溫柔地重新開始'), findsNothing);
    expect(find.text('Bob'), findsNothing);
    expect(find.text('我陪你'), findsNothing);
    expect(find.textContaining('訪客模式不會建立共振資料'), findsOneWidget);
    expect(published, isFalse);
    expect(acknowledged, isFalse);
  });
}
