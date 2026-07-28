import 'package:flutter_test/flutter_test.dart';
import 'package:nudge/models/relationship_outcome.dart';

void main() {
  test('parses formal family outcome and memory response', () {
    final result = RelationshipOutcomeRefreshResult.fromMap({
      'outcome': {
        'outcomeId': 'family--family-1',
        'scopeType': 'family',
        'scopeId': 'family-1',
        'scopeName': '家庭連結',
        'status': 'active',
        'growth': {
          'kind': 'family_tree',
          'xp': 12,
          'level': 2,
          'currentLevelXp': 10,
          'nextLevelXp': 30,
          'milestoneKeys': ['family_seed', 'family_sprout'],
        },
        'metrics': {
          'acknowledgements': 1,
          'completedGoals': 2,
          'memoryCount': 3,
        },
        'characterOutcome': {
          'kind': 'family_companion',
          'stage': 2,
          'title': '同行嫩芽',
          'description': '共同目標與回應已長成穩定的陪伴節奏。',
        },
        'updatedAt': '2026-07-28T08:00:00.000Z',
      },
      'memories': [
        {
          'memoryId': 'goal_completed--goal-1',
          'scopeId': 'family-1',
          'memoryType': 'goal_completed',
          'sourceId': 'goal-1',
          'actorId': 'child-1',
          'title': '一起完成了一個共同目標',
          'points': 8,
          'happenedAt': '2026-07-28T07:00:00.000Z',
        },
      ],
    });

    expect(result.outcome.outcomeId, 'family--family-1');
    expect(result.outcome.growthLevel, 2);
    expect(result.outcome.levelProgress, closeTo(0.1, 0.001));
    expect(result.outcome.metric('completedGoals'), 2);
    expect(result.outcome.characterTitle, '同行嫩芽');
    expect(result.memories.single.points, 8);
  });
}
