// #941: which dated valuation applies "as of" a day. Snapshots are history:
// the latest applicable one is used and amounts are never summed.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';

import '../../features/investment/valuation/valuation_fixtures.dart';

void main() {
  final investment = testInvestment('i1');

  ValuationCandidate? select(
    List<InvestmentValuationSnapshot> snapshots,
    DateTime asOf, {
    InvestmentEntity? inv,
  }) => ValuationSnapshotSelector.select(
    investment: inv ?? investment,
    snapshots: snapshots,
    asOf: asOf,
  );

  group('selection by date (plan test 5)', () {
    final jan = testSnapshot('a', amount: 400000, date: DateTime(2026, 1, 1));
    final jun = testSnapshot('b', amount: 450000, date: DateTime(2026, 6, 1));

    test('none before the first snapshot', () {
      expect(select([jan, jun], DateTime(2025, 12, 31)), isNull);
    });

    test('the earlier snapshot applies between two', () {
      expect(select([jan, jun], DateTime(2026, 3, 1))?.amount, 400000.00);
    });

    test('the later snapshot applies on its own day (inclusive) and after', () {
      expect(select([jan, jun], DateTime(2026, 6, 1))?.amount, 450000.00);
      expect(select([jan, jun], DateTime(2026, 12, 1))?.amount, 450000.00);
    });

    test('snapshots are never summed', () {
      final got = select([jan, jun], DateTime(2026, 12, 1))?.amount;
      expect(got, isNot(850000.00));
    });

    test('the same answer for any input order', () {
      expect(select([jun, jan], DateTime(2026, 3, 1))?.amount, 400000.00);
      expect(select([jun, jan], DateTime(2026, 7, 1))?.amount, 450000.00);
    });

    test('a soft-deleted snapshot is ignored', () {
      final gone = testSnapshot(
        'c',
        amount: 999999,
        date: DateTime(2026, 6, 1),
        deletedAt: DateTime.utc(2026, 6, 2),
      );
      expect(select([jan, gone], DateTime(2026, 7, 1))?.amount, 400000.00);
    });

    test('a future-dated snapshot is ignored until its day', () {
      final future = testSnapshot('f', amount: 1, date: DateTime(2027, 1, 1));
      expect(select([jan, future], DateTime(2026, 7, 1))?.amount, 400000.00);
      expect(select([jan, future], DateTime(2027, 1, 1))?.amount, 1);
    });

    test('a snapshot in another currency is ignored', () {
      final usd = testSnapshot(
        'u',
        amount: 1000,
        date: DateTime(2026, 6, 1),
        currency: 'USD',
      );
      expect(select([jan, usd], DateTime(2026, 7, 1))?.amount, 400000.00);
    });

    test('another investment\'s snapshot is ignored', () {
      final other = testSnapshot(
        'o',
        investmentId: 'i2',
        amount: 5,
        date: DateTime(2026, 6, 1),
      );
      expect(select([jan, other], DateTime(2026, 7, 1))?.amount, 400000.00);
    });
  });

  group('same-day ties', () {
    final older = testSnapshot(
      'z-old',
      amount: 1,
      date: DateTime(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 1, 9),
    );
    final newer = testSnapshot(
      'a-new',
      amount: 2,
      date: DateTime(2026, 5, 1),
      updatedAt: DateTime.utc(2026, 5, 1, 10),
    );

    test('the later updatedAt wins, whatever the id', () {
      expect(select([older, newer], DateTime(2026, 6, 1))?.amount, 2);
      expect(select([newer, older], DateTime(2026, 6, 1))?.amount, 2);
    });

    test('a pending write (null updatedAt) counts as newest', () {
      final pending = testSnapshot(
        'p',
        amount: 3,
        date: DateTime(2026, 5, 1),
        pending: true,
      );
      expect(select([newer, pending], DateTime(2026, 6, 1))?.amount, 3);
      expect(select([pending, newer], DateTime(2026, 6, 1))?.amount, 3);
    });

    test('then the id, the same for any order', () {
      final x = testSnapshot('x', amount: 10, date: DateTime(2026, 5, 1));
      final y = testSnapshot('y', amount: 20, date: DateTime(2026, 5, 1));
      expect(select([x, y], DateTime(2026, 6, 1))?.amount, 20);
      expect(select([y, x], DateTime(2026, 6, 1))?.amount, 20);
    });
  });

  group('compat pair as one more candidate (amended default 8, T22)', () {
    final snapshot = testSnapshot(
      's',
      amount: 500000,
      date: DateTime(2026, 3, 1),
      updatedAt: DateTime.utc(2026, 3, 1, 10),
    );
    final asOf = DateTime(2026, 6, 1);

    test('a pair equal to the latest snapshot is ignored', () {
      final inv = testInvestment(
        'i1',
        compatValue: 500000,
        compatDate: DateTime(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 5),
      );
      final got = select([snapshot], asOf, inv: inv)!;
      expect(got.amount, 500000);
      expect(got.isCompat, isFalse);
    });

    test(
      'same date, another amount, written after the snapshot: compat wins',
      () {
        final inv = testInvestment(
          'i1',
          compatValue: 510000,
          compatDate: DateTime(2026, 3, 1),
          updatedAt: DateTime.utc(2026, 3, 5),
        );
        final got = select([snapshot], asOf, inv: inv)!;
        expect(got.amount, 510000.00);
        expect(got.isCompat, isTrue);
        expect(got.kind, ValuationKind.carryingValue);
      },
    );

    test('same date, another amount, written in the same batch: snapshot', () {
      final inv = testInvestment(
        'i1',
        compatValue: 510000,
        compatDate: DateTime(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 1, 10),
      );
      expect(select([snapshot], asOf, inv: inv)?.amount, 500000.00);
    });

    test('a later-dated compat written after the snapshot wins', () {
      final inv = testInvestment(
        'i1',
        compatValue: 520000,
        compatDate: DateTime(2026, 4, 1),
        updatedAt: DateTime.utc(2026, 4, 2),
      );
      final got = select([snapshot], asOf, inv: inv)!;
      expect(got.amount, 520000);
      expect(got.date, DateTime(2026, 4, 1));
    });

    test('a compat dated earlier than the snapshot is ignored', () {
      final inv = testInvestment(
        'i1',
        compatValue: 100,
        compatDate: DateTime(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 4, 2),
      );
      expect(select([snapshot], asOf, inv: inv)?.amount, 500000);
    });

    test('a compat cleared after the snapshot hides the value', () {
      final inv = testInvestment('i1', updatedAt: DateTime.utc(2026, 4, 2));
      expect(select([snapshot], asOf, inv: inv), isNull);
    });

    test('a compat cleared in the same batch does not hide a snapshot', () {
      final inv = testInvestment('i1', updatedAt: DateTime.utc(2026, 3, 1, 10));
      expect(select([snapshot], asOf, inv: inv)?.amount, 500000);
    });

    test('a pending snapshot is never overruled by the pair', () {
      final pending = testSnapshot(
        'p',
        amount: 500000,
        date: DateTime(2026, 3, 1),
        pending: true,
      );
      final inv = testInvestment(
        'i1',
        compatValue: 510000,
        compatDate: DateTime(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 4, 2),
      );
      expect(select([pending], asOf, inv: inv)?.amount, 500000);
    });

    test('a compat dated after the as-of day is ignored', () {
      final inv = testInvestment(
        'i1',
        compatValue: 777,
        compatDate: DateTime(2026, 7, 1),
        updatedAt: DateTime.utc(2026, 7, 2),
      );
      expect(select([snapshot], asOf, inv: inv)?.amount, 500000);
    });

    test('with no snapshot dated yet, a compat on or before as-of applies', () {
      final inv = testInvestment(
        'i1',
        compatValue: 42,
        compatDate: DateTime(2026, 2, 1),
      );
      final got = select(const [], asOf, inv: inv)!;
      expect(got.amount, 42);
      expect(got.isCompat, isTrue);
    });
  });

  group('time zones (rule 5)', () {
    test('a snapshot written in a zone ahead of the reader is hidden for '
        'up to a day, then shows', () {
      // Written on 2 Jan in UTC+14; the reader\'s today is still 1 Jan.
      final ahead = testSnapshot('a', amount: 9, date: DateTime(2026, 1, 2));
      expect(select([ahead], DateTime(2026, 1, 1)), isNull);
      expect(select([ahead], DateTime(2026, 1, 2))?.amount, 9);
    });
  });

  group('baseline and mirror helpers', () {
    test('openingBaseline finds the one live baseline in the currency', () {
      final base = testSnapshot(
        'b',
        amount: 5,
        date: DateTime(2026, 1, 1),
        provenance: ValuationProvenance.openingBaseline,
      );
      final manual = testSnapshot('m', amount: 6, date: DateTime(2026, 2, 1));
      final usdBase = testSnapshot(
        'ub',
        amount: 7,
        date: DateTime(2026, 1, 1),
        currency: 'USD',
        provenance: ValuationProvenance.openingBaseline,
      );
      expect(
        ValuationSnapshotSelector.openingBaseline(
          [manual, usdBase, base],
          investmentId: 'i1',
          currency: 'INR',
        )!.id,
        'b',
      );
      expect(
        ValuationSnapshotSelector.openingBaseline(
          [manual],
          investmentId: 'i1',
          currency: 'INR',
        ),
        isNull,
      );
    });

    test('openingBaseline given an as-of day ignores a baseline after it', () {
      final base = testSnapshot(
        'b',
        amount: 5,
        date: DateTime(2026, 12, 1),
        provenance: ValuationProvenance.openingBaseline,
      );
      ValuationSnapshotSelector.openingBaseline(
        [base],
        investmentId: 'i1',
        currency: 'INR',
      );
      // Without a day any live baseline counts: there is at most one.
      expect(
        ValuationSnapshotSelector.openingBaseline(
          [base],
          investmentId: 'i1',
          currency: 'INR',
        )!.id,
        'b',
      );
      expect(
        ValuationSnapshotSelector.openingBaseline(
          [base],
          investmentId: 'i1',
          currency: 'INR',
          asOf: DateTime(2026, 11, 30, 23),
        ),
        isNull,
      );
      expect(
        ValuationSnapshotSelector.openingBaseline(
          [base],
          investmentId: 'i1',
          currency: 'INR',
          asOf: DateTime(2026, 12, 1, 9),
        )!.id,
        'b',
      );
    });

    test('mirrorOf is the latest live snapshot in the currency, or null', () {
      final a = testSnapshot('a', amount: 1, date: DateTime(2026, 1, 1));
      final b = testSnapshot('b', amount: 2, date: DateTime(2026, 5, 1));
      final gone = testSnapshot(
        'c',
        amount: 3,
        date: DateTime(2026, 9, 1),
        deletedAt: DateTime.utc(2026, 9, 2),
      );
      final m = ValuationSnapshotSelector.mirrorOf(
        [a, b, gone],
        investmentId: 'i1',
        currency: 'INR',
      )!;
      expect(m.amount, 2);
      expect(m.effectiveDate, DateTime(2026, 5, 1));
      expect(
        ValuationSnapshotSelector.mirrorOf(
          [gone],
          investmentId: 'i1',
          currency: 'INR',
        ),
        isNull,
      );
    });
  });

  group('entity', () {
    test('a kind rolls forward unless it is a market value', () {
      expect(ValuationKind.marketValue.rollsForward, isFalse);
      expect(ValuationKind.carryingValue.rollsForward, isTrue);
      expect(ValuationKind.principalOutstanding.rollsForward, isTrue);
    });

    test('an unknown kind or provenance does not parse', () {
      expect(ValuationKind.tryParse('nonsense'), isNull);
      expect(ValuationKind.tryParse(null), isNull);
      expect(ValuationProvenance.tryParse('nonsense'), isNull);
      expect(
        ValuationProvenance.tryParse('import'),
        ValuationProvenance.imported,
      );
      expect(ValuationProvenance.imported.storageName, 'import');
    });

    test('copyWith, equality and live state', () {
      final s = testSnapshot('a', amount: 1, date: DateTime(2026, 1, 1));
      expect(s.isLive, isTrue);
      expect(s.copyWith(amount: 2).amount, 2);
      expect(s.copyWith(amount: 2).id, 'a');
      expect(s, s.copyWith());
      expect(s.hashCode, s.copyWith().hashCode);
      expect(s == s.copyWith(amount: 2), isFalse);
      final gone = s.copyWith(deletedAt: DateTime.utc(2026, 2, 1));
      expect(gone.isLive, isFalse);
      expect(gone.copyWith(clearDeletedAt: true).isLive, isTrue);
    });
  });
}
