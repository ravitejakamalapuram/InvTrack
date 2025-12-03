import 'package:flutter/material.dart';

/// App color palette.
class AppColors {
  AppColors._();

  // Primary Colors
  static const primary = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFF60AD5E);
  static const primaryDark = Color(0xFF005005);

  // Secondary Colors
  static const secondary = Color(0xFF1976D2);
  static const secondaryLight = Color(0xFF63A4FF);
  static const secondaryDark = Color(0xFF004BA0);

  // Semantic Colors
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFF9800);
  static const error = Color(0xFFF44336);
  static const info = Color(0xFF2196F3);

  // Finance Colors
  static const profit = Color(0xFF4CAF50);
  static const loss = Color(0xFFF44336);
  static const neutral = Color(0xFF9E9E9E);

  // Surface Colors (Light)
  static const surfaceLight = Color(0xFFFAFAFA);
  static const backgroundLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFFFFFFF);

  // Surface Colors (Dark)
  static const surfaceDark = Color(0xFF121212);
  static const backgroundDark = Color(0xFF1E1E1E);
  static const cardDark = Color(0xFF2C2C2C);

  // Text Colors (Light)
  static const textPrimaryLight = Color(0xFF212121);
  static const textSecondaryLight = Color(0xFF757575);
  static const textDisabledLight = Color(0xFFBDBDBD);

  // Text Colors (Dark)
  static const textPrimaryDark = Color(0xFFFFFFFF);
  static const textSecondaryDark = Color(0xFFB3B3B3);
  static const textDisabledDark = Color(0xFF757575);

  // Category Colors for investments
  static const Map<String, Color> categoryColors = {
    'mutualFund': Color(0xFF4CAF50),
    'stock': Color(0xFF2196F3),
    'fixedDeposit': Color(0xFFFF9800),
    'gold': Color(0xFFFFD700),
    'realEstate': Color(0xFF795548),
    'crypto': Color(0xFF9C27B0),
    'bond': Color(0xFF607D8B),
    'ppf': Color(0xFF00BCD4),
    'nps': Color(0xFFE91E63),
    'other': Color(0xFF9E9E9E),
  };

  /// Get color for a category.
  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? neutral;
  }
}

