#!/bin/bash

# Fix Analyzer Errors Script for InvTrack Notification PRs
# This script systematically fixes all 112 analyzer errors across notification report screens

set -e

echo "🔧 Starting Systematic Fixes for InvTrack PRs..."

# 1. Fix Provider Import Paths
echo "📦 Step 1: Fixing provider import paths..."

# Fix incorrect import paths in all notification screens
find lib/features/notifications/presentation/screens -name "*.dart" -exec sed -i '' \
  -e 's|package:inv_tracker/features/investment/presentation/providers/investments_provider.dart|package:inv_tracker/features/investment/presentation/providers/investment_providers.dart|g' \
  -e 's|package:inv_tracker/features/cashflow/presentation/providers/cashflows_provider.dart|package:inv_tracker/features/investment/presentation/providers/investment_providers.dart|g' \
  -e 's|package:inv_tracker/features/settings/presentation/providers/currency_settings_provider.dart|package:inv_tracker/features/settings/presentation/providers/settings_provider.dart|g' \
  -e 's|package:inv_tracker/features/investment/presentation/providers/investment_calculations_provider.dart|package:inv_tracker/features/investment/presentation/providers/multi_currency_providers.dart|g' \
  {} \;

# 2. Fix Provider Names
echo "🔄 Step 2: Fixing provider names..."

find lib/features/notifications/presentation/screens -name "*.dart" -exec sed -i '' \
  -e 's/investmentsStreamProvider/allInvestmentsProvider/g' \
  -e 's/cashFlowsStreamProvider/allCashFlowsStreamProvider/g' \
  {} \;

# 3. Fix AppColors API (neutral50Light -> neutral100Light, neutral200Light, etc.)
echo "🎨 Step 3: Fixing AppColors API..."

find lib/features/notifications lib/core/widgets lib/core/ads -name "*.dart" -exec sed -i '' \
  -e 's/AppColors\.neutral50Light/AppColors.neutral200Light/g' \
  -e 's/AppColors\.infoLight/AppColors.primaryLight/g' \
  {} \;

# 4. Fix AppTypography API (body1 -> bodyMedium, body2 -> caption)
echo "📝 Step 4: Fixing AppTypography API..."

find lib/features/notifications -name "*.dart" -exec sed -i '' \
  -e 's/AppTypography\.body1/AppTypography.bodyMedium/g' \
  -e 's/AppTypography\.body2/AppTypography.caption/g' \
  {} \;

# 5. Add missing GoRouter import
echo "🧭 Step 5: Adding GoRouter imports..."

for file in lib/core/notifications/notification_navigator.dart; do
  if [ -f "$file" ]; then
    # Check if import already exists
    if ! grep -q "package:go_router/go_router.dart" "$file"; then
      # Add import after the first import line
      sed -i '' "1a\\
import 'package:go_router/go_router.dart';\\
" "$file"
    fi
  fi
done

echo "✅ All automated fixes complete!"
echo "🔍 Next: Manual fixes required for complex issues..."
