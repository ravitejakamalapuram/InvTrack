import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

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
                  'assets/icons/app_icon.png',
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
