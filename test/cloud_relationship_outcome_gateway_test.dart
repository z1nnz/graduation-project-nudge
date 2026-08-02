import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/services/cloud_relationship_outcome_gateway.dart';

void main() {
  test(
    'calls the Cloud outcome contract with explicit relationship scope',
    () async {
      Map<String, dynamic>? captured;
      final gateway = CloudRelationshipOutcomeGateway.withCallable((
        payload,
      ) async {
        captured = payload;
        return {
          'outcome': {
            'outcomeId': 'group--group-1',
            'scopeType': 'group',
            'scopeId': 'group-1',
            'scopeName': '晨間自律團',
            'status': 'active',
            'growth': {
              'kind': 'group_planet',
              'xp': 31,
              'level': 3,
              'currentLevelXp': 30,
              'nextLevelXp': null,
              'milestoneKeys': ['group_core', 'group_orbit', 'group_planet'],
            },
            'metrics': {
              'memberCount': 3,
              'sharedMemberCount': 3,
              'joinedChallengeCount': 3,
              'completedChallengeCount': 2,
            },
            'characterOutcome': {
              'kind': 'group_companion',
              'stage': 3,
              'title': '共進星球',
              'description': '團體持續累積由成員自己完成的共同成果。',
            },
            'updatedAt': '2026-07-28T08:00:00.000Z',
          },
          'memories': <dynamic>[],
        };
      });

      final result = await gateway.refresh(
        scopeType: 'group',
        scopeId: 'group-1',
      );

      expect(captured, {'scopeType': 'group', 'scopeId': 'group-1'});
      expect(result.outcome.characterTitle, '共進星球');
      expect(result.outcome.metric('completedChallengeCount'), 2);
    },
  );

  test('rejects mismatched scope returned by Cloud', () async {
    final gateway = CloudRelationshipOutcomeGateway.withCallable((_) async {
      return {
        'outcome': {
          'outcomeId': 'family--family-1',
          'scopeType': 'family',
          'scopeId': 'family-1',
          'growth': <String, dynamic>{},
          'metrics': <String, dynamic>{},
          'characterOutcome': <String, dynamic>{},
        },
        'memories': <dynamic>[],
      };
    });

    expect(
      () => gateway.refresh(scopeType: 'group', scopeId: 'group-1'),
      throwsA(isA<RelationshipOutcomeException>()),
    );
  });

  test('rejects unparseable Cloud outcome protocol data', () async {
    final gateway = CloudRelationshipOutcomeGateway.withCallable((_) async {
      return {
        'outcome': {
          'outcomeId': 'group--group-1',
          'scopeType': 'group',
          'scopeId': 'group-1',
          'scopeName': '晨間自律團',
          'status': 'active',
          'growth': {
            'kind': 'group_planet',
            'xp': '10',
            'level': 2,
            'currentLevelXp': 10,
            'nextLevelXp': 30,
            'milestoneKeys': ['group_core', 'group_orbit'],
          },
          'metrics': {'memberCount': 2},
          'characterOutcome': {
            'kind': 'group_companion',
            'stage': 2,
            'title': '協作軌道',
            'description': '共同成果',
          },
          'updatedAt': '2026-07-28T08:00:00.000Z',
        },
        'memories': <dynamic>[],
      };
    });

    expect(
      () => gateway.refresh(scopeType: 'group', scopeId: 'group-1'),
      throwsA(
        isA<RelationshipOutcomeException>().having(
          (error) => error.code,
          'code',
          'protocol-error',
        ),
      ),
    );
  });
}
