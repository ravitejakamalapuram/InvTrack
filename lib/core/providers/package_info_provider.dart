/// Provider for PackageInfo (app version, build number, etc.)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provider for PackageInfo (app version, build number, etc.)
///
/// This provider fetches app metadata from the platform and caches it.
/// Use this to display version information consistently across the app.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

