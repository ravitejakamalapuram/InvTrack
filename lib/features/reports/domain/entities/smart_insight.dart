/// Smart Insight Entity
///
/// Represents an auto-generated insight based on user's investment data.
/// These insights provide actionable information without requiring user configuration.
library;

/// Type of smart insight
enum InsightType {
  /// Week-over-week summary
  weeklySummary,
  
  /// Month-over-month summary
  monthlySummary,
  
  /// Year-to-date performance
  ytdPerformance,
  
  /// Upcoming maturity warning
  upcomingMaturity,
  
  /// Declining investment alert
  decliningInvestment,
  
  /// Goal progress update
  goalProgress,
  
  /// Tax planning opportunity
  taxPlanning,
}

/// Priority/urgency level of the insight
enum InsightPriority {
  /// Low priority, informational
  info,
  
  /// Medium priority, needs attention soon
  warning,
  
  /// High priority, action required now
  urgent,
}

/// Smart insight that appears automatically based on user data
class SmartInsight {
  /// Type of insight
  final InsightType type;
  
  /// Priority level
  final InsightPriority priority;
  
  /// Main title of the insight
  final String title;
  
  /// Subtitle/description
  final String subtitle;
  
  /// Primary metric value (e.g., "₹50K", "+12%")
  final String value;
  
  /// Secondary metric (optional)
  final String? secondaryValue;
  
  /// Icon to display
  final String icon;
  
  /// Action to perform when tapped (report configuration)
  final String? actionPath;
  
  /// Timestamp when this insight was generated
  final DateTime generatedAt;
  
  const SmartInsight({
    required this.type,
    required this.priority,
    required this.title,
    required this.subtitle,
    required this.value,
    this.secondaryValue,
    required this.icon,
    this.actionPath,
    required this.generatedAt,
  });
  
  /// Check if this insight is time-sensitive (expires after 7 days)
  bool get isExpired {
    final now = DateTime.now();
    return now.difference(generatedAt).inDays > 7;
  }
  
  /// Get color based on priority
  String get priorityColor {
    switch (priority) {
      case InsightPriority.urgent:
        return 'error';
      case InsightPriority.warning:
        return 'warning';
      case InsightPriority.info:
        return 'success';
    }
  }
  
  @override
  String toString() => 'SmartInsight($type, $priority, $title)';
}
