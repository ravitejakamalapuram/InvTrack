/// Golden test helpers for InvTrack design system widgets.
///
/// Usage:
/// ```dart
/// testWidgets('MyWidget golden test', (tester) async {
///   await tester.pumpGoldenWidget(
///     MyWidget(),
///     wrapper: goldenThemeWrapper(isDark: false),
///   );
///   await expectLater(
///     find.byType(MyWidget),
///     matchesGoldenFile('my_widget_light.png'),
///   );
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inv_tracker/core/theme/app_theme.dart';

/// Golden test configuration
class GoldenTestConfig {
  /// Default surface size for golden tests
  static const Size defaultSize = Size(400, 350);

  /// Compact size for small widgets
  static const Size compactSize = Size(250, 200);

  /// Full width size for cards and list items
  static const Size cardSize = Size(400, 200);

  /// Button size
  static const Size buttonSize = Size(350, 100);

  /// Setup test config - call in setUpAll
  static void setup() {
    // Prevent Google Fonts from making network requests in tests
    // Fonts are bundled in assets/fonts/ and registered in pubspec.yaml
    GoogleFonts.config.allowRuntimeFetching = false;
  }
}

/// Creates a themed wrapper for golden tests using the actual app theme.
///
/// Uses the app's theme system with bundled fonts (Inter, Plus Jakarta Sans)
/// registered in pubspec.yaml for deterministic golden test rendering.
Widget goldenThemeWrapper({
  required Widget child,
  bool isDark = false,
  Size size = GoldenTestConfig.defaultSize,
}) {
  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Extension on WidgetTester for golden test convenience methods
extension GoldenTestExtensions on WidgetTester {
  /// Pumps a widget with golden test wrapper and waits for animations
  Future<void> pumpGoldenWidget(
    Widget widget, {
    bool isDark = false,
    Size size = GoldenTestConfig.defaultSize,
  }) async {
    await pumpWidget(
      goldenThemeWrapper(child: widget, isDark: isDark, size: size),
    );
    // Wait for any animations to settle
    await pump(const Duration(milliseconds: 100));
  }

  /// Sets up golden test with specific surface size
  Future<void> setGoldenSize(Size size) async {
    await binding.setSurfaceSize(size);
    addTearDown(() => binding.setSurfaceSize(null));
  }
}

/// Groups light and dark theme tests together
void goldenTestGroup(
  String description,
  Widget widget, {
  required String goldenFilePrefix,
  Size size = GoldenTestConfig.defaultSize,
}) {
  group(description, () {
    testWidgets('light theme', (tester) async {
      await tester.setGoldenSize(size);
      await tester.pumpGoldenWidget(widget, isDark: false, size: size);
      await expectLater(
        find.byType(widget.runtimeType),
        matchesGoldenFile('goldens/${goldenFilePrefix}_light.png'),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.setGoldenSize(size);
      await tester.pumpGoldenWidget(widget, isDark: true, size: size);
      await expectLater(
        find.byType(widget.runtimeType),
        matchesGoldenFile('goldens/${goldenFilePrefix}_dark.png'),
      );
    });
  });
}
