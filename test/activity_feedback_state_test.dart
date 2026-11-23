import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/activity_feedback_state.dart';

void main() {
  final receipt = <String, dynamic>{
    'receiptId': 'r1',
    'actorUserId': 'first',
    'activityType': 'focus',
    'acceptedMetric': 25,
    'verifiedAt': '2026-11-22T06:00:00.000Z',
  };

  test(
    'account transition clears before profile await and rejects stale results',
    () async {
      final state = ActivityFeedbackState();
      final first = state.begin('first');
      state.update(
        first,
        id: 'r1',
        data: receipt,
        fromCache: false,
        pendingWrites: false,
      );
      expect(state.feedback, isNotNull);
      final profileLoaded = Completer<void>();
      final second = state.begin('second');
      expect(state.feedback, isNull);
      var staleSetupRan = false;
      final obsoleteSetup = () async {
        await profileLoaded.future;
        if (state.isCurrent(second)) staleSetupRan = true;
      }();
      state.begin('third');
      state.update(
        first,
        id: 'r1',
        data: receipt,
        fromCache: false,
        pendingWrites: false,
      );
      state.fail(second);
      profileLoaded.complete();
      await obsoleteSetup;
      expect(staleSetupRan, isFalse);
      expect(state.feedback, isNull);
      expect(state.status, '正在讀取活動確認');
      state.begin(null);
      expect(state.status, '登入後查看雲端活動確認');
    },
  );

  test('cached receipts are labelled and pending writes never confirm', () {
    final state = ActivityFeedbackState();
    final token = state.begin('first');
    state.update(
      token,
      id: 'r1',
      data: receipt,
      fromCache: true,
      pendingWrites: false,
    );
    expect(state.feedback, isNotNull);
    expect(state.status, contains('快取'));
    state.update(
      token,
      id: 'r1',
      data: receipt,
      fromCache: false,
      pendingWrites: true,
    );
    expect(state.feedback, isNull);
  });
}
