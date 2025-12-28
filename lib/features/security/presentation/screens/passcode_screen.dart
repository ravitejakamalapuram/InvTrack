import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _PasscodeScreenState extends ConsumerState<PasscodeScreen> {
  String _input = '';
  String? _tempPin; // For create mode (first entry)
  String _message = 'Enter PIN';
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _updateMessage();
    if (widget.mode == PasscodeMode.unlock) {
      // Try biometrics automatically if enabled
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryBiometrics();
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

  Future<void> _tryBiometrics() async {
    final securityState = ref.read(securityProvider);
    if (securityState.isBiometricEnabled) {
      final success = await ref
          .read(securityProvider.notifier)
          .unlockWithBiometrics();
      if (success && mounted) {
        widget.onSuccess?.call();
      }
    }
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

  Future<void> _onSubmit() async {
    final pin = _input;
    setState(() {
      _input = '';
    });

    switch (widget.mode) {
      case PasscodeMode.unlock:
        final success = await ref
            .read(securityProvider.notifier)
            .unlockWithPin(pin);
        if (success) {
          widget.onSuccess?.call();
        } else {
          _showError('Incorrect PIN');
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
              context.pop(); // Close screen
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('App Lock enabled')));
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
          if (mounted) context.pop();
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
                    color: index < _input.length
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
            final showBiometric =
                widget.mode == PasscodeMode.unlock &&
                ref.watch(securityProvider).isBiometricEnabled;
            return SizedBox(
              width: 80,
              height: 80,
              child: showBiometric
                  ? IconButton(
                      icon: const Icon(Icons.fingerprint, size: 32),
                      onPressed: _tryBiometrics,
                    )
                  : const SizedBox(),
            );
          }
          if (key == 'backspace') {
            return SizedBox(
              width: 80,
              height: 80,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined, size: 28),
                onPressed: _onDelete,
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
