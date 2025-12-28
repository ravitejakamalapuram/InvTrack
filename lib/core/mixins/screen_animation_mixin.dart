import 'package:flutter/material.dart';

/// A mixin that provides common screen entry animations.
///
/// Features:
/// - Fade in animation
/// - Slide up animation
/// - Configurable duration and curve
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen>
///     with SingleTickerProviderStateMixin, ScreenAnimationMixin {
///   @override
///   void initState() {
///     super.initState();
///     initScreenAnimation(); // Call this after super.initState()
///   }
///
///   @override
///   void dispose() {
///     disposeScreenAnimation(); // Call this before super.dispose()
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return FadeTransition(
///       opacity: fadeAnimation,
///       child: SlideTransition(
///         position: slideAnimation,
///         child: ...
///       ),
///     );
///   }
/// }
/// ```
mixin ScreenAnimationMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  late AnimationController screenAnimationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  /// Initialize the screen entry animations.
  ///
  /// Call this in [initState] after [super.initState()].
  void initScreenAnimation({
    Duration duration = const Duration(milliseconds: 400),
    Curve fadeCurve = Curves.easeOut,
    Curve slideCurve = Curves.easeOutCubic,
    Offset slideBegin = const Offset(0, 0.1),
    bool autoForward = true,
  }) {
    screenAnimationController = AnimationController(
      duration: duration,
      vsync: this,
    );

    fadeAnimation = CurvedAnimation(
      parent: screenAnimationController,
      curve: fadeCurve,
    );

    slideAnimation = Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(
      CurvedAnimation(parent: screenAnimationController, curve: slideCurve),
    );

    if (autoForward) {
      screenAnimationController.forward();
    }
  }

  /// Dispose the animation controller.
  ///
  /// Call this in [dispose] before [super.dispose()].
  void disposeScreenAnimation() {
    screenAnimationController.dispose();
  }

  /// Build animated content with fade and slide transitions.
  Widget buildAnimatedContent({required Widget child}) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(position: slideAnimation, child: child),
    );
  }
}

/// A simpler mixin for screens using SingleTickerProviderStateMixin
mixin SingleTickerScreenAnimationMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late AnimationController screenAnimationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  /// Initialize the screen entry animations.
  void initScreenAnimation({
    Duration duration = const Duration(milliseconds: 400),
    Curve fadeCurve = Curves.easeOut,
    Curve slideCurve = Curves.easeOutCubic,
    Offset slideBegin = const Offset(0, 0.1),
    bool autoForward = true,
  }) {
    screenAnimationController = AnimationController(
      duration: duration,
      vsync: this,
    );

    fadeAnimation = CurvedAnimation(
      parent: screenAnimationController,
      curve: fadeCurve,
    );

    slideAnimation = Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(
      CurvedAnimation(parent: screenAnimationController, curve: slideCurve),
    );

    if (autoForward) {
      screenAnimationController.forward();
    }
  }

  /// Dispose the animation controller.
  void disposeScreenAnimation() {
    screenAnimationController.dispose();
  }

  /// Build animated content with fade and slide transitions.
  Widget buildAnimatedContent({required Widget child}) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(position: slideAnimation, child: child),
    );
  }
}
