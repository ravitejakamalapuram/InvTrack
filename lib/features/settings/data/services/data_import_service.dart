import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/core/utils/file_signature_utils.dart';
import 'package:uuid/uuid.dart';

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
  final PerformanceService _performanceService;

  static const _uuid = Uuid();

  DataImportService({
    required InvestmentRepository investmentRepository,
    required GoalRepository goalRepository,
    required DocumentRepository documentRepository,
    required DocumentStorageService documentStorageService,
    FireSettingsRepository? fireSettingsRepository,
    ValuationRepository? valuationRepository,
    required PerformanceService performanceService,
  }) : _investmentRepository = investmentRepository,
       _goalRepository = goalRepository,
       _documentRepository = documentRepository,
       _documentStorageService = documentStorageService,
       _fireSettingsRepository = fireSettingsRepository,
       _valuationRepository = valuationRepository,
       _performanceService = performanceService;

  /// Import data from a ZIP file.
  ///
  /// Rows, investments and goals with no currency (backups made before
  /// multi-currency support) take [baseCurrency], the user's base currency.
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
    } catch (e) {
      return ZipImportResult(
        investmentsImported: 0,
        cashflowsImported: 0,
        goalsImported: 0,
        documentsImported: 0,
        errors: ['Invalid ZIP file: $e'],
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
    try {
      metadata = jsonDecode(utf8.decode(metadataFile.content as List<int>));
    } catch (e) {
      return ZipImportResult(
        investmentsImported: 0,
        cashflowsImported: 0,
        goalsImported: 0,
        documentsImported: 0,
        errors: ['Failed to parse metadata.json: $e'],
      );
    }

    // Dated valuations the user entered, attached to the investments created
    // below (money rule 6). Each is taken by the investment it belongs to,
    // so what is left has no cash flows (an opening baseline, say). Read
    // before anything is deleted: a file that cannot be read stops a
    // Replace with the existing data still in place.
    final valuationsFile = archive.findFile('valuations.csv');
    final Map<(bool, String), List<_ImportedValuation>> valuations;
    try {
      valuations = valuationsFile == null
          ? {}
          : _parseValuationsCsv(
              utf8.decode(valuationsFile.content as List<int>),
              warnings,
            );
    } on FormatException catch (e) {
      return ZipImportResult(
        investmentsImported: 0,
        cashflowsImported: 0,
        goalsImported: 0,
        documentsImported: 0,
        errors: ['Failed to read valuations.csv: ${e.message}'],
      );
    }
    final snapshots = <InvestmentValuationSnapshot>[];

    // 3. If strategy is replace, delete all existing data first
    if (strategy == ImportStrategy.replace) {
      await _deleteAllExistingData();
    }

    // 4. Parse and import CSV files
    // Import cashflows first and collect investment name-to-ID mapping
    int investmentsImported = 0;
    int cashflowsImported = 0;
    int goalsImported = 0;
    final investmentNameToIdMap = <String, String>{};

    // Import cashflows (active)
    final cashflowsFile = archive.findFile('cashflows.csv');
    if (cashflowsFile != null) {
      final result = await _importCashflowsCsv(
        utf8.decode(cashflowsFile.content as List<int>),
        isArchived: false,
        strategy: strategy,
        baseCurrency: baseCurrency,
        valuations: valuations,
        snapshots: snapshots,
      );
      investmentsImported += result.investmentsCreated;
      cashflowsImported += result.imported;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
      investmentNameToIdMap.addAll(result.investmentNameToIdMap);
    }

    // Import archived cashflows
    final cashflowsArchivedFile = archive.findFile('cashflows_archived.csv');
    if (cashflowsArchivedFile != null) {
      final result = await _importCashflowsCsv(
        utf8.decode(cashflowsArchivedFile.content as List<int>),
        isArchived: true,
        strategy: strategy,
        baseCurrency: baseCurrency,
        valuations: valuations,
        snapshots: snapshots,
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
    final goalsFile = archive.findFile('goals.csv');
    if (goalsFile != null) {
      final result = await _importGoalsCsv(
        utf8.decode(goalsFile.content as List<int>),
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
    final goalsArchivedFile = archive.findFile('goals_archived.csv');
    if (goalsArchivedFile != null) {
      final result = await _importGoalsCsv(
        utf8.decode(goalsArchivedFile.content as List<int>),
        isArchived: true,
        strategy: strategy,
        investmentNameToIdMap: investmentNameToIdMap,
        baseCurrency: baseCurrency,
      );
      goalsImported += result.imported;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
    }

    // 5. Import documents
    int documentsImported = 0;
    final documentsList = metadata['documents'] as List<dynamic>? ?? [];
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

    // 6. Import FIRE settings if available (Rule 18: Data Lifecycle)
    bool fireSettingsImported = false;
    if (_fireSettingsRepository != null) {
      final fireSettingsFile = archive.findFile('fire_settings.json');
      if (fireSettingsFile != null) {
        try {
          // Merge must not overwrite settings the account already has: FIRE
          // amounts carry no currency, and the guest merge imports into the
          // user's main account without asking.
          if (strategy == ImportStrategy.merge &&
              await _fireSettingsRepository.getSettings() != null) {
            throw const _ExistingFireSettings();
          }
          final fireSettingsJson =
              jsonDecode(utf8.decode(fireSettingsFile.content as List<int>))
                  as Map<String, dynamic>;

          final imported = FireSettingsEntity.fromJson(
            fireSettingsJson,
            fallbackId: _uuid.v4(),
            defaultIsSetupComplete: true,
          );
          // Amounts exported before they had a currency take the base
          // currency, like rows, investments and goals without one.
          final fireSettings = imported.copyWith(
            currency: imported.currency ?? baseCurrency,
            updatedAt: DateTime.now(),
          );

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

  /// Import cashflows from CSV content
  /// Reuses SimpleCsvParser from bulk import
  Future<_CsvImportResult> _importCashflowsCsv(
    String csvContent, {
    required bool isArchived,
    required ImportStrategy strategy,
    required String baseCurrency,
    required Map<(bool, String), List<_ImportedValuation>> valuations,
    required List<InvestmentValuationSnapshot> snapshots,
  }) async {
    // The app wrote this file, so restore what it holds: rows that a bulk
    // import now rejects (old dates, stored codes) must not be lost, as
    // Replace has already deleted the existing data.
    final parseResult = SimpleCsvParser.parseString(
      csvContent,
      baseCurrency: baseCurrency,
      fromBackup: true,
    );
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
  /// source is never reinterpreted, and an estimate is never stored.
  Map<(bool, String), List<_ImportedValuation>> _parseValuationsCsv(
    String content,
    List<String> warnings,
  ) {
    final List<List<dynamic>> rows;
    try {
      rows = csv.decode(content);
    } catch (e) {
      warnings.add('Current values not imported: valuations.csv is invalid');
      return {};
    }
    if (rows.isEmpty) return {};

    final header = [for (final h in rows.first) h.toString().trim()];
    final nameCol = header.indexOf('Investment Name');
    final archivedCol = header.indexOf('Archived');
    final dateCol = header.indexOf('Date');
    final valueCol = header.indexOf('Value');
    final currencyCol = header.indexOf('Currency');
    if ([nameCol, archivedCol, dateCol, valueCol, currencyCol].contains(-1)) {
      warnings.add('Current values not imported: valuations.csv is invalid');
      return {};
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
        warnings.add('Current value of "$name" not imported: invalid row');
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

  /// Import goals from CSV content
  Future<_CsvImportResult> _importGoalsCsv(
    String csvContent, {
    required bool isArchived,
    required ImportStrategy strategy,
    required Map<String, String> investmentNameToIdMap,
    required String baseCurrency,
  }) async {
    final parseResult = GoalsCsvParser.parseString(
      csvContent,
      baseCurrency: baseCurrency,
    );
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
      throw Exception('Security: File signature validation failed for $fileName');
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
