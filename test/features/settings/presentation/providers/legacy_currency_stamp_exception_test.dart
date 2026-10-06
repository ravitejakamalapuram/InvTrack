// The cause of a failed stamp is reported with its Firestore error code, so a
// crash report can tell a timed-out transaction from an unreachable server.
// Only the type and code are kept: never a message, path or value.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/presentation/providers/currency_switch_provider.dart';

void main() {
  test('a Firestore error keeps its code but not its message', () {
    final e = LegacyCurrencyStampException.from(
      FirebaseException(
        plugin: 'cloud_firestore',
        code: 'deadline-exceeded',
        message: 'users/uid-1/cashflows/cf-1 timed out',
      ),
    );

    expect(e.causeType, 'FirebaseException(deadline-exceeded)');
    expect(
      e.toString(),
      'LegacyCurrencyStampException(FirebaseException(deadline-exceeded))',
    );
    expect(e.toString(), isNot(contains('uid-1')));
  });

  test('any other error keeps only its type', () {
    expect(
      LegacyCurrencyStampException.from(
        TimeoutException('read of users/uid-1 timed out'),
      ).toString(),
      'LegacyCurrencyStampException(TimeoutException)',
    );
  });
}
