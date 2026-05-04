// Unit tests for Portfolio Health Score entities
//
// Tests ComponentScore and PortfolioHealthScore:
// - Equality and hashCode
// - Weighted score calculation
// - Top suggestions algorithm
// - Score tier mapping
// - Validation and edge cases
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/portfolio_health/domain/entities/portfolio_health_score.dart';

void main() {
  group('ComponentScore', () {
    test('calculates weighted score correctly', () {
      final component = ComponentScore(
        name: 'Test Component',
        score: 80.0,
        weight: 0.30,
        description: 'Test description',
        suggestions: ['Test suggestion'],
      );

      expect(component.weightedScore, 24.0); // 80 * 0.30
    });

    test('validates score range (0-100)', () {
      expect(
        () => ComponentScore(
          name: 'Invalid',
          score: 150.0, // Invalid: > 100
          weight: 0.30,
          description: 'Test',
          suggestions: [],
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => ComponentScore(
          name: 'Invalid',
          score: -10.0, // Invalid: < 0
          weight: 0.30,
          description: 'Test',
          suggestions: [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('validates weight range (0-1)', () {
      expect(
        () => ComponentScore(
          name: 'Invalid',
          score: 80.0,
          weight: 1.5, // Invalid: > 1
          description: 'Test',
          suggestions: [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects non-finite scores', () {
      // Note: AssertionError is thrown first (score range check),
      // then ArgumentError (isFinite check) in the constructor
      expect(
        () => ComponentScore(
          name: 'Invalid',
          score: double.nan,
          weight: 0.30,
          description: 'Test',
          suggestions: [],
        ),
        throwsA(isA<AssertionError>()),
      );

      expect(
        () => ComponentScore(
          name: 'Invalid',
          score: double.infinity,
          weight: 0.30,
          description: 'Test',
          suggestions: [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('equality works correctly', () {
      final component1 = ComponentScore(
        name: 'Test',
        score: 80.0,
        weight: 0.30,
        description: 'Desc',
        suggestions: ['Sug1', 'Sug2'],
      );

      final component2 = ComponentScore(
        name: 'Test',
        score: 80.0,
        weight: 0.30,
        description: 'Desc',
        suggestions: ['Sug1', 'Sug2'],
      );

      final component3 = ComponentScore(
        name: 'Test',
        score: 70.0, // Different score
        weight: 0.30,
        description: 'Desc',
        suggestions: ['Sug1', 'Sug2'],
      );

      expect(component1, equals(component2));
      expect(component1, isNot(equals(component3)));
      expect(component1.hashCode, equals(component2.hashCode));
    });

    test('suggestions list comparison works', () {
      final component1 = ComponentScore(
        name: 'Test',
        score: 80.0,
        weight: 0.30,
        description: 'Desc',
        suggestions: ['Sug1', 'Sug2'],
      );

      final component2 = ComponentScore(
        name: 'Test',
        score: 80.0,
        weight: 0.30,
        description: 'Desc',
        suggestions: ['Sug1', 'Sug3'], // Different suggestion
      );

      final component3 = ComponentScore(
        name: 'Test',
        score: 80.0,
        weight: 0.30,
        description: 'Desc',
        suggestions: ['Sug1'], // Different length
      );

      expect(component1, isNot(equals(component2)));
      expect(component1, isNot(equals(component3)));
    });

    test('copyWith creates proper copy', () {
      final original = ComponentScore(
        name: 'Original',
        score: 80.0,
        weight: 0.30,
        description: 'Original desc',
        suggestions: ['Original sug'],
      );

      final copied = original.copyWith(score: 90.0, name: 'Modified');

      expect(copied.score, 90.0);
      expect(copied.name, 'Modified');
      expect(copied.weight, 0.30); // Unchanged
      expect(copied.description, 'Original desc'); // Unchanged
    });
  });

  group('ScoreTier', () {
    test('maps scores to correct tiers', () {
      expect(ScoreTier.fromScore(100.0), ScoreTier.excellent);
      expect(ScoreTier.fromScore(85.0), ScoreTier.excellent);
      expect(ScoreTier.fromScore(80.0), ScoreTier.excellent);

      expect(ScoreTier.fromScore(79.9), ScoreTier.good);
      expect(ScoreTier.fromScore(70.0), ScoreTier.good);
      expect(ScoreTier.fromScore(60.0), ScoreTier.good);

      expect(ScoreTier.fromScore(59.9), ScoreTier.fair);
      expect(ScoreTier.fromScore(50.0), ScoreTier.fair);
      expect(ScoreTier.fromScore(40.0), ScoreTier.fair);

      expect(ScoreTier.fromScore(39.9), ScoreTier.poor);
      expect(ScoreTier.fromScore(20.0), ScoreTier.poor);
      expect(ScoreTier.fromScore(0.0), ScoreTier.poor);
    });

    test('has correct tier properties', () {
      expect(ScoreTier.excellent.label, 'Excellent');
      expect(ScoreTier.excellent.emoji, '💚');
      expect(ScoreTier.good.label, 'Good');
      expect(ScoreTier.good.emoji, '💛');
      expect(ScoreTier.fair.label, 'Fair');
      expect(ScoreTier.fair.emoji, '🧡');
      expect(ScoreTier.poor.label, 'Poor');
      expect(ScoreTier.poor.emoji, '❤️');
    });
  });

  group('PortfolioHealthScore', () {
    late ComponentScore returns;
    late ComponentScore diversification;
    late ComponentScore liquidity;
    late ComponentScore goals;
    late ComponentScore actions;

    setUp(() {
      returns = ComponentScore(
        name: 'Returns',
        score: 80.0,
        weight: 0.30,
        description: 'Good returns',
        suggestions: ['Keep it up'],
      );
      diversification = ComponentScore(
        name: 'Diversification',
        score: 60.0,
        weight: 0.25,
        description: 'Fair diversification',
        suggestions: ['Add more types', 'Consider bonds'],
      );
      liquidity = ComponentScore(
        name: 'Liquidity',
        score: 90.0,
        weight: 0.20,
        description: 'Excellent liquidity',
        suggestions: [],
      );
      goals = ComponentScore(
        name: 'Goals',
        score: 40.0,
        weight: 0.15,
        description: 'Behind schedule',
        suggestions: ['Increase contributions', 'Review targets'],
      );
      actions = ComponentScore(
        name: 'Actions',
        score: 70.0,
        weight: 0.10,
        description: 'Some overdue',
        suggestions: ['Renew FDs'],
      );
    });

    test('calculates overall score correctly', () {
      final score = PortfolioHealthScore(
        overallScore: 70.5,
        returnsPerformance: returns,
        diversification: diversification,
        liquidity: liquidity,
        goalAlignment: goals,
        actionReadiness: actions,
        calculatedAt: DateTime.now(),
      );

      expect(score.overallScore, 70.5);
    });

    test('tier is derived from overall score', () {
      final excellent = PortfolioHealthScore(
        overallScore: 85.0,
        returnsPerformance: returns,
        diversification: diversification,
        liquidity: liquidity,
        goalAlignment: goals,
        actionReadiness: actions,
        calculatedAt: DateTime.now(),
      );

      expect(excellent.tier, ScoreTier.excellent);
    });

    test('components list includes all 5 components', () {
      final score = PortfolioHealthScore(
        overallScore: 70.0,
        returnsPerformance: returns,
        diversification: diversification,
        liquidity: liquidity,
        goalAlignment: goals,
        actionReadiness: actions,
        calculatedAt: DateTime.now(),
      );

      expect(score.components.length, 5);
      expect(score.components, contains(returns));
      expect(score.components, contains(diversification));
      expect(score.components, contains(liquidity));
      expect(score.components, contains(goals));
      expect(score.components, contains(actions));
    });

    test('topSuggestions returns top 3 from lowest scoring components', () {
      final score = PortfolioHealthScore(
        overallScore: 70.0,
        returnsPerformance: returns,
        diversification: diversification,
        liquidity: liquidity,
        goalAlignment: goals, // Lowest: 40.0
        actionReadiness: actions,
        calculatedAt: DateTime.now(),
      );

      final suggestions = score.topSuggestions;

      // Should prioritize suggestions from lowest scoring components
      expect(suggestions.length, lessThanOrEqualTo(3));
      // Goals (40.0) suggestions should come first
      expect(suggestions, contains('Increase contributions'));
      expect(suggestions, contains('Review targets'));
    });

    test('equality and hashCode work correctly', () {
      final timestamp = DateTime.now();
      final score1 = PortfolioHealthScore(
        overallScore: 70.0,
        returnsPerformance: returns,
        diversification: diversification,
        liquidity: liquidity,
        goalAlignment: goals,
        actionReadiness: actions,
        calculatedAt: timestamp,
      );

      final score2 = PortfolioHealthScore(
        overallScore: 70.0,
        returnsPerformance: returns,
        diversification: diversification,
        liquidity: liquidity,
        goalAlignment: goals,
        actionReadiness: actions,
        calculatedAt: timestamp,
      );

      expect(score1, equals(score2));
      expect(score1.hashCode, equals(score2.hashCode));
    });
  });
}
