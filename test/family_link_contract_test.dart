import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/family_link_contract.dart';

void main() {
  final cases =
      (jsonDecode(
                File(
                  'test/fixtures/family_link_contract_cases.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  group('FamilyLinkContract', () {
    for (final testCase in cases) {
      test(testCase['name'] as String, () {
        FamilyLinkContract build() => FamilyLinkContract.fromAcceptedRequest(
          linkId: 'link-1',
          senderId: testCase['senderId'] as String,
          senderRole: testCase['senderRole'] as String,
          receiverId: testCase['receiverId'] as String,
          receiverRole: testCase['receiverRole'] as String,
          now: DateTime.utc(2026, 7, 27),
        );

        if (testCase['valid'] == false) {
          expect(build, throwsArgumentError);
          return;
        }

        final contract = build();
        expect(contract.guardianId, testCase['guardianId']);
        expect(contract.childId, testCase['childId']);
        expect(contract.participantIds, {
          testCase['guardianId'],
          testCase['childId'],
        });
        expect(contract.status, FamilyLinkStatus.active);
        expect(contract.consent.summary, isFalse);
        expect(contract.consent.healthTrends, isFalse);
      });
    }

    test(
      'encouragement targets the child and never mints personal rewards',
      () {
        final payload = FamilyLinkContract.buildEncouragementPayload(
          guardianId: 'guardian-1',
          childId: 'child-1',
          title: '今天也辛苦了',
          message: '先休息也沒關係',
          now: DateTime.utc(2026, 7, 27, 12),
        );

        expect(payload['senderId'], 'guardian-1');
        expect(payload['recipientId'], 'child-1');
        expect(payload['status'], 'sent');
        expect(payload.containsKey('disciplineCoins'), isFalse);
        expect(payload.containsKey('avatarExperience'), isFalse);
      },
    );

    test('shared goals begin proposed and need the child decision', () {
      final payload = FamilyLinkContract.buildSharedGoalPayload(
        guardianId: 'guardian-1',
        childId: 'child-1',
        title: '每天專注 30 分鐘',
        message: '我們一起慢慢建立節奏',
        now: DateTime.utc(2026, 7, 27, 12),
      );

      expect(payload['status'], 'proposed');
      expect(payload['proposedBy'], 'guardian-1');
      expect(payload['decisionBy'], 'child-1');
    });

    test('bond growth rewards two-way interaction, not message volume', () {
      expect(FamilyBondPolicy.pointsFor(FamilyBondEvent.acknowledgement), 3);
      expect(FamilyBondPolicy.pointsFor(FamilyBondEvent.goalCompleted), 10);
      expect(FamilyBondPolicy.levelForXp(0), 1);
      expect(FamilyBondPolicy.levelForXp(12), 2);
      expect(FamilyBondPolicy.levelForXp(30), 3);
    });
  });
}
