import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/user_profile/presentation/providers/user_profile_provider.dart';

/// Widget that initializes user profile on first login
/// This widget should be placed high in the widget tree to ensure
/// profile is initialized before other features need it
class ProfileInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const ProfileInitializer({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ProfileInitializer> createState() => _ProfileInitializerState();
}

class _ProfileInitializerState extends ConsumerState<ProfileInitializer> {
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize profile after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfile();
    });
  }

  Future<void> _initializeProfile() async {
    if (_hasInitialized) return;

    final authState = ref.read(authStateProvider);
    final user = authState.value;

    if (user == null) return;

    // Initialize profile for new user
    await ref
        .read(userProfileNotifierProvider.notifier)
        .initializeProfileForNewUser(user.id);

    // Listen to profile changes and sync to settings
    ref.listen<AsyncValue<UserProfileEntity?>>(
      userProfileNotifierProvider,
      (previous, next) {
        next.whenData((profile) {
          if (profile != null) {
            // Sync profile to local settings
            final settingsNotifier = ref.read(settingsProvider.notifier);
            settingsNotifier.setCurrency(profile.preferredCurrency);
            settingsNotifier.setLocale(profile.preferredLocale);
            settingsNotifier.setDateFormatPattern(profile.dateFormatPattern);
          }
        });
      },
    );

    _hasInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    ref.listen<AsyncValue<UserEntity?>>(
      authStateProvider,
      (previous, next) {
        next.whenData((user) {
          if (user != null && !_hasInitialized) {
            _initializeProfile();
          }
        });
      },
    );

    return widget.child;
  }
}

