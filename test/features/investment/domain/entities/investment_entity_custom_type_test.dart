// #936: an investment of type Other may carry a custom type: the id of the
// reusable definition it refers to and its own copy of the label. The
// built-in type stays `other` and nothing else about the investment changes.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

InvestmentEntity _investment({
  InvestmentType type = InvestmentType.other,
  String? customTypeId,
  String? customTypeLabel,
}) => InvestmentEntity(
  id: 'inv-1',
  name: 'Stamp album',
  type: type,
  status: InvestmentStatus.open,
  createdAt: DateTime(2026, 4, 1),
  updatedAt: DateTime(2026, 4, 1),
  currency: 'INR',
  customTypeId: customTypeId,
  customTypeLabel: customTypeLabel,
);

void main() {
  test('a legacy investment has no custom type and shows as Other', () {
    final legacy = _investment();
    expect(legacy.customTypeId, isNull);
    expect(legacy.customTypeLabel, isNull);
    expect(legacy.typeLabel, 'Other');
  });

  test('a custom label is shown in place of Other', () {
    expect(_investment(customTypeLabel: 'Stamps').typeLabel, 'Stamps');
  });

  test('a blank label still shows as Other', () {
    expect(_investment(customTypeLabel: '  ').typeLabel, 'Other');
  });

  test('a label on a built-in type is ignored: the type decides the name', () {
    final fd = _investment(
      type: InvestmentType.fixedDeposit,
      customTypeLabel: 'Stamps',
    );
    expect(fd.typeLabel, 'Fixed Deposit');
    expect(fd.type, InvestmentType.fixedDeposit);
  });

  test('the custom type is part of equality', () {
    expect(
      _investment(customTypeId: 'c1', customTypeLabel: 'Stamps'),
      _investment(customTypeId: 'c1', customTypeLabel: 'Stamps'),
    );
    expect(
      _investment(customTypeLabel: 'Stamps') ==
          _investment(customTypeLabel: 'Wine'),
      isFalse,
    );
    expect(
      _investment(customTypeId: 'c1', customTypeLabel: 'Stamps') ==
          _investment(customTypeId: 'c2', customTypeLabel: 'Stamps'),
      isFalse,
    );
    expect(
      _investment(customTypeId: 'c1', customTypeLabel: 'Stamps').hashCode ==
          _investment(customTypeId: 'c2', customTypeLabel: 'Stamps').hashCode,
      isFalse,
    );
  });

  test('copyWith keeps the custom type and can replace it', () {
    final base = _investment(customTypeId: 'c1', customTypeLabel: 'Stamps');
    expect(base.copyWith(name: 'Album').customTypeLabel, 'Stamps');
    expect(base.copyWith(name: 'Album').customTypeId, 'c1');
    final replaced = base.copyWith(customTypeId: 'c2', customTypeLabel: 'Wine');
    expect(replaced.customTypeId, 'c2');
    expect(replaced.customTypeLabel, 'Wine');
  });
}
