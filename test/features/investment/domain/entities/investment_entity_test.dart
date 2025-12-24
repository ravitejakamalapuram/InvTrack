import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

void main() {
  group('InvestmentStatus', () {
    group('fromString', () {
      test('should parse OPEN', () {
        expect(InvestmentStatus.fromString('OPEN'), InvestmentStatus.open);
      });

      test('should parse CLOSED', () {
        expect(InvestmentStatus.fromString('CLOSED'), InvestmentStatus.closed);
      });

      test('should be case insensitive', () {
        expect(InvestmentStatus.fromString('open'), InvestmentStatus.open);
        expect(InvestmentStatus.fromString('Open'), InvestmentStatus.open);
      });

      test('should default to open for unknown values', () {
        expect(InvestmentStatus.fromString('UNKNOWN'), InvestmentStatus.open);
      });
    });

    group('displayName', () {
      test('should return Open for open status', () {
        expect(InvestmentStatus.open.displayName, 'Open');
      });

      test('should return Closed for closed status', () {
        expect(InvestmentStatus.closed.displayName, 'Closed');
      });
    });
  });

  group('InvestmentType', () {
    group('fromString', () {
      test('should parse all investment types', () {
        expect(InvestmentType.fromString('p2pLending'), InvestmentType.p2pLending);
        expect(InvestmentType.fromString('fixedDeposit'), InvestmentType.fixedDeposit);
        expect(InvestmentType.fromString('bonds'), InvestmentType.bonds);
        expect(InvestmentType.fromString('realEstate'), InvestmentType.realEstate);
        expect(InvestmentType.fromString('privateEquity'), InvestmentType.privateEquity);
        expect(InvestmentType.fromString('angelInvesting'), InvestmentType.angelInvesting);
        expect(InvestmentType.fromString('chitFunds'), InvestmentType.chitFunds);
        expect(InvestmentType.fromString('gold'), InvestmentType.gold);
        expect(InvestmentType.fromString('crypto'), InvestmentType.crypto);
        expect(InvestmentType.fromString('mutualFunds'), InvestmentType.mutualFunds);
        expect(InvestmentType.fromString('stocks'), InvestmentType.stocks);
        expect(InvestmentType.fromString('other'), InvestmentType.other);
      });

      test('should default to other for unknown values', () {
        expect(InvestmentType.fromString('UNKNOWN'), InvestmentType.other);
      });
    });

    group('displayName', () {
      test('should return correct display names', () {
        expect(InvestmentType.p2pLending.displayName, 'P2P Lending');
        expect(InvestmentType.fixedDeposit.displayName, 'Fixed Deposit');
        expect(InvestmentType.realEstate.displayName, 'Real Estate');
      });
    });
  });

  group('InvestmentEntity', () {
    final now = DateTime.now();

    test('isOpen should return true for open status', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: now,
        updatedAt: now,
      );

      expect(investment.isOpen, true);
      expect(investment.isClosed, false);
    });

    test('isClosed should return true for closed status', () {
      final investment = InvestmentEntity(
        id: '1',
        name: 'Test Investment',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.closed,
        createdAt: now,
        closedAt: now,
        updatedAt: now,
      );

      expect(investment.isOpen, false);
      expect(investment.isClosed, true);
    });

    test('copyWith should create copy with updated fields', () {
      final original = InvestmentEntity(
        id: '1',
        name: 'Original',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        notes: 'Original notes',
        createdAt: now,
        updatedAt: now,
      );

      final copy = original.copyWith(
        name: 'Updated',
        status: InvestmentStatus.closed,
        closedAt: now,
      );

      expect(copy.id, '1');
      expect(copy.name, 'Updated');
      expect(copy.status, InvestmentStatus.closed);
      expect(copy.closedAt, now);
      expect(copy.type, InvestmentType.p2pLending); // Unchanged
      expect(copy.notes, 'Original notes'); // Unchanged
    });

    test('equality should work correctly', () {
      final investment1 = InvestmentEntity(
        id: '1',
        name: 'Test',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: now,
        updatedAt: now,
      );

      final investment2 = InvestmentEntity(
        id: '1',
        name: 'Test',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: now,
        updatedAt: now,
      );

      final investment3 = InvestmentEntity(
        id: '2', // Different ID
        name: 'Test',
        type: InvestmentType.p2pLending,
        status: InvestmentStatus.open,
        createdAt: now,
        updatedAt: now,
      );

      expect(investment1, investment2);
      expect(investment1, isNot(investment3));
    });
  });
}

