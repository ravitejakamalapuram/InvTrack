// A70 (#835): a cash-flow, start or maturity date saved in one time zone must
// read as the same calendar day in any other. Older builds saved the writer's
// local midnight and read it back with Timestamp.toDate(), so a 1 Apr 2026
// cash flow saved in India read as 31 Mar 2026 in New York.
//
// The reading device's zone is injected, so the results do not depend on the
// zone of the machine running the tests.

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/utils/stored_date.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockBatch extends Mock implements WriteBatch {}

class _MockSnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

/// An in-memory cash-flow collection that applies `where` range filters on
/// Timestamps the way Firestore does.
class _FakeCashFlows extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _FakeCashFlows(this.docs);

  final Map<String, Map<String, dynamic>> docs;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    bool keep(Timestamp value) =>
        (isLessThan == null || value.compareTo(isLessThan as Timestamp) < 0) &&
        (isLessThanOrEqualTo == null ||
            value.compareTo(isLessThanOrEqualTo as Timestamp) <= 0) &&
        (isGreaterThan == null ||
            value.compareTo(isGreaterThan as Timestamp) > 0) &&
        (isGreaterThanOrEqualTo == null ||
            value.compareTo(isGreaterThanOrEqualTo as Timestamp) >= 0);
    return _FakeCashFlows({
      for (final entry in docs.entries)
        if (keep(entry.value[field] as Timestamp)) entry.key: entry.value,
    });
  }

  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    final sorted = docs.entries.toList()
      ..sort((a, b) {
        final order = (a.value[field] as Timestamp).compareTo(
          b.value[field] as Timestamp,
        );
        return descending ? -order : order;
      });
    return _FakeCashFlows(Map.fromEntries(sorted));
  }

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    final snapshot = _MockSnapshot();
    final queryDocs = [
      for (final entry in docs.entries)
        () {
          final doc = _MockQueryDoc();
          when(() => doc.id).thenReturn(entry.key);
          when(() => doc.data()).thenReturn(entry.value);
          return doc;
        }(),
    ];
    when(() => snapshot.docs).thenReturn(queryDocs);
    return snapshot;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.fromFuture(get());
}

/// The UTC offset of [zone] at a given instant, as a device in [zone] sees it.
UtcOffsetAt zone(String zone) {
  final location = tz.getLocation(zone);
  return (instant) => location.timeZone(instant.millisecondsSinceEpoch).offset;
}

/// What an older build stored for a date picked on a device in [zone]: that
/// device's local midnight.
Timestamp legacyMidnight(String zone, int year, int month, int day) =>
    Timestamp.fromDate(
      tz.TZDateTime(tz.getLocation(zone), year, month, day).toUtc(),
    );

final _newYork = zone('America/New_York');

Map<String, dynamic> cashFlowDoc(
  Timestamp date, {
  String type = 'INVEST',
  double amount = 100000,
}) => {
  'investmentId': 'inv-p2p',
  'date': date,
  'type': type,
  'amount': amount,
  'notes': null,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 9, 15, 42)),
  'currency': 'INR',
};

CashFlowEntity readInNewYork(Map<String, dynamic> doc, [String id = 'cf']) =>
    FirestoreInvestmentRepository.cashFlowFromFirestore(
      doc,
      id,
      baseCurrency: 'INR',
      offsetAt: _newYork,
    );

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_MockDoc());
  });

  group('reading a date saved in another time zone', () {
    test('a cash flow of 1 Apr 2026 saved in India reads as 1 Apr 2026 in '
        'New York and falls in FY 2026-27', () {
      final saved = legacyMidnight('Asia/Kolkata', 2026, 4, 1);
      expect(saved.toDate().toUtc(), DateTime.utc(2026, 3, 31, 18, 30));

      final cashFlow = readInNewYork(cashFlowDoc(saved));

      expect(cashFlow.date, DateTime(2026, 4, 1));
      final fyStart = DateTime(2026, 4, 1);
      final nextFyStart = DateTime(2027, 4, 1);
      expect(
        !cashFlow.date.isBefore(fyStart) && cashFlow.date.isBefore(nextFyStart),
        isTrue,
        reason: 'FY 2026-27 is [1 Apr 2026, 1 Apr 2027)',
      );
    });

    test('start and maturity dates saved in India keep their day in New '
        'York', () {
      final investment = FirestoreInvestmentRepository.investmentFromFirestore(
        {
          'name': 'SBI FD',
          'type': 'fixedDeposit',
          'status': 'OPEN',
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 4, 12)),
          'startDate': legacyMidnight('Asia/Kolkata', 2026, 4, 1),
          'maturityDate': legacyMidnight('Asia/Kolkata', 2026, 10, 10),
          'currency': 'INR',
        },
        'inv-fd',
        baseCurrency: 'INR',
        offsetAt: _newYork,
      );

      expect(investment.startDate, DateTime(2026, 4, 1));
      expect(investment.maturityDate, DateTime(2026, 10, 10));
      // createdAt is an instant, not a date, and is left as it was.
      expect(investment.createdAt.toUtc(), DateTime.utc(2026, 4, 1, 4, 12));
    });

    test('XIRR of -100,000 on 1 Apr 2025 and +108,000 on 1 Apr 2026, both '
        'saved in India and read in New York, is 0.080000', () {
      final flows = [
        readInNewYork(
          cashFlowDoc(legacyMidnight('Asia/Kolkata', 2025, 4, 1)),
          'cf-1',
        ),
        readInNewYork(
          cashFlowDoc(
            legacyMidnight('Asia/Kolkata', 2026, 4, 1),
            type: 'RETURN',
            amount: 108000,
          ),
          'cf-2',
        ),
      ];

      expect(flows.map((f) => f.date), [
        DateTime(2025, 4, 1),
        DateTime(2026, 4, 1),
      ]);
      expect(
        FinancialCalculator.calculateXirrFromCashFlows(flows),
        closeTo(0.08, 1e-6),
      );
    });

    test('XIRR is 0.080000 when the two cash flows were saved on devices in '
        'different zones', () {
      final flows = [
        readInNewYork(
          cashFlowDoc(legacyMidnight('America/New_York', 2025, 4, 1)),
          'cf-1',
        ),
        readInNewYork(
          cashFlowDoc(
            legacyMidnight('Asia/Kolkata', 2026, 4, 1),
            type: 'RETURN',
            amount: 108000,
          ),
          'cf-2',
        ),
      ];

      expect(
        FinancialCalculator.calculateXirrFromCashFlows(flows),
        closeTo(0.08, 1e-6),
      );
    });
  });

  group('saving a date', () {
    late _MockCollection cashFlows;
    late _MockCollection investments;
    late _MockDoc cashFlowDocRef;
    late _MockDoc investmentDocRef;
    late _MockFirestore firestore;
    late FirestoreInvestmentRepository repository;

    setUp(() {
      firestore = _MockFirestore();
      final users = _MockCollection();
      final userDoc = _MockDoc();
      cashFlows = _MockCollection();
      investments = _MockCollection();
      cashFlowDocRef = _MockDoc();
      investmentDocRef = _MockDoc();

      when(() => firestore.collection('users')).thenReturn(users);
      when(() => users.doc('uid-1')).thenReturn(userDoc);
      when(() => userDoc.collection('cashflows')).thenReturn(cashFlows);
      when(() => userDoc.collection('investments')).thenReturn(investments);
      when(() => cashFlows.doc(any())).thenReturn(cashFlowDocRef);
      when(() => investments.doc(any())).thenReturn(investmentDocRef);
      when(() => cashFlowDocRef.set(any())).thenAnswer((_) async {});
      when(() => investmentDocRef.update(any())).thenAnswer((_) async {});

      repository = FirestoreInvestmentRepository(
        firestore: firestore,
        userId: 'uid-1',
        baseCurrency: () => 'INR',
      );
    });

    final createdAt = DateTime.utc(2026, 4, 1, 16, 0, 15, 123);

    test('a cash flow date is stored as UTC midnight of its day', () async {
      await repository.addCashFlow(
        CashFlowEntity(
          id: 'cf-1',
          investmentId: 'inv-p2p',
          type: CashFlowType.invest,
          amount: 100000,
          date: DateTime(2026, 4, 1, 21, 30),
          createdAt: createdAt,
          currency: 'INR',
        ),
      );

      final written =
          verify(() => cashFlowDocRef.set(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(written['date'], Timestamp.fromDate(DateTime.utc(2026, 4, 1)));
      expect(written['createdAt'], Timestamp.fromDate(createdAt));
    });

    test('start and maturity dates are stored as UTC midnight', () async {
      await repository.updateInvestment(
        InvestmentEntity(
          id: 'inv-fd',
          name: 'SBI FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          createdAt: createdAt,
          updatedAt: createdAt,
          startDate: DateTime(2026, 4, 1),
          maturityDate: DateTime(2026, 10, 10, 18, 45),
          currency: 'INR',
        ),
      );

      final written =
          verify(() => investmentDocRef.update(captureAny())).captured.single
              as Map<Object, Object?>;
      expect(
        written['startDate'],
        Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      );
      expect(
        written['maturityDate'],
        Timestamp.fromDate(DateTime.utc(2026, 10, 10)),
      );
      expect(written['createdAt'], Timestamp.fromDate(createdAt));
    });

    test('an imported cash flow is stored as UTC midnight', () async {
      final batch = _MockBatch();
      when(() => firestore.batch()).thenReturn(batch);
      when(() => batch.commit()).thenAnswer((_) async {});

      await repository.bulkImport(
        investments: const [],
        cashFlows: [
          CashFlowEntity(
            id: 'cf-csv',
            investmentId: 'inv-p2p',
            type: CashFlowType.invest,
            amount: 100000,
            // The CSV parser gives the importing device's local midnight.
            date: DateTime(2026, 4, 1),
            createdAt: createdAt,
            currency: 'INR',
          ),
        ],
      );

      final written =
          verify(
                () => batch.set<Map<String, dynamic>>(any(), captureAny()),
              ).captured.single
              as Map<String, dynamic>;
      expect(written['date'], Timestamp.fromDate(DateTime.utc(2026, 4, 1)));
    });
  });

  group('date-range queries', () {
    test('the FY 2026-27 range returns older and newer saves of its days '
        'only', () async {
      final firestore = _MockFirestore();
      final users = _MockCollection();
      final userDoc = _MockDoc();
      when(() => firestore.collection('users')).thenReturn(users);
      when(() => users.doc('uid-1')).thenReturn(userDoc);
      when(() => userDoc.collection('cashflows')).thenReturn(
        _FakeCashFlows({
          // 1 Apr 2026 saved by an older build in India: 31 Mar 18:30Z.
          'ist-1-apr-2026': cashFlowDoc(
            legacyMidnight('Asia/Kolkata', 2026, 4, 1),
          ),
          // 31 Mar 2026 saved in India belongs to FY 2025-26.
          'ist-31-mar-2026': cashFlowDoc(
            legacyMidnight('Asia/Kolkata', 2026, 3, 31),
          ),
          // 31 Mar 2027 saved by an older build in New York: 04:00Z.
          'ny-31-mar-2027': cashFlowDoc(
            legacyMidnight('America/New_York', 2027, 3, 31),
          ),
          'new-31-mar-2027': cashFlowDoc(
            Timestamp.fromDate(DateTime.utc(2027, 3, 31)),
          ),
          'new-1-apr-2027': cashFlowDoc(
            Timestamp.fromDate(DateTime.utc(2027, 4, 1)),
          ),
        }),
      );

      final repository = FirestoreInvestmentRepository(
        firestore: firestore,
        userId: 'uid-1',
        baseCurrency: () => 'INR',
      );
      final start = DateTime(2026, 4, 1);
      final end = DateTime(2027, 3, 31, 23, 59, 59);

      final fetched = await repository.getCashFlowsInDateRange(
        startDate: start,
        endDate: end,
      );
      final watched = await repository
          .watchCashFlowsInDateRange(startDate: start, endDate: end)
          .first;

      for (final result in [fetched, watched]) {
        expect(result.map((cf) => cf.id).toSet(), {
          'ist-1-apr-2026',
          'ny-31-mar-2027',
          'new-31-mar-2027',
        });
      }
    });
  });
}
