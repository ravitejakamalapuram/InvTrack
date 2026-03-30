import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/premium/presentation/providers/premium_provider.dart';
import 'package:inv_tracker/features/premium/presentation/screens/paywall_screen.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class PremiumGate extends ConsumerWidget {
  final Widget child;
  final Widget? lockedChild;
  final VoidCallback? onTap;

  const PremiumGate({
    super.key,
    required this.child,
    this.lockedChild,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final l10n = AppLocalizations.of(context);

    if (isPremium) {
      return child;
    }

    return Semantics(
      button: true,
      label: l10n.premiumFeatureLockedSemanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PaywallScreen()),
              );
            },
        child: AbsorbPointer(
          child:
              lockedChild ??
              Stack(
                children: [
                  Opacity(opacity: 0.3, child: child),
                  const Positioned.fill(
                    child: Center(
                      child: Icon(Icons.lock, size: 32, color: Colors.grey),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
