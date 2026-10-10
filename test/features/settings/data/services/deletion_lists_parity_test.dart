import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';

/// Account deletion has three paths: the in-app wipe
/// ([AccountDataDeletionService.userCollections]), the server job in
/// scripts/account-deletion (recursiveDelete, which needs no list), and the
/// Cloud Function that purges abandoned guest accounts, which hard-codes its
/// own list. The coverage test scans lib/ only, so without this one a new
/// collection could survive in a guest account the function cleans up.
void main() {
  test('the guest-account cleanup function deletes the same collections', () {
    final source = File(
      'functions/src/cleanupAnonymousUsers.ts',
    ).readAsStringSync();
    final list = RegExp(
      r'const collections = \[(.*?)\];',
      dotAll: true,
    ).firstMatch(source);
    expect(list, isNotNull, reason: 'the collections list was not found');

    final inFunction = {
      for (final m in RegExp(r"'([A-Za-z0-9_]+)'").allMatches(list!.group(1)!))
        m.group(1)!,
    };
    expect(
      inFunction,
      AccountDataDeletionService.userCollections.toSet(),
      reason:
          'functions/src/cleanupAnonymousUsers.ts and '
          'AccountDataDeletionService.userCollections must list the same '
          'collections',
    );
  });
}
