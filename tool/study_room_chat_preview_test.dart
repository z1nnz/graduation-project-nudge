// Offline screenshot generator. Run only when refreshing review evidence:
// flutter test tool/study_room_chat_preview_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/screens/study_room_chat_page.dart';
import 'package:nudge/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('offline chat preview at 360 by 780', (tester) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      final fontBytes = await File('C:/Windows/Fonts/msjh.ttc').readAsBytes();
      await (FontLoader(
        'PreviewChinese',
      )..addFont(Future.value(ByteData.sublistView(fontBytes)))).load();
    });
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState();
    appState.createStudyRoom(
      name: '星光自習室',
      description: '一起專注',
      accentColor: const Color(0xFF7C6AE6),
    );
    final roomId = appState.studyRooms.first.id;
    await appState.addStudyRoomMessage(roomId: roomId, text: '今天先完成一小步。');
    await appState.addStudyRoomMessage(roomId: roomId, text: '加油');

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true, fontFamily: 'PreviewChinese'),
          home: StudyRoomChatPage(roomId: roomId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        '../docs/acceptance/screenshots/study-room-chat/chat-360x780.png',
      ),
    );
  });
}
