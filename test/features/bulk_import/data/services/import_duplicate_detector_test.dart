import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/csv_template_service.dart';
import 'package:inv_tracker/features/bulk_import/data/services/import_duplicate_detector.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  final created = DateTime(2024, 1, 15, 9, 30);

  InvestmentEntity investment(String id, String name) => InvestmentEntity(
    id: id,
    name: name,
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    createdAt: created,
    updatedAt: created,
    currency: 'INR',
  );

  CashFlowEntity flow({
    String investmentId = 'bhive',
    CashFlowType type = CashFlowType.invest,
    double amount = 100000,
    String currency = 'INR',
    DateTime? date,
  }) => CashFlowEntity(
    id: 'cf-$investmentId-$amount',
    investmentId: investmentId,
    type: type,
    amount: amount,
    currency: currency,
    date: date ?? DateTime(2024, 1, 15),
    createdAt: created,
  );

  final template = SimpleCsvParser.parseString(
    CsvTemplateService.generateTemplateContent(),
    baseCurrency: 'INR',
  );

  Set<int> duplicatesOf(List<CashFlowEntity> flows, {String? name}) =>
      findLikelyDuplicateRows(
        template.rows,
        investments: [investment('bhive', name ?? 'Bhive Investment')],
        cashFlows: flows,
        baseCurrency: 'INR',
      );

  test('re-importing the template flags only the row already saved', () {
    // The template's first row is Bhive Investment, INVEST 100000 INR on
    // 2024-01-15, on spreadsheet row 2.
    expect(template.rows.first.rowNumber, 2);
    expect(duplicatesOf([flow()]), {2});
  });

  test('names match ignoring case and surrounding spaces', () {
    expect(duplicatesOf([flow()], name: '  bhive investment '), {2});
  });

  test('a time of day on the saved flow does not hide the duplicate', () {
    expect(duplicatesOf([flow(date: DateTime(2024, 1, 15, 18, 45))]), {2});
  });

  test('a different amount, type, date or currency is not a duplicate', () {
    expect(duplicatesOf([flow(amount: 100000.01)]), isEmpty);
    expect(duplicatesOf([flow(type: CashFlowType.returnFlow)]), isEmpty);
    expect(duplicatesOf([flow(date: DateTime(2024, 1, 16))]), isEmpty);
    expect(duplicatesOf([flow(currency: 'USD')]), isEmpty);
  });

  test('a flow of another investment is not a duplicate', () {
    expect(
      findLikelyDuplicateRows(
        template.rows,
        investments: [
          investment('bhive', 'Bhive Investment'),
          investment('other', 'Other Investment'),
        ],
        cashFlows: [flow(investmentId: 'other')],
        baseCurrency: 'INR',
      ),
      isEmpty,
    );
  });

  test('a row without a currency matches a flow in the base currency', () {
    final rows = SimpleCsvParser.parseString(
      'Date,Investment Name,Type,Amount\n'
      '2024-01-15,Bhive Investment,INVEST,100000',
    ).rows;

    expect(
      findLikelyDuplicateRows(
        rows,
        investments: [investment('bhive', 'Bhive Investment')],
        cashFlows: [flow()],
        baseCurrency: 'INR',
      ),
      {2},
    );
  });
}
