#!/usr/bin/env bash
# Fails when the merged release AndroidManifest.xml (app + every library) holds
# the advertising ID permission or an AdMob application ID (A34, #778).
# Usage: bash scripts/ci/check_release_manifest.sh <merged AndroidManifest.xml>
set -euo pipefail

manifest="${1:?usage: check_release_manifest.sh <merged AndroidManifest.xml>}"
[[ -f "$manifest" ]] || { echo "manifest not found: $manifest" >&2; exit 2; }

status=0
if grep -q 'com.google.android.gms.permission.AD_ID' "$manifest"; then
  echo "FAIL: merged manifest declares the AD_ID permission"
  status=1
fi
if grep -q 'com.google.android.gms.ads.APPLICATION_ID' "$manifest"; then
  echo "FAIL: merged manifest holds an AdMob application ID"
  status=1
fi
[[ $status -eq 0 ]] && echo "OK: no AD_ID permission and no AdMob application ID in $manifest"
exit $status
