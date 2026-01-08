import 'package:flutter/material.dart';

/// A widget that overlays a privacy screen when the app goes into the background
/// or becomes inactive (e.g. app switcher, notification shade).
///
/// This protects sensitive data from being visible in the app switcher snapshot.
class PrivacyProtectionWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PrivacyProtectionWrapper({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<PrivacyProtectionWrapper> createState() => _PrivacyProtectionWrapperState();
}

class _PrivacyProtectionWrapperState extends State<PrivacyProtectionWrapper>
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
    final shouldObscure = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused;

    if (_shouldObscure != shouldObscure) {
      setState(() {
        _shouldObscure = shouldObscure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_shouldObscure)
          Positioned.fill(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/app_icon.png',
                    width: 100,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if asset is missing
                      return const Icon(
                        Icons.security,
                        size: 80,
                        color: Colors.grey,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'InvTracker',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
