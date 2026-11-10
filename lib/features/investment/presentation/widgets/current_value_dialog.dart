import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';
import 'package:inv_tracker/features/investment/domain/entities/unit_holding.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/holding_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// What the user chose in [CurrentValueDialog]: a value as of a date, or
/// removing their value.
class CurrentValueEdit {
  final double? value;
  final DateTime? date;

  /// Set when the value was typed as weight x price (#946).
  final UnitHolding? holding;

  const CurrentValueEdit.set({
    required double this.value,
    required DateTime this.date,
    this.holding,
  });

  const CurrentValueEdit.remove() : value = null, date = null, holding = null;

  bool get isRemove => value == null;
}

/// Opens [CurrentValueDialog] for [investment] and saves the result.
/// [hasUserValue] offers to remove the user's value so the estimate applies.
/// [firstCashFlowDate] is the earliest date the value can be dated.
Future<void> showCurrentValueDialog(
  BuildContext context,
  WidgetRef ref, {
  required InvestmentEntity investment,
  required bool hasUserValue,
  DateTime? firstCashFlowDate,
}) async {
  final edit = await showDialog<CurrentValueEdit>(
    context: context,
    builder: (_) => CurrentValueDialog(
      currency: investment.currency,
      canRemove: hasUserValue,
      firstDate: firstCashFlowDate,
      // Weight is kept with dated valuations, so it is offered only then.
      allowWeight:
          investment.type == InvestmentType.gold &&
          ref.read(valuationSnapshotsActiveProvider),
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
        holding: edit.holding,
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

  /// Whether the value can also be typed as weight x price (#946).
  final bool allowWeight;

  /// Label of the remove button; the default says the estimate applies again.
  final String? removeLabel;

  /// What an edit starts from: the value, its date and its weight x price.
  /// All null for a new value.
  final double? initialValue;
  final DateTime? initialDate;
  final UnitHolding? initialHolding;

  /// Today; injectable for tests.
  final DateTime? today;

  /// The first cash flow's date: a value cannot be dated before it.
  final DateTime? firstDate;

  const CurrentValueDialog({
    super.key,
    required this.currency,
    required this.canRemove,
    this.allowWeight = false,
    this.removeLabel,
    this.initialValue,
    this.initialDate,
    this.initialHolding,
    this.today,
    this.firstDate,
  });

  @override
  State<CurrentValueDialog> createState() => _CurrentValueDialogState();
}

class _CurrentValueDialogState extends State<CurrentValueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  QuantityUnit _unit = QuantityUnit.gram;
  bool _byWeight = false;
  late final DateTime _today;
  late final DateTime _firstDate;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final now = widget.today ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    final first = widget.firstDate;
    final firstDay = first == null
        ? DateTime(1970)
        : DateTime(first.year, first.month, first.day);
    // A first cash flow in the future leaves only today to pick.
    _firstDate = firstDay.isAfter(_today) ? _today : firstDay;
    final initialDay = widget.initialDate;
    _date = initialDay == null
        ? _today
        : DateTime(initialDay.year, initialDay.month, initialDay.day);
    final holding = widget.initialHolding;
    if (holding != null && widget.allowWeight) {
      _byWeight = true;
      _quantity.text = _plain(holding.quantity);
      _price.text = _plain(holding.unitPrice);
      _unit = holding.unit;
    } else if (widget.initialValue != null) {
      _controller.text = _plain(widget.initialValue!);
    }
  }

  /// A number as typed: no trailing ".0", no exponent.
  static String _plain(double value) {
    final text = value.toStringAsFixed(10);
    return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _quantity.dispose();
    _price.dispose();
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
      firstDate: _firstDate,
      lastDate: _today,
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// The weight typed so far, or null while it is not a usable holding.
  UnitHolding? get _holding {
    final quantity = _parse(_quantity.text);
    final price = _parse(_price.text);
    if (quantity == null || price == null) return null;
    final holding = UnitHolding(
      quantity: quantity,
      unit: _unit,
      unitPrice: price,
    );
    return holding.isValid ? holding : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final holding = _byWeight ? _holding! : null;
    final value = holding?.value(widget.currency) ?? _parse(_controller.text)!;
    Navigator.of(
      context,
    ).pop(CurrentValueEdit.set(value: value, date: _date, holding: holding));
  }

  List<Widget> _weightFields(AppLocalizations l10n) {
    const decimalKeys = TextInputType.numberWithOptions(decimal: true);
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    final holding = _holding;
    // Echo of what was typed, so it follows the entry fields.
    final total = holding?.value(widget.currency);
    return [
      TextFormField(
        controller: _quantity,
        autofocus: true,
        keyboardType: decimalKeys,
        inputFormatters: digits,
        decoration: InputDecoration(labelText: l10n.weightQuantityLabel),
        onChanged: (_) => setState(() {}),
        // One message for both fields; it names both.
        validator: (_) => _holding == null ? l10n.weightInvalid : null,
      ),
      DropdownButtonFormField<QuantityUnit>(
        initialValue: _unit,
        decoration: InputDecoration(labelText: l10n.weightUnitLabel),
        items: [
          for (final unit in QuantityUnit.values)
            DropdownMenuItem(
              value: unit,
              child: Text(quantityUnitName(l10n, unit)),
            ),
        ],
        onChanged: (unit) => setState(() => _unit = unit ?? _unit),
      ),
      TextFormField(
        controller: _price,
        keyboardType: decimalKeys,
        inputFormatters: digits,
        decoration: InputDecoration(
          labelText: l10n.weightPriceLabel(
            quantityUnitName(l10n, _unit),
            widget.currency,
          ),
        ),
        onChanged: (_) => setState(() {}),
        onFieldSubmitted: (_) => _save(),
      ),
      if (total != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.weightTotalPreview(
              '${widget.currency} ${total.toStringAsFixed(MoneyPrecision.fractionDigitsFor(widget.currency))}',
            ),
          ),
        ),
    ];
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
            if (_byWeight)
              ..._weightFields(l10n)
            else
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
                validator: (text) {
                  final value = _parse(text);
                  if (value == null) return l10n.currentValueInvalid;
                  // 15 digits at most, also after rounding (rules 19.1). A
                  // record with no currency cannot be rounded; the notifier
                  // refuses its save with its own message.
                  final rounded = widget.currency.trim().isEmpty
                      ? value
                      : MoneyPrecision.round(
                          value,
                          currencyCode: widget.currency,
                        );
                  return rounded >= ValidationConstants.maxAmount
                      ? l10n.amountInvestedTooLarge
                      : null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            if (widget.allowWeight)
              TextButton(
                onPressed: () => setState(() => _byWeight = !_byWeight),
                child: Text(
                  _byWeight
                      ? l10n.currentValueByTotal
                      : l10n.currentValueByWeight,
                ),
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
            child: Text(widget.removeLabel ?? l10n.currentValueRemove),
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
