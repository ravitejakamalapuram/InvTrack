import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

enum PasscodeMode { unlock, create, verify }

class PasscodeScreen extends ConsumerStatefulWidget {
  final PasscodeMode mode;
  final VoidCallback? onSuccess;

  const PasscodeScreen({
    super.key,
    this.mode = PasscodeMode.unlock,
    this.onSuccess,
  });

  @override
  ConsumerState<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends ConsumerState<PasscodeScreen>
    with WidgetsBindingObserver {
  String _input = '';
  String? _tempPin; // For create mode (first entry)
  String _message = 'Enter PIN';
  bool _isError = false;
  bool _autoAttemptedOnInit = false;
  bool _biometricInProgress = false;
  int _biometricAttemptCount = 0;
  DateTime? _lastBiometricAttempt;

  // Maximum biometric attempts before requiring PIN
  static const int _maxBiometricAttempts = 3;
  // Cooldown period between auto-retry attempts
  static const Duration _biometricCooldown = Duration(seconds: 2);
  static const platform = MethodChannel('com.invtracker/security');

  Future<void> _setSecureMode(bool secure) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await platform.invokeMethod('setSecureMode', {'secure': secure});
      }
    } catch (e) {
      LoggerService.warn('Failed to set secure mode', error: e);
    }
  }

  @override
  void initState() {
    super.initState();
    _setSecureMode(true);
    WidgetsBinding.instance.addObserver(this);
    _updateMessage();
    if (widget.mode == PasscodeMode.unlock) {
      // Try biometrics automatically if enabled (with small delay to ensure state is ready)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_autoAttemptedOnInit) {
            _autoAttemptedOnInit = true;
            _tryBiometrics(isAutoAttempt: true);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _setSecureMode(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from background, try biometrics again if we're on unlock screen
    // BUT only if we haven't exceeded max attempts and aren't in cooldown
    if (state == AppLifecycleState.resumed && widget.mode == PasscodeMode.unlock) {
      // Don't auto-retry if we've had too many failed attempts
      if (_biometricAttemptCount >= _maxBiometricAttempts) {
        LoggerService.debug(
          'Max biometric attempts reached, user must enter PIN or tap fingerprint',
          metadata: {'attemptCount': _biometricAttemptCount},
        );
        return;
      }

      // Check cooldown to prevent rapid retries
      if (_lastBiometricAttempt != null) {
        final elapsed = DateTime.now().difference(_lastBiometricAttempt!);
        if (elapsed < _biometricCooldown) {
          LoggerService.debug('Biometric cooldown active, skipping auto-retry');
          return;
        }
      }

      // Small delay to let the system settle after resume
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_biometricInProgress) {
          _tryBiometrics(isAutoAttempt: true);
        }
      });
    }
  }

  void _updateMessage() {
    setState(() {
      switch (widget.mode) {
        case PasscodeMode.create:
          _message = _tempPin == null ? 'Create your PIN' : 'Confirm PIN';
          break;
        case PasscodeMode.unlock:
          _message = 'Enter PIN to unlock';
          break;
        case PasscodeMode.verify:
          _message = 'Enter current PIN';
          break;
      }
    });
  }

  Future<void> _tryBiometrics({bool isAutoAttempt = false}) async {
    // Prevent multiple simultaneous biometric prompts
    if (_biometricInProgress) {
      LoggerService.debug('Biometric auth already in progress, skipping');
      return;
    }

    final securityState = ref.read(securityProvider);
    if (!securityState.isBiometricEnabled ||
        !securityState.isBiometricAvailable) {
      LoggerService.debug('Biometrics not enabled or not available');
      return;
    }

    // For auto-attempts, check if we've exceeded max attempts
    if (isAutoAttempt && _biometricAttemptCount >= _maxBiometricAttempts) {
      LoggerService.debug('Max biometric attempts reached for auto-retry', metadata: {
        'attemptCount': _biometricAttemptCount,
      });
      return;
    }

    _biometricInProgress = true;
    _lastBiometricAttempt = DateTime.now();

    try {
      LoggerService.debug('Starting biometric authentication', metadata: {
        'isAutoAttempt': isAutoAttempt,
        'attemptNumber': _biometricAttemptCount + 1,
      });

      final success = await ref
          .read(securityProvider.notifier)
          .unlockWithBiometrics();

      if (success && mounted) {
        LoggerService.info('Biometric authentication successful');
        // Reset attempt counter on success
        _biometricAttemptCount = 0;
        widget.onSuccess?.call();
      } else if (mounted) {
        LoggerService.debug('Biometric auth failed or cancelled');
        // Only increment counter for auto attempts to allow manual retries
        if (isAutoAttempt) {
          _biometricAttemptCount++;
        }
      }
    } catch (e) {
      // Biometric auth failed or was cancelled - user can retry or use PIN
      LoggerService.warn('Biometric auth exception', error: e);
      if (isAutoAttempt) {
        _biometricAttemptCount++;
      }
    } finally {
      _biometricInProgress = false;
    }
  }

  /// Manual biometric retry from fingerprint button - resets attempt counter
  void _onBiometricButtonPressed() {
    // Manual attempt - reset counter to allow user to try again
    _biometricAttemptCount = 0;
    _tryBiometrics(isAutoAttempt: false);
  }

  void _onKeyPress(String key) {
    if (_input.length < 4) {
      setState(() {
        _input += key;
        _isError = false;
      });
    }

    if (_input.length == 4) {
      _onSubmit();
    }
  }

  void _onDelete() {
    if (_input.isNotEmpty) {
      setState(() {
        _input = _input.substring(0, _input.length - 1);
        _isError = false;
      });
    }
  }

  void _onClear() {
    if (_input.isNotEmpty) {
      setState(() {
        _input = '';
        _isError = false;
      });
    }
  }

  Future<void> _onSubmit() async {
    final pin = _input;
    setState(() {
      _input = '';
    });

    switch (widget.mode) {
      case PasscodeMode.unlock:
        // Check for lockout first
        final lockoutRemaining = await ref
            .read(securityServiceProvider)
            .getLockoutRemainingSeconds();

        if (lockoutRemaining != null) {
          _showError('Locked out. Try again in ${lockoutRemaining}s');
          return;
        }

        final success = await ref
            .read(securityProvider.notifier)
            .unlockWithPin(pin);
        if (success) {
          widget.onSuccess?.call();
        } else {
          // Check if we are now locked out
           final newLockout = await ref
            .read(securityServiceProvider)
            .getLockoutRemainingSeconds();
          if (newLockout != null) {
             _showError('Locked out. Try again in ${newLockout}s');
          } else {
            _showError('Incorrect PIN');
          }
        }
        break;

      case PasscodeMode.create:
        if (_tempPin == null) {
          setState(() {
            _tempPin = pin;
            _updateMessage();
          });
        } else {
          if (pin == _tempPin) {
            await ref.read(securityProvider.notifier).setPin(pin);
            if (mounted) {
              context.safePop(); // Close screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App Lock enabled')),
              );
            }
          } else {
            _tempPin = null;
            _showError('PINs don\'t match');
            _updateMessage();
          }
        }
        break;

      case PasscodeMode.verify:
        // Used for changing settings etc.
        final success = await ref
            .read(securityProvider.notifier)
            .unlockWithPin(pin); // Re-use unlock logic for verification
        if (success) {
          widget.onSuccess?.call();
          if (mounted) context.safePop();
        } else {
          _showError('Incorrect PIN');
        }
        break;
    }
  }

  void _showError(String msg) {
    setState(() {
      _isError = true;
      _message = msg;
    });
    // Shake animation could go here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(
              Icons.lock_outline,
              size: 48,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 24),
            Text(
              _message,
              style: AppTypography.h3.copyWith(
                color: _isError ? Colors.red : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        index < _input.length
                            ? AppColors.primaryLight
                            : AppColors.neutral300Light,
                  ),
                );
              }),
            ),
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeyRow(['1', '2', '3']),
        _buildKeyRow(['4', '5', '6']),
        _buildKeyRow(['7', '8', '9']),
        _buildKeyRow(['biometric', '0', 'backspace']),
      ],
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key == 'biometric') {
            final securityState = ref.watch(securityProvider);
            final showBiometric =
                widget.mode == PasscodeMode.unlock &&
                securityState.isBiometricEnabled &&
                securityState.isBiometricAvailable;
            return SizedBox(
              width: 80,
              height: 80,
              child:
                  showBiometric
                      ? IconButton(
                        icon: Icon(
                          Icons.fingerprint,
                          size: 32,
                          color: AppColors.primaryLight,
                        ),
                        onPressed: _onBiometricButtonPressed,
                      )
                      : IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 28,
                          color:
                              _input.isNotEmpty
                                  ? AppColors.textPrimaryLight
                                  : AppColors.neutral300Light,
                        ),
                        onPressed: _input.isNotEmpty ? _onClear : null,
                      ),
            );
          }
          if (key == 'backspace') {
            return SizedBox(
              width: 80,
              height: 80,
              child: IconButton(
                icon: Icon(
                  Icons.backspace_outlined,
                  size: 28,
                  color:
                      _input.isNotEmpty
                          ? AppColors.textPrimaryLight
                          : AppColors.neutral300Light,
                ),
                onPressed: _input.isNotEmpty ? _onDelete : null,
              ),
            );
          }
          return SizedBox(
            width: 80,
            height: 80,
            child: TextButton(
              onPressed: () => _onKeyPress(key),
              style: TextButton.styleFrom(
                shape: const CircleBorder(),
                backgroundColor: AppColors.neutral100Light,
              ),
              child: Text(
                key,
                style: AppTypography.h2.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
