/// Core facade and registry for all calculation modules in the application.
library;

import 'package:inv_tracker/core/calculations/modules/currency_module.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/modules/portfolio_health_module.dart';
import 'package:inv_tracker/core/calculations/modules/projection_module.dart';

/// Base class for all modules registered in the calculation engine.
abstract class CalculationModule {
  String get name;
}

/// A unified, registry-based calculation engine that delegates calculations
/// to specialized calculation modules.
class CalculationEngine {
  final Map<Type, CalculationModule> _modules = {};

  /// Registers a calculation module into the engine.
  void registerModule<T extends CalculationModule>(T module) {
    _modules[T] = module;
  }

  /// Retrieves a registered calculation module.
  /// Throws a [StateError] if the module is not registered.
  T getModule<T extends CalculationModule>() {
    final module = _modules[T];
    if (module == null) {
      throw StateError('Calculation module $T is not registered in the engine.');
    }
    return module as T;
  }

  /// Getter for the Financial calculation module.
  FinancialCalculatorModule get financial => getModule<FinancialCalculatorModule>();

  /// Getter for the Projection calculation module.
  ProjectionCalculatorModule get projection => getModule<ProjectionCalculatorModule>();

  /// Getter for the Currency conversion module.
  CurrencyConverterModule get currency => getModule<CurrencyConverterModule>();

  /// Getter for the Portfolio Health score module.
  PortfolioHealthModule get health => getModule<PortfolioHealthModule>();
}
