import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/domain/entities/entry.dart';
import 'package:inv_tracker/presentation/providers/repository_providers.dart';

/// Modal form to add/edit an entry.
class EntryFormModal extends ConsumerStatefulWidget {
  final String investmentId;
  final Entry? existingEntry;

  const EntryFormModal({super.key, required this.investmentId, this.existingEntry});

  @override
  ConsumerState<EntryFormModal> createState() => _EntryFormModalState();
}

class _EntryFormModalState extends ConsumerState<EntryFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _unitsController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();
  EntryType _selectedType = EntryType.inflow;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  bool get isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final e = widget.existingEntry!;
      _selectedType = e.type;
      _selectedDate = e.date;
      _amountController.text = e.amount.toString();
      if (e.units != null) _unitsController.text = e.units.toString();
      if (e.pricePerUnit != null) _priceController.text = e.pricePerUnit.toString();
      _noteController.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _unitsController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(entryRepositoryProvider);
      if (repo == null) throw Exception('Database not ready');

      final amount = double.parse(_amountController.text);
      final units = _unitsController.text.isNotEmpty ? double.parse(_unitsController.text) : null;
      final price = _priceController.text.isNotEmpty ? double.parse(_priceController.text) : null;
      final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

      if (isEditing) {
        await repo.update(widget.existingEntry!.copyWith(
          type: _selectedType, date: _selectedDate, amount: amount, units: units, pricePerUnit: price, note: note,
        ));
      } else {
        await repo.create(Entry(
          id: '', investmentId: widget.investmentId, type: _selectedType, date: _selectedDate,
          amount: amount, units: units, pricePerUnit: price, note: note,
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: AppSpacing.screenPadding,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEditing ? 'Edit Entry' : 'Add Entry', style: Theme.of(context).textTheme.titleLarge),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                AppSpacing.gapVerticalLg,
                // Entry type selector
                Wrap(
                  spacing: AppSpacing.sm,
                  children: EntryType.values.map((type) => ChoiceChip(
                    label: Text(type.name.toUpperCase()),
                    selected: _selectedType == type,
                    onSelected: (selected) => setState(() => _selectedType = type),
                    selectedColor: _getTypeColor(type).withOpacity(0.2),
                  )).toList(),
                ),
                AppSpacing.gapVerticalLg,
                // Date picker
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (date != null) setState(() => _selectedDate = date);
                  },
                ),
                AppSpacing.gapVerticalMd,
                // Amount field
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Amount is required';
                    final amount = double.tryParse(v);
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                if (_selectedType == EntryType.inflow || _selectedType == EntryType.outflow) ...[
                  AppSpacing.gapVerticalMd,
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: _unitsController, decoration: const InputDecoration(labelText: 'Units (optional)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                      AppSpacing.gapHorizontalMd,
                      Expanded(child: TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Price/Unit', prefixText: '₹ '), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                    ],
                  ),
                ],
                AppSpacing.gapVerticalMd,
                TextFormField(controller: _noteController, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
                AppSpacing.gapVerticalXl,
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isEditing ? 'Update' : 'Save Entry'),
                ),
                AppSpacing.gapVerticalMd,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(EntryType type) {
    switch (type) {
      case EntryType.inflow: return AppColors.profit;
      case EntryType.outflow: return AppColors.loss;
      case EntryType.dividend: return AppColors.success;
      case EntryType.expense: return AppColors.warning;
      case EntryType.valuation: return AppColors.info;
    }
  }
}

/// Show entry form modal.
Future<bool?> showEntryFormModal(BuildContext context, String investmentId, {Entry? entry}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => EntryFormModal(investmentId: investmentId, existingEntry: entry),
  );
}

