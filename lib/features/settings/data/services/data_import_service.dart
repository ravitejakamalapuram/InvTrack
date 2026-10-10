import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/custom_type_catalog.dart';
import 'package:inv_tracker/features/investment/domain/repositories/custom_investment_type_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/core/utils/file_signature_utils.dart';
import 'package:uuid/uuid.dart';

// What an optional backup file that cannot be used adds to the warnings of a
// Merge import (a Replace import stops instead). They name the file kind only,
// never an investment, goal or amount (rule 7).
const _valuationsWarning =
    'Current values not imported: valuations.csv is invalid';
const _cashflowsArchivedWarning =
    'Archived cash flows not imported: cashflows_archived.csv is invalid';
const _goalsWarning = 'Goals not imported: goals.csv is invalid';
const _goalsArchivedWarning =
    'Archived goals not imported: goals_archived.csv is invalid';
const _customTypesWarning =
    'Custom types not imported: custom_types.json is invalid';

/// Import strategy options
enum ImportStrategy {
  merge, // Add to existing data (skip duplicates by investment name)
  replace, // Delete all existing data and replace with imported data
}

/// Result of a ZIP import operation
class ZipImportResult {
  final int investmentsImported;
  final int cashflowsImported;
  final int goalsImported;
  final int documentsImported;
  final bool fireSettingsImported;

  /// Dated valuations written (not part of [totalImported]).
  final int valuationsImported;
  final List<String> errors;
  final List<String> warnings;

  const ZipImportResult({
    required this.investmentsImported,
    required this.cashflowsImported,
    required this.goalsImported,
    required this.documentsImported,
    this.fireSettingsImported = false,
    this.valuationsImported = 0,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => !hasErrors;

  int get totalImported =>
      investmentsImported +
      cashflowsImported +
      goalsImported +
      documentsImported;
}

/// Service for importing user data from a ZIP file
class DataImportService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  final DocumentRepository _documentRepository;
  final DocumentStorageService _documentStorageService;
  final FireSettingsRepository? _fireSettingsRepository;
  final ValuationRepository? _valuationRepository;
  final CustomInvestmentTypeRepository? _customInvestmentTypeRepository;
  final PerformanceService _performanceService;

  static const _uuid = Uuid();

  DataImportService({
    required InvestmentRepository investmentRepository,
    required GoalRepository goalRepository,
    required DocumentRepository documentRepository,
    required DocumentStorageService documentStorageService,
    FireSettingsRepository? fireSettingsRepository,
    ValuationRepository? valuationRepository,
    CustomInvestmentTypeRepository? customInvestmentTypeRepository,
    required PerformanceService performanceService,
  }) : _investmentRepository = investmentRepository,
       _goalRepository = goalRepository,
       _documentRepository = documentRepository,
       _documentStorageService = documentStorageService,
       _fireSettingsRepository = fireSettingsRepository,
       _valuationRepository = valuationRepository,
       _customInvestmentTypeRepository = customInvestmentTypeRepository,
       _performanceService = performanceService;

  /// Import data from a ZIP file.
  ///
  /// Rows, investments and goals with no currency (backups made before
  /// multi-currency support) take [baseCurrency], the user's base currency.
  ///
  /// If any file in the backup is damaged, [ImportStrategy.replace] returns an
  /// error that names the file and changes nothing. [ImportStrategy.merge]
  /// skips that file with a warning and imports the rest.
  Future<ZipImportResult> importFromZip(
    Uint8List zipBytes,
    ImportStrategy strategy, {
    required String baseCurrency,
  }) async {
    return _performanceService.trackOperation(
      'data_import',
      () => _importFromZipInternal(zipBytes, strategy, baseCurrency),
      metrics: {'zip_size_kb': (zipBytes.length / 1024).round()},
      attributes: {'strategy': strategy.name},
    );
  }

  /// Internal import implementation with performance tracking
  Future<ZipImportResult> _importFromZipInternal(
    Uint8List zipBytes,
    ImportStrategy strategy,
    String baseCurrency,
  ) async {
    LoggerService.info(
      'Starting ZIP import',
      metadata: {'strategy': strategy.name},
    );

    final errors = <String>[];
    final warnings = <String>[];

    // 1. Decode ZIP archive
    Archive archive;
    try {
      // Security: Enable CRC verification to protect against malformed or corrupted ZIP file extraction.
      archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    } catch (_) {
      return ZipImportResult(
        investmentsImported: 0,
        cashflowsImported: 0,
        goalsImported: 0,
        documentsImported: 0,
        // The exception can quote the file, so it is left out (rule 7).
        errors: ['Invalid ZIP file'],
      );
    }

    // 2. Find and parse metadata.json
    final metadataFile = archive.findFile('metadata.json');
    if (metadataFile == null) {
      return ZipImportResult(
        investmentsImported: 0,
        cashflowsImported: 0,
        goalsImported: 0,
        documentsImported: 0,
        errors: ['Invalid ZIP file: metadata.json not found'],
      );
    }

    Map<String, dynamic> metadata;
    // Read here, so a metadata.json of the wrong shape fails before Replace
    // deletes anything.
    List<dynamic> documentsList;
    try {
      metadata = jsonDecode(utf8.decode(metadataFile.content as List<int>));
      documentsList = metadata['documents'] as List<dynamic>? ?? [];
    } catch (_) {
      return ZipImportResult(
        investmentsImported: 0,
        cashflowsImported: 0,
        goalsImported: 0,
        documentsImported: 0,
        // The exception quotes the text it could not parse: document and
        // investment names (rule 7).
        errors: ['Failed to parse metadata.json'],
      );
    }

    // 3. Read and parse every file the import uses BEFORE anything is deleted
    // (#956). Replace used to delete first, so a file that could not be read
    // or parsed failed after the account was wiped. Now cashflows.csv, which
    // holds the investments, must be readable or nothing changes. Any other
    // damaged file stops Replace too: the settings screen shows no warnings
    // (#959), so skipping it would delete the matching data (all the goals,
    // say) without a word. Merge deletes nothing, so it skips a damaged file
    // with a warning that holds no name or amount (rule 7) and imports the
    // rest. Each file is parsed once, here, and the result is imported below.
    final isReplace = strategy == ImportStrategy.replace;
    final damagedFiles = <String>[];
    final String? cashflowsCsv;
    try {
      cashflowsCsv = _readText(archive, 'cashflows.csv');
    } catch (_) {
      return _notImported('cashflows.csv could not be read');
    }
    final cashflows = cashflowsCsv == null
        ? null
        : _parseBackupCashflows(cashflowsCsv, baseCurrency);
    if (isReplace) {
      // The exporter always writes cashflows.csv, so a backup without it is
      // damaged or edited. Merge deletes nothing and imports the rest.
      if (cashflows == null) {
        return _notImported('cashflows.csv is missing');
      }
      if (_isDamaged(cashflows.validRows, cashflows.errors)) {
        return _notImported('cashflows.csv has no readable rows');
      }
    }
    final valuations =
        _readParsed(
          archive,
          'valuations.csv',
          _valuationsWarning,
          warnings,
          damagedFiles,
          (text) => _parseValuationsCsv(text, warnings),
        ) ??
        <(bool, String), List<_ImportedValuation>>{};
    final cashflowsArchived = _readParsed(
      archive,
      'cashflows_archived.csv',
      _cashflowsArchivedWarning,
      warnings,
      damagedFiles,
      (text) {
        final parsed = _parseBackupCashflows(text, baseCurrency);
        return _isDamaged(parsed.validRows, parsed.errors) ? null : parsed;
      },
    );
    final goals = _readParsed(
      archive,
      'goals.csv',
      _goalsWarning,
      warnings,
      damagedFiles,
      (text) => _parseGoals(text, baseCurrency),
    );
    final goalsArchived = _readParsed(
      archive,
      'goals_archived.csv',
      _goalsArchivedWarning,
      warnings,
      damagedFiles,
      (text) => _parseGoals(text, baseCurrency),
    );
    final fireSettings = _fireSettingsRepository == null
        ? null
        : _readFireSettings(archive, baseCurrency, warnings, damagedFiles);
    final customTypes = _readParsed(
      archive,
      'custom_types.json',
      _customTypesWarning,
      warnings,
      damagedFiles,
      _parseCustomTypes,
    );
    if (isReplace && damagedFiles.isNotEmpty) {
      // The file name only: not a row, a name, an amount or the exception.
      return _notImported('${damagedFiles.first} is damaged');
    }

    // Dated valuations are attached to the investments created below (money
    // rule 6). Each is taken by the investment it belongs to, so what is left
    // has no cash flows (an opening baseline, say).
    final snapshots = <InvestmentValuationSnapshot>[];

    // 4. If strategy is replace, delete all existing data first
    if (isReplace) {
      await _deleteAllExistingData();
    }

    // 5. Import the parsed files
    // Import cashflows first and collect investment name-to-ID mapping
    int investmentsImported = 0;
    int cashflowsImported = 0;
    int goalsImported = 0;
    final investmentNameToIdMap = <String, String>{};

    // Reusable custom types (#936) first, so the investments below can link
    // to them. Replace with the file replaces the account's own types (the
    // old ones are deleted for good); without the file they stay. A damaged
    // file never gets here: it stopped Replace above. If the types cannot be
    // saved (Replace has already cleared the investments), the investments
    // still import with their labels, unlinked.
    var customTypesByKey = const <String, CustomInvestmentType>{};
    if (customTypes != null) {
      try {
        if (strategy == ImportStrategy.replace) {
          await _customInvestmentTypeRepository?.deleteAll();
        }
        customTypesByKey = await _importCustomTypes(
          customTypes.types,
          warnings,
        );
      } catch (e) {
        warnings.add('Custom types not imported: they could not be saved');
      }
    }
    final investmentCustomTypes =
        customTypes?.links ?? const <(bool, String), _ImportedCustomTypeRef>{};

    // Import cashflows (active)
    if (cashflows != null) {
      final result = await _importCashflowsCsv(
        cashflows,
        isArchived: false,
        strategy: strategy,
        baseCurrency: baseCurrency,
        valuations: valuations,
        snapshots: snapshots,
        customTypeRefs: investmentCustomTypes,
        customTypesByKey: customTypesByKey,
      );
      investmentsImported += result.investmentsCreated;
      cashflowsImported += result.imported;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
      investmentNameToIdMap.addAll(result.investmentNameToIdMap);
    }

    // Import archived cashflows
    if (cashflowsArchived != null) {
      final result = await _importCashflowsCsv(
        cashflowsArchived,
        isArchived: true,
        strategy: strategy,
        baseCurrency: baseCurrency,
        valuations: valuations,
        snapshots: snapshots,
        customTypeRefs: investmentCustomTypes,
        customTypesByKey: customTypesByKey,
      );
      investmentsImported += result.investmentsCreated;
      cashflowsImported += result.imported;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
      investmentNameToIdMap.addAll(result.investmentNameToIdMap);
    }

    // Investments with valuations and no cash flows, then every valuation.
    final shells = await _importValuationOnlyInvestments(
      valuations,
      strategy: strategy,
      baseCurrency: baseCurrency,
      snapshots: snapshots,
      warnings: warnings,
    );
    investmentsImported += shells.length;
    investmentNameToIdMap.addAll(shells);
    var valuationsImported = 0;
    final valuationRepository = _valuationRepository;
    if (valuationRepository != null && snapshots.isNotEmpty) {
      valuationsImported = await valuationRepository.importAll(snapshots);
    }

    // Import goals (with investment name-to-ID mapping for linked investments)
    if (goals != null) {
      final result = await _importGoalsCsv(
        goals,
        isArchived: false,
        strategy: strategy,
        investmentNameToIdMap: investmentNameToIdMap,
        baseCurrency: baseCurrency,
      );
      goalsImported += result.imported;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
    }

    // Import archived goals
    if (goalsArchived != null) {
      final result = await _importGoalsCsv(
        goalsArchived,
        isArchived: true,
        strategy: strategy,
        investmentNameToIdMap: investmentNameToIdMap,
        baseCurrency: baseCurrency,
      );
      goalsImported += result.imported;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
    }

    // 6. Import documents
    int documentsImported = 0;
    for (final docMeta in documentsList) {
      try {
        final zipPath = docMeta['zipPath'] as String;
        final docFile = archive.findFile(zipPath);
        if (docFile != null) {
          // Get the new investment ID by looking up the investment name
          final investmentName = docMeta['investmentName'] as String?;
          String? newInvestmentId;

          if (investmentName != null && investmentName.isNotEmpty) {
            // Use the name-to-ID mapping we built during import
            newInvestmentId =
                investmentNameToIdMap[investmentName.toLowerCase()];
          }

          // Fallback: try using the original investmentId (for replace mode
          // where IDs might be preserved, or for backward compatibility)
          newInvestmentId ??= docMeta['investmentId'] as String?;

          if (newInvestmentId == null) {
            warnings.add(
              'Document "${docMeta['fileName']}": could not find investment',
            );
            continue;
          }

          await _importDocument(
            docMeta,
            docFile.content as List<int>,
            investmentId: newInvestmentId,
          );
          documentsImported++;
        } else {
          warnings.add('Document not found in ZIP: $zipPath');
        }
      } catch (e) {
        warnings.add('Failed to import document: $e');
      }
    }

    // 7. Import FIRE settings if available (Rule 18: Data Lifecycle)
    bool fireSettingsImported = false;
    if (_fireSettingsRepository != null && fireSettings != null) {
      try {
        // Merge must not overwrite settings the account already has: FIRE
        // amounts carry no currency, and the guest merge imports into the
        // user's main account without asking.
        if (strategy == ImportStrategy.merge &&
            await _fireSettingsRepository.getSettings() != null) {
          throw const _ExistingFireSettings();
        }
        await _fireSettingsRepository.saveSettings(fireSettings);
        fireSettingsImported = true;
        LoggerService.info('FIRE settings imported successfully');
      } on _ExistingFireSettings {
        warnings.add(
          'FIRE settings not imported: this account already has FIRE '
          'settings',
        );
      } catch (e) {
        warnings.add('Failed to import FIRE settings: $e');
      }
    }

    LoggerService.info(
      'Import complete',
      metadata: {
        'investments': investmentsImported,
        'cashflows': cashflowsImported,
        'goals': goalsImported,
        'documents': documentsImported,
        'fireSettings': fireSettingsImported,
        'valuations': valuationsImported,
      },
    );

    return ZipImportResult(
      investmentsImported: investmentsImported,
      cashflowsImported: cashflowsImported,
      goalsImported: goalsImported,
      documentsImported: documentsImported,
      fireSettingsImported: fireSettingsImported,
      valuationsImported: valuationsImported,
      errors: errors,
      warnings: warnings,
    );
  }

  // ============ Private Helper Methods ============

  /// The result of an import that stopped before it changed anything.
  ZipImportResult _notImported(String reason) => ZipImportResult(
    investmentsImported: 0,
    cashflowsImported: 0,
    goalsImported: 0,
    documentsImported: 0,
    errors: [
      'Backup not imported: $reason. Your existing data was not changed.',
    ],
  );

  /// The text of [name] in the backup: null if the backup has no such file.
  /// Throws if the file is not valid UTF-8.
  String? _readText(Archive archive, String name) {
    final file = archive.findFile(name);
    return file == null ? null : utf8.decode(file.content as List<int>);
  }

  /// [name] read and parsed by [parse], or null if the backup has no such
  /// file. A file that cannot be read, or that [parse] rejects by returning
  /// null, is damaged: [name] is added to [damagedFiles] and [warning] to
  /// [warnings] (shown by Merge, which skips the file). The error itself is
  /// left out because it can quote the file.
  T? _readParsed<T extends Object>(
    Archive archive,
    String name,
    String warning,
    List<String> warnings,
    List<String> damagedFiles,
    T? Function(String text) parse,
  ) {
    try {
      final text = _readText(archive, name);
      if (text == null) return null;
      final parsed = parse(text);
      if (parsed != null) return parsed;
    } catch (_) {
      // Damaged, as below.
    }
    damagedFiles.add(name);
    warnings.add(warning);
    return null;
  }

  /// The goals in a goals.csv or goals_archived.csv, or null if it is damaged.
  ParsedGoalsResult? _parseGoals(String text, String baseCurrency) {
    final parsed = GoalsCsvParser.parseString(text, baseCurrency: baseCurrency);
    return _isDamaged(parsed.validRows, parsed.errors) ? null : parsed;
  }

  /// Whether a parsed CSV has nothing to restore: no valid row, and at least
  /// one error (a header-only file has neither and is just empty).
  bool _isDamaged(int validRows, List<String> errors) =>
      validRows == 0 && errors.isNotEmpty;

  /// The FIRE settings in the backup, or null if there are none or they
  /// cannot be read (the file is added to [damagedFiles], with one warning
  /// that holds none of the file's content).
  FireSettingsEntity? _readFireSettings(
    Archive archive,
    String baseCurrency,
    List<String> warnings,
    List<String> damagedFiles,
  ) {
    try {
      final text = _readText(archive, 'fire_settings.json');
      if (text == null) return null;
      final imported = FireSettingsEntity.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
        fallbackId: _uuid.v4(),
        defaultIsSetupComplete: true,
      );
      // Amounts exported before they had a currency take the base
      // currency, like rows, investments and goals without one.
      return imported.copyWith(
        currency: imported.currency ?? baseCurrency,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      damagedFiles.add('fire_settings.json');
      warnings.add('FIRE settings not imported: fire_settings.json is invalid');
      return null;
    }
  }

  /// Reads cashflows.csv or cashflows_archived.csv. The app wrote this file,
  /// so restore what it holds: rows that a bulk import now rejects (old
  /// dates, stored codes) must not be lost, as Replace has already deleted
  /// the existing data.
  ParsedCsvResult _parseBackupCashflows(
    String csvContent,
    String baseCurrency,
  ) {
    return SimpleCsvParser.parseString(
      csvContent,
      baseCurrency: baseCurrency,
      fromBackup: true,
    );
  }

  /// Delete all existing data (for replace strategy)
  ///
  /// Note: FIRE settings are intentionally NOT deleted during import replace.
  /// FIRE settings are user preferences/configuration, not investment data.
  /// They are managed separately through the FIRE settings screen.
  /// For full account deletion (including FIRE settings), see [DataManagementScreen].
  Future<void> _deleteAllExistingData() async {
    // Delete all investments (cascades to cashflows)
    final investments = await _investmentRepository.getAllInvestments();
    final archivedInvestments = await _investmentRepository
        .watchArchivedInvestments()
        .first;

    for (final inv in investments) {
      await _investmentRepository.deleteInvestment(inv.id);
    }
    for (final inv in archivedInvestments) {
      await _investmentRepository.deleteArchivedInvestment(inv.id);
    }

    // Delete all goals
    final goals = await _goalRepository.getAllGoals();
    final archivedGoals = await _goalRepository.watchArchivedGoals().first;

    for (final goal in goals) {
      await _goalRepository.deleteGoal(goal.id);
    }
    for (final goal in archivedGoals) {
      await _goalRepository.deleteArchivedGoal(goal.id);
    }
  }

  /// Import the cash flows of a parsed cashflows.csv or
  /// cashflows_archived.csv.
  Future<_CsvImportResult> _importCashflowsCsv(
    ParsedCsvResult parseResult, {
    required bool isArchived,
    required ImportStrategy strategy,
    required String baseCurrency,
    required Map<(bool, String), List<_ImportedValuation>> valuations,
    required List<InvestmentValuationSnapshot> snapshots,
    Map<(bool, String), _ImportedCustomTypeRef> customTypeRefs = const {},
    Map<String, CustomInvestmentType> customTypesByKey = const {},
  }) async {
    if (parseResult.validRows == 0) {
      return _CsvImportResult(
        imported: 0,
        errors: parseResult.errors,
        warnings: [],
      );
    }

    // Group cashflows by investment name
    final grouped = <String, List<ParsedCashFlowRow>>{};
    for (final row in parseResult.rows) {
      if (row.isValid) {
        grouped.putIfAbsent(row.investmentName, () => []).add(row);
      }
    }

    // For merge strategy, get existing investment names
    Set<String> existingInvestmentNames = {};
    if (strategy == ImportStrategy.merge) {
      final existing = await _investmentRepository.getAllInvestments();
      existingInvestmentNames = existing
          .map((e) => e.name.toLowerCase())
          .toSet();
    }

    final now = DateTime.now();
    final investments = <InvestmentEntity>[];
    final cashFlows = <CashFlowEntity>[];
    final warnings = <String>[];
    final nameToIdMap = <String, String>{};

    for (final entry in grouped.entries) {
      final investmentName = entry.key;
      final rows = entry.value;

      // The valuations of this investment go with it, or are dropped with it.
      final valuationRows =
          valuations.remove((isArchived, investmentName.toLowerCase())) ??
          const <_ImportedValuation>[];

      // Skip if merging and investment already exists
      if (strategy == ImportStrategy.merge &&
          existingInvestmentNames.contains(investmentName.toLowerCase())) {
        warnings.add('Skipped "$investmentName" - already exists');
        continue;
      }

      final investmentId = _uuid.v4();

      // Get investment type and status from the first row (all rows for same
      // investment should have the same type/status)
      final firstRow = rows.first;
      final investmentType = firstRow.investmentType ?? InvestmentType.other;
      final investmentStatus =
          firstRow.investmentStatus ?? InvestmentStatus.open;

      final currency = resolveSharedCurrency(
        rows.map((r) => r.currency ?? baseCurrency),
        baseCurrency,
      );
      final routed = _routeSnapshots(
        investmentId: investmentId,
        name: investmentName,
        currency: currency,
        rows: valuationRows,
        now: now,
        warnings: warnings,
        keepIds: strategy == ImportStrategy.replace,
        takenIds: {for (final s in snapshots) s.id},
      );
      snapshots.addAll(routed);
      // The currentValue pair mirrors the latest snapshot, whatever the
      // feature flag says: it is what older versions and the old dialog read.
      final mirror = ValuationSnapshotSelector.mirrorOf(
        routed,
        investmentId: investmentId,
        currency: currency,
      );

      final customType = _customTypeOf(
        customTypeRefs[(isArchived, investmentName.toLowerCase())],
        investmentName: investmentName,
        type: investmentType,
        typesByKey: customTypesByKey,
        warnings: warnings,
      );

      investments.add(
        InvestmentEntity(
          id: investmentId,
          name: investmentName,
          type: investmentType,
          status: investmentStatus,
          createdAt: now,
          updatedAt: now,
          isArchived: isArchived,
          currency: currency,
          currentValue: mirror?.amount,
          currentValueDate: mirror?.effectiveDate,
          customTypeId: customType.id,
          customTypeLabel: customType.label,
        ),
      );

      // Track name -> ID mapping for goals remapping
      nameToIdMap[investmentName.toLowerCase()] = investmentId;

      for (final row in rows) {
        cashFlows.add(
          CashFlowEntity(
            id: _uuid.v4(),
            investmentId: investmentId,
            type: row.type,
            amount: row.amount,
            date: row.date,
            notes: row.notes,
            createdAt: now,
            currency: row.currency ?? baseCurrency, // Rule 21.4
          ),
        );
      }
    }

    // Bulk import
    if (investments.isNotEmpty) {
      await _investmentRepository.bulkImport(
        investments: investments,
        cashFlows: cashFlows,
      );

      // If these should be archived, archive them
      if (isArchived) {
        for (final inv in investments) {
          await _investmentRepository.archiveInvestment(inv.id);
        }
      }
    }

    return _CsvImportResult(
      imported: cashFlows.length,
      investmentsCreated: investments.length,
      errors: parseResult.errors,
      warnings: warnings,
      investmentNameToIdMap: nameToIdMap,
    );
  }

  /// A snapshot id the file may keep: what this app writes (UUIDs, Firestore
  /// ids), and nothing that could address another path.
  static final _snapshotIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// Parses valuations.csv into rows keyed by (archived, lowercase
  /// investment name), the way cash flow rows name their investment. Files
  /// from before the Snapshot ID, Kind, Source, Updated At, Investment Type
  /// and Investment Status columns read as manual carrying values. A bad row
  /// is skipped with a warning that holds no amount; an unknown kind or
  /// source is never reinterpreted, and an estimate is never stored. Null if
  /// the file is damaged: it cannot be read as a whole, is empty, or has bad
  /// rows and no good one (nothing to restore, like a goals.csv in the same
  /// state). Then no row warning is added: the caller reports the file alone.
  Map<(bool, String), List<_ImportedValuation>>? _parseValuationsCsv(
    String content,
    List<String> warnings,
  ) {
    final List<List<dynamic>> rows;
    try {
      rows = csv.decode(content);
    } catch (_) {
      return null;
    }
    if (rows.isEmpty) return null;

    final header = [for (final h in rows.first) h.toString().trim()];
    final nameCol = header.indexOf('Investment Name');
    final archivedCol = header.indexOf('Archived');
    final dateCol = header.indexOf('Date');
    final valueCol = header.indexOf('Value');
    final currencyCol = header.indexOf('Currency');
    if ([nameCol, archivedCol, dateCol, valueCol, currencyCol].contains(-1)) {
      return null;
    }
    final idCol = header.indexOf('Snapshot ID');
    final kindCol = header.indexOf('Kind');
    final sourceCol = header.indexOf('Source');
    final updatedCol = header.indexOf('Updated At');
    final typeCol = header.indexOf('Investment Type');
    final statusCol = header.indexOf('Investment Status');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <(bool, String), List<_ImportedValuation>>{};
    final rowWarnings = <String>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      String cell(int col) =>
          col >= 0 && col < row.length ? row[col].toString().trim() : '';
      final name = cell(nameCol);
      if (name.isEmpty) continue;
      final value = double.tryParse(cell(valueCol));
      final parsedDate = DateTime.tryParse(cell(dateCol));
      final currency = cell(currencyCol).toUpperCase();
      final kind = cell(kindCol).isEmpty
          ? ValuationKind.carryingValue
          : ValuationKind.tryParse(cell(kindCol));
      final provenance = cell(sourceCol).isEmpty
          ? ValuationProvenance.manual
          : ValuationProvenance.tryParse(cell(sourceCol));
      if (value == null ||
          !value.isFinite ||
          value < 0 ||
          parsedDate == null ||
          // A value cannot be dated after today (as in setCurrentValue).
          DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
          ).isAfter(today) ||
          currency.isEmpty ||
          kind == null ||
          provenance == null ||
          provenance == ValuationProvenance.estimate) {
        rowWarnings.add('Current value of "$name" not imported: invalid row');
        continue;
      }
      final type = cell(typeCol);
      (result[(
                cell(archivedCol).toLowerCase() == 'true',
                name.toLowerCase(),
              )] ??=
              [])
          .add(
            _ImportedValuation(
              name: name,
              value: value,
              date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
              currency: currency,
              snapshotId: cell(idCol),
              kind: kind,
              provenance: provenance,
              updatedAt: DateTime.tryParse(cell(updatedCol))?.toUtc(),
              investmentType: type.isEmpty
                  ? null
                  : InvestmentType.fromString(type),
              investmentStatus: cell(statusCol).isEmpty
                  ? null
                  : InvestmentStatus.fromString(cell(statusCol)),
            ),
          );
    }
    if (result.isEmpty && rowWarnings.isNotEmpty) return null;
    warnings.addAll(rowWarnings);
    return result;
  }

  /// The snapshots of the investment [investmentId], from the [rows] that
  /// name it. Same-name investments collapse into one on import, so what
  /// the app guarantees is checked again here: every row is in the
  /// investment's currency, there is at most one opening baseline (the
  /// earliest), and no more than the 100 live snapshots an investment keeps
  /// (the oldest go first). Skipped rows are reported without amounts.
  ///
  /// Amounts are rounded to the currency here, so that the snapshot and the
  /// investment's mirror of it hold the same figure. With [keepIds] (Replace,
  /// when no investment is left whose snapshot an id could overwrite) a row
  /// keeps the id of the file, unless it is unusable or in [takenIds] or
  /// repeated; every other snapshot gets a new one.
  List<InvestmentValuationSnapshot> _routeSnapshots({
    required String investmentId,
    required String name,
    required String currency,
    required List<_ImportedValuation> rows,
    required DateTime now,
    required List<String> warnings,
    required bool keepIds,
    required Set<String> takenIds,
  }) {
    final used = {...takenIds};
    String idOf(_ImportedValuation row) {
      final id = row.snapshotId;
      return keepIds && _snapshotIdPattern.hasMatch(id) && used.add(id)
          ? id
          : _uuid.v4();
    }

    final ordered = [...rows]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return (a.updatedAt ?? now).compareTo(b.updatedAt ?? now);
      });
    final accepted = <InvestmentValuationSnapshot>[];
    var hasBaseline = false;
    for (final row in ordered) {
      if (row.currency != currency) {
        // A value is only meaningful in the investment's own currency.
        warnings.add(
          'Current value of "$name" not imported: its currency differs from '
          'the investment\'s',
        );
        continue;
      }
      if (row.provenance == ValuationProvenance.openingBaseline) {
        if (hasBaseline) {
          warnings.add(
            'Opening value of "$name" not imported: the investment already '
            'has one',
          );
          continue;
        }
        hasBaseline = true;
      }
      accepted.add(
        InvestmentValuationSnapshot(
          id: idOf(row),
          investmentId: investmentId,
          amount: MoneyPrecision.round(row.value, currencyCode: currency),
          currency: currency,
          effectiveDate: row.date,
          kind: row.kind,
          provenance: row.provenance,
          createdAt: now,
          updatedAt: row.updatedAt ?? now,
        ),
      );
    }
    final excess = accepted.length - ValuationSnapshotSelector.maxLiveSnapshots;
    if (excess > 0) {
      warnings.add(
        'Older values of "$name" not imported: an investment keeps at most '
        '${ValuationSnapshotSelector.maxLiveSnapshots}',
      );
      var toDrop = excess;
      accepted.removeWhere((s) {
        if (toDrop > 0 && !s.isOpeningBaseline) {
          toDrop--;
          return true;
        }
        return false;
      });
    }
    return accepted;
  }

  /// Creates the investments that valuations name but no cash flow does (an
  /// opening baseline has none), from the Investment Type and Investment
  /// Status of their rows, and adds their snapshots. [valuations] holds the
  /// rows no cash flow group took. Returns lowercase name to new id.
  Future<Map<String, String>> _importValuationOnlyInvestments(
    Map<(bool, String), List<_ImportedValuation>> valuations, {
    required ImportStrategy strategy,
    required String baseCurrency,
    required List<InvestmentValuationSnapshot> snapshots,
    required List<String> warnings,
  }) async {
    if (valuations.isEmpty) return const {};
    var existingNames = <String>{};
    if (strategy == ImportStrategy.merge) {
      existingNames = {
        for (final e in await _investmentRepository.getAllInvestments())
          e.name.toLowerCase(),
      };
    }

    final now = DateTime.now();
    final investments = <InvestmentEntity>[];
    final nameToId = <String, String>{};
    for (final MapEntry(key: (isArchived, nameKey), value: rows)
        in valuations.entries) {
      final name = rows.first.name;
      if (strategy == ImportStrategy.merge && existingNames.contains(nameKey)) {
        warnings.add('Skipped "$name" - already exists');
        continue;
      }
      final investmentId = _uuid.v4();
      final currency = resolveSharedCurrency(
        rows.map((r) => r.currency),
        baseCurrency,
      );
      final routed = _routeSnapshots(
        investmentId: investmentId,
        name: name,
        currency: currency,
        rows: rows,
        now: now,
        warnings: warnings,
        keepIds: strategy == ImportStrategy.replace,
        takenIds: {for (final s in snapshots) s.id},
      );
      // Nothing usable is left for this investment: create nothing.
      if (routed.isEmpty) continue;
      snapshots.addAll(routed);
      final mirror = ValuationSnapshotSelector.mirrorOf(
        routed,
        investmentId: investmentId,
        currency: currency,
      );
      investments.add(
        InvestmentEntity(
          id: investmentId,
          name: name,
          type: rows.first.investmentType ?? InvestmentType.other,
          status: rows.first.investmentStatus ?? InvestmentStatus.open,
          createdAt: now,
          updatedAt: now,
          isArchived: isArchived,
          currency: currency,
          currentValue: mirror?.amount,
          currentValueDate: mirror?.effectiveDate,
        ),
      );
      nameToId[nameKey] = investmentId;
    }
    valuations.clear();

    if (investments.isNotEmpty) {
      await _investmentRepository.bulkImport(
        investments: investments,
        cashFlows: const [],
      );
      for (final inv in investments) {
        if (inv.isArchived) {
          await _investmentRepository.archiveInvestment(inv.id);
        }
      }
    }
    return nameToId;
  }

  /// Reads custom_types.json (see `DataExportService`): the reusable types
  /// and the custom type label of each Other investment, keyed by (archived,
  /// lowercase investment name) the way valuations are. Null if the file is
  /// damaged: not JSON, not an object, without the two lists the exporter
  /// always writes, or with rows but none of them readable. A row of the wrong
  /// shape among readable ones is skipped, and a file with empty lists has
  /// nothing to restore but is not damaged.
  _ImportedCustomTypes? _parseCustomTypes(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, dynamic>) return null;
    final rawTypes = json['types'];
    final rawLinks = json['investments'];
    if (rawTypes is! List || rawLinks is! List) return null;

    var badRows = 0;
    final types = <_ImportedCustomType>[];
    for (final row in rawTypes) {
      final label = row is Map ? row['label'] : null;
      if (row is! Map || label is! String || label.trim().isEmpty) {
        badRows++;
        continue;
      }
      types.add(
        _ImportedCustomType(label: label, removed: row['removed'] == true),
      );
    }
    final links = <(bool, String), _ImportedCustomTypeRef>{};
    for (final row in rawLinks) {
      final name = row is Map ? row['name'] : null;
      final label = row is Map ? row['label'] : null;
      if (row is! Map ||
          name is! String ||
          name.trim().isEmpty ||
          label is! String ||
          label.trim().isEmpty) {
        badRows++;
        continue;
      }
      links[(row['archived'] == true, name.trim().toLowerCase())] =
          _ImportedCustomTypeRef(label: label, linked: row['linked'] == true);
    }
    if (types.isEmpty && links.isEmpty && badRows > 0) return null;
    return _ImportedCustomTypes(types: types, links: links);
  }

  /// Saves the reusable types of an import and returns them by key. A type
  /// the account already has (any case or spacing) is reused, never
  /// duplicated; an active one in the file revives a removed one; a removed
  /// one in the file is created removed, or left as the account has it. Types
  /// over the limit of [CustomTypeLabel.maxActiveDefinitions] are skipped.
  /// Without a repository there are no reusable types to save, and the
  /// investments keep their labels without a link.
  Future<Map<String, CustomInvestmentType>> _importCustomTypes(
    List<_ImportedCustomType> imported,
    List<String> warnings,
  ) async {
    final repository = _customInvestmentTypeRepository;
    if (repository == null || imported.isEmpty) return const {};
    var all = await repository.getAll();
    final byKey = <String, CustomInvestmentType>{};
    final now = DateTime.now();
    var overLimit = 0;
    var tooLong = 0;

    for (final row in imported) {
      final label = CustomTypeLabel.clean(row.label);
      if (label.isEmpty) continue;
      if (CustomTypeLabel.exceedsMaxLength(label)) {
        tooLong++;
        continue;
      }
      final key = CustomTypeLabel.keyOf(label);
      CustomInvestmentType? result;
      if (row.removed) {
        result = all.where((d) => d.key == key).firstOrNull;
        if (result == null) {
          result = CustomInvestmentType(
            id: _uuid.v4(),
            label: label,
            createdAt: now,
            updatedAt: now,
            removedAt: now,
          );
          await repository.put(result);
          all = [...all, result];
        }
      } else {
        final change = CustomTypeCatalog.save(
          all,
          label,
          newId: _uuid.v4(),
          now: now,
        );
        if (change.issue == CustomTypeIssue.atCapacity) {
          overLimit++;
          continue;
        }
        final write = change.write;
        if (write != null) {
          await repository.put(write);
          all = [
            for (final d in all)
              if (d.id != write.id) d,
            write,
          ];
        }
        result = change.result;
      }
      if (result != null) byKey[key] = result;
    }

    // Counts only, like the other warnings about skipped rows.
    if (tooLong > 0) {
      warnings.add(
        '$tooLong custom ${tooLong == 1 ? 'type' : 'types'} not imported: '
        'longer than ${CustomTypeLabel.maxLength} characters',
      );
    }
    if (overLimit > 0) {
      warnings.add(
        '$overLimit custom ${overLimit == 1 ? 'type' : 'types'} not '
        'imported: an account holds at most '
        '${CustomTypeLabel.maxActiveDefinitions}',
      );
    }
    return byKey;
  }

  /// What an imported investment of [type] stores for its custom type: its
  /// label, linked to the reusable type of that label when the file says it
  /// was and the account has one. Only an investment of type Other has one.
  CustomTypeLink _customTypeOf(
    _ImportedCustomTypeRef? ref, {
    required String investmentName,
    required InvestmentType type,
    required Map<String, CustomInvestmentType> typesByKey,
    required List<String> warnings,
  }) {
    if (ref == null) return CustomTypeLink.none;
    final label = CustomTypeLabel.clean(ref.label);
    if (label.isEmpty) return CustomTypeLink.none;
    if (type != InvestmentType.other) {
      warnings.add(
        'Custom type of "$investmentName" not imported: only an investment '
        'of type Other has one',
      );
      return CustomTypeLink.none;
    }
    if (CustomTypeLabel.exceedsMaxLength(label)) {
      warnings.add(
        'Custom type of "$investmentName" not imported: longer than '
        '${CustomTypeLabel.maxLength} characters',
      );
      return CustomTypeLink.none;
    }
    final linked = ref.linked ? typesByKey[CustomTypeLabel.keyOf(label)] : null;
    return CustomTypeLink(id: linked?.id, label: label);
  }

  /// Import the goals of a parsed goals.csv or goals_archived.csv.
  Future<_CsvImportResult> _importGoalsCsv(
    ParsedGoalsResult parseResult, {
    required bool isArchived,
    required ImportStrategy strategy,
    required Map<String, String> investmentNameToIdMap,
    required String baseCurrency,
  }) async {
    if (parseResult.validRows == 0) {
      return _CsvImportResult(
        imported: 0,
        errors: parseResult.errors,
        warnings: [],
      );
    }

    // For merge strategy, get existing goal names
    Set<String> existingGoalNames = {};
    if (strategy == ImportStrategy.merge) {
      final existing = await _goalRepository.getAllGoals();
      existingGoalNames = existing.map((e) => e.name.toLowerCase()).toSet();
    }

    final now = DateTime.now();
    final warnings = <String>[];
    int imported = 0;

    for (final row in parseResult.validRowsOnly) {
      // Skip if merging and goal already exists
      if (strategy == ImportStrategy.merge &&
          existingGoalNames.contains(row.name.toLowerCase())) {
        warnings.add('Skipped goal "${row.name}" - already exists');
        continue;
      }

      // Remap investment names to IDs
      final linkedInvestmentIds = <String>[];
      for (final name in row.linkedInvestmentNames) {
        final id = investmentNameToIdMap[name.toLowerCase()];
        if (id != null) {
          linkedInvestmentIds.add(id);
        } else {
          warnings.add('Goal "${row.name}": could not find investment "$name"');
        }
      }

      final goal = GoalEntity(
        id: _uuid.v4(),
        name: row.name,
        type: GoalType.fromString(row.type),
        targetAmount: row.targetAmount,
        targetMonthlyIncome: row.targetMonthlyIncome,
        targetDate: row.targetDate,
        trackingMode: GoalTrackingMode.fromString(row.trackingMode),
        linkedInvestmentIds: linkedInvestmentIds,
        linkedTypes: row.linkedTypes
            .map(
              (t) => InvestmentType.values.firstWhere(
                (e) => e.name == t,
                orElse: () => InvestmentType.other,
              ),
            )
            .toList(),
        icon: row.icon,
        colorValue: row.colorValue,
        // Preserve original currency; legacy goals use the base (Rule 21.2)
        currency: row.currency ?? baseCurrency,
        isArchived: isArchived,
        createdAt: now,
        updatedAt: now,
      );

      await _goalRepository.createGoal(goal);

      // If should be archived, archive it
      if (isArchived) {
        await _goalRepository.archiveGoal(goal.id);
      }

      imported++;
    }

    return _CsvImportResult(
      imported: imported,
      errors: parseResult.errors,
      warnings: warnings,
    );
  }

  /// Import a document from metadata and file bytes
  ///
  /// [investmentId] is the new investment ID to use (after remapping)
  Future<void> _importDocument(
    Map<String, dynamic> docMeta,
    List<int> bytes, {
    required String investmentId,
  }) async {
    final documentId = docMeta['id'] as String? ?? _uuid.v4();
    final fileName = docMeta['fileName'] as String;

    final uint8Bytes = Uint8List.fromList(bytes);

    // Security: Validate file signature to prevent extension spoofing
    // and malicious file uploads during ZIP import.
    if (!FileSignatureUtils.validateFileSignature(uint8Bytes, fileName)) {
      throw Exception(
        'Security: File signature validation failed for $fileName',
      );
    }

    // Save the file to local storage
    final localPath = await _documentStorageService.saveDocument(
      investmentId: investmentId,
      documentId: documentId,
      fileName: fileName,
      bytes: uint8Bytes,
    );

    // Create document entity with the remapped investment ID
    final doc = DocumentEntity(
      id: documentId,
      investmentId: investmentId,
      name: docMeta['name'] as String? ?? fileName,
      fileName: fileName,
      type: DocumentType.fromString(docMeta['type'] as String? ?? 'other'),
      mimeType: docMeta['mimeType'] as String? ?? 'application/octet-stream',
      localPath: localPath,
      fileSize: bytes.length,
      createdAt:
          DateTime.tryParse(docMeta['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(docMeta['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );

    await _documentRepository.createDocument(doc);
  }
}

/// A row of valuations.csv.
class _ImportedValuation {
  /// As written in the file; the key to the investment is its lowercase.
  final String name;
  final double value;
  final DateTime date;
  final String currency;

  /// The Snapshot ID column; blank in files from before it existed and for
  /// a value an older app saved.
  final String snapshotId;
  final ValuationKind kind;
  final ValuationProvenance provenance;
  final DateTime? updatedAt;

  /// For an investment that has no cash flows to take them from.
  final InvestmentType? investmentType;
  final InvestmentStatus? investmentStatus;

  const _ImportedValuation({
    required this.name,
    required this.value,
    required this.date,
    required this.currency,
    required this.snapshotId,
    required this.kind,
    required this.provenance,
    this.updatedAt,
    this.investmentType,
    this.investmentStatus,
  });
}

/// What custom_types.json holds.
class _ImportedCustomTypes {
  final List<_ImportedCustomType> types;

  /// The custom type label of each investment, by (archived, lowercase name).
  final Map<(bool, String), _ImportedCustomTypeRef> links;

  const _ImportedCustomTypes({required this.types, required this.links});
}

/// A reusable custom type read from custom_types.json.
class _ImportedCustomType {
  final String label;
  final bool removed;

  const _ImportedCustomType({required this.label, required this.removed});
}

/// The custom type label of one investment, read from custom_types.json.
class _ImportedCustomTypeRef {
  final String label;

  /// Whether the investment referred to a reusable type.
  final bool linked;

  const _ImportedCustomTypeRef({required this.label, required this.linked});
}

/// Internal result class for CSV import operations
class _CsvImportResult {
  final int imported;
  final int investmentsCreated;
  final List<String> errors;
  final List<String> warnings;

  /// Map of investment name (lowercase) to investment ID (for goals linking)
  final Map<String, String> investmentNameToIdMap;

  const _CsvImportResult({
    required this.imported,
    this.investmentsCreated = 0,
    required this.errors,
    required this.warnings,
    this.investmentNameToIdMap = const {},
  });
}

/// Thrown to skip a merge import of FIRE settings the account already has.
class _ExistingFireSettings implements Exception {
  const _ExistingFireSettings();
}
