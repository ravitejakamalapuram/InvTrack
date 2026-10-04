import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// What the user chose in [CurrentValueDialog]: a value as of a date, or
/// removing their value.
class CurrentValueEdit {
  final double? value;
  final DateTime? date;

  const CurrentValueEdit.set({
    required double this.value,
    required DateTime this.date,
  });

  const CurrentValueEdit.remove() : value = null, date = null;

  bool get isRemove => value == null;
}

/// Opens [CurrentValueDialog] for [investment] and saves the result.
/// [hasUserValue] offers to remove the user's value so the estimate applies.
Future<void> showCurrentValueDialog(
  BuildContext context,
  WidgetRef ref, {
  required InvestmentEntity investment,
  required bool hasUserValue,
}) async {
  final edit = await showDialog<CurrentValueEdit>(
    context: context,
    builder: (_) => CurrentValueDialog(
      currency: investment.currency,
      canRemove: hasUserValue,
    ),
  );
  if (edit == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).currentValueSaveFailed;
  final notifier = ref.read(investmentNotifierProvider.notifier);
  try {
    if (edit.isRemove) {
      await notifier.clearCurrentValue(investment.id);
    } else {
      await notifier.setCurrentValue(
        id: investment.id,
        value: edit.value!,
        date: edit.date!,
      );
    }
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }
}

/// Editor for an open investment's current value, in its own currency.
class CurrentValueDialog extends StatefulWidget {
  final String currency;
  final bool canRemove;

  /// Today; injectable for tests.
  final DateTime? today;

  const CurrentValueDialog({
    super.key,
    required this.currency,
    required this.canRemove,
    this.today,
  });

  @override
  State<CurrentValueDialog> createState() => _CurrentValueDialogState();
}

class _CurrentValueDialogState extends State<CurrentValueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  late final DateTime _today;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _date = _today;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Digits with an optional '.' fraction. A comma is accepted only as a
  /// thousands (1,234,567) or lakh (12,34,567) separator, so a decimal
  /// comma ('1234,56') is rejected rather than read as 123456.
  static final _amountPattern = RegExp(
    r'^(\d*|\d{1,3}(,\d{3})+|\d{1,2}(,\d{2})*,\d{3})(\.\d*)?$',
  );

  double? _parse(String? text) {
    final trimmed = (text ?? '').trim();
    if (!_amountPattern.hasMatch(trimmed)) return null;
    final value = double.tryParse(trimmed.replaceAll(',', ''));
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: _today,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(
      context,
    ).pop(CurrentValueEdit.set(value: _parse(_controller.text)!, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.currentValueLabel),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.currentValueAmountLabel(widget.currency),
              ),
              validator: (text) =>
                  _parse(text) == null ? l10n.currentValueInvalid : null,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(
                l10n.currentValueDateLabel(AppDateUtils.formatShort(_date)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.canRemove)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const CurrentValueEdit.remove()),
            child: Text(l10n.currentValueRemove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}
