import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
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
      investmentsImported + cashflowsImported + goalsImported + documentsImported;
}

/// Service for importing user data from a ZIP file
class DataImportService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  final DocumentRepository _documentRepository;
  final DocumentStorageService _documentStorageService;
  final FireSettingsRepository? _fireSettingsRepository;

  static const _uuid = Uuid();

  DataImportService({
    required InvestmentRepository investmentRepository,
    required GoalRepository goalRepository,
    required DocumentRepository documentRepository,
    required DocumentStorageService documentStorageService,
    FireSettingsRepository? fireSettingsRepository,
  })  : _investmentRepository = investmentRepository,
        _goalRepository = goalRepository,
        _documentRepository = documentRepository,
        _documentStorageService = documentStorageService,
        _fireSettingsRepository = fireSettingsRepository;

  /// Import data from a ZIP file
  Future<ZipImportResult> importFromZip(
    Uint8List zipBytes,
    ImportStrategy strategy,
  ) async {
    LoggerService.info('Starting ZIP import', metadata: {'strategy': strategy.name});

    final errors = <String>[];
    final warnings = <String>[];

    // 1. Decode ZIP archive
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
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
      );
      investmentsImported += result.investmentsCreated;
      cashflowsImported += result.imported;
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
      );
      goalsImported += result.imported;
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
            newInvestmentId = investmentNameToIdMap[investmentName.toLowerCase()];
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
          final fireSettingsJson = jsonDecode(
            utf8.decode(fireSettingsFile.content as List<int>),
          ) as Map<String, dynamic>;

          final fireSettings = FireSettingsEntity(
            id: fireSettingsJson['id'] as String? ?? _uuid.v4(),
            monthlyExpenses: (fireSettingsJson['monthlyExpenses'] as num).toDouble(),
            safeWithdrawalRate:
                (fireSettingsJson['safeWithdrawalRate'] as num?)?.toDouble() ?? 4.0,
            currentAge: fireSettingsJson['currentAge'] as int,
            targetFireAge: fireSettingsJson['targetFireAge'] as int,
            lifeExpectancy: (fireSettingsJson['lifeExpectancy'] as int?) ?? 85,
            inflationRate:
                (fireSettingsJson['inflationRate'] as num?)?.toDouble() ?? 6.0,
            preRetirementReturn:
                (fireSettingsJson['preRetirementReturn'] as num?)?.toDouble() ?? 12.0,
            postRetirementReturn:
                (fireSettingsJson['postRetirementReturn'] as num?)?.toDouble() ?? 8.0,
            healthcareBuffer:
                (fireSettingsJson['healthcareBuffer'] as num?)?.toDouble() ?? 20.0,
            emergencyMonths:
                (fireSettingsJson['emergencyMonths'] as num?)?.toDouble() ?? 6,
            fireType: FireType.fromString(
              fireSettingsJson['fireType'] as String? ?? 'regular',
            ),
            monthlyPassiveIncome:
                (fireSettingsJson['monthlyPassiveIncome'] as num?)?.toDouble() ?? 0,
            expectedPension:
                (fireSettingsJson['expectedPension'] as num?)?.toDouble() ?? 0,
            isSetupComplete: fireSettingsJson['isSetupComplete'] as bool? ?? true,
            createdAt: DateTime.tryParse(
                    fireSettingsJson['createdAt'] as String? ?? '') ??
                DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _fireSettingsRepository.saveSettings(fireSettings);
          fireSettingsImported = true;
          LoggerService.info('FIRE settings imported successfully');
        } catch (e) {
          warnings.add('Failed to import FIRE settings: $e');
        }
      }
    }

    LoggerService.info('Import complete', metadata: {
      'investments': investmentsImported,
      'cashflows': cashflowsImported,
      'goals': goalsImported,
      'documents': documentsImported,
      'fireSettings': fireSettingsImported,
    });

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
    final archivedInvestments =
        await _investmentRepository.watchArchivedInvestments().first;

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
  }) async {
    final parseResult = SimpleCsvParser.parseString(csvContent);
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
      existingInvestmentNames = existing.map((e) => e.name.toLowerCase()).toSet();
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
      final investmentStatus = firstRow.investmentStatus ?? InvestmentStatus.open;

      investments.add(
        InvestmentEntity(
          id: investmentId,
          name: investmentName,
          type: investmentType,
          status: investmentStatus,
          createdAt: now,
          updatedAt: now,
          isArchived: isArchived,
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

  /// Import goals from CSV content
  Future<_CsvImportResult> _importGoalsCsv(
    String csvContent, {
    required bool isArchived,
    required ImportStrategy strategy,
    required Map<String, String> investmentNameToIdMap,
  }) async {
    final parseResult = GoalsCsvParser.parseString(csvContent);
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
          warnings.add(
            'Goal "${row.name}": could not find investment "$name"',
          );
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
        linkedTypes:
            row.linkedTypes.map((t) => InvestmentType.values.firstWhere(
                  (e) => e.name == t,
                  orElse: () => InvestmentType.other,
                )).toList(),
        icon: row.icon,
        colorValue: row.colorValue,
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

    // Save the file to local storage
    final localPath = await _documentStorageService.saveDocument(
      investmentId: investmentId,
      documentId: documentId,
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
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
      createdAt: DateTime.tryParse(docMeta['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(docMeta['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );

    await _documentRepository.createDocument(doc);
  }
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
