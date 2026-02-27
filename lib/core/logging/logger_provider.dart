import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Provider for LoggerService (stateless utility class)
///
/// Usage:
/// ```dart
/// // In presentation layer (not needed since LoggerService is static)
/// // But provided for consistency with other services
/// final logger = ref.read(loggerServiceProvider);
/// logger.info('Message');
///
/// // Direct usage (preferred for static utility)
/// LoggerService.info('Message');
/// ```
final loggerServiceProvider = Provider<LoggerService>((ref) {
  // LoggerService is a static utility class, so we return a dummy instance
  // This provider exists for consistency with other services
  throw UnimplementedError(
    'LoggerService is a static utility class. Use LoggerService.debug/info/warn/error directly.',
  );
});
