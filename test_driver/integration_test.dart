// Test driver for running integration tests with performance profiling.
//
// Usage:
// ```bash
// # Run integration tests
// flutter test integration_test/app_test.dart
//
// # Run with performance profiling
// flutter drive \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/performance/performance_test.dart \
//   --profile
// ```
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
