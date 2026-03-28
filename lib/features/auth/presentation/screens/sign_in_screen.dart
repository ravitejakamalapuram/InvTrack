import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _floatController;
  late AnimationController _glowController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Main entrance animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    // Floating animation for logo
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // Glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      LoggerService.info('Starting Google Sign-In');

      // Ensure Google Sign-In is initialized before attempting auth
      await ref.read(googleSignInInitializedProvider.future);

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      LoggerService.info('Sign-in result', metadata: {'success': user != null});

      // Check if widget is still mounted after sign-in completes
      if (!mounted) return;

      if (user != null) {
        // Track successful sign-in in Analytics
        final analytics = ref.read(analyticsServiceProvider);
        await analytics.logSignIn(method: 'google');
        await analytics.setUserId(user.id);

        // Check mounted again before accessing crashlytics
        if (!mounted) return;

        // Set user identifier in Crashlytics for crash reports
        final crashlytics = ref.read(crashlyticsServiceProvider);
        await crashlytics.setUserIdentifier(user.id);

        // Request notification permissions on first sign-in
        if (!mounted) return;
        await _requestNotificationPermissionsIfNeeded();
      }
      // Firestore sync happens automatically via listeners - no manual sync needed
    } catch (e, st) {
      if (!mounted) return;

      // Use centralized error handler for proper error mapping and user feedback
      final appException = ErrorHandler.handle(
        e,
        st,
        context: context,
        showFeedback: true,
      );

      // Don't show error for cancelled sign-in (user action, not an error)
      if (appException is AuthException &&
          appException.userMessage == 'Sign in was cancelled.') {
        // User cancelled - no error feedback needed
        LoggerService.debug('User cancelled sign-in');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      LoggerService.info('Starting Anonymous Sign-In');

      final user = await ref.read(authRepositoryProvider).signInAnonymously();
      LoggerService.info(
        'Anonymous sign-in result',
        metadata: {'success': user != null},
      );

      // Check if widget is still mounted after sign-in completes
      if (!mounted) return;

      if (user != null) {
        // Track guest mode started in Analytics
        final analytics = ref.read(analyticsServiceProvider);
        await analytics.logEvent(
          name: 'guest_mode_started',
          parameters: {'method': 'anonymous'},
        );

        // Request notification permissions on first sign-in
        if (!mounted) return;
        await _requestNotificationPermissionsIfNeeded();
      }
      // Firestore sync happens automatically via listeners - no manual sync needed
    } catch (e, st) {
      if (!mounted) return;

      // Use centralized error handler for proper error mapping and user feedback
      ErrorHandler.handle(e, st, context: context, showFeedback: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Request notification permissions on first sign-in
  /// Only requests once per user to avoid annoying repeated prompts
  Future<void> _requestNotificationPermissionsIfNeeded() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final hasRequestedPermissions = prefs.getBool('notification_permissions_requested') ?? false;

      // Only request permissions once per install
      if (!hasRequestedPermissions) {
        LoggerService.info('Requesting notification permissions on first sign-in');

        final notificationService = ref.read(notificationServiceProvider);
        final granted = await notificationService.requestPermissions();

        LoggerService.info(
          'Notification permissions request result',
          metadata: {'granted': granted},
        );

        // Mark as requested to avoid repeated prompts
        await prefs.setBool('notification_permissions_requested', true);
      } else {
        LoggerService.debug('Notification permissions already requested');
      }
    } catch (e) {
      // Don't block sign-in flow if permission request fails
      LoggerService.warn('Error requesting notification permissions', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppColors.heroGradientDark
              : const LinearGradient(
                  colors: [Color(0xFFFAFAF9), Color(0xFFF5F5F4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingHorizontal,
            ),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Animated Logo Section with floating effect
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Floating App Icon with animated glow
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _floatAnimation,
                            _glowAnimation,
                          ]),
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatAnimation.value),
                              child: Container(
                                width: AppSizes.signInLogoSize,
                                height: AppSizes.signInLogoSize,
                                decoration: BoxDecoration(
                                  gradient: AppColors.heroGradient,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.signInLogoRadius,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryLight.withValues(
                                        alpha: _glowAnimation.value,
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Inner glow
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.white.withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Semantics(
                                      label: 'Investment tracking icon',
                                      child: const Icon(
                                        Icons.trending_up_rounded,
                                        size: 52,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.xxxl),

                        // App Name with gradient
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppColors.heroGradient.createShader(bounds),
                          child: Text(
                            'InvTracker',
                            style: AppTypography.displayLarge.copyWith(
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),

                        // Tagline with subtle animation
                        Text(
                          l10n.signInTagline,
                          style: AppTypography.bodyLarge.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.neutral600Light,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // Feature Pills
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _buildFeaturePill('📊', 'XIRR & MOIC', isDark),
                      _buildFeaturePill('🔒', 'Offline-first', isDark),
                      _buildFeaturePill('☁️', 'Cloud Sync', isDark),
                    ],
                  ),
                ),

                const Spacer(),

                // Buttons Section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Google Sign In Button
                        _buildGoogleButton(isDark),
                        SizedBox(height: AppSpacing.lg),

                        // OR Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : AppColors.neutral300Light,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              child: Text(
                                'OR',
                                style: AppTypography.small.copyWith(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : AppColors.neutral500Light,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.2)
                                    : AppColors.neutral300Light,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.lg),

                        // Continue as Guest Button
                        _buildGuestButton(isDark),
                        SizedBox(height: AppSpacing.xl),

                        // Terms text
                        Text(
                          l10n.signInTermsText,
                          style: AppTypography.small.copyWith(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppColors.neutral500Light,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(String emoji, String text, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : AppColors.primaryLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusXxl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.primaryLight.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: AppSizes.iconXs)),
          SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTypography.label.copyWith(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppColors.neutral700Light,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      enabled: !_isLoading,
      label: _isLoading ? l10n.signingIn : l10n.continueWithGoogle,
      excludeSemantics: true,
      onTap: _isLoading ? null : _signInWithGoogle,
      child: Container(
        width: double.infinity,
        height: AppSizes.buttonHeightXl + 4, // 60px for extra prominence
        decoration: BoxDecoration(
          gradient: isDark ? null : AppColors.heroGradient,
          color: isDark ? Colors.white : null,
          borderRadius: AppSizes.borderRadiusLg,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.white : AppColors.primaryLight)
                  .withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _signInWithGoogle,
            borderRadius: AppSizes.borderRadiusLg,
            child: Center(
              child: _isLoading
                  ? SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isDark ? AppColors.primaryLight : Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google "G" icon
                        Container(
                          width: AppSizes.iconLg,
                          height: AppSizes.iconLg,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.primaryLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusSm - 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'G',
                              style: AppTypography.buttonLarge.copyWith(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.primaryLight,
                                fontWeight: FontWeight.w800,
                                fontSize: AppSizes.iconXs,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm + 2),
                        Text(
                          l10n.continueWithGoogle,
                          style: AppTypography.buttonLarge.copyWith(
                            color: isDark
                                ? AppColors.neutral900Light
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestButton(bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      enabled: !_isLoading,
      label: l10n.continueAsGuest,
      hint: l10n.guestModeNotice,
      excludeSemantics: true,
      onTap: _isLoading ? null : _signInAnonymously,
      child: Container(
        width: double.infinity,
        height: AppSizes.buttonHeightXl,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.neutral100Light,
          borderRadius: AppSizes.borderRadiusLg,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : AppColors.neutral300Light,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _signInAnonymously,
            borderRadius: AppSizes.borderRadiusLg,
            child: Center(
              child: Text(
                l10n.continueAsGuest,
                style: AppTypography.buttonLarge.copyWith(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : AppColors.neutral700Light,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
