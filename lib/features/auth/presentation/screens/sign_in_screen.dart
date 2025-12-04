import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo or App Name
              Center(
                child: Text(
                  'InvTracker',
                  style: AppTypography.display.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Your offline-first investment tracker',
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral600Light,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              // Sign In Button
              ElevatedButton(
                onPressed: () async {
                  try {
                    await ref.read(authRepositoryProvider).signInWithGoogle();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sign in failed: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whiteLight,
                  foregroundColor: AppColors.neutral900Light,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.neutral400Light),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Placeholder for Google Icon
                    const Icon(Icons.login, color: AppColors.primaryLight),
                    const SizedBox(width: 12),
                    Text(
                      'Sign in with Google',
                      style: AppTypography.h3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(authRepositoryProvider).signInAsGuest();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('Continue as Guest'),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
