import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';

/// Guard for account deletion: the client cannot list Firestore subcollections,
/// so [AccountDataDeletionService.userCollections] is the ONLY thing that decides
/// what gets deleted. Any `users/{uid}/<name>` collection the app writes to that is
/// missing from that list would survive an account deletion forever (security rules
/// block every cleanup once the Auth account is gone). This test fails the moment
/// someone references a new collection without adding it to the list.
void main() {
  test('every Firestore collection referenced in lib/ is deleted on account deletion', () {
    final referenced = <String>{};
    final pattern = RegExp(r"\.collection\(\s*'([A-Za-z0-9_]+)'\s*\)");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/generated/')) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        referenced.add(m.group(1)!);
      }
    }
    // 'users' is the parent collection; its document is deleted explicitly.
    referenced.remove('users');

    final missing = referenced.difference(
      AccountDataDeletionService.userCollections.toSet(),
    );
    expect(
      missing,
      isEmpty,
      reason:
          'These collections are used by the app but not deleted by '
          'AccountDataDeletionService.userCollections: $missing. Add them (and a '
          'test), or explain why they hold no user data.',
    );
    expect(referenced, isNotEmpty, reason: 'scan found no collections - the regex or path is wrong');
  });
}
