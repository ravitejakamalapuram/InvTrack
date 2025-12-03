import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/domain/entities/investment.dart';
import 'package:inv_tracker/presentation/providers/repository_providers.dart';

/// Investment form screen for creating/editing investments.
class InvestmentFormScreen extends ConsumerStatefulWidget {
  final String? investmentId;

  const InvestmentFormScreen({super.key, this.investmentId});

  @override
  ConsumerState<InvestmentFormScreen> createState() => _InvestmentFormScreenState();
}

class _InvestmentFormScreenState extends ConsumerState<InvestmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = 'mutualFund';
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;
  Investment? _existingInvestment;

  static const _categories = [
    ('mutualFund', 'Mutual Fund'),
    ('stock', 'Stock'),
    ('fixedDeposit', 'Fixed Deposit'),
    ('gold', 'Gold'),
    ('realEstate', 'Real Estate'),
    ('crypto', 'Crypto'),
    ('bond', 'Bond'),
    ('ppf', 'PPF'),
    ('nps', 'NPS'),
    ('other', 'Other'),
  ];

  bool get isEditing => widget.investmentId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadInvestment();
  }

  Future<void> _loadInvestment() async {
    final repo = ref.read(investmentRepositoryProvider);
    if (repo == null) return;
    final inv = await repo.getById(widget.investmentId!);
    if (inv != null && mounted) {
      setState(() {
        _existingInvestment = inv;
        _nameController.text = inv.name;
        _notesController.text = inv.notes ?? '';
        _selectedCategory = inv.category;
        _startDate = inv.startDate;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(investmentRepositoryProvider);
      if (repo == null) throw Exception('Database not ready');

      if (isEditing && _existingInvestment != null) {
        await repo.update(_existingInvestment!.copyWith(
          name: _nameController.text.trim(),
          category: _selectedCategory,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          startDate: _startDate,
        ));
      } else {
        await repo.create(Investment(
          id: '',
          name: _nameController.text.trim(),
          category: _selectedCategory,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          startDate: _startDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }

      if (mounted) context.go(AppRoutes.investments);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Investment' : 'New Investment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Investment Name', hintText: 'e.g., HDFC Equity Fund'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            AppSpacing.gapVerticalLg,
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories.map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2))).toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            AppSpacing.gapVerticalLg,
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date'),
              subtitle: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                if (date != null) setState(() => _startDate = date);
              },
            ),
            AppSpacing.gapVerticalLg,
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Any additional notes...'),
              maxLines: 3,
            ),
            AppSpacing.gapVerticalXl,
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

