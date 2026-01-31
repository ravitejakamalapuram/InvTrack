/// Enums for investment list filtering and sorting.
library;

import 'package:flutter/material.dart';

/// Filter state for investment list
enum InvestmentFilter { all, open, closed, archived }

/// Sort options for investment list
enum InvestmentSort {
  lastActivity('Last Activity', Icons.schedule),
  nameAsc('Name (A-Z)', Icons.sort_by_alpha),
  nameDesc('Name (Z-A)', Icons.sort_by_alpha),
  totalInvestedDesc('Total Invested (High)', Icons.payments),
  totalInvestedAsc('Total Invested (Low)', Icons.payments_outlined),
  totalReturnsDesc('Total Returns (High)', Icons.savings),
  totalReturnsAsc('Total Returns (Low)', Icons.savings_outlined),
  returnPercentDesc('Return % (High)', Icons.percent),
  returnPercentAsc('Return % (Low)', Icons.percent),
  xirrDesc('XIRR (High)', Icons.show_chart),
  xirrAsc('XIRR (Low)', Icons.show_chart),
  netPositionDesc('Net Position (High)', Icons.trending_up),
  netPositionAsc('Net Position (Low)', Icons.trending_down),
  createdDesc('Date Created (Newest)', Icons.calendar_today),
  createdAsc('Date Created (Oldest)', Icons.calendar_today),
  maturityDateAsc('Maturity Date (Soonest)', Icons.event_rounded);

  final String displayName;
  final IconData icon;
  const InvestmentSort(this.displayName, this.icon);

  /// Whether this sort option requires investment statistics (like values, returns, XIRR).
  /// Optimization: If false, we can skip watching stats providers in the list.
  bool get requiresStats {
    switch (this) {
      case InvestmentSort.nameAsc:
      case InvestmentSort.nameDesc:
      case InvestmentSort.createdDesc:
      case InvestmentSort.createdAsc:
      case InvestmentSort.maturityDateAsc:
        return false;
      default:
        return true;
    }
  }
}
