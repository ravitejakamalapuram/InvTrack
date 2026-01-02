import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Base class for all robot classes.
/// Provides common functionality for interacting with the app during integration tests.
abstract class BaseRobot {
  final WidgetTester tester;

  BaseRobot(this.tester);

  /// Get the integration test binding for screenshots
  IntegrationTestWidgetsFlutterBinding get binding =>
      IntegrationTestWidgetsFlutterBinding.instance;

  /// Wait for animations to complete
  Future<void> pumpAndSettle([Duration? duration]) async {
    await tester.pumpAndSettle(duration ?? const Duration(milliseconds: 300));
  }

  /// Tap on a widget found by finder
  Future<void> tap(Finder finder) async {
    await tester.tap(finder);
    await pumpAndSettle();
  }

  /// Tap on a widget by text
  Future<void> tapText(String text) async {
    await tap(find.text(text));
  }

  /// Tap on a widget by icon
  Future<void> tapIcon(IconData icon) async {
    await tap(find.byIcon(icon));
  }

  /// Tap on a widget by key
  Future<void> tapKey(Key key) async {
    await tap(find.byKey(key));
  }

  /// Enter text into a text field
  Future<void> enterText(Finder finder, String text) async {
    await tester.enterText(finder, text);
    await pumpAndSettle();
  }

  /// Scroll until a widget is visible
  Future<void> scrollUntilVisible(
    Finder finder, {
    double delta = 300.0,
    Finder? scrollable,
  }) async {
    await tester.scrollUntilVisible(
      finder,
      delta,
      scrollable: scrollable ?? find.byType(Scrollable).first,
    );
    await pumpAndSettle();
  }

  /// Verify a widget exists
  void verifyExists(Finder finder, {String? reason}) {
    expect(finder, findsWidgets, reason: reason);
  }

  /// Verify a widget exists exactly once
  void verifyExistsOnce(Finder finder, {String? reason}) {
    expect(finder, findsOneWidget, reason: reason);
  }

  /// Verify a widget does not exist
  void verifyNotExists(Finder finder, {String? reason}) {
    expect(finder, findsNothing, reason: reason);
  }

  /// Verify text is displayed
  void verifyTextDisplayed(String text, {String? reason}) {
    verifyExists(find.text(text), reason: reason ?? 'Text "$text" should be displayed');
  }

  /// Verify text is not displayed
  void verifyTextNotDisplayed(String text, {String? reason}) {
    verifyNotExists(find.text(text), reason: reason ?? 'Text "$text" should not be displayed');
  }

  /// Take a screenshot (for visual regression)
  /// Note: On real devices, requires convertFlutterSurfaceToImage() first
  Future<void> takeScreenshot(String name) async {
    try {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    } catch (e) {
      // Screenshot may fail on some platforms - log but don't fail test
      // ignore: avoid_print
      print('Screenshot "$name" skipped: $e');
    }
  }

  /// Wait for a specific duration
  Future<void> wait(Duration duration) async {
    await tester.pump(duration);
  }

  /// Long press on a widget
  Future<void> longPress(Finder finder) async {
    await tester.longPress(finder);
    await pumpAndSettle();
  }

  /// Drag from one position to another
  Future<void> drag(Finder finder, Offset offset) async {
    await tester.drag(finder, offset);
    await pumpAndSettle();
  }

  /// Swipe left on a widget (for dismissible actions)
  Future<void> swipeLeft(Finder finder) async {
    await drag(finder, const Offset(-300, 0));
  }

  /// Swipe right on a widget
  Future<void> swipeRight(Finder finder) async {
    await drag(finder, const Offset(300, 0));
  }
}

