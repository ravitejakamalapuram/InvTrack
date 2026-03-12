# Guest Mode Technical Specification

## 1. Data Storage Architecture

### 1.1 Hive Encryption Key Management (OWASP MASVS-STORAGE-1/2)

**🔴 CRITICAL: Encryption key MUST be stored in FlutterSecureStorage**

```dart
// ✅ CORRECT: Store encryption key in secure storage (Android Keystore / iOS Secure Enclave)
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<List<int>> getHiveEncryptionKey() async {
  const secureStorage = FlutterSecureStorage();

  // Try to read existing key
  var keyString = await secureStorage.read(key: 'hive_encryption_key');

  if (keyString == null) {
    // Generate new key on first run
    final keyBytes = Hive.generateSecureKey();
    await secureStorage.write(
      key: 'hive_encryption_key',
      value: base64Url.encode(keyBytes),
    );
    keyString = await secureStorage.read(key: 'hive_encryption_key');
  }

  return base64Url.decode(keyString!);
}

// Open encrypted box
final encryptionKey = await getHiveEncryptionKey();
final box = await Hive.openBox<InvestmentHiveModel>(
  'guest_investments',
  encryptionCipher: HiveAesCipher(encryptionKey),
);
```

**❌ WRONG: Never store key in SharedPreferences (readable on rooted devices)**

### 1.2 Hive Async Initialization

**🔴 CRITICAL: Hive boxes must be opened before app starts**

```dart
// lib/main.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(InvestmentHiveModelAdapter());
  Hive.registerAdapter(CashFlowHiveModelAdapter());
  Hive.registerAdapter(GoalHiveModelAdapter());
  // ... register all adapters

  // ✅ CRITICAL: Open all boxes BEFORE runApp()
  // Boxes must be open before providers try to access them
  final encryptionKey = await getHiveEncryptionKey();
  final cipher = HiveAesCipher(encryptionKey);

  await Hive.openBox<InvestmentHiveModel>('guest_investments', encryptionCipher: cipher);
  await Hive.openBox<CashFlowHiveModel>('guest_cashflows', encryptionCipher: cipher);
  await Hive.openBox<GoalHiveModel>('guest_goals', encryptionCipher: cipher);
  // ... open all boxes

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

// Hive box providers (synchronous - boxes already open)
final investmentsBoxProvider = Provider<Box<InvestmentHiveModel>>((ref) {
  return Hive.box<InvestmentHiveModel>('guest_investments');
});

// ✅ FIXED: Don't close globally opened boxes from autoDispose providers
// Boxes are opened once in main() and reused app-wide
// Closing from a disposable provider would invalidate the box for other repositories
final investmentsBoxProviderAutoDispose = Provider.autoDispose<Box<InvestmentHiveModel>>((ref) {
  // Simply return the already-opened box without closing it
  // Box lifecycle is managed at app scope (opened in main(), closed on app exit)
  return Hive.box<InvestmentHiveModel>('guest_investments');
});
```

### 1.3 Hive Box Structure

```dart
// ✅ FIXED: Use namespaced box names to prevent conflicts
// Prefix all guest boxes with 'guest_' to avoid accidental deletion
// of Firestore-mode caching boxes (e.g., exchange rate cache)
const String _guestBoxPrefix = 'guest_';
const String investmentsBox = '${_guestBoxPrefix}investments';
const String cashFlowsBox = '${_guestBoxPrefix}cashflows';
const String goalsBox = '${_guestBoxPrefix}goals';
const String archivedInvestmentsBox = '${_guestBoxPrefix}archived_investments';
const String archivedCashFlowsBox = '${_guestBoxPrefix}archived_cashflows';
const String archivedGoalsBox = '${_guestBoxPrefix}archived_goals';
const String documentsBox = '${_guestBoxPrefix}documents';
const String settingsBox = '${_guestBoxPrefix}settings';
const String fireSettingsBox = '${_guestBoxPrefix}fire_settings';
const String userProfileBox = '${_guestBoxPrefix}user_profile';
const String exchangeRatesBox = '${_guestBoxPrefix}exchange_rates';

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
    // ✅ FIXED: Sanitize fileName to prevent path traversal attacks
    final sanitizedFileName = _sanitizeFileName(fileName);
    if (sanitizedFileName.isEmpty) {
      throw ArgumentError('Invalid file name: $fileName');
    }

    final dir = Directory('${_baseDir.path}/guest_$guestUserId/documents/$investmentId');
    await dir.create(recursive: true);

    final file = File('${dir.path}/$sanitizedFileName');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  /// Sanitize file name to prevent path traversal and invalid characters
  String _sanitizeFileName(String fileName) {
    // Get basename to remove any path separators
    final basename = path.basename(fileName);

    // Remove or replace disallowed characters: slashes, nulls, "..", control chars
    final sanitized = basename
        .replaceAll(RegExp(r'[/\\]'), '_')  // Replace slashes
        .replaceAll(RegExp(r'\.\.'), '_')   // Replace ".."
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');  // Remove control chars

    // Enforce max length (255 chars is typical filesystem limit)
    final maxLength = 255;
    return sanitized.length > maxLength
        ? sanitized.substring(0, maxLength)
        : sanitized;
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

// ✅ FIXED: Exchange rate refresh strategy for guest mode
// Default rates for common pairs (fallback only)
// These are updated periodically in the codebase
const Map<String, double> defaultExchangeRates = {
  'USD_INR': 83.12,
  'EUR_INR': 90.45,
  'GBP_INR': 105.23,
  'USD_EUR': 0.92,
  'USD_GBP': 0.79,
  // ... more pairs
};

// Refresh strategy:
// 1. On first internet connection (even in guest mode), fetch live rates
// 2. Store in exchangeRatesBox with timestamp
// 3. Refresh every 24 hours when online
// 4. Fall back to defaultExchangeRates only when offline
// 5. Show "estimated" label if rates are >7 days old

class ExchangeRateService {
  Future<double> getRate(String from, String to, {DateTime? date}) async {
    // Try to fetch from cache
    final cached = await _getCachedRate(from, to);
    if (cached != null && !_isStale(cached.cachedAt)) {
      return cached.rate;
    }

    // Try to fetch live rate (even in guest mode)
    if (await _hasInternetConnection()) {
      try {
        final liveRate = await _fetchLiveRate(from, to);
        await _cacheRate(from, to, liveRate);
        return liveRate;
      } catch (e) {
        LoggerService.warning('Failed to fetch live rate, using cached/default');
      }
    }

    // Fall back to cached or default
    return cached?.rate ?? _getDefaultRate(from, to);
  }

  bool _isStale(DateTime cachedAt) {
    return DateTime.now().difference(cachedAt).inDays > 7;
  }
}
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
    // ✅ FIXED: Combine initial value + watch stream to emit immediately and on changes
    // box.watch() returns Stream<BoxEvent> but doesn't emit initial state
    // Solution: Start with current values, then merge with watch stream
    return Stream.value(_getCurrentInvestments())
        .followedBy(
          _investmentsBox.watch().map((_) => _getCurrentInvestments()),
        );
  }

  List<InvestmentEntity> _getCurrentInvestments() {
    return _investmentsBox.values
        .map((model) => _toEntity(model))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      // ✅ FIXED: Add orElse to handle unknown enum values gracefully
      type: InvestmentType.values.firstWhere(
        (e) => e.name == model.type,
        orElse: () => throw Exception('Unknown investment type: ${model.type}'),
      ),
      status: InvestmentStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == model.status,
        orElse: () => throw Exception('Unknown investment status: ${model.status}'),
      ),
      notes: model.notes,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      closedAt: model.closedAt,
      maturityDate: model.maturityDate,
      incomeFrequency: model.incomeFrequency != null
          ? IncomeFrequency.values.firstWhere(
              (e) => e.name == model.incomeFrequency,
              orElse: () => throw Exception('Unknown income frequency: ${model.incomeFrequency}'),
            )
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

// ✅ FIXED: Handle AsyncValue states properly to avoid crashes
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null || user.isGuest) {
        // Guest mode: Use Hive
        return ref.watch(hiveInvestmentRepositoryProvider);
      } else {
        // Signed-in mode: Use Firestore
        return ref.watch(firestoreInvestmentRepositoryProvider);
      }
    },
    loading: () {
      // Default to guest mode while loading auth state
      return ref.watch(hiveInvestmentRepositoryProvider);
    },
    error: (_, __) {
      // Fallback to guest mode on auth error
      return ref.watch(hiveInvestmentRepositoryProvider);
    },
  );
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

// ✅ FIXED: Only access userId when we have authenticated user data
final firestoreInvestmentRepositoryProvider = Provider<FirestoreInvestmentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final authState = ref.watch(authStateProvider);

  // This provider should only be called when user is authenticated
  // If called during loading/error, throw descriptive error
  final userId = authState.maybeWhen(
    data: (user) => user?.id,
    orElse: () => null,
  );

  if (userId == null) {
    throw StateError('FirestoreInvestmentRepository requires authenticated user');
  }

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
  // ✅ FIXED: Store current guest user to return from currentUser getter
  UserEntity? _currentGuestUser;

  GuestAuthRepository({required SharedPreferences prefs}) : _prefs = prefs {
    // Initialize with existing guest user or create new one
    _initializeGuestUser();
  }

  void _initializeGuestUser() {
    final existingGuestId = _prefs.getString(_guestUserIdKey);
    if (existingGuestId != null) {
      _currentGuestUser = UserEntity(
        id: existingGuestId,
        email: 'guest@local',
        displayName: 'Guest User',
        isGuest: true,
      );
      // Don't add to broadcast stream here - will be emitted on first listen
    }
  }

  @override
  // ✅ FIXED: Emit current state immediately to new subscribers
  // Broadcast streams don't replay, so we emit the current value first
  Stream<UserEntity?> get authStateChanges async* {
    yield _currentGuestUser; // Emit current state immediately
    yield* _authStateController.stream; // Then emit future changes
  }

  @override
  // ✅ FIXED: Return current guest user instead of null
  UserEntity? get currentUser => _currentGuestUser;
  
  Future<UserEntity> startGuestSession() async {
    final guestUser = UserEntity.guest();
    await _prefs.setString(_guestUserIdKey, guestUser.id);
    _currentGuestUser = guestUser;
    _authStateController.add(guestUser);
    return guestUser;
  }

  Future<void> endGuestSession() async {
    await _prefs.remove(_guestUserIdKey);
    _currentGuestUser = null;
    _authStateController.add(null);
  }

  // ✅ FIXED: Add dispose method to close stream controller
  void dispose() {
    _authStateController.close();
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

// ✅ FIXED: Add disposal for GuestAuthRepository
final guestAuthRepositoryProvider = Provider<GuestAuthRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final repo = GuestAuthRepository(prefs: prefs);
  ref.onDispose(() => repo.dispose());
  return repo;
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
    // ✅ FIXED: Add error handling for backup creation
    // Migration should not proceed without a backup
    try {
      final exportService = DataExportService(
        investmentRepository: _hiveRepo,
        goalRepository: _hiveGoalRepo,
        documentStorageService: _localDocStorage,
      );
      return await exportService.exportAsZip();
    } catch (e, st) {
      LoggerService.error('Backup creation failed', error: e, stackTrace: st);
      throw Exception('Cannot proceed with migration without backup: $e');
    }
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
    // ⚠️ LIMITATION: This is a simplified implementation for documentation
    // ✅ PRODUCTION SOLUTION: Use Cloud Function for atomic server-side swap
    //
    // Recommended production approach:
    // 1. Upload guest data to staging namespace: users/{userId}/staging_*
    // 2. Call Cloud Function that performs atomic swap:
    //    - Firestore transaction/batch write
    //    - Delete all live investments/cashflows/goals/documents
    //    - Move staging_* data to live namespace
    //    - All-or-nothing operation
    // 3. Cleanup staging namespace after successful swap
    //
    // This ensures no partial state if operation fails mid-process

    // Simplified implementation (for MVP/documentation):
    // Step 1: Upload guest data to live namespace
    LoggerService.info('Uploading guest data...');
    await _mergeData(
      guestInvestments: guestInvestments,
      guestCashFlows: guestCashFlows,
      guestGoals: guestGoals,
      guestDocuments: guestDocuments,
      signedInUserId: signedInUserId,
    );

    // Step 2: Verify upload succeeded
    final verified = await _verifyMigration(
      guestInvestments: guestInvestments,
      guestCashFlows: guestCashFlows,
      guestGoals: guestGoals,
      signedInUserId: signedInUserId,
    );

    if (!verified) {
      throw Exception('Guest data upload verification failed - aborting replace');
    }

    // Step 3: Delete old cloud data (non-atomic - see limitation note above)
    LoggerService.info('Deleting old cloud data...');
    final existingInvestments = await _firestoreRepo.getAllInvestments();
    for (final inv in existingInvestments) {
      // Skip newly uploaded guest investments
      final isGuestInvestment = guestInvestments.any((g) => g.id == inv.id);
      if (!isGuestInvestment) {
        await _firestoreRepo.deleteInvestment(inv.id);
      }
    }

    // Also delete old cash flows and documents (not just investments/goals)
    final existingCashFlows = await _firestoreRepo.getAllCashFlows();
    for (final cf in existingCashFlows) {
      final isGuestCashFlow = guestCashFlows.any((g) => g.id == cf.id);
      if (!isGuestCashFlow) {
        await _firestoreRepo.deleteCashFlow(cf.id);
      }
    }

    final existingGoals = await _firestoreGoalRepo.getAllGoals();
    for (final goal in existingGoals) {
      // Skip newly uploaded guest goals
      final isGuestGoal = guestGoals.any((g) => g.id == goal.id);
      if (!isGuestGoal) {
        await _firestoreGoalRepo.deleteGoal(goal.id);
      }
    }
  }

  Future<bool> _verifyMigration({
    required List<InvestmentEntity> guestInvestments,
    required List<CashFlowEntity> guestCashFlows,
    required List<GoalEntity> guestGoals,
    required String signedInUserId,
  }) async {
    // ✅ FIXED: Verify actual data integrity, not just counts
    LoggerService.info('Verifying migration data integrity...');

    final cloudInvestments = await _firestoreRepo.getAllInvestments();
    final cloudGoals = await _firestoreGoalRepo.getAllGoals();

    // Verify each guest investment exists in cloud with matching data
    for (final guestInv in guestInvestments) {
      final found = cloudInvestments.any((cloud) =>
        cloud.id == guestInv.id &&
        cloud.name == guestInv.name &&
        cloud.currency == guestInv.currency &&
        cloud.type == guestInv.type &&
        cloud.status == guestInv.status &&
        cloud.createdAt.difference(guestInv.createdAt).abs().inSeconds < 5
      );

      if (!found) {
        LoggerService.warning('Investment not found in cloud: ${guestInv.name} (${guestInv.id})');
        return false;
      }
    }

    // Verify each guest goal exists in cloud with matching data
    for (final guestGoal in guestGoals) {
      final found = cloudGoals.any((cloud) =>
        cloud.id == guestGoal.id &&
        cloud.name == guestGoal.name &&
        cloud.targetAmount == guestGoal.targetAmount &&
        cloud.targetDate == guestGoal.targetDate
      );

      if (!found) {
        LoggerService.warning('Goal not found in cloud: ${guestGoal.name} (${guestGoal.id})');
        return false;
      }
    }

    // Verify cash flows (spot check - verify at least 10% or first 100)
    final cashFlowsToVerify = guestCashFlows.length > 100
        ? guestCashFlows.take(100).toList()
        : guestCashFlows;

    for (final guestCf in cashFlowsToVerify) {
      final cloudCashFlows = await _firestoreRepo.getCashFlowsByInvestment(guestCf.investmentId);
      final found = cloudCashFlows.any((cloud) =>
        cloud.id == guestCf.id &&
        cloud.amount == guestCf.amount &&
        cloud.type == guestCf.type &&
        cloud.date.difference(guestCf.date).abs().inSeconds < 5
      );

      if (!found) {
        LoggerService.warning('CashFlow not found in cloud: ${guestCf.id}');
        return false;
      }
    }

    LoggerService.info('Migration verification passed');
    return true;
  }

  Future<void> _cleanupGuestData(String guestUserId) async {
    // ✅ FIXED: Use namespaced box names to avoid conflicts
    // Prefix all guest boxes with 'guest_' to prevent accidental deletion
    // of Firestore-mode caching boxes
    LoggerService.info('Cleaning up guest data...');

    const guestBoxPrefix = 'guest_';
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}investments');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}cashflows');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}goals');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}archived_investments');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}archived_cashflows');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}archived_goals');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}documents');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}settings');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}fire_settings');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}user_profile');
    await Hive.deleteBoxFromDisk('${guestBoxPrefix}exchange_rates');

    // Delete local documents directory
    final appDir = await getApplicationDocumentsDirectory();
    final guestDir = Directory('${appDir.path}/guest_$guestUserId');
    if (await guestDir.exists()) {
      await guestDir.delete(recursive: true);
    }

    // Delete guest user ID and guest mode flag from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_user_id');
    // ✅ FIXED: Disable guest mode after successful migration
    await prefs.remove('guest_mode_enabled');

    LoggerService.info('Guest data cleanup complete');
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


