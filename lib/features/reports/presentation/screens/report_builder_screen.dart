/// Report Builder Screen - DIY Custom Report Creation
///
/// Wizard-style interface for users to create custom reports
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_type.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_type_selector.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/date_range_selector.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/filter_selector.dart';

/// Report Builder Screen - Step-by-step report configuration
class ReportBuilderScreen extends ConsumerStatefulWidget {
  const ReportBuilderScreen({super.key});

  @override
  ConsumerState<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends ConsumerState<ReportBuilderScreen> {
  int _currentStep = 0;

  // Configuration state
  ReportType? _selectedReportType;
  DateRangePreset _dateRangePreset = DateRangePreset.thisMonth;
  String? _selectedInvestmentId;
  String? _selectedGoalId;
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createCustomReport),
        elevation: 0,
      ),
      body: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: theme.colorScheme.primary,
          ),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: _buildControls,
          steps: [
            Step(
              title: Text(l10n.selectReportType),
              content: ReportTypeSelector(
                selectedType: _selectedReportType,
                onTypeSelected: (type) {
                  setState(() => _selectedReportType = type);
                },
              ),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text(l10n.selectDateRange),
              content: DateRangeSelector(
                selectedPreset: _dateRangePreset,
                onPresetSelected: (preset) {
                  setState(() => _dateRangePreset = preset);
                },
              ),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: Text(l10n.selectFilters),
              content: FilterSelector(
                reportType: _selectedReportType,
                selectedInvestmentId: _selectedInvestmentId,
                selectedGoalId: _selectedGoalId,
                onInvestmentSelected: (id) {
                  setState(() => _selectedInvestmentId = id);
                },
                onGoalSelected: (id) {
                  setState(() => _selectedGoalId = id);
                },
              ),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            ),
          ],
        ),
      ),
    );
  }
  
  void _onStepContinue() {
    if (_currentStep < 2) {
      // Validate current step
      if (_currentStep == 0 && _selectedReportType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).pleaseSelectReportType)),
        );
        return;
      }
      
      setState(() => _currentStep++);
    } else {
      // Final step - generate report
      _generateReport();
    }
  }
  
  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }
  
  void _generateReport() {
    if (_selectedReportType == null) return;

    final config = ReportConfiguration(
      reportType: _selectedReportType!,
      dateRange: _dateRangePreset.toFilter(),
      investmentId: _selectedInvestmentId,
      goalId: _selectedGoalId,
    );

    // Navigate to dynamic report screen
    context.push('/reports/builder?${config.toQueryParams()}');
  }
  
  Widget _buildControls(BuildContext context, ControlsDetails details) {
    final l10n = AppLocalizations.of(context);
    final isLastStep = details.stepIndex == 2;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          FilledButton(
            onPressed: details.onStepContinue,
            child: Text(isLastStep ? l10n.generateReport : l10n.continueStep),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: details.onStepCancel,
            child: Text(l10n.back),
          ),
        ],
      ),
    );
  }
}
