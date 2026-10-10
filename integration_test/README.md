# InvTrack Integration Tests

Comprehensive E2E and integration tests for InvTrack using Flutter's `integration_test` package.

## Quick Start

```bash
# Run all integration tests
flutter test integration_test/app_test.dart

# Run specific flow tests
flutter test integration_test/flows/navigation_flow_test.dart
flutter test integration_test/flows/investment_flow_test.dart
flutter test integration_test/flows/goals_flow_test.dart
flutter test integration_test/flows/settings_flow_test.dart

# Run performance benchmarks
flutter test integration_test/performance/performance_test.dart
```

## Test Structure

```
integration_test/
├── app_test.dart           # Main integration test suite
├── test_app.dart           # Test app helper with mocked providers
├── README.md               # This file
├── flows/                  # Feature-specific E2E tests
│   ├── navigation_flow_test.dart
│   ├── investment_flow_test.dart
│   ├── goals_flow_test.dart
│   └── settings_flow_test.dart
├── mocks/                  # Mock implementations
│   ├── mock_investment_repository.dart
│   ├── mock_goal_repository.dart
│   ├── mock_analytics_service.dart
│   └── mock_notification_service.dart
├── performance/            # Performance benchmarks
│   └── performance_test.dart
└── robots/                 # Page Object Pattern robots
    ├── robots.dart         # Barrel export
    ├── base_robot.dart     # Base class with common methods
    ├── navigation_robot.dart
    ├── investment_robot.dart
    ├── goals_robot.dart
    └── settings_robot.dart
```

## Robot Pattern

We use the **Robot Pattern** (Page Object Pattern) for cleaner, more maintainable tests.

### Example Usage

```dart
testWidgets('should add investment', (tester) async {
  final testApp = await TestApp.create(tester);
  final nav = NavigationRobot(tester);
  final inv = InvestmentRobot(tester);

  await testApp.pumpApp();

  // Navigate to investments
  await nav.goToInvestments();
  nav.verifyOnInvestments();

  // Add investment
  await inv.addInvestment(
    name: 'My Investment',
    type: InvestmentType.fixedDeposit,
  );

  // Verify
  inv.verifyInvestmentDisplayed('My Investment');
});
```

## Running on Device/Emulator

```bash
# iOS Simulator
flutter test integration_test/app_test.dart -d <simulator_id>

# Android Emulator
flutter test integration_test/app_test.dart -d <emulator_id>

# Physical device
flutter test integration_test/app_test.dart -d <device_id>
```

## Performance Profiling

```bash
# Run with profiling (generates timeline)
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/performance/performance_test.dart \
  --profile

# Results saved to build/performance/
```

## Screenshots

Screenshots are captured during tests using `robot.takeScreenshot('name')`.

```dart
await nav.goToSettings();
await settings.takeScreenshot('settings_main');
```

Screenshots are uploaded as artifacts in CI.

### Play Store screenshots without an emulator

The five Play phone screenshots (`android/fastlane/metadata/android/en-US/images/phoneScreenshots/play_01..05`) can be regenerated with plain `flutter test`, on any machine, from the demo portfolio in `integration_test/mocks/store_demo_data.dart` (the same data `flows/store_screenshots_test.dart` uses on a device): `STORE_SCREENSHOTS_ALLOW_FONT_FALLBACK=1 STORE_SCREENSHOTS_DIR=android/fastlane/metadata/android/en-US/images/phoneScreenshots flutter test test/store_screenshots/store_screenshots_test.dart`. It runs the real app at 1080x1920 (411.43x731.43 dp at 2.625), checks each scene and writes 24-bit PNGs without alpha, the format the Play listing check wants. The checks per scene: none of the app's loading skeletons, spinners, endless progress bars, error icons or error texts (read from the l10n file) on screen; the cards the scene is about are present (the Overview must show the hero, a goal and the FIRE card, because a card that fails to load can disappear without a message); no negative amount in the frame; no unloaded font; and in privacy mode no amount in text or semantics. A load failure the checks do not know about, such as a new error widget, can still pass, so look at the images before committing them. The Plus Jakarta Sans files are not valid fonts yet (#973), so headings fall back to Roboto: the generator refuses to write files that way unless `STORE_SCREENSHOTS_ALLOW_FONT_FALLBACK=1` is set, and prints the fonts used for each file. It needs an emoji font for the goal icons (Noto Color Emoji; set `STORE_SCREENSHOTS_EMOJI_FONT` if it is not in a standard path). Without `STORE_SCREENSHOTS_DIR` it renders and checks the scenes but writes nothing, which is what the normal test run does (`--exclude-tags=store-screenshots` skips it). Dates in the images count back from the day it runs, and the Overview header shows whatever the app shows then, so regenerate after UI changes. Uploading the images to Play stays manual (the `listing` workflow).

## CI/CD Integration

Tests run automatically on every PR via GitHub Actions:

| Job | Platform | Trigger |
|-----|----------|---------|
| Unit Tests | Ubuntu | All PRs |
| iOS Integration | macOS | All PRs |
| Android Integration | Ubuntu + Emulator | All PRs |
| Performance | macOS | Main branch only |

## Mocking Strategy

### What We Mock
- **Repositories** - `FakeInvestmentRepository`, `FakeGoalRepository`
- **Services** - Analytics, Notifications
- **Platform** - `FlutterSecureStorage`, `LocalAuthentication`
- **Auth** - Always logged in as test user

### Seeding Test Data

```dart
final testApp = await TestApp.create(tester);

testApp.seedInvestments([
  InvestmentEntity(
    id: 'test-1',
    name: 'Test Investment',
    type: InvestmentType.fixedDeposit,
    ...
  ),
]);

testApp.seedGoals([
  GoalEntity(
    id: 'goal-1',
    name: 'Test Goal',
    targetAmount: 100000,
    ...
  ),
]);

await testApp.pumpApp();
```

## Best Practices

1. **Use robots** for all UI interactions
2. **Seed data** before pumping the app
3. **Take screenshots** at key states for visual regression
4. **Assert frequently** - verify state after each action
5. **Reset between tests** - tests should be independent

## Troubleshooting

### Tests timing out
Increase the pumpAndSettle timeout:
```dart
await tester.pumpAndSettle(const Duration(seconds: 10));
```

### Flaky tests
Use explicit waits instead of pumpAndSettle:
```dart
await tester.pump(const Duration(milliseconds: 500));
```

### Can't find widget
Check if the widget is off-screen and scroll to it:
```dart
await robot.scrollUntilVisible(find.text('Target'));
```

