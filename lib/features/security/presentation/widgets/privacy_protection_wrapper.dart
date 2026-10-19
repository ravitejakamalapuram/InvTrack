import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

/// Turns Android's FLAG_SECURE on or off for the whole window. While it is on,
/// the recents thumbnail and screenshots are blank.
Future<void> setSecureWindow(bool secure) async {
  try {
    if (!kIsWeb && Platform.isAndroid) {
      await const MethodChannel(
        'com.invtracker/security',
      ).invokeMethod('setSecureMode', {'secure': secure});
    }
  } catch (e) {
    LoggerService.warn('Failed to set secure mode', error: e);
  }
}

/// A widget that overlays a privacy screen when the app goes into the background
/// or becomes inactive (e.g. app switcher, notification shade).
///
/// This protects sensitive data from being visible in the app switcher snapshot.
/// It also stays up after a resume until the auto-lock check has decided
/// ([autoLockCheckPendingProvider]), so the portfolio never shows before the
/// lock. Follows Android standard: solid brand color with centered app icon.
class PrivacyProtectionWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final bool enabled;

  const PrivacyProtectionWrapper({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  ConsumerState<PrivacyProtectionWrapper> createState() =>
      _PrivacyProtectionWrapperState();
}

class _PrivacyProtectionWrapperState
    extends ConsumerState<PrivacyProtectionWrapper>
    with WidgetsBindingObserver {
  bool _shouldObscure = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // FLAG_SECURE follows the app lock, so the recents thumbnail is blank
    // whenever a PIN is set, not only while the passcode screen is up.
    if (widget.enabled) {
      setSecureWindow(ref.read(securityProvider).hasPin);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;

    // inactive: App is transitioning (app switcher, control center, biometric auth)
    // paused: App is in background
    // detached: App is detached from engine
    final shouldObscure =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused;

    if (_shouldObscure != shouldObscure) {
      setState(() {
        _shouldObscure = shouldObscure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.listen(securityProvider.select((s) => s.hasPin), (_, hasPin) {
      if (widget.enabled) setSecureWindow(hasPin);
    });
    final lockPending =
        widget.enabled && ref.watch(autoLockCheckPendingProvider);

    return Stack(
      children: [
        widget.child,
        if (_shouldObscure || lockPending)
          Positioned.fill(
            child: ColoredBox(
              // Solid brand color - professional Android standard
              color: isDark ? AppColors.backgroundDark : AppColors.primaryLight,
              child: Center(
                child: Image.asset(
                  // Transparent mark, so the srcIn tint below draws the ring and
                  // not a square.
                  'assets/icons/app_icon_mark.png',
                  width: 72,
                  height: 72,
                  // Use white tint for light mode (icon on primary color)
                  color: isDark ? null : Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                  semanticLabel: 'App icon - privacy screen active',
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback icon matching app branding
                    return Icon(
                      Icons.shield_rounded,
                      size: 72,
                      color: isDark ? AppColors.primaryDark : Colors.white,
                      semanticLabel: 'Privacy screen active',
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
