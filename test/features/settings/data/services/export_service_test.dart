import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/settings/data/services/export_service.dart';

import '../../../investment/data/repositories/mock_investment_repository.dart';

void main() {
  late FakeInvestmentRepository investmentRepository;
  late ExportService exportService;
  late Directory tempDir;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync();

    // Mock path_provider
    const pathProviderChannel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (
          MethodCall methodCall,
        ) async {
          return tempDir.path;
        });

    // Mock share_plus
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (MethodCall methodCall) async {
          // Mock successful share - just return null
          return null;
        });

    investmentRepository = FakeInvestmentRepository();
    exportService = ExportService(investmentRepository);
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ExportService - Multi-Currency Support (Rule 21.4)', () {
    group('CSV Header Format', () {
      test('includes Currency column in header', () async {
        // Arrange - Create a simple investment
        final investment = InvestmentEntity(
          id: 'inv1',
          name: 'Test Investment',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final cashFlow = CashFlowEntity(
          id: 'cf1',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 1),
        );

        await investmentRepository.createInvestment(investment);
        await investmentRepository.addCashFlow(cashFlow);

        // Act - Export to CSV
        await exportService.exportToCsv();

        // Assert - Find the generated CSV file
        final files = tempDir.listSync();
        expect(files.length, 1);

        final csvFile = files.first as File;
        final csvContent = await csvFile.readAsString();

        // Verify header includes Currency column
        final lines = csvContent.split('\n');
        expect(lines.first, contains('Currency'));
        expect(
          lines.first.trim(),
          'Date,Investment Name,Type,Amount,Currency,Notes',
        );
      });
    });

    group('Currency Preservation', () {
      test('preserves original currency for each cash flow', () async {
        // Arrange - Create multi-currency investments
        final usdInvestment = InvestmentEntity(
          id: 'inv1',
          name: 'US Stocks',
          type: InvestmentType.stocks,
          status: InvestmentStatus.open,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final inrInvestment = InvestmentEntity(
          id: 'inv2',
          name: 'Indian FD',
          type: InvestmentType.fixedDeposit,
          status: InvestmentStatus.open,
          currency: 'INR',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        );

        final usdCashFlow = CashFlowEntity(
          id: 'cf1',
          investmentId: 'inv1',
          date: DateTime(2024, 1, 1),
          type: CashFlowType.invest,
          amount: 1000,
          currency: 'USD',
          createdAt: DateTime(2024, 1, 1),
        );

        final inrCashFlow = CashFlowEntity(
          id: 'cf2',
          investmentId: 'inv2',
          date: DateTime(2024, 2, 1),
          type: CashFlowType.invest,
          amount: 100000,
          currency: 'INR',
          createdAt: DateTime(2024, 2, 1),
        );

        await investmentRepository.createInvestment(usdInvestment);
        await investmentRepository.createInvestment(inrInvestment);
        await investmentRepository.addCashFlow(usdCashFlow);
        await investmentRepository.addCashFlow(inrCashFlow);

        // Act
        await exportService.exportToCsv();

        // Assert
        final files = tempDir.listSync();
        final csvFile = files.first as File;
        final csvContent = await csvFile.readAsString();
        final lines = csvContent.split('\n');

        // Verify USD cash flow
        expect(lines[1], contains('USD'));
        expect(lines[1], contains('US Stocks'));
        expect(lines[1], contains('1000'));

        // Verify INR cash flow
        expect(lines[2], contains('INR'));
        expect(lines[2], contains('Indian FD'));
        expect(lines[2], contains('100000'));
      });

      test('handles multiple currencies in same export', () async {
        // Arrange - Create diverse portfolio
        final investments = [
          InvestmentEntity(
            id: 'inv1',
            name: 'US Tech Stocks',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            currency: 'USD',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          InvestmentEntity(
            id: 'inv2',
            name: 'Indian FD',
            type: InvestmentType.fixedDeposit,
            status: InvestmentStatus.open,
            currency: 'INR',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          InvestmentEntity(
            id: 'inv3',
            name: 'European Bonds',
            type: InvestmentType.bonds,
            status: InvestmentStatus.open,
            currency: 'EUR',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        final cashFlows = [
          CashFlowEntity(
            id: 'cf1',
            investmentId: 'inv1',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 1000,
            currency: 'USD',
            createdAt: DateTime(2024, 1, 1),
          ),
          CashFlowEntity(
            id: 'cf2',
            investmentId: 'inv2',
            date: DateTime(2024, 2, 1),
            type: CashFlowType.invest,
            amount: 100000,
            currency: 'INR',
            createdAt: DateTime(2024, 2, 1),
          ),
          CashFlowEntity(
            id: 'cf3',
            investmentId: 'inv3',
            date: DateTime(2024, 3, 1),
            type: CashFlowType.invest,
            amount: 800,
            currency: 'EUR',
            createdAt: DateTime(2024, 3, 1),
          ),
        ];

        for (final inv in investments) {
          await investmentRepository.createInvestment(inv);
        }
        for (final cf in cashFlows) {
          await investmentRepository.addCashFlow(cf);
        }

        // Act
        await exportService.exportToCsv();

        // Assert
        final files = tempDir.listSync();
        final csvFile = files.first as File;
        final csvContent = await csvFile.readAsString();

        // Verify all currencies present
        expect(csvContent, contains('USD'));
        expect(csvContent, contains('INR'));
        expect(csvContent, contains('EUR'));

        // Verify amounts not modified
        expect(csvContent, contains('1000'));
        expect(csvContent, contains('100000'));
        expect(csvContent, contains('800'));
      });
    });

    group('Data Integrity (Rule 21.1)', () {
      test('does not convert amounts during export', () async {
        // Arrange - Same amount in different currencies
        final investments = [
          InvestmentEntity(
            id: 'inv1',
            name: 'USD Investment',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            currency: 'USD',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
          InvestmentEntity(
            id: 'inv2',
            name: 'INR Investment',
            type: InvestmentType.stocks,
            status: InvestmentStatus.open,
            currency: 'INR',
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        ];

        final cashFlows = [
          CashFlowEntity(
            id: 'cf1',
            investmentId: 'inv1',
            date: DateTime(2024, 1, 1),
            type: CashFlowType.invest,
            amount: 1000,
            currency: 'USD',
            createdAt: DateTime(2024, 1, 1),
          ),
          CashFlowEntity(
            id: 'cf2',
            investmentId: 'inv2',
            date: DateTime(2024, 1, 2),
            type: CashFlowType.invest,
            amount: 1000,
            currency: 'INR',
            createdAt: DateTime(2024, 1, 2),
          ),
        ];

        for (final inv in investments) {
          await investmentRepository.createInvestment(inv);
        }
        for (final cf in cashFlows) {
          await investmentRepository.addCashFlow(cf);
        }

        // Act
        await exportService.exportToCsv();

        // Assert
        final files = tempDir.listSync();
        final csvFile = files.first as File;
        final csvContent = await csvFile.readAsString();
        final lines = csvContent.split('\n');

        // Both amounts should be 1000 (no conversion)
        final usdLine = lines.firstWhere((l) => l.contains('USD'));
        final inrLine = lines.firstWhere((l) => l.contains('INR'));

        expect(usdLine, contains('1000'));
        expect(inrLine, contains('1000'));
      });
    });
  });
}
