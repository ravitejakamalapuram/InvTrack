/// Barrel file for all investment providers.
/// Import this file to access all investment-related providers.
library;

// Stream providers (single source of truth)
export 'investment_providers.dart';

// Stats calculation providers
export 'investment_stats_provider.dart';

// Analytics and trend providers
export 'investment_analytics_provider.dart';

// Notifier for mutations (CRUD operations)
export 'investment_notifier.dart';

// Investment list screen state
export 'investment_list_state_provider.dart';

