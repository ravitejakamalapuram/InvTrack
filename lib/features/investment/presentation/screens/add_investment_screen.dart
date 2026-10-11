import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'; // Explicit import
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/calculations/investment_projector.dart';
import 'package:inv_tracker/core/config/app_constants.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/mixins/screen_animation_mixin.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/currency_selector.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/more_details_tile.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_form_config.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_template.dart';
import 'package:inv_tracker/features/investment/domain/models/investment_type_defaults.dart';
import 'package:inv_tracker/features/investment/presentation/utils/investment_amount_input.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_template_ui.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/amount_invested_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/custom_type_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/first_investment_form_view.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/start_date_field.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/template_selector.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:uuid/uuid.dart';

/// Combined screen for adding and editing investments.
/// Pass [investmentToEdit] to edit an existing investment, or leave null to add a new one.
/// Pass [preselectedTemplate] to pre-fill the form with a template (only for new investments).
class AddInvestmentScreen extends ConsumerStatefulWidget {
  final InvestmentEntity? investmentToEdit;
  final InvestmentTemplate? preselectedTemplate;

  const AddInvestmentScreen({
    super.key,
    this.investmentToEdit,
    this.preselectedTemplate,
  });

  bool get isEditing => investmentToEdit != null;

  @override
  ConsumerState<AddInvestmentScreen> createState() =>
      _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends ConsumerState<AddInvestmentScreen>
    with SingleTickerProviderStateMixin, SingleTickerScreenAnimationMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late TextEditingController _customTypeController;
  late TextEditingController _platformController;
  late TextEditingController _expectedRateController;
  late TextEditingController _tenureController;
  final _nameFocusNode = FocusNode();
  final _notesFocusNode = FocusNode();

  late InvestmentType _selectedType;
  DateTime? _maturityDate;
  IncomeFrequency? _incomeFrequency;
  bool _isLoading = false;

  // Template selection state (only for new investments)
  InvestmentTemplate? _selectedTemplate;
  bool _showTemplateSelector = true;

  // New enhanced data capture fields (non-controller based)
  DateTime? _startDate;
  InterestPayoutMode? _interestPayoutMode;
  bool? _autoRenewal;
  RiskLevel? _riskLevel;
  CompoundingFrequency? _compoundingFrequency;

  // Multi-currency support
  late String _selectedCurrency;

  // Smart defaults tracking
  bool _maturityDateAutoCalculated = false;

  /// The user cleared a maturity date that the start date and tenure would
  /// work out again, so the tenure was cleared with it (A119).
  bool _tenureClearedWithMaturity = false;

  // First investment flow (A40, #783). Only used when [_firstInvestmentForm].

  /// The form behind the first investment flow, decided once when the screen
  /// opens: a new investment, with the flag on.
  late final bool _firstInvestmentForm;

  /// The id of the investment this form saves. Minted when the form opens and
  /// kept for as long as it lives, so a retry after a failed save sends the
  /// same id and replaces the first attempt instead of adding a second one.
  final String _investmentId = const Uuid().v4();
  final _amountController = TextEditingController();
  final _amountFocusNode = FocusNode();
  bool _moreDetailsOpen = false;

  /// The user picked the start date; a default of today is not a field used.
  bool _startDatePicked = false;

  /// What the type chips have set so far, to tell a structural choice the user
  /// made in More details from one a chip set.
  InvestmentTypeDefaults _appliedDefaults = InvestmentTypeDefaults.none;

  /// The typical rate of the chosen type: the hint of the empty rate field,
  /// never a value that is saved.
  double? _typicalRateHint;

  /// Today, date-only, when the form opened.
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    // Initialize with existing data if editing
    final investment = widget.investmentToEdit;
    _nameController = TextEditingController(text: investment?.name ?? '');
    _notesController = TextEditingController(text: investment?.notes ?? '');
    _customTypeController = TextEditingController(
      text: investment?.customTypeLabel ?? '',
    );
    _selectedType = investment?.type ?? InvestmentType.p2pLending;
    _maturityDate = investment?.maturityDate;
    _incomeFrequency = investment?.incomeFrequency;

    // Initialize new field controllers
    _platformController = TextEditingController(
      text: investment?.platform ?? '',
    );
    _expectedRateController = TextEditingController(
      text: investment?.expectedRate != null
          ? investment!.expectedRate!.toString()
          : '',
    );
    _tenureController = TextEditingController(
      text: investment?.tenureMonths != null
          ? investment!.tenureMonths!.toString()
          : '',
    );

    // Add listeners for live projections and smart defaults
    _tenureController.addListener(_onTenureChanged);
    _expectedRateController.addListener(_onProjectionInputChanged);

    // Initialize new fields from existing investment if editing
    if (investment != null) {
      _startDate = investment.startDate;
      _interestPayoutMode = investment.interestPayoutMode;
      _autoRenewal = investment.autoRenewal;
      _riskLevel = investment.riskLevel;
      _compoundingFrequency = investment.compoundingFrequency;
      _selectedCurrency = investment.currency;
      // Hide template selector when editing
      _showTemplateSelector = false;
    } else {
      // Default to user's base currency for new investments
      _selectedCurrency = ref.read(currencyCodeProvider);
    }

    _firstInvestmentForm =
        investment == null && ref.read(firstInvestmentFormEnabledProvider);
    if (_firstInvestmentForm) {
      final now = ref.read(valuationClockProvider)();
      _today = DateTime(now.year, now.month, now.day);
      _startDate = _today;
      _typicalRateHint = InvestmentTypeDefaults.forType(
        _selectedType,
      ).typicalRate;
    }

    // Apply preselected template if provided (from empty state quick-add)
    if (widget.preselectedTemplate != null && investment == null) {
      // Defer template application to after first frame so setState works
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_firstInvestmentForm) {
          _applyStructuralDefaults(widget.preselectedTemplate!);
        } else {
          _applyTemplate(widget.preselectedTemplate!);
        }
      });
      // Hide template selector since user already chose a template
      _showTemplateSelector = false;
    }

    initScreenAnimation();
  }

  /// Called when tenure changes - auto-calculate maturity date
  void _onTenureChanged() {
    _updateAutoCalculatedMaturityDate();
    _onProjectionInputChanged();
  }

  /// Called when any projection input changes - trigger UI rebuild
  void _onProjectionInputChanged() {
    setState(() {});
  }

  /// Auto-calculate maturity date from start date + tenure
  void _updateAutoCalculatedMaturityDate() {
    final tenure = int.tryParse(_tenureController.text);
    final calculatedDate = InvestmentProjector.calculateMaturityDate(
      startDate: _startDate,
      tenureMonths: tenure,
    );

    if (calculatedDate != null) {
      // Only auto-update if user hasn't manually set a maturity date
      // or if the current maturity date was auto-calculated
      if (_maturityDate == null || _maturityDateAutoCalculated) {
        setState(() {
          _maturityDate = calculatedDate;
          _maturityDateAutoCalculated = true;
        });
      }
    }
  }

  /// Clears the maturity date. A start date and tenure would work it out
  /// again (InvestmentEntity.calculatedMaturityDate), and the health score
  /// and value estimate would keep using it, so the tenure is cleared too.
  void _clearMaturityDate() {
    final derivable =
        InvestmentProjector.calculateMaturityDate(
          startDate: _startDate,
          tenureMonths: int.tryParse(_tenureController.text.trim()),
        ) !=
        null;
    setState(() {
      _maturityDate = null;
      _maturityDateAutoCalculated = false;
      _tenureClearedWithMaturity = derivable;
    });
    if (derivable) _tenureController.clear();
  }

  /// Apply the template's type and structural defaults to the form
  void _applyTemplate(InvestmentTemplate template) {
    setState(() {
      _selectedTemplate = template;
      _selectedType = template.type;
      _incomeFrequency = template.defaultIncomeFrequency;
      _interestPayoutMode = template.defaultPayoutMode;
      _riskLevel = template.defaultRiskLevel;
      _compoundingFrequency = template.defaultCompoundingFrequency;

      // The rate and the tenure stay as the user left them (empty, unless they
      // typed): a number the user never typed would set a maturity date and
      // reminder and an estimated value (#994). The template's typical rate is
      // only the rate field's hint.

      // Pre-fill name with suggested prefix if name is empty
      if (_nameController.text.isEmpty &&
          template.suggestedNamePrefix != null &&
          template.suggestedNamePrefix!.isNotEmpty) {
        _nameController.text = template.suggestedNamePrefix!;
      }
    });

    // Track analytics
    ref
        .read(analyticsServiceProvider)
        .logTemplateSelected(
          templateId: template.id,
          templateName: template.name,
        );
  }

  /// A template on the first investment flow form sets the type and its
  /// structure and nothing else: no rate, no term, no name, no risk level, no
  /// income frequency. A number the user never typed would set a maturity
  /// date, a reminder and an estimated value for them, and an income frequency
  /// schedules income reminders for payouts they never mentioned.
  void _applyStructuralDefaults(InvestmentTemplate template) {
    final defaults = InvestmentTypeDefaults.forTemplate(template);
    setState(() {
      _selectedTemplate = template;
      _selectedType = template.type;
      _interestPayoutMode = defaults.payoutMode;
      _compoundingFrequency = defaults.compounding;
      _appliedDefaults = defaults;
      _typicalRateHint = defaults.typicalRate;
    });

    // Track analytics (the catalogue's id and name, nothing the user typed)
    ref
        .read(analyticsServiceProvider)
        .logTemplateSelected(
          templateId: template.id,
          templateName: template.name,
        );
  }

  /// A type chip sets the type and the structure that goes with it (never an
  /// income frequency). A value that is no longer what the last chip set is the
  /// user's choice and stays.
  void _onTypeChipSelected(InvestmentType type) {
    final next = InvestmentTypeDefaults.forType(type);
    setState(() {
      final applied = _appliedDefaults;
      _selectedType = type;
      if (_interestPayoutMode == applied.payoutMode) {
        _interestPayoutMode = next.payoutMode;
      }
      if (_compoundingFrequency == applied.compounding) {
        _compoundingFrequency = next.compounding;
      }
      _appliedDefaults = next;
      _typicalRateHint = next.typicalRate;
    });
  }

  @override
  void dispose() {
    // Remove listeners before disposing
    _tenureController.removeListener(_onTenureChanged);
    _expectedRateController.removeListener(_onProjectionInputChanged);

    _nameController.dispose();
    _notesController.dispose();
    _customTypeController.dispose();
    _platformController.dispose();
    _expectedRateController.dispose();
    _tenureController.dispose();
    _amountController.dispose();
    _amountFocusNode.dispose();
    _nameFocusNode.dispose();
    _notesFocusNode.dispose();
    disposeScreenAnimation();
    super.dispose();
  }

  Future<void> _selectMaturityDate(BuildContext context, bool isDark) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _maturityDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
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
    if (picked != null) {
      setState(() {
        _maturityDate = picked;
        _maturityDateAutoCalculated = false; // User manually set the date
      });
    }
  }

  /// The text to send as the investment's custom type (#936): what is typed
  /// in the field, null when it is blank or the type is not Other. While the
  /// feature is off the field is hidden, and an edit sends back the label the
  /// investment already has, so saving it never loses one.
  String? _customTypeForSave() {
    if (_selectedType != InvestmentType.other) return null;
    if (!ref.read(isCustomInvestmentTypesEnabledProvider)) {
      return widget.investmentToEdit?.customTypeLabel;
    }
    final typed = _customTypeController.text.trim();
    return typed.isEmpty ? null : typed;
  }

  /// Tracks which of the optional fields a new investment was saved with. Only
  /// flags go out, never what was typed.
  void _trackNewInvestment({
    required bool startDateUsed,
    required double? expectedRate,
    required int? tenureMonths,
    required String? platform,
  }) {
    final enhancedFields = <String>[];
    if (startDateUsed) enhancedFields.add('start_date');
    if (expectedRate != null) enhancedFields.add('expected_rate');
    if (tenureMonths != null) enhancedFields.add('tenure_months');
    if (platform != null) enhancedFields.add('platform');
    // What a type chip set is not a field the user used. (_appliedDefaults is
    // empty on the form of today, so nothing is left out there.)
    final applied = _appliedDefaults;
    if (_interestPayoutMode != null &&
        _interestPayoutMode != applied.payoutMode) {
      enhancedFields.add('payout_mode');
    }
    if (_autoRenewal != null) enhancedFields.add('auto_renewal');
    if (_riskLevel != null) enhancedFields.add('risk_level');
    if (_compoundingFrequency != null &&
        _compoundingFrequency != applied.compounding) {
      enhancedFields.add('compounding');
    }

    if (enhancedFields.isNotEmpty) {
      ref
          .read(analyticsServiceProvider)
          .logEnhancedFieldsUsed(
            investmentType: _selectedType.name,
            fieldsUsed: enhancedFields,
          );
    }

    // Track smart default usage
    if (_maturityDateAutoCalculated && _maturityDate != null) {
      ref
          .read(analyticsServiceProvider)
          .logSmartDefaultApplied(fieldName: 'maturity_date');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();

      // Parse values from controllers
      final platform = _platformController.text.trim().isEmpty
          ? null
          : _platformController.text.trim();
      final expectedRate = double.tryParse(_expectedRateController.text.trim());
      final tenureMonths = int.tryParse(_tenureController.text.trim());

      if (widget.isEditing) {
        await ref
            .read(investmentNotifierProvider.notifier)
            .updateInvestment(
              id: widget.investmentToEdit!.id,
              name: name,
              type: _selectedType,
              notes: notes,
              maturityDate: _maturityDate,
              incomeFrequency: _incomeFrequency,
              // New enhanced data capture fields
              startDate: _startDate,
              expectedRate: expectedRate,
              tenureMonths: tenureMonths,
              platform: platform,
              interestPayoutMode: _interestPayoutMode,
              autoRenewal: _autoRenewal,
              riskLevel: _riskLevel,
              compoundingFrequency: _compoundingFrequency,
              // Multi-currency
              currency: _selectedCurrency,
              customTypeLabel: _customTypeForSave(),
            );
      } else {
        await ref
            .read(investmentNotifierProvider.notifier)
            .addInvestment(
              name: name,
              type: _selectedType,
              notes: notes,
              maturityDate: _maturityDate,
              incomeFrequency: _incomeFrequency,
              // New enhanced data capture fields
              startDate: _startDate,
              expectedRate: expectedRate,
              tenureMonths: tenureMonths,
              platform: platform,
              interestPayoutMode: _interestPayoutMode,
              autoRenewal: _autoRenewal,
              riskLevel: _riskLevel,
              compoundingFrequency: _compoundingFrequency,
              // Multi-currency
              currency: _selectedCurrency,
              customTypeLabel: _customTypeForSave(),
            );

        _trackNewInvestment(
          startDateUsed: _startDate != null,
          expectedRate: expectedRate,
          tenureMonths: tenureMonths,
          platform: platform,
        );
      }

      if (mounted) {
        final message = widget.isEditing
            ? 'Investment updated successfully'
            : 'Investment created successfully';
        AppFeedback.showSuccess(context, message);
        context.pop(widget.isEditing ? true : null);
      }
    } catch (e) {
      if (mounted) {
        final message = widget.isEditing
            ? 'Failed to update investment'
            : 'Failed to create investment';
        AppFeedback.showError(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Saves the investment of the first investment flow form: with the amount
  /// typed, if any, as its first cash flow dated the start date, in one write.
  /// A failure keeps the form as it is. The retry sends the same id.
  Future<void> _submitFirstInvestment() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final amount = InvestmentAmountInput.parse(
      _amountController.text,
      currencyCode: _selectedCurrency,
    ).amount;

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final platform = _platformController.text.trim().isEmpty
        ? null
        : _platformController.text.trim();
    final expectedRate = double.tryParse(_expectedRateController.text.trim());
    final tenureMonths = int.tryParse(_tenureController.text.trim());

    // Only the write can fail the save.
    final InvestmentEntity investment;
    var confirmed = true;
    try {
      investment = await ref
          .read(investmentNotifierProvider.notifier)
          .addInvestment(
            name: _nameController.text.trim(),
            type: _selectedType,
            notes: notes,
            maturityDate: _maturityDate,
            incomeFrequency: _incomeFrequency,
            startDate: _startDate,
            expectedRate: expectedRate,
            tenureMonths: tenureMonths,
            platform: platform,
            interestPayoutMode: _interestPayoutMode,
            autoRenewal: _autoRenewal,
            riskLevel: _riskLevel,
            compoundingFrequency: _compoundingFrequency,
            currency: _selectedCurrency,
            customTypeLabel: _customTypeForSave(),
            id: _investmentId,
            initialAmount: amount,
            onWriteResult: (value) => confirmed = value,
          );
    } catch (e, st) {
      // The type and code of the failure only, never its message (CLAUDE.md
      // rule 7): this is the activation funnel, and a save that starts failing
      // should show up.
      ErrorHandler.logError(ErrorHandler.mapException(e, st));
      if (mounted) {
        AppFeedback.showError(context, l10n.investmentCreateFailed);
        setState(() => _isLoading = false);
      }
      return;
    }

    // The record exists from here: nothing below may say it was not saved. The
    // button stays busy until the form is gone, so a tap during the pop does
    // not send it again.
    try {
      _trackNewInvestment(
        startDateUsed: _startDatePicked,
        expectedRate: expectedRate,
        tenureMonths: tenureMonths,
        platform: platform,
      );
    } catch (_) {
      // Analytics never fail a saved investment.
    }

    if (!mounted) return;
    if (confirmed) {
      AppFeedback.showSuccess(context, l10n.investmentCreated);
    } else {
      AppFeedback.showInfo(context, l10n.investmentSavedOffline);
    }
    // The form gives way to the investment it made. This form was opened with
    // Navigator.push, which GoRouter does not know, so it is popped and the
    // detail pushed on the router: Back lands on the page that opened the
    // form, and the stack is no deeper than before.
    final router = GoRouter.of(context);
    context.safePop();
    router.push(
      '/investments/${Uri.encodeComponent(investment.id)}',
      extra: investment,
    );
  }

  /// The form behind the first investment flow (A40, #783): the same State and
  /// the same field builders as the form below, laid out by
  /// [FirstInvestmentFormView]. The type, name, amount and start date come
  /// first; the rest is behind More details.
  Widget _buildFirstInvestmentForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showCustomType =
        _selectedType == InvestmentType.other &&
        ref.watch(isCustomInvestmentTypesEnabledProvider);
    // The date also dates the first cash flow, which exists only with an amount.
    final startDateHelper = _amountController.text.trim().isEmpty
        ? null
        : (DateUtils.isSameDay(_startDate, _today)
              ? l10n.startDateHelperToday
              : l10n.startDateHelper);

    return FirstInvestmentFormView(
      formKey: _formKey,
      title: l10n.addInvestment,
      closeTooltip: l10n.tooltipClose,
      onClose: () => context.safePop(),
      typeLabel: l10n.investmentType,
      typeRow: TypeSelector<InvestmentType>(
        values: InvestmentType.values,
        selectedValue: _selectedType,
        onSelected: _onTypeChipSelected,
        colorBuilder: (type) => type.color,
        iconBuilder: (type) => type.icon,
        labelBuilder: (type) => type.displayName,
        compactMode: true,
        scrollingRow: true,
        rowPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingHorizontal,
        ),
        rowSemanticsLabel: l10n.investmentTypeRowSemantics(
          InvestmentType.values.length,
        ),
        itemKeyBuilder: AddInvestmentKeys.typeChip,
      ),
      customType: showCustomType
          ? CustomTypeField(controller: _customTypeController)
          : null,
      name: AppTextField(
        key: AddInvestmentKeys.name,
        controller: _nameController,
        focusNode: _nameFocusNode,
        label: l10n.investmentNameLabel,
        hint: l10n.investmentNameHint,
        showHintWhenEmpty: true,
        prefixIcon: Icons.business_rounded,
        // Limited here, not with maxLength, which prints a counter.
        inputFormatters: [
          LengthLimitingTextInputFormatter(ValidationConstants.maxNameLength),
        ],
        validator: (value) => value == null || value.trim().isEmpty
            ? l10n.investmentNameRequired
            : null,
        onSubmitted: (_) => _amountFocusNode.requestFocus(),
      ),
      amount: AmountInvestedField(
        controller: _amountController,
        currencyCode: _selectedCurrency,
        focusNode: _amountFocusNode,
        // The start date's helper depends on whether an amount is typed.
        onChanged: (_) => setState(() {}),
      ),
      startDate: StartDateField(
        date: _startDate!,
        helper: startDateHelper,
        onTap: () => _selectStartDate(context, isDark),
      ),
      moreDetails: MoreDetailsTile(
        key: AddInvestmentKeys.moreDetails,
        title: l10n.moreDetailsTitle,
        summary: l10n.moreDetailsSummary,
        expanded: _moreDetailsOpen,
        onChanged: (open) => setState(() => _moreDetailsOpen = open),
        children: [
          CurrencySelector(
            selectedCurrency: _selectedCurrency,
            onCurrencySelected: (code) {
              setState(() => _selectedCurrency = code);
              ref
                  .read(analyticsServiceProvider)
                  .logCurrencySelected(currency: code, context: 'investment');
            },
            label: l10n.investmentCurrencyLabel,
            subtitle: l10n.investmentCurrencySubtitle,
          ),
          SizedBox(height: AppSpacing.sectionSpacing),
          ..._buildDynamicFields(isDark, l10n, includeStartDate: false),
          _buildProjectionCard(isDark),
          _buildMaturityDatePicker(isDark),
          SizedBox(height: AppSpacing.formFieldSpacing),
          _buildIncomeFrequencySelector(isDark),
          SizedBox(height: AppSpacing.sectionSpacing),
          AppTextField(
            key: AddInvestmentKeys.notes,
            controller: _notesController,
            focusNode: _notesFocusNode,
            label: l10n.investmentNotesLabel,
            hint: l10n.investmentNotesHint,
            prefixIcon: Icons.edit_note_rounded,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            maxLength: ValidationConstants.maxNotesLength,
          ),
        ],
      ),
      submitLabel: l10n.addInvestment,
      isLoading: _isLoading,
      onSubmit: _submitFirstInvestment,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_firstInvestmentForm) return _buildFirstInvestmentForm(context);
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The flag is read only while Other is selected.
    final showCustomType =
        _selectedType == InvestmentType.other &&
        ref.watch(isCustomInvestmentTypesEnabledProvider);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.tooltipClose,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.05,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white : AppColors.neutral700Light,
            ),
          ),
          onPressed: () => context.safePop(),
        ),
        title: Text(
          widget.isEditing ? 'Edit Investment' : 'Add Investment',
          style: AppTypography.h3.copyWith(
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        centerTitle: true,
      ),
      body: buildAnimatedContent(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Template Selector - Only show for new investments
                if (_showTemplateSelector && !widget.isEditing) ...[
                  SizedBox(height: AppSpacing.md),
                  TemplateSelector(
                    selectedTemplate: _selectedTemplate,
                    onTemplateSelected: _applyTemplate,
                    showSkipOption: true,
                    onSkip: () {
                      setState(() => _showTemplateSelector = false);
                    },
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Divider(
                    color: isDark
                        ? AppColors.neutral700Dark
                        : AppColors.neutral200Light,
                    height: 1,
                  ),
                  SizedBox(height: AppSpacing.md),
                ],

                // Main form content with padding
                Padding(
                  padding: AppSpacing.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Investment Type Selector
                      TypeSelector<InvestmentType>(
                        label: 'Investment Type',
                        subtitle:
                            'Select the category that best describes this investment',
                        values: InvestmentType.values,
                        selectedValue: _selectedType,
                        onSelected: (type) =>
                            setState(() => _selectedType = type),
                        colorBuilder: (type) => type.color,
                        iconBuilder: (type) => type.icon,
                        labelBuilder: (type) => type.displayName,
                        gridLayout: true,
                        compactMode: true,
                        spacing: 10,
                        runSpacing: 10,
                        itemKeyBuilder: AddInvestmentKeys.typeChip,
                      ),

                      SizedBox(height: AppSpacing.sectionSpacing),

                      // Optional custom type, for type Other only (#936)
                      if (showCustomType) ...[
                        CustomTypeField(controller: _customTypeController),
                        SizedBox(height: AppSpacing.sectionSpacing),
                      ],

                      // Name Field
                      AppTextField(
                        key: AddInvestmentKeys.name,
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        label: 'Investment Name',
                        hint: 'e.g. LenDenClub, Grip Invest',
                        prefixIcon: Icons.business_rounded,
                        maxLength: ValidationConstants.maxNameLength,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        onSubmitted: (_) {
                          FocusScope.of(context).requestFocus(_notesFocusNode);
                        },
                      ),

                      SizedBox(height: AppSpacing.formFieldSpacing),

                      // Notes Field - reduced to 2 lines for more compact form
                      AppTextField(
                        key: AddInvestmentKeys.notes,
                        controller: _notesController,
                        focusNode: _notesFocusNode,
                        label: 'Notes (Optional)',
                        hint: 'Add any details about this investment',
                        prefixIcon: Icons.edit_note_rounded,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        maxLength: ValidationConstants.maxNotesLength,
                      ),

                      SizedBox(height: AppSpacing.sectionSpacing),

                      // Currency Selector
                      CurrencySelector(
                        selectedCurrency: _selectedCurrency,
                        onCurrencySelected: (code) {
                          setState(() => _selectedCurrency = code);
                          // Track currency selection
                          ref
                              .read(analyticsServiceProvider)
                              .logCurrencySelected(
                                currency: code,
                                context: 'investment',
                              );
                        },
                        label: 'Investment Currency',
                        subtitle: 'Primary currency for this investment',
                      ),

                      SizedBox(height: AppSpacing.sectionSpacing),

                      // Dynamic fields based on investment type
                      ..._buildDynamicFields(isDark, l10n),

                      // Live Projection Card (shows maturity estimate)
                      _buildProjectionCard(isDark),

                      // Maturity Date (Optional)
                      _buildMaturityDatePicker(isDark),

                      SizedBox(height: AppSpacing.formFieldSpacing),

                      // Income Frequency (Optional)
                      _buildIncomeFrequencySelector(isDark),

                      SizedBox(height: AppSpacing.xxl),

                      // Submit Button
                      GradientButton(
                        key: AddInvestmentKeys.submit,
                        onPressed: _submit,
                        isLoading: _isLoading,
                        icon: widget.isEditing
                            ? Icons.save_rounded
                            : Icons.add_rounded,
                        label: widget.isEditing
                            ? 'Save Changes'
                            : 'Add Investment',
                      ),

                      SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds dynamic form fields based on the selected investment type
  List<Widget> _buildDynamicFields(
    bool isDark,
    AppLocalizations l10n, {
    bool includeStartDate = true,
  }) {
    final config = InvestmentFormConfig.forType(_selectedType);
    final fields = <Widget>[];

    // Start Date (the first investment flow form has its own, above)
    if (config.showStartDate && includeStartDate) {
      fields.add(_buildStartDatePicker(isDark, l10n));
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    // Expected Rate
    if (config.showExpectedRate) {
      fields.add(
        _buildExpectedRateField(
          hint: _firstInvestmentForm ? _rateHint(l10n) : null,
        ),
      );
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    // Tenure
    if (config.showTenure) {
      fields.add(_buildTenureField());
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    // Platform
    if (config.showPlatform) {
      fields.add(_buildPlatformField());
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    // Interest Payout Mode
    if (config.showPayoutMode) {
      fields.add(_buildPayoutModeSelector(isDark));
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    // Compounding Frequency
    if (config.showCompoundingFrequency) {
      fields.add(_buildCompoundingSelector(isDark));
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    // Risk Level
    if (config.showRiskLevel) {
      fields.add(_buildRiskLevelSelector(isDark));
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    // Auto Renewal
    if (config.showAutoRenewal) {
      fields.add(_buildAutoRenewalSwitch(isDark));
      fields.add(SizedBox(height: AppSpacing.formFieldSpacing));
    }

    return fields;
  }

  /// The Recurring Deposit template was picked and the type is still Fixed
  /// Deposit: project monthly installments, not a lump sum.
  bool get _isRecurringDeposit =>
      _selectedTemplate?.id == InvestmentTemplates.recurringDeposit.id &&
      _selectedType == InvestmentType.fixedDeposit;

  /// Builds the live projection card showing estimated maturity value
  Widget _buildProjectionCard(bool isDark) {
    final config = InvestmentFormConfig.forType(_selectedType);
    final locale = ref.watch(currencyLocaleProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);

    // Only show projection if this investment type supports expected rate and tenure
    if (!config.showExpectedRate || !config.showTenure) {
      return const SizedBox.shrink();
    }

    final rate = double.tryParse(_expectedRateController.text.trim());
    final tenure = int.tryParse(_tenureController.text.trim());

    // Use a placeholder principal for the projection display
    // Since we don't have cashflows yet, use a standard amount for illustration
    const illustrativePrincipal = 100000.0; // 100K for illustration

    // Needs a rate and a tenure: months, or else the days from start to
    // maturity date (e.g. a 444-day FD).
    final projection = InvestmentProjector.getProjectionSummary(
      principal: illustrativePrincipal,
      annualRate: rate,
      tenureMonths: tenure,
      tenureDays: InvestmentProjector.tenureDaysBetween(
        _startDate,
        _maturityDate,
      ),
      compounding: _compoundingFrequency,
      type: _selectedType,
      recurring: _isRecurringDeposit,
    );

    if (projection == null) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.successLight.withValues(alpha: 0.1),
                        borderRadius: AppSizes.borderRadiusSm,
                      ),
                      child: Icon(
                        Icons.trending_up_rounded,
                        color: isDark
                            ? AppColors.successDark
                            : AppColors.successLight,
                        size: AppSizes.iconSm,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Estimated Returns',
                        style: AppTypography.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : AppColors.neutral900Light,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: AppSizes.borderRadiusSm,
                      ),
                      child: Text(
                        'Per ${formatCompactCurrency(illustrativePrincipal, symbol: currencySymbol, locale: locale)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),

                // Maturity Value
                _buildProjectionRow(
                  isDark: isDark,
                  label: 'Maturity Value',
                  value: formatCompactCurrency(
                    projection.maturityValue,
                    symbol: currencySymbol,
                    locale: locale,
                  ),
                  isHighlighted: true,
                ),
                SizedBox(height: AppSpacing.xs),

                // Interest Earned
                _buildProjectionRow(
                  isDark: isDark,
                  label: 'Interest Earned',
                  value:
                      '+${formatCompactCurrency(projection.interestEarned, symbol: currencySymbol, locale: locale)}',
                  valueColor: isDark
                      ? AppColors.successDark
                      : AppColors.successLight,
                ),

                // Show EAR vs Nominal if compounding makes a difference
                if (projection.hasCompoundingBenefit) ...[
                  SizedBox(height: AppSpacing.xs),
                  _buildProjectionRow(
                    isDark: isDark,
                    label: 'Effective Rate (EAR)',
                    value: '${projection.effectiveRate.toStringAsFixed(2)}%',
                    subtitle:
                        '${projection.nominalRate.toStringAsFixed(2)}% nominal → ${projection.effectiveRate.toStringAsFixed(2)}% effective',
                    valueColor: isDark
                        ? AppColors.accentDark
                        : AppColors.accentLight,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: AppSpacing.formFieldSpacing),
        ],
      ),
    );
  }

  /// Helper to build a row in the projection card
  Widget _buildProjectionRow({
    required bool isDark,
    required String label,
    required String value,
    String? subtitle,
    Color? valueColor,
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral600Light,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.neutral500Dark
                        : AppColors.neutral500Light,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: (isHighlighted ? AppTypography.h4 : AppTypography.bodyLarge)
              .copyWith(
                fontWeight: FontWeight.w600,
                color:
                    valueColor ??
                    (isDark ? Colors.white : AppColors.neutral900Light),
              ),
        ),
      ],
    );
  }

  Widget _buildStartDatePicker(bool isDark, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start Date (Optional)',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Builder(
          builder: (context) {
            final selectLabel = AppLocalizations.of(
              context,
            ).semanticSelectStartDate;
            final notSetValue = AppLocalizations.of(context).notSet;
            final clearLabel = AppLocalizations.of(
              context,
            ).tooltipClearStartDate;

            return Semantics(
              button: true,
              label: selectLabel,
              value: _startDate != null
                  ? AppDateUtils.formatLong(_startDate!)
                  : notSetValue,
              excludeSemantics: true,
              onTap: () => _selectStartDate(context, isDark),
              customSemanticsActions: _startDate != null
                  ? {
                      CustomSemanticsAction(label: clearLabel): () {
                        setState(() => _startDate = null);
                        // Also clear auto-calculated maturity if needed?
                        // For now, mirroring existing clear behavior.
                      },
                    }
                  : null,
              child: GlassCard(
                onTap: () => _selectStartDate(context, isDark),
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: AppSizes.borderRadiusMd,
                      ),
                      child: Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.primaryLight,
                        size: AppSizes.iconSm,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        _startDate != null
                            ? AppDateUtils.formatLong(_startDate!)
                            : l10n.hintWhenDidYouInvest,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _startDate != null
                              ? (isDark
                                    ? Colors.white
                                    : AppColors.neutral900Light)
                              : (isDark
                                    ? AppColors.neutral400Dark
                                    : AppColors.neutral500Light),
                        ),
                      ),
                    ),
                    if (_startDate != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral400Light,
                          size: 20,
                        ),
                        tooltip: l10n.tooltipClearStartDate,
                        onPressed: () => setState(() => _startDate = null),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral400Light,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _selectStartDate(BuildContext context, bool isDark) async {
    HapticFeedback.selectionClick();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? (_firstInvestmentForm ? _today : DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: _firstInvestmentForm ? _today : DateTime.now(),
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
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDatePicked = true;
      });
      // Auto-calculate maturity date with new start date
      _updateAutoCalculatedMaturityDate();
    }
  }

  /// The hint of the empty rate field on the first investment flow form: the
  /// typical rate of the type as an example ("e.g. 7"). Null when the type has
  /// none, which leaves the generic hint.
  String? _rateHint(AppLocalizations l10n) {
    final rate = _typicalRateHint;
    if (rate == null) return null;
    return l10n.hintExample(
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString(),
    );
  }

  /// The example in the rate field's hint on the classic form: the typical rate
  /// of the template picked, as long as the type is still the template's, else
  /// a generic one.
  String get _rateHintExample {
    final template = _selectedTemplate;
    return (template?.type == _selectedType
            ? template?.typicalRateText
            : null) ??
        '7.5';
  }

  Widget _buildExpectedRateField({String? hint}) {
    return AppTextField(
      controller: _expectedRateController,
      label: 'Expected Return Rate (% p.a.)',
      hint:
          hint ??
          AppLocalizations.of(context).hintExpectedRateExample(_rateHintExample),
      showHintWhenEmpty: _firstInvestmentForm,
      prefixIcon: Icons.percent_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
    );
  }

  Widget _buildTenureField() {
    return AppTextField(
      controller: _tenureController,
      label: 'Tenure (Months)',
      hint: 'e.g. 12',
      prefixIcon: Icons.schedule_rounded,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  Widget _buildPlatformField() {
    return AppTextField(
      controller: _platformController,
      label: 'Platform/Broker (Optional)',
      hint: 'e.g. Zerodha, HDFC Bank, Groww',
      prefixIcon: Icons.storefront_rounded,
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildPayoutModeSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interest Payout Mode (Optional)',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How is interest paid?',
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: InterestPayoutMode.values
              .map(
                (mode) => _buildEnumChip<InterestPayoutMode>(
                  value: mode,
                  isSelected: _interestPayoutMode == mode,
                  label: mode.displayName,
                  icon: mode.icon,
                  onTap: () => setState(() => _interestPayoutMode = mode),
                  isDark: isDark,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCompoundingSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compounding Frequency (Optional)',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How often is interest compounded?',
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CompoundingFrequency.values
              .map(
                (freq) => _buildEnumChip<CompoundingFrequency>(
                  value: freq,
                  isSelected: _compoundingFrequency == freq,
                  label: freq.displayName,
                  icon: Icons.autorenew_rounded,
                  onTap: () => setState(() => _compoundingFrequency = freq),
                  isDark: isDark,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRiskLevelSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Risk Level (Optional)',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How risky is this investment?',
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RiskLevel.values
              .map(
                (risk) => _buildEnumChip<RiskLevel>(
                  value: risk,
                  isSelected: _riskLevel == risk,
                  label: risk.displayName,
                  icon: risk.icon,
                  color: risk.color,
                  onTap: () => setState(() => _riskLevel = risk),
                  isDark: isDark,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAutoRenewalSwitch(bool isDark) {
    return GlassCard(
      padding: AppSpacing.cardPadding,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: AppSizes.borderRadiusMd,
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: AppColors.primaryLight,
              size: AppSizes.iconSm,
            ),
          ),
          SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Auto Renewal',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                Text(
                  'Automatically renews on maturity',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _autoRenewal ?? false,
            onChanged: (value) {
              HapticFeedback.selectionClick();
              setState(() => _autoRenewal = value);
            },
            activeTrackColor: AppColors.primaryLight.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }

  /// Generic enum chip builder for consistent styling
  Widget _buildEnumChip<T>({
    required T value,
    required bool isSelected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
  }) {
    final chipColor = color ?? AppColors.primaryLight;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            final backgroundColor = Color.lerp(
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              chipColor,
              progress,
            )!;
            final borderColor = Color.lerp(
              isDark ? AppColors.neutral700Dark : AppColors.neutral300Light,
              Colors.transparent,
              progress,
            )!;
            final iconBgColor = Color.lerp(
              chipColor.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.2),
              progress,
            )!;
            final iconColor = Color.lerp(chipColor, Colors.white, progress)!;
            final textColor = Color.lerp(
              isDark ? AppColors.neutral200Dark : AppColors.neutral700Light,
              Colors.white,
              progress,
            )!;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: progress > 0.1
                    ? [
                        BoxShadow(
                          color: chipColor.withValues(alpha: progress * 0.35),
                          blurRadius: 12 * progress,
                          offset: Offset(0, 4 * progress),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      color: textColor,
                      fontWeight: progress > 0.5
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMaturityDatePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Flexible: at large text the label wraps instead of running off
            // the end of the row.
            Flexible(
              child: Text(
                'Maturity Date (Optional)',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
            ),
            if (_maturityDateAutoCalculated && _maturityDate != null) ...[
              SizedBox(width: AppSpacing.xs),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withValues(alpha: 0.1),
                  borderRadius: AppSizes.borderRadiusSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: isDark
                          ? AppColors.accentDark
                          : AppColors.accentLight,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Auto',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.accentDark
                            : AppColors.accentLight,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: AppSpacing.xs),
        Builder(
          builder: (context) {
            final clearLabel = AppLocalizations.of(
              context,
            ).tooltipClearMaturityDate;
            final selectLabel = AppLocalizations.of(
              context,
            ).semanticSelectMaturityDate;
            final notSetValue = AppLocalizations.of(context).notSet;
            return Semantics(
              button: true,
              label: selectLabel,
              value: _maturityDate != null
                  ? AppDateUtils.formatLong(_maturityDate!)
                  : notSetValue,
              excludeSemantics: true,
              onTap: () => _selectMaturityDate(context, isDark),
              customSemanticsActions: _maturityDate != null
                  ? {
                      CustomSemanticsAction(label: clearLabel):
                          _clearMaturityDate,
                    }
                  : null,
              child: GlassCard(
                onTap: () => _selectMaturityDate(context, isDark),
                padding: AppSpacing.cardPadding,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: AppSizes.borderRadiusMd,
                      ),
                      child: Icon(
                        Icons.event_rounded,
                        color: AppColors.primaryLight,
                        size: AppSizes.iconSm,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Text(
                        _maturityDate != null
                            ? AppDateUtils.formatLong(_maturityDate!)
                            : AppLocalizations.of(
                                context,
                              ).hintNoMaturityDateSet,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                          color: _maturityDate != null
                              ? (isDark
                                    ? Colors.white
                                    : AppColors.neutral900Light)
                              : (isDark
                                    ? AppColors.neutral400Dark
                                    : AppColors.neutral500Light),
                        ),
                      ),
                    ),
                    if (_maturityDate != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral400Light,
                          size: 20,
                        ),
                        tooltip: AppLocalizations.of(
                          context,
                        ).tooltipClearMaturityDate,
                        onPressed: _clearMaturityDate,
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral400Light,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        // Shown while the tenure stays cleared, also after a new date is
        // picked, because the save then drops the tenure.
        if (_tenureClearedWithMaturity && _tenureController.text.isEmpty) ...[
          SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              AppLocalizations.of(context).noteTenureClearedWithMaturity,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIncomeFrequencySelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Income Frequency (Optional)',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How often does this investment pay income?',
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFrequencyChip(null, 'None', Icons.block_rounded, isDark),
            ...IncomeFrequency.values.map(
              (freq) => _buildFrequencyChip(
                freq,
                freq.displayName,
                freq.icon,
                isDark,
                color: freq.color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFrequencyChip(
    IncomeFrequency? frequency,
    String label,
    IconData icon,
    bool isDark, {
    Color? color,
  }) {
    final isSelected = _incomeFrequency == frequency;
    // theme-neutral: the selected fill, under a white label in both themes.
    final chipColor = color ?? AppColors.neutral500Light;
    // The idle icon sits on the page, not on the fill.
    final idleIconColor =
        color ??
        (isDark ? AppColors.neutral400Dark : AppColors.neutral500Light);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label income frequency',
      excludeSemantics: true,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _incomeFrequency = frequency);
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _incomeFrequency = frequency);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isSelected ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            final backgroundColor = Color.lerp(
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              chipColor,
              progress,
            )!;
            final borderColor = Color.lerp(
              isDark ? AppColors.neutral700Dark : AppColors.neutral300Light,
              Colors.transparent,
              progress,
            )!;
            final iconBgColor = Color.lerp(
              chipColor.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.2),
              progress,
            )!;
            final iconColor = Color.lerp(
              idleIconColor,
              Colors.white,
              progress,
            )!;
            final textColor = Color.lerp(
              isDark ? AppColors.neutral200Dark : AppColors.neutral700Light,
              Colors.white,
              progress,
            )!;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: progress > 0.1
                    ? [
                        BoxShadow(
                          color: chipColor.withValues(alpha: progress * 0.35),
                          blurRadius: 12 * progress,
                          offset: Offset(0, 4 * progress),
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.body.copyWith(
                      fontSize: 13,
                      color: textColor,
                      fontWeight: progress > 0.5
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
