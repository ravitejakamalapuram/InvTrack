import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/portfolio/domain/entities/portfolio_entity.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

class AddInvestmentScreen extends ConsumerStatefulWidget {
  const AddInvestmentScreen({super.key});

  @override
  ConsumerState<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends ConsumerState<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  String? _selectedType = 'Stock';
  String? _selectedPortfolioId;

  final List<String> _investmentTypes = ['Stock', 'Crypto', 'Mutual Fund', 'ETF', 'Bond', 'Real Estate', 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedPortfolioId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a portfolio')),
        );
        return;
      }

      try {
        await ref.read(investmentProvider.notifier).addInvestment(
              name: _nameController.text,
              symbol: _symbolController.text.isEmpty ? null : _symbolController.text,
              type: _selectedType!,
              portfolioId: _selectedPortfolioId!,
            );
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final portfoliosAsync = ref.watch(allPortfoliosProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Investment', style: AppTypography.h3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Apple Inc.',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _symbolController,
                decoration: const InputDecoration(
                  labelText: 'Symbol (Optional)',
                  hintText: 'e.g. AAPL',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _investmentTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              portfoliosAsync.when(
                data: (portfolios) {
                  if (portfolios.isEmpty) {
                    return const Text('No portfolios found. Please create one first.');
                  }
                  // Auto-select first if none selected
                  if (_selectedPortfolioId == null && portfolios.isNotEmpty) {
                     // We don't set state here to avoid rebuild loops, usually handled better
                     // For now, let user select or handle in init
                  }
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedPortfolioId,
                    decoration: const InputDecoration(labelText: 'Portfolio'),
                    items: portfolios.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPortfolioId = value;
                      });
                    },
                    validator: (value) => value == null ? 'Required' : null,
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error loading portfolios: $err'),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Add Investment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
