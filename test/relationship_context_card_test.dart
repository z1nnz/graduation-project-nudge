import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/relationship_membership.dart';
import 'package:nudge/widgets/relationship_context_switcher.dart';

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

void main() {
  testWidgets('family context shows the canonical role and switches links', (
    tester,
  ) async {
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
    expect(find.textContaining('你可以決定資料分享、接受共同目標與回應鼓勵'), findsOneWidget);
    expect(find.text('切換家庭關係'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('陪伴家庭 · 家長').last);
    await tester.pumpAndSettle();

    expect(selectedScopeId, 'family-guardian');
  });

  testWidgets('group context explains the manager boundary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelationshipContextCard(
            scope: RelationshipScope.group,
            memberships: [
              membership(
                scope: RelationshipScope.group,
                scopeId: 'group-1',
                scopeName: '專題團隊',
                role: RelationshipRole.manager,
              ),
            ],
            selectedScopeId: 'group-1',
            accentColor: Colors.blue,
            onSelected: (_) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('你在此情境是「團體管理者」'), findsOneWidget);
    expect(find.textContaining('建立共同框架，但不會替成員開始或結束活動'), findsOneWidget);
    expect(find.text('切換團體'), findsNothing);
  });
}
