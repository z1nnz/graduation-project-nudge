import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/study_room_models.dart';
import 'package:nudge/screens/study_room_chat_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('room chat sends text and stickers through existing room state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    appState.createStudyRoom(
      name: '測試讀書房',
      description: '一起專注',
      accentColor: const Color(0xFF7C6AE6),
    );
    final roomId = appState.studyRooms.first.id;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(home: StudyRoomChatPage(roomId: roomId)),
      ),
    );
    expect(find.text('還沒有訊息，送出第一句鼓勵吧。'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '一起加油');
    await tester.tap(find.byTooltip('傳送訊息'));
    await tester.pumpAndSettle();
    expect(appState.getStudyRoomById(roomId)!.messages.first.text, '一起加油');

    await tester.tap(find.text('穩住').first);
    await tester.pumpAndSettle();
    final latest = appState.getStudyRoomById(roomId)!.messages.first;
    expect(latest.text, '穩住');
    expect(latest.type, StudyRoomMessageType.sticker);
  });

  testWidgets('unknown rooms do not expose a composer or message history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appState = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: StudyRoomChatPage(roomId: 'unknown-room'),
        ),
      ),
    );

    expect(find.text('加入房間並通過審核後才能查看聊天。'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
