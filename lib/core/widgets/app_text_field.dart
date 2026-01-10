import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A styled text field widget following the app's design language.
/// Supports both single-line and multi-line input with optional prefix icon and label.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final String? prefixText;
  final String? Function(String?)? validator;
  final void Function(String)? onSubmitted;
  final void Function(String)? onChanged;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;

  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.prefixIcon,
    this.prefixText,
    this.validator,
    this.onSubmitted,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late TextEditingController _internalController;
  late bool _isInternalController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _internalController = widget.controller!;
      _isInternalController = false;
    } else {
      _internalController = TextEditingController();
      _isInternalController = true;
    }

    _internalController.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(AppTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      // Remove listener from the old controller instance
      if (oldWidget.controller != null) {
         oldWidget.controller!.removeListener(_handleTextChange);
      } else {
        // If it was internal, we should remove listener from the internal one we created
        // Note: _internalController is currently holding the "old" controller reference
        _internalController.removeListener(_handleTextChange);
      }

      if (widget.controller != null) {
        // Switching to new external controller
        if (_isInternalController) {
          // Dispose the old internal one
          _internalController.dispose();
        }
        _internalController = widget.controller!;
        _isInternalController = false;
      } else {
        // Switching to internal (from external)
        _internalController = TextEditingController();
        _isInternalController = true;
      }
      _internalController.addListener(_handleTextChange);
    }
  }

  void _handleTextChange() {
    // Rebuild to toggle clear button
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _internalController.removeListener(_handleTextChange);
    if (_isInternalController) {
      _internalController.dispose();
    }
    super.dispose();
  }

  void _clearText() {
    _internalController.clear();
    widget.onChanged?.call('');
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showClearButton =
        !widget.readOnly && widget.enabled && _internalController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: _internalController,
          focusNode: widget.focusNode,
          textCapitalization: widget.textCapitalization,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          style: AppTypography.body.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.neutral500Dark
                  : AppColors.neutral400Light,
            ),
            prefixText: widget.prefixText,
            prefixStyle: AppTypography.body.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          widget.maxLines > 1 ? (widget.maxLines - 1) * 20.0 : 0,
                    ),
                    child: Icon(
                      widget.prefixIcon,
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                    ),
                  )
                : null,
            suffixIcon: showClearButton
                ? Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          widget.maxLines > 1 ? (widget.maxLines - 1) * 20.0 : 0,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.cancel,
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral400Light,
                        size: 20,
                      ),
                      tooltip: 'Clear text',
                      onPressed: _clearText,
                    ),
                  )
                : null,
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.neutral700Dark
                    : AppColors.neutral200Light,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.errorLight),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.errorLight, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}
