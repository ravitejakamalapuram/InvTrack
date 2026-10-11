import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/form_helper_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// The start date field of the add investment form (A40, #783): a read-only
/// field that opens the caller's date picker when tapped, with an optional
/// [helper] line under it.
///
/// A screen reader meets one button: "Select Start Date", the long date and
/// the helper as its value. A hardware keyboard reaches the field with Tab,
/// sees its focus border, and opens the picker with Enter or Space.
class StartDateField extends StatefulWidget {
  const StartDateField({
    super.key,
    required this.date,
    this.helper,
    required this.onTap,
  });

  final DateTime date;

  /// The line under the field, for example that the date also dates the first
  /// cash flow. None when null.
  final String? helper;

  /// Opens the date picker.
  final VoidCallback onTap;

  @override
  State<StartDateField> createState() => _StartDateFieldState();
}

class _StartDateFieldState extends State<StartDateField> {
  late TextEditingController _controller = _controllerFor(widget.date);
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKey);

  static TextEditingController _controllerFor(DateTime date) =>
      TextEditingController(text: AppDateUtils.formatShort(date));

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // A key held down repeats as another kind of event, which is not a second
    // request for the picker.
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter &&
        key != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    widget.onTap();
    return KeyEventResult.handled;
  }

  @override
  void didUpdateWidget(StartDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      // Not _controller.text = ...: that would notify the field's listeners
      // while the tree is building. A new date gets a new controller, and the
      // field below is keyed by the date, so it starts over with it. The old
      // controller goes once the old field has let go of it.
      final old = _controller;
      _controller = _controllerFor(widget.date);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final helper = widget.helper;
    final spoken = AppDateUtils.formatLong(widget.date);

    return Semantics(
      button: true,
      label: l10n.semanticSelectStartDate,
      value: helper == null ? spoken : '$spoken. $helper',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: IgnorePointer(
              child: AppTextField(
                key: ValueKey(widget.date),
                controller: _controller,
                focusNode: _focusNode,
                label: l10n.startDateFieldLabel,
                prefixIcon: Icons.calendar_today_rounded,
                readOnly: true,
              ),
            ),
          ),
          if (helper != null) FormHelperText(helper),
        ],
      ),
    );
  }
}
