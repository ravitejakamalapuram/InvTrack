// A118 (#892): updateInvestment builds the saved investment field by field,
// and a null argument clears the stored value. A field added to
// InvestmentEntity (and its Firestore mapper) but not to updateInvestment
// would be erased by every edit. Saving an investment unchanged must give
// back the same investment, and the written document must hold every field.
//
// When you add a field to InvestmentEntity, set it in [_everyField] with a
// non-default value; the completeness test fails until you do.

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/data/repositories/firestore_investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../data/repositories/mock_investment_repository.dart';
import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_notification_service.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

/// An open investment with every field set to a non-default value. Only
/// [InvestmentEntity.closedAt] is null, because the investment is open.
final _everyField = InvestmentEntity(
  id: 'inv-fd',
  name: 'Test Bank FD',
  type: InvestmentType.fixedDeposit,
  status: InvestmentStatus.open,
  notes: 'n',
  createdAt: DateTime(2026, 4, 1, 9, 30),
  updatedAt: DateTime(2026, 4, 1, 9, 30),
  maturityDate: DateTime(2027, 4, 1),
  incomeFrequency: IncomeFrequency.monthly,
  startDate: DateTime(2024, 4, 1),
  expectedRate: 7.25,
  tenureMonths: 36,
  platform: 'Test Bank',
  interestPayoutMode: InterestPayoutMode.periodic,
  autoRenewal: true,
  riskLevel: RiskLevel.low,
  compoundingFrequency: CompoundingFrequency.quarterly,
  currency: 'INR',
  currentValue: 105000.00,
  currentValueDate: DateTime(2026, 9, 30),
);

/// Writes [investment] through the Firestore repository and returns the
/// map passed to `set()` (create) or `update()` (edit).
Future<Map<String, dynamic>> _written(
  InvestmentEntity investment, {
  required bool create,
}) async {
  final firestore = _MockFirestore();
  final users = _MockCollection();
  final userDoc = _MockDoc();
  final investments = _MockCollection();
  final doc = _MockDoc();
  when(() => firestore.collection('users')).thenReturn(users);
  when(() => users.doc('uid-1')).thenReturn(userDoc);
  when(() => userDoc.collection('investments')).thenReturn(investments);
  when(() => investments.doc('inv-fd')).thenReturn(doc);
  when(() => doc.set(any())).thenAnswer((_) async {});
  when(() => doc.update(any())).thenAnswer((_) async {});

  final repository = FirestoreInvestmentRepository(
    firestore: firestore,
    userId: 'uid-1',
    baseCurrency: () => 'INR',
  );
  if (create) {
    await repository.createInvestment(investment);
    return verify(() => doc.set(captureAny())).captured.single
        as Map<String, dynamic>;
  }
  await repository.updateInvestment(investment);
  return (verify(() => doc.update(captureAny())).captured.single as Map)
      .cast<String, dynamic>();
}

void main() {
  late FakeInvestmentRepository fakeRepository;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, dynamic>{}));

  setUp(() {
    fakeRepository = FakeInvestmentRepository();
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(fakeRepository),
        analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        currencyCodeProvider.overrideWithValue('INR'),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Saves the edit form for [from] unchanged: every field as stored.
  Future<InvestmentEntity> saveUnchanged(InvestmentEntity from) async {
    fakeRepository.seed(investments: [from]);
    await container
        .read(investmentNotifierProvider.notifier)
        .updateInvestment(
          id: from.id,
          name: from.name,
          type: from.type,
          notes: from.notes,
          maturityDate: from.maturityDate,
          incomeFrequency: from.incomeFrequency,
          startDate: from.startDate,
          expectedRate: from.expectedRate,
          tenureMonths: from.tenureMonths,
          platform: from.platform,
          interestPayoutMode: from.interestPayoutMode,
          autoRenewal: from.autoRenewal,
          riskLevel: from.riskLevel,
          compoundingFrequency: from.compoundingFrequency,
          currency: from.currency,
        );
    return fakeRepository.investments.single;
  }

  test('saving an investment unchanged keeps every field', () async {
    final stored = await saveUnchanged(_everyField);

    expect(stored.updatedAt.isAfter(_everyField.updatedAt), isTrue);
    expect(stored.copyWith(updatedAt: _everyField.updatedAt), _everyField);
  });

  test(
    'the edit writes every field the create wrote, none of them null',
    () async {
      final created = await _written(_everyField, create: true);
      final stored = await saveUnchanged(_everyField);
      final edited = await _written(stored, create: false);

      // The fixture must set every field the mapper writes, or this guard
      // would not notice the edit dropping it.
      expect(
        [
          for (final e in created.entries)
            if (e.value == null) e.key,
        ],
        ['closedAt'],
        reason: 'set the new field in _everyField',
      );
      expect(edited.keys.toSet(), created.keys.toSet());
      expect(
        [
          for (final e in edited.entries)
            if (e.value == null) e.key,
        ],
        ['closedAt'],
        reason: 'updateInvestment dropped these fields',
      );
    },
  );
}
