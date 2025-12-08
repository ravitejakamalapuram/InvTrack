import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';

class EditInvestmentScreen extends ConsumerStatefulWidget {
  final InvestmentEntity investment;
  
  const EditInvestmentScreen({super.key, required this.investment});

  @override
  ConsumerState<EditInvestmentScreen> createState() => _EditInvestmentScreenState();
}

class _EditInvestmentScreenState extends ConsumerState<EditInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _symbolController;
  late String _selectedType;
  bool _isLoading = false;

  final List<_InvestmentTypeOption> _investmentTypes = [
    _InvestmentTypeOption('Stock', Icons.trending_up_rounded, AppColors.graphBlue),
    _InvestmentTypeOption('Crypto', Icons.currency_bitcoin_rounded, AppColors.graphPurple),
    _InvestmentTypeOption('Mutual Fund', Icons.account_balance_rounded, AppColors.graphEmerald),
    _InvestmentTypeOption('ETF', Icons.pie_chart_rounded, AppColors.graphCyan),
    _InvestmentTypeOption('Bond', Icons.security_rounded, AppColors.graphAmber),
    _InvestmentTypeOption('Real Estate', Icons.home_rounded, AppColors.graphPink),
    _InvestmentTypeOption('Other', Icons.category_rounded, AppColors.graphOrange),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.investment.name);
    _symbolController = TextEditingController(text: widget.investment.symbol ?? '');
    _selectedType = widget.investment.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(investmentProvider.notifier).updateInvestment(
        id: widget.investment.id,
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim().isEmpty 
            ? null 
            : _symbolController.text.trim().toUpperCase(),
        type: _selectedType,
        portfolioId: widget.investment.portfolioId,
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        context.pop(true); // Return true to indicate success
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white : AppColors.neutral700Light,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Edit Investment',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildNameField(isDark),
          const SizedBox(height: 20),
          _buildSymbolField(isDark),
          const SizedBox(height: 24),
          _buildTypeSelector(isDark),
          const SizedBox(height: 32),
          _buildSubmitButton(isDark),
        ],
      ),
    );
  }

  Widget _buildNameField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Investment Name *', style: AppTypography.labelMedium.copyWith(
          color: isDark ? Colors.white70 : AppColors.neutral600Light,
        )),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: _inputDecoration(isDark, 'e.g., Apple Inc.'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
      ],
    );
  }

  Widget _buildSymbolField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Symbol (Optional)', style: AppTypography.labelMedium.copyWith(
          color: isDark ? Colors.white70 : AppColors.neutral600Light,
        )),
        const SizedBox(height: 8),
        TextFormField(
          controller: _symbolController,
          decoration: _inputDecoration(isDark, 'e.g., AAPL'),
          textCapitalization: TextCapitalization.characters,
        ),
      ],
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Investment Type', style: AppTypography.labelMedium.copyWith(
          color: isDark ? Colors.white70 : AppColors.neutral600Light,
        )),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _investmentTypes.map((type) {
            final isSelected = _selectedType == type.name;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type.name);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? type.color.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? type.color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.icon, size: 18, color: isSelected ? type.color : (isDark ? Colors.white54 : Colors.grey)),
                    const SizedBox(width: 8),
                    Text(
                      type.name,
                      style: AppTypography.small.copyWith(
                        color: isSelected ? type.color : (isDark ? Colors.white : AppColors.neutral700Light),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text('Save Changes', style: AppTypography.button.copyWith(color: Colors.white)),
      ),
    );
  }

  InputDecoration _inputDecoration(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.errorLight, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

class _InvestmentTypeOption {
  final String name;
  final IconData icon;
  final Color color;

  _InvestmentTypeOption(this.name, this.icon, this.color);
}
