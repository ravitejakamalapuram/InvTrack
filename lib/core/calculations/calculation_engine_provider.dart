import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/modules/portfolio_health_module.dart';
import 'package:inv_tracker/core/calculations/modules/projection_module.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'calculation_engine_provider.g.dart';

/// Provider for the unified [CalculationEngine].
///
/// Automatically registers calculation modules and resolves active services.
@riverpod
CalculationEngine calculationEngine(Ref ref) {
  final conversionService = ref.watch(currencyConversionServiceProvider);
  final engine = CalculationEngine();

  // Register modules in the engine
  engine.registerModule(CurrencyConverterModule(conversionService));
  engine.registerModule(FinancialCalculatorModule());
  engine.registerModule(ProjectionCalculatorModule());
  engine.registerModule(PortfolioHealthModule());

  return engine;
}
