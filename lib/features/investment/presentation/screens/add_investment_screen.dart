import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:inv_tracker/features/portfolio/presentation/providers/portfolio_provider.dart';

class AddInvestmentScreen extends ConsumerStatefulWidget {
  const AddInvestmentScreen({super.key});

  @override
  ConsumerState<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends ConsumerState<AddInvestmentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _symbolController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _symbolFocusNode = FocusNode();

  String _selectedType = 'Stock';
  String? _selectedPortfolioId;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<InvestmentTypeOption> _investmentTypes = [
    InvestmentTypeOption('Stock', Icons.trending_up_rounded, AppColors.graphBlue),
    InvestmentTypeOption('Crypto', Icons.currency_bitcoin_rounded, AppColors.graphPurple),
    InvestmentTypeOption('Mutual Fund', Icons.account_balance_rounded, AppColors.graphEmerald),
    InvestmentTypeOption('ETF', Icons.pie_chart_rounded, AppColors.graphCyan),
    InvestmentTypeOption('Bond', Icons.security_rounded, AppColors.graphAmber),
    InvestmentTypeOption('Real Estate', Icons.home_rounded, AppColors.graphPink),
    InvestmentTypeOption('Other', Icons.category_rounded, AppColors.graphOrange),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _symbolController.dispose();
    _nameFocusNode.dispose();
    _symbolFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPortfolioId == null) {
      final portfolios = ref.read(allPortfoliosProvider).valueOrNull;
      if (portfolios != null && portfolios.isNotEmpty) {
        _selectedPortfolioId = portfolios.first.id;
      } else {
        _showError('Please select a portfolio');
        return;
      }
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(investmentProvider.notifier).addInvestment(
        name: _nameController.text.trim(),
        symbol: _symbolController.text.trim().isEmpty ? null : _symbolController.text.trim().toUpperCase(),
        type: _selectedType,
        portfolioId: _selectedPortfolioId!,
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        context.pop();
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
    final portfoliosAsync = ref.watch(allPortfoliosProvider);
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
          'Add Investment',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Investment Type Selector
                  Text(
                    'Investment Type',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTypeSelector(isDark),

                  const SizedBox(height: 28),

                  // Name Field
                  _buildInputField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    label: 'Investment Name',
                    hint: 'e.g. Apple Inc.',
                    icon: Icons.label_outline_rounded,
                    isDark: isDark,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                    onSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_symbolFocusNode);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Symbol Field
                  _buildInputField(
                    controller: _symbolController,
                    focusNode: _symbolFocusNode,
                    label: 'Symbol (Optional)',
                    hint: 'e.g. AAPL',
                    icon: Icons.code_rounded,
                    isDark: isDark,
                    textCapitalization: TextCapitalization.characters,
                  ),

                  const SizedBox(height: 20),

                  // Portfolio Selector
                  portfoliosAsync.when(
                    data: (portfolios) {
                      if (portfolios.isEmpty) {
                        return _buildWarningCard(
                          'No portfolios found',
                          'Please create a portfolio first',
                          isDark,
                        );
                      }

                      if (_selectedPortfolioId == null && portfolios.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedPortfolioId == null) {
                            setState(() => _selectedPortfolioId = portfolios.first.id);
                          }
                        });
                      }

                      return _buildPortfolioSelector(portfolios, isDark);
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (err, _) => _buildWarningCard(
                      'Error loading portfolios',
                      err.toString(),
                      isDark,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Submit Button
                  _buildSubmitButton(isDark),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
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
              gradient: isSelected
                  ? LinearGradient(
                      colors: [type.color, type.color.withValues(alpha: 0.8)],
                    )
                  : null,
              color: isSelected ? null : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.transparent : (isDark ? AppColors.neutral700Dark : AppColors.neutral200Light),
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: type.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  type.icon,
                  size: 18,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.neutral400Dark : AppColors.neutral600Light),
                ),
                const SizedBox(width: 8),
                Text(
                  type.name,
                  style: AppTypography.body.copyWith(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.neutral300Dark : AppColors.neutral700Light),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: textCapitalization,
          style: AppTypography.body.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body.copyWith(
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
            ),
            prefixIcon: Icon(
              icon,
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
            ),
            filled: true,
            fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.primaryLight,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.errorLight),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: validator,
          onFieldSubmitted: onSubmitted,
        ),
      ],
    );
  }

  Widget _buildPortfolioSelector(List portfolios, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portfolio',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedPortfolioId,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.folder_outlined,
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            dropdownColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            items: portfolios.map<DropdownMenuItem<String>>((p) {
              return DropdownMenuItem(
                value: p.id,
                child: Text(
                  p.name,
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedPortfolioId = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard(String title, String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: AppColors.warningLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                Text(
                  message,
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isLoading ? null : AppColors.heroGradient,
        color: _isLoading ? (isDark ? AppColors.neutral700Dark : AppColors.neutral300Light) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.white : AppColors.neutral700Light,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Add Investment',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class InvestmentTypeOption {
  final String name;
  final IconData icon;
  final Color color;

  InvestmentTypeOption(this.name, this.icon, this.color);
}
