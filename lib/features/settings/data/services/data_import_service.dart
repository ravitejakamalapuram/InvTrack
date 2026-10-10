import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/custom_type_catalog.dart';
import 'package:inv_tracker/features/investment/domain/repositories/custom_investment_type_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
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
  final List<String> errors;
  final List<String> warnings;

  const ZipImportResult({
    required this.investmentsImported,
    required this.cashflowsImported,
    required this.goalsImported,
    required this.documentsImported,
    this.fireSettingsImported = false,
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
  final CustomInvestmentTypeRepository? _customInvestmentTypeRepository;
  final PerformanceService _performanceService;

  static const _uuid = Uuid();

  DataImportService({
    required InvestmentRepository investmentRepository,
    required GoalRepository goalRepository,
    required DocumentRepository documentRepository,
    required DocumentStorageService documentStorageService,
    FireSettingsRepository? fireSettingsRepository,
    CustomInvestmentTypeRepository? customInvestmentTypeRepository,
    required PerformanceService performanceService,
  }) : _investmentRepository = investmentRepository,
       _goalRepository = goalRepository,
       _documentRepository = documentRepository,
       _documentStorageService = documentStorageService,
       _fireSettingsRepository = fireSettingsRepository,
       _customInvestmentTypeRepository = customInvestmentTypeRepository,
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

    // Custom types (#936) are read before anything is deleted: an unreadable
    // file is skipped with a warning (never with label text) and the cash
    // flows import without labels, instead of failing a Replace after it has
    // cleared the account.
    final customTypesFile = archive.findFile('custom_types.json');
    final customTypes = customTypesFile == null
        ? null
        : _parseCustomTypes(customTypesFile.content as List<int>, warnings);

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

    // Current values the user entered, attached to the investments created
    // below (money rule 6).
    final valuationsFile = archive.findFile('valuations.csv');
    final valuations = valuationsFile == null
        ? const <(bool, String), _ImportedValuation>{}
        : _parseValuationsCsv(
            utf8.decode(valuationsFile.content as List<int>),
            warnings,
          );

    // Reusable custom types (#936) first, so the investments below can link
    // to them. Replace with a readable file replaces the account's own types
    // (the old ones are deleted for good); without the file, or with an
    // unreadable one, they stay. If they cannot be saved (Replace has already
    // cleared the investments), the investments still import with their
    // labels, unlinked.
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
    final cashflowsFile = archive.findFile('cashflows.csv');
    if (cashflowsFile != null) {
      final result = await _importCashflowsCsv(
        utf8.decode(cashflowsFile.content as List<int>),
        isArchived: false,
        strategy: strategy,
        baseCurrency: baseCurrency,
        valuations: valuations,
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
    final cashflowsArchivedFile = archive.findFile('cashflows_archived.csv');
    if (cashflowsArchivedFile != null) {
      final result = await _importCashflowsCsv(
        utf8.decode(cashflowsArchivedFile.content as List<int>),
        isArchived: true,
        strategy: strategy,
        baseCurrency: baseCurrency,
        valuations: valuations,
        customTypeRefs: investmentCustomTypes,
        customTypesByKey: customTypesByKey,
      );
      investmentsImported += result.investmentsCreated;
      cashflowsImported += result.imported;
      errors.addAll(result.errors);
      warnings.addAll(result.warnings);
      investmentNameToIdMap.addAll(result.investmentNameToIdMap);
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
      },
    );

    return ZipImportResult(
      investmentsImported: investmentsImported,
      cashflowsImported: cashflowsImported,
      goalsImported: goalsImported,
      documentsImported: documentsImported,
      fireSettingsImported: fireSettingsImported,
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
    Map<(bool, String), _ImportedValuation> valuations = const {},
    Map<(bool, String), _ImportedCustomTypeRef> customTypeRefs = const {},
    Map<String, CustomInvestmentType> customTypesByKey = const {},
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
      var valuation = valuations[(isArchived, investmentName.toLowerCase())];
      if (valuation != null && valuation.currency != currency) {
        // A value is only meaningful in the investment's own currency.
        warnings.add(
          'Current value of "$investmentName" not imported: its currency '
          'differs from the investment\'s',
        );
        valuation = null;
      }

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
          currentValue: valuation?.value,
          currentValueDate: valuation?.date,
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

  /// Parses valuations.csv into values keyed by (archived, lowercase
  /// investment name), the way cash flow rows name their investment. Bad
  /// rows are skipped with a warning that holds no amount.
  Map<(bool, String), _ImportedValuation> _parseValuationsCsv(
    String content,
    List<String> warnings,
  ) {
    final List<List<dynamic>> rows;
    try {
      rows = csv.decode(content);
    } catch (e) {
      warnings.add('Current values not imported: valuations.csv is invalid');
      return const {};
    }
    if (rows.isEmpty) return const {};

    final header = [for (final h in rows.first) h.toString().trim()];
    final nameCol = header.indexOf('Investment Name');
    final archivedCol = header.indexOf('Archived');
    final dateCol = header.indexOf('Date');
    final valueCol = header.indexOf('Value');
    final currencyCol = header.indexOf('Currency');
    if ([nameCol, archivedCol, dateCol, valueCol, currencyCol].contains(-1)) {
      warnings.add('Current values not imported: valuations.csv is invalid');
      return const {};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <(bool, String), _ImportedValuation>{};
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      String cell(int col) =>
          col < row.length ? row[col].toString().trim() : '';
      final name = cell(nameCol);
      if (name.isEmpty) continue;
      final value = double.tryParse(cell(valueCol));
      final parsedDate = DateTime.tryParse(cell(dateCol));
      final currency = cell(currencyCol).toUpperCase();
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
          currency.isEmpty) {
        warnings.add('Current value of "$name" not imported: invalid row');
        continue;
      }
      result[(
        cell(archivedCol).toLowerCase() == 'true',
        name.toLowerCase(),
      )] = _ImportedValuation(
        value: value,
        date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
        currency: currency,
      );
    }
    return result;
  }

  /// Reads custom_types.json (see `DataExportService`): the reusable types
  /// and the custom type label of each Other investment, keyed by (archived,
  /// lowercase investment name) the way valuations are. Null, with one
  /// warning that holds no label text, if the file is not readable JSON of
  /// the expected shape. A row of the wrong shape is skipped.
  _ImportedCustomTypes? _parseCustomTypes(
    List<int> bytes,
    List<String> warnings,
  ) {
    Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      json = null;
    }
    if (json is! Map<String, dynamic>) {
      warnings.add('Custom types not imported: custom_types.json is invalid');
      return null;
    }
    final types = <_ImportedCustomType>[];
    final rawTypes = json['types'];
    if (rawTypes is List) {
      for (final row in rawTypes) {
        if (row is! Map) continue;
        final label = row['label'];
        if (label is! String || label.trim().isEmpty) continue;
        types.add(
          _ImportedCustomType(label: label, removed: row['removed'] == true),
        );
      }
    }
    final links = <(bool, String), _ImportedCustomTypeRef>{};
    final rawLinks = json['investments'];
    if (rawLinks is List) {
      for (final row in rawLinks) {
        if (row is! Map) continue;
        final name = row['name'];
        final label = row['label'];
        if (name is! String || name.trim().isEmpty) continue;
        if (label is! String || label.trim().isEmpty) continue;
        links[(row['archived'] == true, name.trim().toLowerCase())] =
            _ImportedCustomTypeRef(label: label, linked: row['linked'] == true);
      }
    }
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

/// A current value read from valuations.csv.
class _ImportedValuation {
  final double value;
  final DateTime date;
  final String currency;

  const _ImportedValuation({
    required this.value,
    required this.date,
    required this.currency,
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
