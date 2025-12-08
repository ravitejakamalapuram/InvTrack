import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_provider.dart';
import 'package:intl/intl.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String investmentId;

  const AddTransactionScreen({super.key, required this.investmentId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _feesController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'BUY';
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<TransactionTypeOption> _transactionTypes = [
    TransactionTypeOption('BUY', Icons.arrow_downward_rounded, AppColors.successLight, 'Purchase new units'),
    TransactionTypeOption('SELL', Icons.arrow_upward_rounded, AppColors.errorLight, 'Sell existing units'),
    TransactionTypeOption('DIVIDEND', Icons.payments_rounded, AppColors.graphAmber, 'Dividend received'),
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
    _quantityController.dispose();
    _priceController.dispose();
    _feesController.dispose();
    _notesController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDark) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryLight,
              onPrimary: Colors.white,
              surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              onSurface: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  double get _totalAmount {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final fees = double.tryParse(_feesController.text) ?? 0;
    return (quantity * price) + fees;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final quantity = double.parse(_quantityController.text);
      final price = double.parse(_priceController.text);
      final fees = _feesController.text.isNotEmpty ? double.parse(_feesController.text) : 0.0;

      await ref.read(investmentProvider.notifier).addTransaction(
        investmentId: widget.investmentId,
        type: _selectedType,
        date: _selectedDate,
        quantity: quantity,
        pricePerUnit: price,
        fees: fees,
        notes: _notesController.text.trim(),
      );

      HapticFeedback.mediumImpact();
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.errorLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

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
          'Add Transaction',
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
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Transaction Type Selector
                Text(
                  'Transaction Type',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                const SizedBox(height: 12),
                _buildTypeSelector(isDark),

                const SizedBox(height: 28),

                // Date Picker
                Text(
                  'Transaction Date',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _selectDate(context, isDark),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            color: AppColors.primaryLight,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE').format(_selectedDate),
                                style: AppTypography.small.copyWith(
                                  color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                                ),
                              ),
                              Text(
                                DateFormat('MMMM d, yyyy').format(_selectedDate),
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : AppColors.neutral900Light,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Amount Fields
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _quantityController,
                        label: 'Quantity',
                        hint: '0.00',
                        icon: Icons.numbers_rounded,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        controller: _priceController,
                        label: 'Price/Unit',
                        hint: '0.00',
                        icon: Icons.attach_money_rounded,
                        isDark: isDark,
                        prefix: '\$',
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Required';
                          if (double.tryParse(value) == null) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Fees Field
                _buildNumberField(
                  controller: _feesController,
                  label: 'Fees (Optional)',
                  hint: '0.00',
                  icon: Icons.receipt_long_rounded,
                  isDark: isDark,
                  prefix: '\$',
                ),

                const SizedBox(height: 20),

                // Notes Field
                Text(
                  'Notes (Optional)',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add any notes about this transaction...',
                    hintStyle: AppTypography.body.copyWith(
                      color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
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
                      borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 28),

                // Total Preview
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Amount',
                            style: AppTypography.body.copyWith(
                              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ListenableBuilder(
                            listenable: Listenable.merge([_quantityController, _priceController, _feesController]),
                            builder: (context, _) {
                              return Text(
                                currencyFormat.format(_totalAmount),
                                style: AppTypography.numberLarge.copyWith(
                                  color: isDark ? Colors.white : AppColors.neutral900Light,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: _selectedType == 'BUY'
                              ? AppColors.successGradient
                              : _selectedType == 'SELL'
                                  ? AppColors.dangerGradient
                                  : LinearGradient(colors: [AppColors.graphAmber, AppColors.graphAmber.withValues(alpha: 0.7)]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _selectedType == 'BUY'
                              ? Icons.arrow_downward_rounded
                              : _selectedType == 'SELL'
                                  ? Icons.arrow_upward_rounded
                                  : Icons.payments_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Submit Button
                _buildSubmitButton(isDark),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isDark) {
    return Row(
      children: _transactionTypes.map((type) {
        final isSelected = _selectedType == type.name;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: type.name == 'BUY' ? 0 : 6,
              right: type.name == 'DIVIDEND' ? 0 : 6,
            ),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type.name);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                child: Column(
                  children: [
                    Icon(
                      type.icon,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.neutral400Dark : AppColors.neutral600Light),
                      size: 24,
                    ),
                    const SizedBox(height: 8),
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
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? prefix,
    String? Function(String?)? validator,
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.body.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body.copyWith(
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
            ),
            prefixText: prefix,
            prefixStyle: AppTypography.body.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
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
              borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.errorLight),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: validator,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(bool isDark) {
    final typeOption = _transactionTypes.firstWhere((t) => t.name == _selectedType);

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : LinearGradient(
                colors: [typeOption.color, typeOption.color.withValues(alpha: 0.8)],
              ),
        color: _isLoading ? (isDark ? AppColors.neutral700Dark : AppColors.neutral300Light) : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? null
            : [
                BoxShadow(
                  color: typeOption.color.withValues(alpha: 0.4),
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
                  Icon(typeOption.icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Save ${typeOption.name} Transaction',
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

class TransactionTypeOption {
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  TransactionTypeOption(this.name, this.icon, this.color, this.description);
}
