import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/relationship_membership.dart';
import 'package:nudge/widgets/relationship_context_switcher.dart';
import 'package:nudge/widgets/relationship_role_surface_card.dart';

RelationshipMembership membership({
  required RelationshipScope scope,
  required String scopeId,
  required String scopeName,
  required RelationshipRole role,
}) {
  const userId = 'member-1';
  return RelationshipMembership(
    id: RelationshipMembership.documentId(
      scope: scope,
      scopeId: scopeId,
      userId: userId,
    ),
    scope: scope,
    scopeId: scopeId,
    scopeName: scopeName,
    userId: userId,
    role: role,
    status: RelationshipMembershipStatus.active,
  );
}

Widget roleSurface(RelationshipRole role) => MaterialApp(
  home: Scaffold(body: RelationshipRoleSurfaceCard(role: role)),
);

void main() {
  group('RelationshipRoleSurfaceCard', () {
    testWidgets('guardian sees companionship actions without child authority', (
      tester,
    ) async {
      await tester.pumpWidget(roleSurface(RelationshipRole.guardian));

      expect(find.text('家長陪伴介面'), findsOneWidget);
      expect(find.text('提出共同目標'), findsOneWidget);
      expect(find.text('傳送鼓勵'), findsOneWidget);
      expect(find.textContaining('不能替孩子調整分享'), findsOneWidget);
      expect(find.text('接受或婉拒共同目標'), findsNothing);
    });

    testWidgets('child sees consent and decision actions', (tester) async {
      await tester.pumpWidget(roleSurface(RelationshipRole.child));

      expect(find.text('孩子自主介面'), findsOneWidget);
      expect(find.text('調整分享範圍'), findsOneWidget);
      expect(find.text('接受或婉拒共同目標'), findsOneWidget);
      expect(find.text('回應鼓勵'), findsOneWidget);
      expect(find.textContaining('家長只能看到你主動同意'), findsOneWidget);
      expect(find.text('提出共同目標'), findsNothing);
    });

    testWidgets(
      'manager sees framework actions without member activity control',
      (tester) async {
        await tester.pumpWidget(roleSurface(RelationshipRole.manager));

        expect(find.text('團體管理介面'), findsOneWidget);
        expect(find.text('發布共同框架'), findsOneWidget);
        expect(find.text('管理成員與管理權'), findsOneWidget);
        expect(find.textContaining('不能替成員開始、暫停或結束活動'), findsOneWidget);
        expect(find.text('自行開始與完成活動'), findsNothing);
      },
    );

    testWidgets('member keeps activity and sharing autonomy', (tester) async {
      await tester.pumpWidget(roleSurface(RelationshipRole.member));

      expect(find.text('團體成員介面'), findsOneWidget);
      expect(find.text('自行開始與完成活動'), findsOneWidget);
      expect(find.text('參與或退出挑戰'), findsOneWidget);
      expect(find.text('開啟或撤回成果分享'), findsOneWidget);
      expect(find.textContaining('管理者只能定義共同框架'), findsOneWidget);
      expect(find.text('管理成員與管理權'), findsNothing);
    });
  });

  group('RelationshipContextCard', () {
    testWidgets(
      'family context switches between child and guardian memberships',
      (tester) async {
        String? selectedScopeId;
        final memberships = [
          membership(
            scope: RelationshipScope.family,
            scopeId: 'family-child',
            scopeName: '我的家庭',
            role: RelationshipRole.child,
          ),
          membership(
            scope: RelationshipScope.family,
            scopeId: 'family-guardian',
            scopeName: '陪伴家庭',
            role: RelationshipRole.guardian,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RelationshipContextCard(
                scope: RelationshipScope.family,
                memberships: memberships,
                selectedScopeId: 'family-child',
                accentColor: Colors.purple,
                onSelected: (scopeId) async => selectedScopeId = scopeId,
              ),
            ),
          ),
        );

        expect(find.textContaining('你在此情境是「孩子」'), findsOneWidget);
        expect(find.textContaining('你可以決定資料分享'), findsOneWidget);
        expect(find.text('切換家庭關係'), findsOneWidget);

        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('陪伴家庭 · 家長').last);
        await tester.pumpAndSettle();

        expect(selectedScopeId, 'family-guardian');
      },
    );

    testWidgets('group contexts describe both manager and member boundaries', (
      tester,
    ) async {
      Future<void> pumpRole(RelationshipRole role) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelationshipContextCard(
              scope: RelationshipScope.group,
              memberships: [
                membership(
                  scope: RelationshipScope.group,
                  scopeId: 'group-1',
                  scopeName: '專題團隊',
                  role: role,
                ),
              ],
              selectedScopeId: 'group-1',
              accentColor: Colors.blue,
              onSelected: (_) async {},
            ),
          ),
        ),
      );

      await pumpRole(RelationshipRole.manager);
      expect(find.textContaining('你在此情境是「團體管理者」'), findsOneWidget);
      expect(find.textContaining('不會替成員開始或結束活動'), findsOneWidget);

      await pumpRole(RelationshipRole.member);
      expect(find.textContaining('你在此情境是「團體成員」'), findsOneWidget);
      expect(find.textContaining('隨時撤回成果分享'), findsOneWidget);
      expect(find.text('切換團體'), findsNothing);
    });
  });
}
