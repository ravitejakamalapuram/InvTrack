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
  late bool _wasClearButtonVisible;

  // Focus node management to support clicking label to focus
  FocusNode? _internalFocusNode;
  bool _isInternalFocusNode = false;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

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

    if (widget.focusNode != null) {
      _isInternalFocusNode = false;
    } else {
      _internalFocusNode = FocusNode();
      _isInternalFocusNode = true;
    }

    _internalController.addListener(_handleTextChange);
    _wasClearButtonVisible = _shouldShowClearButton;
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

    // Handle FocusNode updates
    if (widget.focusNode != oldWidget.focusNode) {
      if (widget.focusNode != null) {
        // Switching to new external focus node
        if (_isInternalFocusNode) {
          _internalFocusNode?.dispose();
          _internalFocusNode = null;
        }
        _isInternalFocusNode = false;
      } else {
        // Switching to internal (from external)
        _internalFocusNode = FocusNode();
        _isInternalFocusNode = true;
      }
    }
  }

  bool get _shouldShowClearButton =>
      !widget.readOnly && widget.enabled && _internalController.text.isNotEmpty;

  void _handleTextChange() {
    // OPTIMIZATION: Only rebuild if the visibility of the clear button needs to change.
    // Previously, this called setState on every character change, causing
    // the entire widget (including InputDecoration and borders) to rebuild unnecessarily.
    final shouldShow = _shouldShowClearButton;
    if (_wasClearButtonVisible != shouldShow) {
      _wasClearButtonVisible = shouldShow;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _internalController.removeListener(_handleTextChange);
    if (_isInternalController) {
      _internalController.dispose();
    }
    if (_isInternalFocusNode) {
      _internalFocusNode?.dispose();
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

    // Sync state in case parent rebuilt us (e.g. readOnly changed)
    _wasClearButtonVisible = _shouldShowClearButton;
    final showClearButton = _wasClearButtonVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Semantics(
            button: true,
            label: 'Focus ${widget.label} field',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                // UX: Allow clicking the label to focus the text field
                if (widget.enabled && !widget.readOnly) {
                  _focusNode.requestFocus();
                }
              },
              child: Text(
                widget.label!,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: _internalController,
          focusNode: _focusNode,
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
            // Accessibility: Associate label with input but hide it visually
            // to preserve the design (since label is rendered outside).
            labelText: widget.label,
            floatingLabelBehavior: FloatingLabelBehavior.never,
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
                      bottom: widget.maxLines > 1
                          ? (widget.maxLines - 1) * 20.0
                          : 0,
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
                      bottom: widget.maxLines > 1
                          ? (widget.maxLines - 1) * 20.0
                          : 0,
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
