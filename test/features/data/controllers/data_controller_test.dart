import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:inv_tracker/core/services/connectivity_service.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/data/data/controllers/data_controller_impl.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/sync/domain/repositories/cloud_repository.dart';

// Mock classes
class MockInvestmentRepository extends Mock implements InvestmentRepository {}
class MockCloudRepository extends Mock implements CloudRepository {}
class MockConnectivityService extends Mock implements ConnectivityService {}
class MockAuthRepository extends Mock implements AuthRepository {}

// Fake classes for registerFallbackValue
class FakeInvestmentEntity extends Fake implements InvestmentEntity {}
class FakeCashFlowEntity extends Fake implements CashFlowEntity {}

void main() {
  late DataControllerImpl dataController;
  late MockInvestmentRepository mockLocalRepository;
  late MockCloudRepository mockCloudRepository;
  late MockConnectivityService mockConnectivityService;
  late MockAuthRepository mockAuthRepository;

  // Test fixtures
  final guestUser = const UserEntity(
    id: 'guest-123',
    email: 'guest@local',
    isGuest: true,
  );

  final googleUser = const UserEntity(
    id: 'google-123',
    email: 'user@gmail.com',
    displayName: 'Test User',
    isGuest: false,
  );

  final testInvestment = InvestmentEntity(
    id: 'inv-1',
    name: 'Test Investment',
    type: InvestmentType.fixedDeposit,
    status: InvestmentStatus.open,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );

  final testCashFlow = CashFlowEntity(
    id: 'cf-1',
    investmentId: 'inv-1',
    date: DateTime(2024, 1, 1),
    type: CashFlowType.invest,
    amount: 1000,
    createdAt: DateTime(2024, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(FakeInvestmentEntity());
    registerFallbackValue(FakeCashFlowEntity());
    registerFallbackValue(<InvestmentEntity>[]);
    registerFallbackValue(<CashFlowEntity>[]);
  });

  setUp(() {
    mockLocalRepository = MockInvestmentRepository();
    mockCloudRepository = MockCloudRepository();
    mockConnectivityService = MockConnectivityService();
    mockAuthRepository = MockAuthRepository();

    // Default behaviors for local repository
    when(() => mockLocalRepository.getAllInvestments())
        .thenAnswer((_) async => []);
    when(() => mockLocalRepository.getAllCashFlows())
        .thenAnswer((_) async => []);
    when(() => mockLocalRepository.watchAllInvestments())
        .thenAnswer((_) => Stream.value([]));
    when(() => mockLocalRepository.getInvestmentById(any()))
        .thenAnswer((_) async => null);
    when(() => mockLocalRepository.createInvestment(any()))
        .thenAnswer((_) async => {});
    when(() => mockLocalRepository.updateInvestment(any()))
        .thenAnswer((_) async => {});
    when(() => mockLocalRepository.deleteInvestment(any()))
        .thenAnswer((_) async => {});
    when(() => mockLocalRepository.addCashFlow(any()))
        .thenAnswer((_) async => {});
    when(() => mockLocalRepository.updateCashFlow(any()))
        .thenAnswer((_) async => {});
    when(() => mockLocalRepository.deleteCashFlow(any()))
        .thenAnswer((_) async => {});
    // Bulk cache operations
    when(() => mockLocalRepository.replaceAllData(any(), any()))
        .thenAnswer((_) async => {});
    when(() => mockLocalRepository.clearAllData())
        .thenAnswer((_) async => {});
    when(() => mockLocalRepository.hasData())
        .thenAnswer((_) async => false);
    when(() => mockLocalRepository.getInvestmentCount())
        .thenAnswer((_) async => 0);

    // Default behaviors for connectivity
    when(() => mockConnectivityService.hasInternetConnection())
        .thenAnswer((_) async => true);

    // Default behaviors for auth
    when(() => mockAuthRepository.signOut())
        .thenAnswer((_) async => {});
  });

  DataControllerImpl createController(UserEntity? user) {
    return DataControllerImpl(
      localRepository: mockLocalRepository,
      cloudRepository: mockCloudRepository,
      connectivityService: mockConnectivityService,
      authRepository: mockAuthRepository,
      currentUser: user,
    );
  }

  group('DataController - isGoogleUser', () {
    test('should return true for non-guest user', () {
      dataController = createController(googleUser);
      expect(dataController.isGoogleUser, true);
    });

    test('should return false for guest user', () {
      dataController = createController(guestUser);
      expect(dataController.isGoogleUser, false);
    });

    test('should return false when user is null', () {
      dataController = createController(null);
      expect(dataController.isGoogleUser, false);
    });
  });

  group('DataController - initialize', () {
    test('should return success for null user', () async {
      dataController = createController(null);
      final result = await dataController.initialize();
      expect(result.isSuccess, true);
    });

    test('should return success for guest user without fetching cloud', () async {
      dataController = createController(guestUser);
      final result = await dataController.initialize();

      expect(result.isSuccess, true);
      verifyNever(() => mockCloudRepository.fetchAllInvestments());
    });

    test('should fetch from cloud for Google user with internet', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockCloudRepository.fetchAllInvestments())
          .thenAnswer((_) async => [testInvestment]);
      when(() => mockCloudRepository.fetchAllCashFlows())
          .thenAnswer((_) async => [testCashFlow]);
      when(() => mockLocalRepository.deleteCashFlow(any()))
          .thenAnswer((_) async => {});
      when(() => mockLocalRepository.deleteInvestment(any()))
          .thenAnswer((_) async => {});
      when(() => mockLocalRepository.createInvestment(any()))
          .thenAnswer((_) async => {});
      when(() => mockLocalRepository.addCashFlow(any()))
          .thenAnswer((_) async => {});

      dataController = createController(googleUser);
      final result = await dataController.initialize();

      expect(result.isSuccess, true);
      verify(() => mockCloudRepository.fetchAllInvestments()).called(1);
      verify(() => mockCloudRepository.fetchAllCashFlows()).called(1);
    });

    test('should fail for Google user without internet', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => false);

      dataController = createController(googleUser);
      final result = await dataController.initialize();

      expect(result.isFailure, true);
      expect(result.error, 'No internet connection');
    });
  });

  group('DataController - addInvestment', () {
    test('should add to local only for guest user', () async {
      when(() => mockLocalRepository.createInvestment(any()))
          .thenAnswer((_) async => {});

      dataController = createController(guestUser);
      final result = await dataController.addInvestment(testInvestment);

      expect(result.isSuccess, true);
      verify(() => mockLocalRepository.createInvestment(testInvestment)).called(1);
      verifyNever(() => mockCloudRepository.addInvestment(any()));
    });

    test('should add to cloud first then local for Google user', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockCloudRepository.addInvestment(any()))
          .thenAnswer((_) async => testInvestment);
      when(() => mockLocalRepository.createInvestment(any()))
          .thenAnswer((_) async => {});

      dataController = createController(googleUser);
      final result = await dataController.addInvestment(testInvestment);

      expect(result.isSuccess, true);
      verifyInOrder([
        () => mockCloudRepository.addInvestment(testInvestment),
        () => mockLocalRepository.createInvestment(testInvestment),
      ]);
    });

    test('should fail for Google user without internet', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => false);

      dataController = createController(googleUser);
      final result = await dataController.addInvestment(testInvestment);

      expect(result.isFailure, true);
      expect(result.error, 'No internet connection');
      verifyNever(() => mockLocalRepository.createInvestment(any()));
    });

    test('should not update local if cloud fails for Google user', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockCloudRepository.addInvestment(any()))
          .thenThrow(Exception('Cloud error'));

      dataController = createController(googleUser);
      final result = await dataController.addInvestment(testInvestment);

      expect(result.isFailure, true);
      verifyNever(() => mockLocalRepository.createInvestment(any()));
    });
  });

  group('DataController - deleteInvestment', () {
    test('should delete from local only for guest user', () async {
      when(() => mockLocalRepository.deleteInvestment(any()))
          .thenAnswer((_) async => {});

      dataController = createController(guestUser);
      final result = await dataController.deleteInvestment('inv-1');

      expect(result.isSuccess, true);
      verify(() => mockLocalRepository.deleteInvestment('inv-1')).called(1);
      verifyNever(() => mockCloudRepository.deleteInvestment(any()));
    });

    test('should delete from cloud first then local for Google user', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockCloudRepository.deleteInvestment(any()))
          .thenAnswer((_) async => {});
      when(() => mockLocalRepository.deleteInvestment(any()))
          .thenAnswer((_) async => {});

      dataController = createController(googleUser);
      final result = await dataController.deleteInvestment('inv-1');

      expect(result.isSuccess, true);
      verifyInOrder([
        () => mockCloudRepository.deleteInvestment('inv-1'),
        () => mockLocalRepository.deleteInvestment('inv-1'),
      ]);
    });

    test('should fail for Google user without internet', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => false);

      dataController = createController(googleUser);
      final result = await dataController.deleteInvestment('inv-1');

      expect(result.isFailure, true);
      verifyNever(() => mockLocalRepository.deleteInvestment(any()));
    });
  });

  group('DataController - addCashFlow', () {
    test('should add to local only for guest user', () async {
      when(() => mockLocalRepository.addCashFlow(any()))
          .thenAnswer((_) async => {});

      dataController = createController(guestUser);
      final result = await dataController.addCashFlow(testCashFlow);

      expect(result.isSuccess, true);
      verify(() => mockLocalRepository.addCashFlow(testCashFlow)).called(1);
      verifyNever(() => mockCloudRepository.addCashFlow(any()));
    });

    test('should add to cloud first then local for Google user', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => true);
      when(() => mockCloudRepository.addCashFlow(any()))
          .thenAnswer((_) async => testCashFlow);
      when(() => mockLocalRepository.addCashFlow(any()))
          .thenAnswer((_) async => {});

      dataController = createController(googleUser);
      final result = await dataController.addCashFlow(testCashFlow);

      expect(result.isSuccess, true);
      verifyInOrder([
        () => mockCloudRepository.addCashFlow(testCashFlow),
        () => mockLocalRepository.addCashFlow(testCashFlow),
      ]);
    });

    test('should fail for Google user without internet', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => false);

      dataController = createController(googleUser);
      final result = await dataController.addCashFlow(testCashFlow);

      expect(result.isFailure, true);
      expect(result.error, 'No internet connection');
      verifyNever(() => mockLocalRepository.addCashFlow(any()));
    });
  });

  group('DataController - refreshFromCloud', () {
    test('should be no-op for guest user', () async {
      dataController = createController(guestUser);
      final result = await dataController.refreshFromCloud();

      expect(result.isSuccess, true);
      verifyNever(() => mockCloudRepository.fetchAllInvestments());
    });

    test('should fail without internet for Google user', () async {
      when(() => mockConnectivityService.hasInternetConnection())
          .thenAnswer((_) async => false);

      dataController = createController(googleUser);
      final result = await dataController.refreshFromCloud();

      expect(result.isFailure, true);
    });
  });

  group('DataController - closeInvestment', () {
    test('should update investment status to closed', () async {
      when(() => mockLocalRepository.getInvestmentById('inv-1'))
          .thenAnswer((_) async => testInvestment);
      when(() => mockLocalRepository.updateInvestment(any()))
          .thenAnswer((_) async => {});

      dataController = createController(guestUser);
      final result = await dataController.closeInvestment('inv-1');

      expect(result.isSuccess, true);
      final captured = verify(() => mockLocalRepository.updateInvestment(captureAny()))
          .captured.single as InvestmentEntity;
      expect(captured.status, InvestmentStatus.closed);
    });

    test('should fail if investment not found', () async {
      when(() => mockLocalRepository.getInvestmentById('inv-1'))
          .thenAnswer((_) async => null);

      dataController = createController(guestUser);
      final result = await dataController.closeInvestment('inv-1');

      expect(result.isFailure, true);
      expect(result.error, 'Investment not found');
    });
  });

  group('DataController - signOut', () {
    test('should clear local data and sign out', () async {
      when(() => mockLocalRepository.clearAllData())
          .thenAnswer((_) async => {});
      when(() => mockAuthRepository.signOut())
          .thenAnswer((_) async => {});

      dataController = createController(googleUser);
      final result = await dataController.signOut();

      expect(result.isSuccess, true);
      verify(() => mockLocalRepository.clearAllData()).called(1);
      verify(() => mockAuthRepository.signOut()).called(1);
    });
  });

  group('DataController - hasLocalData', () {
    test('should return true when investments exist', () async {
      when(() => mockLocalRepository.hasData())
          .thenAnswer((_) async => true);

      dataController = createController(guestUser);
      final hasData = await dataController.hasLocalData();

      expect(hasData, true);
    });

    test('should return false when no investments', () async {
      when(() => mockLocalRepository.hasData())
          .thenAnswer((_) async => false);

      dataController = createController(guestUser);
      final hasData = await dataController.hasLocalData();

      expect(hasData, false);
    });
  });
}

