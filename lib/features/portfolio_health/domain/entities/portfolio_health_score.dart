/// Portfolio Health Score - "The Fitbit for Your Money"
///
/// A unified score (0-100) that measures portfolio health across 5 dimensions:
/// - Returns Performance (30%): XIRR vs inflation/benchmarks
/// - Diversification (25%): Herfindahl index across types/platforms
/// - Liquidity (20%): % maturing in next 90 days
/// - Goal Alignment (15%): On-track vs behind goals
/// - Action Readiness (10%): Overdue renewals, stale investments
library;

/// Score tier for visual representation
enum ScoreTier {
  excellent(80, 100, 'Excellent', 'Your portfolio is thriving', '💚'),
  good(60, 79, 'Good', 'Minor improvements possible', '💛'),
  fair(40, 59, 'Fair', 'Attention needed', '🧡'),
  poor(0, 39, 'Poor', 'Urgent action required', '❤️');

  final int minScore;
  final int maxScore;
  final String label;
  final String message;
  final String emoji;

  const ScoreTier(this.minScore, this.maxScore, this.label, this.message, this.emoji);

  /// Get tier for a given score
  static ScoreTier fromScore(double score) {
    // Use raw double comparison to avoid rounding issues (79.6 should be good, not excellent)
    if (score >= 80.0) return ScoreTier.excellent;
    if (score >= 60.0) return ScoreTier.good;
    if (score >= 40.0) return ScoreTier.fair;
    return ScoreTier.poor;
  }
}

/// Individual component score of portfolio health
class ComponentScore {
  final String name;
  final double score; // 0-100
  final double weight; // 0-1 (e.g., 0.30 for 30%)
  final String description;
  final List<String> suggestions;

  const ComponentScore({
    required this.name,
    required this.score,
    required this.weight,
    required this.description,
    required this.suggestions,
  });

  /// Weighted contribution to overall score
  double get weightedScore => score * weight;

  ComponentScore copyWith({
    String? name,
    double? score,
    double? weight,
    String? description,
    List<String>? suggestions,
  }) {
    return ComponentScore(
      name: name ?? this.name,
      score: score ?? this.score,
      weight: weight ?? this.weight,
      description: description ?? this.description,
      suggestions: suggestions ?? this.suggestions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComponentScore) return false;

    // Compare suggestions list element by element
    if (suggestions.length != other.suggestions.length) return false;
    for (var i = 0; i < suggestions.length; i++) {
      if (suggestions[i] != other.suggestions[i]) return false;
    }

    return name == other.name &&
        score == other.score &&
        weight == other.weight &&
        description == other.description;
  }

  @override
  int get hashCode => Object.hash(
        name,
        score,
        weight,
        description,
        Object.hashAll(suggestions),
      );
}

/// Portfolio Health Score Entity
class PortfolioHealthScore {
  /// Overall health score (0-100)
  final double overallScore;

  /// Individual component scores
  final ComponentScore returnsPerformance;
  final ComponentScore diversification;
  final ComponentScore liquidity;
  final ComponentScore goalAlignment;
  final ComponentScore actionReadiness;

  /// When this score was calculated
  final DateTime calculatedAt;

  /// Score tier for visual representation
  ScoreTier get tier => ScoreTier.fromScore(overallScore);

  const PortfolioHealthScore({
    required this.overallScore,
    required this.returnsPerformance,
    required this.diversification,
    required this.liquidity,
    required this.goalAlignment,
    required this.actionReadiness,
    required this.calculatedAt,
  });

  /// All component scores as a list
  List<ComponentScore> get components => [
        returnsPerformance,
        diversification,
        liquidity,
        goalAlignment,
        actionReadiness,
      ];

  /// Get top 3 improvement suggestions across all components
  List<String> get topSuggestions {
    // Collect all suggestions with their component scores
    final allSuggestions = <({double score, String suggestion})>[];
    for (final component in components) {
      for (final suggestion in component.suggestions) {
        allSuggestions.add((score: component.score, suggestion: suggestion));
      }
    }

    // Sort by lowest score (highest priority improvements)
    allSuggestions.sort((a, b) => a.score.compareTo(b.score));

    // Return top 3 unique suggestions (deduplicate by text)
    final seen = <String>{};
    final uniqueSuggestions = <String>[];

    for (final item in allSuggestions) {
      if (!seen.contains(item.suggestion)) {
        seen.add(item.suggestion);
        uniqueSuggestions.add(item.suggestion);
        if (uniqueSuggestions.length >= 3) break;
      }
    }

    return uniqueSuggestions;
  }

  PortfolioHealthScore copyWith({
    double? overallScore,
    ComponentScore? returnsPerformance,
    ComponentScore? diversification,
    ComponentScore? liquidity,
    ComponentScore? goalAlignment,
    ComponentScore? actionReadiness,
    DateTime? calculatedAt,
  }) {
    return PortfolioHealthScore(
      overallScore: overallScore ?? this.overallScore,
      returnsPerformance: returnsPerformance ?? this.returnsPerformance,
      diversification: diversification ?? this.diversification,
      liquidity: liquidity ?? this.liquidity,
      goalAlignment: goalAlignment ?? this.goalAlignment,
      actionReadiness: actionReadiness ?? this.actionReadiness,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PortfolioHealthScore &&
        other.overallScore == overallScore &&
        other.returnsPerformance == returnsPerformance &&
        other.diversification == diversification &&
        other.liquidity == liquidity &&
        other.goalAlignment == goalAlignment &&
        other.actionReadiness == actionReadiness &&
        other.calculatedAt == calculatedAt;
  }

  @override
  int get hashCode => Object.hash(
        overallScore,
        returnsPerformance,
        diversification,
        liquidity,
        goalAlignment,
        actionReadiness,
        calculatedAt,
      );
}
