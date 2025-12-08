import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

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
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
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
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.dangerLight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInAsGuest();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.dangerLight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                          animation: Listenable.merge([_floatAnimation, _glowAnimation]),
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatAnimation.value),
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  gradient: AppColors.heroGradient,
                                  borderRadius: BorderRadius.circular(32),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryLight.withValues(alpha: _glowAnimation.value),
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
                                    const Icon(
                                      Icons.trending_up_rounded,
                                      size: 52,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 36),

                        // App Name with gradient
                        ShaderMask(
                          shaderCallback: (bounds) => AppColors.heroGradient.createShader(bounds),
                          child: Text(
                            'InvTracker',
                            style: AppTypography.displayLarge.copyWith(
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tagline with subtle animation
                        Text(
                          'Track investments. Grow wealth.',
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
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFeaturePill('📊', 'XIRR & CAGR', isDark),
                      _buildFeaturePill('🔒', 'Offline-first', isDark),
                      _buildFeaturePill('☁️', 'Google Sync', isDark),
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
                        const SizedBox(height: 16),

                        // Guest Button
                        _buildGuestButton(isDark),
                        const SizedBox(height: 24),

                        // Terms text
                        Text(
                          'By continuing, you agree to our Terms of Service\nand Privacy Policy',
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

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePill(String emoji, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : AppColors.primaryLight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.primaryLight.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
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
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: isDark ? null : AppColors.heroGradient,
        color: isDark ? Colors.white : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _signInWithGoogle,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
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
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primaryLight : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            'G',
                            style: AppTypography.buttonLarge.copyWith(
                              color: isDark ? Colors.white : AppColors.primaryLight,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Continue with Google',
                        style: AppTypography.buttonLarge.copyWith(
                          color: isDark ? AppColors.neutral900Light : Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.neutral100Light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.neutral300Light,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _signInAsGuest,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  color: isDark ? Colors.white : AppColors.neutral700Light,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue as Guest',
                  style: AppTypography.buttonLarge.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral700Light,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
