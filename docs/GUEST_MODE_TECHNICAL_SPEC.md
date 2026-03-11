# Guest Mode Technical Specification

## 1. Data Storage Architecture

### 1.1 Hive Box Structure

```dart
// Box names
const String investmentsBox = 'investments';
const String cashFlowsBox = 'cashflows';
const String goalsBox = 'goals';
const String archivedInvestmentsBox = 'archived_investments';
const String archivedCashFlowsBox = 'archived_cashflows';
const String archivedGoalsBox = 'archived_goals';
const String documentsBox = 'documents';
const String settingsBox = 'settings';
const String fireSettingsBox = 'fire_settings';
const String userProfileBox = 'user_profile';
const String exchangeRatesBox = 'exchange_rates';

// Hive Type Adapters
@HiveType(typeId: 0)
class InvestmentHiveModel extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String type;
  @HiveField(3) String status;
  @HiveField(4) String? notes;
  @HiveField(5) DateTime createdAt;
  @HiveField(6) DateTime updatedAt;
  @HiveField(7) DateTime? closedAt;
  @HiveField(8) DateTime? maturityDate;
  @HiveField(9) String? incomeFrequency;
  @HiveField(10) bool isArchived;
  @HiveField(11) DateTime? startDate;
  @HiveField(12) double? expectedRate;
  @HiveField(13) int? tenureMonths;
  @HiveField(14) String? platform;
  @HiveField(15) String? interestPayoutMode;
  @HiveField(16) bool? autoRenewal;
  @HiveField(17) String? riskLevel;
  @HiveField(18) String? compoundingFrequency;
  @HiveField(19) String currency;
}

@HiveType(typeId: 1)
class CashFlowHiveModel extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String investmentId;
  @HiveField(2) String type;
  @HiveField(3) double amount;
  @HiveField(4) String currency;
  @HiveField(5) DateTime date;
  @HiveField(6) String? notes;
  @HiveField(7) DateTime createdAt;
}

// Similar adapters for Goal, Document, Settings, etc.
```

### 1.2 Document Storage

```dart
// Guest mode: Store in app documents directory
// Path: {appDocumentsDir}/guest_{userId}/documents/{investmentId}/{fileName}

class LocalDocumentStorageService {
  final Directory _baseDir;
  
  Future<String> saveDocument(
    String guestUserId,
    String investmentId,
    String fileName,
    Uint8List bytes,
  ) async {
    final dir = Directory('${_baseDir.path}/guest_$guestUserId/documents/$investmentId');
    await dir.create(recursive: true);
    
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    
    return file.path;
  }
  
  Future<Uint8List?> readDocument(String localPath) async {
    final file = File(localPath);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }
}
```

### 1.3 Exchange Rate Caching

```dart
// Guest mode: Cache exchange rates locally (no API calls)
// Use last known rates or default rates

@HiveType(typeId: 10)
class ExchangeRateHiveModel extends HiveObject {
  @HiveField(0) String fromCurrency;
  @HiveField(1) String toCurrency;
  @HiveField(2) double rate;
  @HiveField(3) DateTime cachedAt;
  @HiveField(4) bool isDefault; // true if using fallback rate
}

// Default rates for common pairs (updated periodically)
const Map<String, double> defaultExchangeRates = {
  'USD_INR': 83.12,
  'EUR_INR': 90.45,
  'GBP_INR': 105.23,
  'USD_EUR': 0.92,
  'USD_GBP': 0.79,
  // ... more pairs
};
```

## 2. Repository Implementations

### 2.1 Hive Investment Repository

```dart
class HiveInvestmentRepository implements InvestmentRepository {
  final Box<InvestmentHiveModel> _investmentsBox;
  final Box<InvestmentHiveModel> _archivedInvestmentsBox;
  final Box<CashFlowHiveModel> _cashFlowsBox;
  final Box<CashFlowHiveModel> _archivedCashFlowsBox;
  
  HiveInvestmentRepository({
    required Box<InvestmentHiveModel> investmentsBox,
    required Box<InvestmentHiveModel> archivedInvestmentsBox,
    required Box<CashFlowHiveModel> cashFlowsBox,
    required Box<CashFlowHiveModel> archivedCashFlowsBox,
  }) : _investmentsBox = investmentsBox,
       _archivedInvestmentsBox = archivedInvestmentsBox,
       _cashFlowsBox = cashFlowsBox,
       _archivedCashFlowsBox = archivedCashFlowsBox;
  
  @override
  Stream<List<InvestmentEntity>> watchAllInvestments() {
    return _investmentsBox.watch().map((_) {
      return _investmentsBox.values
          .map((model) => _toEntity(model))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }
  
  @override
  Future<void> createInvestment(InvestmentEntity investment) async {
    final model = _toModel(investment);
    await _investmentsBox.put(investment.id, model);
  }
  
  @override
  Future<void> updateInvestment(InvestmentEntity investment) async {
    final model = _toModel(investment);
    await _investmentsBox.put(investment.id, model);
  }
  
  @override
  Future<void> deleteInvestment(String id) async {
    await _investmentsBox.delete(id);
    // Also delete associated cashflows
    final cashFlowsToDelete = _cashFlowsBox.values
        .where((cf) => cf.investmentId == id)
        .map((cf) => cf.id)
        .toList();
    await _cashFlowsBox.deleteAll(cashFlowsToDelete);
  }
  
  // ... other methods
  
  InvestmentEntity _toEntity(InvestmentHiveModel model) {
    return InvestmentEntity(
      id: model.id,
      name: model.name,
      type: InvestmentType.values.firstWhere((e) => e.name == model.type),
      status: InvestmentStatus.values.firstWhere((e) => e.name.toUpperCase() == model.status),
      notes: model.notes,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      closedAt: model.closedAt,
      maturityDate: model.maturityDate,
      incomeFrequency: model.incomeFrequency != null
          ? IncomeFrequency.values.firstWhere((e) => e.name == model.incomeFrequency)
          : null,
      isArchived: model.isArchived,
      startDate: model.startDate,
      expectedRate: model.expectedRate,
      tenureMonths: model.tenureMonths,
      platform: model.platform,
      interestPayoutMode: InterestPayoutMode.fromString(model.interestPayoutMode),
      autoRenewal: model.autoRenewal,
      riskLevel: RiskLevel.fromString(model.riskLevel),
      compoundingFrequency: CompoundingFrequency.fromString(model.compoundingFrequency),
      currency: model.currency,
    );
  }
  
  InvestmentHiveModel _toModel(InvestmentEntity entity) {
    return InvestmentHiveModel()
      ..id = entity.id
      ..name = entity.name
      ..type = entity.type.name
      ..status = entity.status.name.toUpperCase()
      ..notes = entity.notes
      ..createdAt = entity.createdAt
      ..updatedAt = entity.updatedAt
      ..closedAt = entity.closedAt
      ..maturityDate = entity.maturityDate
      ..incomeFrequency = entity.incomeFrequency?.name
      ..isArchived = entity.isArchived
      ..startDate = entity.startDate
      ..expectedRate = entity.expectedRate
      ..tenureMonths = entity.tenureMonths
      ..platform = entity.platform
      ..interestPayoutMode = entity.interestPayoutMode?.name
      ..autoRenewal = entity.autoRenewal
      ..riskLevel = entity.riskLevel?.name
      ..compoundingFrequency = entity.compoundingFrequency?.name
      ..currency = entity.currency;
  }
}
```

### 2.2 Repository Provider Selection

```dart
// lib/core/di/repository_module.dart

final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  
  if (user == null || user.isGuest) {
    // Guest mode: Use Hive
    return ref.watch(hiveInvestmentRepositoryProvider);
  } else {
    // Signed-in mode: Use Firestore
    return ref.watch(firestoreInvestmentRepositoryProvider);
  }
});

final hiveInvestmentRepositoryProvider = Provider<HiveInvestmentRepository>((ref) {
  final investmentsBox = ref.watch(investmentsBoxProvider);
  final archivedInvestmentsBox = ref.watch(archivedInvestmentsBoxProvider);
  final cashFlowsBox = ref.watch(cashFlowsBoxProvider);
  final archivedCashFlowsBox = ref.watch(archivedCashFlowsBoxProvider);
  
  return HiveInvestmentRepository(
    investmentsBox: investmentsBox,
    archivedInvestmentsBox: archivedInvestmentsBox,
    cashFlowsBox: cashFlowsBox,
    archivedCashFlowsBox: archivedCashFlowsBox,
  );
});

final firestoreInvestmentRepositoryProvider = Provider<FirestoreInvestmentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);
  final userId = authState.value!.id;
  
  return FirestoreInvestmentRepository(
    firestore: firestore,
    userId: userId,
  );
});
```

## 3. Authentication Changes

### 3.1 Guest User Entity

```dart
// lib/features/auth/domain/entities/user_entity.dart

class UserEntity {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest;
  
  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isGuest = false,
  });
  
  factory UserEntity.guest() {
    final guestId = 'guest_${const Uuid().v4()}';
    return UserEntity(
      id: guestId,
      email: 'guest@local',
      displayName: 'Guest User',
      photoUrl: null,
      isGuest: true,
    );
  }
  
  bool get isSignedIn => !isGuest;
}
```

### 3.2 Guest Auth Repository

```dart
// lib/features/auth/data/repositories/guest_auth_repository.dart

class GuestAuthRepository implements AuthRepository {
  final SharedPreferences _prefs;
  static const String _guestUserIdKey = 'guest_user_id';
  
  final _authStateController = StreamController<UserEntity?>.broadcast();
  
  GuestAuthRepository({required SharedPreferences prefs}) : _prefs = prefs {
    // Initialize with existing guest user or create new one
    _initializeGuestUser();
  }
  
  void _initializeGuestUser() {
    final existingGuestId = _prefs.getString(_guestUserIdKey);
    if (existingGuestId != null) {
      _authStateController.add(UserEntity(
        id: existingGuestId,
        email: 'guest@local',
        displayName: 'Guest User',
        isGuest: true,
      ));
    }
  }
  
  @override
  Stream<UserEntity?> get authStateChanges => _authStateController.stream;
  
  @override
  UserEntity? get currentUser => null; // Guest has no persistent user
  
  Future<UserEntity> startGuestSession() async {
    final guestUser = UserEntity.guest();
    await _prefs.setString(_guestUserIdKey, guestUser.id);
    _authStateController.add(guestUser);
    return guestUser;
  }
  
  Future<void> endGuestSession() async {
    await _prefs.remove(_guestUserIdKey);
    _authStateController.add(null);
  }
  
  @override
  Future<UserEntity?> signInWithGoogle() async {
    throw UnimplementedError('Use FirebaseAuthRepository for sign-in');
  }
  
  @override
  Future<void> signOut() async {
    await endGuestSession();
  }
  
  @override
  Future<String?> getAuthToken() async => null;
  
  @override
  Future<void> deleteAccount() async {
    await endGuestSession();
  }
}
```

### 3.3 Auth State Provider Update

```dart
// lib/features/auth/presentation/providers/auth_provider.dart

final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final guestMode = ref.watch(guestModeEnabledProvider);

  if (guestMode) {
    final guestRepo = ref.watch(guestAuthRepositoryProvider);
    return guestRepo.authStateChanges;
  } else {
    final firebaseRepo = ref.watch(authRepositoryProvider);
    return firebaseRepo.authStateChanges;
  }
});

final guestModeEnabledProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('guest_mode_enabled') ?? false;
});
```

## 4. Data Migration Service

### 4.1 Migration Service Implementation

```dart
// lib/features/auth/data/services/guest_data_migration_service.dart

class GuestDataMigrationService {
  final HiveInvestmentRepository _hiveRepo;
  final FirestoreInvestmentRepository _firestoreRepo;
  final HiveGoalRepository _hiveGoalRepo;
  final FirestoreGoalRepository _firestoreGoalRepo;
  final LocalDocumentStorageService _localDocStorage;
  final FirebaseDocumentStorageService _cloudDocStorage;

  GuestDataMigrationService({
    required HiveInvestmentRepository hiveRepo,
    required FirestoreInvestmentRepository firestoreRepo,
    required HiveGoalRepository hiveGoalRepo,
    required FirestoreGoalRepository firestoreGoalRepo,
    required LocalDocumentStorageService localDocStorage,
    required FirebaseDocumentStorageService cloudDocStorage,
  }) : _hiveRepo = hiveRepo,
       _firestoreRepo = firestoreRepo,
       _hiveGoalRepo = hiveGoalRepo,
       _firestoreGoalRepo = firestoreGoalRepo,
       _localDocStorage = localDocStorage,
       _cloudDocStorage = cloudDocStorage;

  Future<MigrationResult> migrateToCloud({
    required String guestUserId,
    required String signedInUserId,
    required MigrationStrategy strategy,
  }) async {
    LoggerService.info('Starting guest data migration', metadata: {
      'guestUserId': guestUserId,
      'signedInUserId': signedInUserId,
      'strategy': strategy.name,
    });

    try {
      // 1. Export guest data for backup
      final backupPath = await _createBackup(guestUserId);

      // 2. Fetch all guest data
      final guestInvestments = await _hiveRepo.getAllInvestments();
      final guestCashFlows = <CashFlowEntity>[];
      for (final inv in guestInvestments) {
        final cfs = await _hiveRepo.getCashFlowsByInvestment(inv.id);
        guestCashFlows.addAll(cfs);
      }
      final guestGoals = await _hiveGoalRepo.getAllGoals();
      final guestDocuments = await _hiveRepo.getAllDocuments();

      // 3. Handle strategy
      if (strategy == MigrationStrategy.merge) {
        // Merge with existing cloud data
        await _mergeData(
          guestInvestments: guestInvestments,
          guestCashFlows: guestCashFlows,
          guestGoals: guestGoals,
          guestDocuments: guestDocuments,
          signedInUserId: signedInUserId,
        );
      } else if (strategy == MigrationStrategy.replace) {
        // Replace cloud data with guest data
        await _replaceData(
          guestInvestments: guestInvestments,
          guestCashFlows: guestCashFlows,
          guestGoals: guestGoals,
          guestDocuments: guestDocuments,
          signedInUserId: signedInUserId,
        );
      }

      // 4. Verify migration
      final verified = await _verifyMigration(
        guestInvestments: guestInvestments,
        guestCashFlows: guestCashFlows,
        guestGoals: guestGoals,
        signedInUserId: signedInUserId,
      );

      if (!verified) {
        throw Exception('Migration verification failed');
      }

      // 5. Cleanup guest data
      await _cleanupGuestData(guestUserId);

      LoggerService.info('Guest data migration completed successfully');

      return MigrationResult(
        success: true,
        investmentsMigrated: guestInvestments.length,
        cashFlowsMigrated: guestCashFlows.length,
        goalsMigrated: guestGoals.length,
        documentsMigrated: guestDocuments.length,
        backupPath: backupPath,
      );
    } catch (e, st) {
      LoggerService.error('Guest data migration failed', error: e, stackTrace: st);
      return MigrationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<String> _createBackup(String guestUserId) async {
    // Create ZIP backup of guest data
    final exportService = DataExportService(
      investmentRepository: _hiveRepo,
      goalRepository: _hiveGoalRepo,
      documentStorageService: _localDocStorage,
    );
    return await exportService.exportAsZip();
  }

  Future<void> _mergeData({
    required List<InvestmentEntity> guestInvestments,
    required List<CashFlowEntity> guestCashFlows,
    required List<GoalEntity> guestGoals,
    required List<DocumentEntity> guestDocuments,
    required String signedInUserId,
  }) async {
    // Bulk import to Firestore (appends to existing data)
    await _firestoreRepo.bulkImport(
      investments: guestInvestments,
      cashFlows: guestCashFlows,
    );

    for (final goal in guestGoals) {
      await _firestoreGoalRepo.createGoal(goal);
    }

    // Upload documents to Firebase Storage
    for (final doc in guestDocuments) {
      final bytes = await _localDocStorage.readDocument(doc.localPath);
      if (bytes != null) {
        await _cloudDocStorage.uploadDocument(
          investmentId: doc.investmentId,
          fileName: doc.fileName,
          bytes: bytes,
        );
      }
    }
  }

  Future<void> _replaceData({
    required List<InvestmentEntity> guestInvestments,
    required List<CashFlowEntity> guestCashFlows,
    required List<GoalEntity> guestGoals,
    required List<DocumentEntity> guestDocuments,
    required String signedInUserId,
  }) async {
    // Delete all existing cloud data
    final existingInvestments = await _firestoreRepo.getAllInvestments();
    for (final inv in existingInvestments) {
      await _firestoreRepo.deleteInvestment(inv.id);
    }

    final existingGoals = await _firestoreGoalRepo.getAllGoals();
    for (final goal in existingGoals) {
      await _firestoreGoalRepo.deleteGoal(goal.id);
    }

    // Import guest data
    await _mergeData(
      guestInvestments: guestInvestments,
      guestCashFlows: guestCashFlows,
      guestGoals: guestGoals,
      guestDocuments: guestDocuments,
      signedInUserId: signedInUserId,
    );
  }

  Future<bool> _verifyMigration({
    required List<InvestmentEntity> guestInvestments,
    required List<CashFlowEntity> guestCashFlows,
    required List<GoalEntity> guestGoals,
    required String signedInUserId,
  }) async {
    // Verify all data migrated successfully
    final cloudInvestments = await _firestoreRepo.getAllInvestments();
    final cloudGoals = await _firestoreGoalRepo.getAllGoals();

    // Check counts match (for merge strategy, should be >= guest count)
    if (cloudInvestments.length < guestInvestments.length) return false;
    if (cloudGoals.length < guestGoals.length) return false;

    return true;
  }

  Future<void> _cleanupGuestData(String guestUserId) async {
    // Delete all Hive boxes
    await Hive.deleteBoxFromDisk('investments');
    await Hive.deleteBoxFromDisk('cashflows');
    await Hive.deleteBoxFromDisk('goals');
    await Hive.deleteBoxFromDisk('archived_investments');
    await Hive.deleteBoxFromDisk('archived_cashflows');
    await Hive.deleteBoxFromDisk('archived_goals');
    await Hive.deleteBoxFromDisk('documents');

    // Delete local documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final guestDir = Directory('${appDir.path}/guest_$guestUserId');
    if (await guestDir.exists()) {
      await guestDir.delete(recursive: true);
    }
  }
}

enum MigrationStrategy {
  merge,   // Merge guest data with existing cloud data
  replace, // Replace cloud data with guest data
}

class MigrationResult {
  final bool success;
  final int investmentsMigrated;
  final int cashFlowsMigrated;
  final int goalsMigrated;
  final int documentsMigrated;
  final String? backupPath;
  final String? error;

  MigrationResult({
    required this.success,
    this.investmentsMigrated = 0,
    this.cashFlowsMigrated = 0,
    this.goalsMigrated = 0,
    this.documentsMigrated = 0,
    this.backupPath,
    this.error,
  });
}
```


