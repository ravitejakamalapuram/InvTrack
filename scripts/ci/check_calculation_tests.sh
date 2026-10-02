#!/usr/bin/env bash
# Money-code test guard.
#
# Fails when a change touches Dart code that computes money figures without
# adding or changing at least one *_test.dart file. Guarded paths:
#   lib/core/calculations/   lib/features/goals/
#   lib/features/fire_number/   lib/features/reports/
# Generated files (*.g.dart, *.freezed.dart) are ignored.
#
# Input on stdin: `git diff --name-status <base> <head>` output.
# CI usage (pull requests, including bot PRs):
#   git diff --name-status BASE HEAD | bash scripts/ci/check_calculation_tests.sh
set -euo pipefail

guarded=()
test_changed=0

while IFS=$'\t' read -r status path1 path2 || [[ -n "${status:-}" ]]; do
  [[ -z "${status:-}" ]] && continue
  # Renames and copies (R100, C075) list the old path then the new path.
  path="${path2:-$path1}"

  if [[ "$status" != D* && "$path" =~ ^(test|integration_test)/.*_test\.dart$ ]]; then
    test_changed=1
  fi

  if [[ "$status" != D* && "$path" =~ ^lib/(core/calculations|features/(goals|fire_number|reports))/.*\.dart$ \
    && ! "$path" =~ \.(g|freezed)\.dart$ ]]; then
    guarded+=("$path")
  fi
done

if [[ ${#guarded[@]} -eq 0 ]]; then
  echo "No money-calculation code changed."
  exit 0
fi

if [[ $test_changed -eq 1 ]]; then
  echo "Money-calculation code changed and tests were added or updated:"
  printf '  %s\n' "${guarded[@]}"
  exit 0
fi

echo "::error::Money-calculation code changed without an added or updated *_test.dart file."
echo "Changed files that need test coverage:"
printf '  %s\n' "${guarded[@]}"
echo "Add or update a test that fails before this change and passes after it."
exit 1
