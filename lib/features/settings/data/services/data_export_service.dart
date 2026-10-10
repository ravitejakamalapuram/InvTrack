import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:inv_tracker/core/calculations/valuation_snapshot_selector.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/core/utils/csv_utils.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/income_projection/domain/repositories/expected_cash_flow_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_valuation_snapshot.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/valuation_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';

/// File types for metadata.json
enum ExportFileType {
  cashflows,
  cashflowsArchived,
  goals,
  goalsArchived,
  valuations,
}

/// An export ZIP held in memory, with the number of records it was built
/// from, so a caller can check that an import of it was complete.
class ZipExport {
  const ZipExport({
    required this.bytes,
    required this.investments,
    required this.cashFlows,
    required this.goals,
    required this.documents,
    required this.hasFireSettings,
    required this.investmentsWithDetailsNotInExport,
    required this.investmentsNotInExport,
    required this.expectedCashFlows,
  });

  final Uint8List bytes;

  /// Active and archived investments, including any without cash flows.
  final int investments;

  /// Active and archived cash flows.
  final int cashFlows;

  /// Active and archived goals.
  final int goals;

  final int documents;
  final bool hasFireSettings;

  /// Investments holding details the ZIP does not carry (see
  /// [investmentHasDetailsNotInExport]); an import recreates them without.
  final int investmentsWithDetailsNotInExport;

  /// Investments with neither cash flows nor a valuation. The ZIP holds an
  /// investment only as cash flow rows or valuation rows, so it does not hold
  /// these at all (nor can an import attach their documents to them).
  final int investmentsNotInExport;

  /// Expected cash flows, which the ZIP does not carry at all; null if they
  /// could not be counted.
  final int? expectedCashFlows;

  /// Whether an import of [bytes] can recreate everything counted here.
  bool get carriesEverything =>
      investmentsWithDetailsNotInExport == 0 &&
      investmentsNotInExport == 0 &&
      expectedCashFlows == 0;

  /// The investments an import of [bytes] can recreate.
  int get investmentsInExport => investments - investmentsNotInExport;
}

/// Whether [investment] holds details the export ZIP does not carry. The ZIP
/// keeps only name, type, status, currency and cash flows per investment, so
/// an import recreates it without these (and without the maturity and income
/// reminders that depend on them).
bool investmentHasDetailsNotInExport(InvestmentEntity investment) =>
    (investment.notes?.isNotEmpty ?? false) ||
    investment.closedAt != null ||
    investment.maturityDate != null ||
    investment.incomeFrequency != null ||
    investment.startDate != null ||
    investment.expectedRate != null ||
    investment.tenureMonths != null ||
    investment.platform != null ||
    investment.interestPayoutMode != null ||
    investment.autoRenewal != null ||
    investment.riskLevel != null ||
    investment.compoundingFrequency != null;

/// Service for exporting all user data as a ZIP file with CSV data files
class DataExportService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  final DocumentRepository _documentRepository;
  final DocumentStorageService _documentStorageService;
  final FireSettingsRepository? _fireSettingsRepository;
  final ExpectedCashFlowRepository? _expectedCashFlowRepository;
  final ValuationRepository? _valuationRepository;
  final PerformanceService _performanceService;

  DataExportService({
    required InvestmentRepository investmentRepository,
    required GoalRepository goalRepository,
    required DocumentRepository documentRepository,
    required DocumentStorageService documentStorageService,
    FireSettingsRepository? fireSettingsRepository,
    ExpectedCashFlowRepository? expectedCashFlowRepository,
    ValuationRepository? valuationRepository,
    required PerformanceService performanceService,
  }) : _investmentRepository = investmentRepository,
       _goalRepository = goalRepository,
       _documentRepository = documentRepository,
       _documentStorageService = documentStorageService,
       _fireSettingsRepository = fireSettingsRepository,
       _expectedCashFlowRepository = expectedCashFlowRepository,
       _valuationRepository = valuationRepository,
       _performanceService = performanceService;

  /// Export all user data as a ZIP file
  /// Returns the path to the exported ZIP file
  Future<String> exportAsZip() async {
    return _performanceService.trackOperation(
      'data_export',
      () async => _saveToTempFile((await _buildZip()).bytes),
    );
  }

  /// Export all user data as a ZIP held in memory, without writing a file.
  Future<ZipExport> exportAsZipBytes() async {
    return _performanceService.trackOperation('data_export', _buildZip);
  }

  /// Builds the export ZIP in memory.
  Future<ZipExport> _buildZip() async {
    LoggerService.info('Starting data export');

    // 1. Fetch all data
    final investments = await _investmentRepository.getAllInvestments();
    final archivedInvestments = await _investmentRepository
        .watchArchivedInvestments()
        .first;
    // Dated valuations: the live ones, by investment. Cleared ones are
    // tombstones and are not exported.
    final snapshotsByInvestment = <String, List<InvestmentValuationSnapshot>>{};
    for (final snapshot
        in await _valuationRepository?.getAll() ??
            const <InvestmentValuationSnapshot>[]) {
      if (snapshot.isLive) {
        snapshotsByInvestment
            .putIfAbsent(snapshot.investmentId, () => [])
            .add(snapshot);
      }
    }

    // Separate active and archived cashflows
    final activeCashFlows = <_CashFlowWithInvestment>[];
    final archivedCashFlows = <_CashFlowWithInvestment>[];
    // The ZIP holds an investment only as its cash flow rows or its
    // valuation rows.
    var investmentsWithoutCashFlows = 0;

    for (final inv in investments) {
      final cashFlows = await _investmentRepository.getCashFlowsByInvestment(
        inv.id,
      );
      if (cashFlows.isEmpty &&
          _valuationRowsOf(inv, snapshotsByInvestment).isEmpty) {
        investmentsWithoutCashFlows++;
      }
      for (final cf in cashFlows) {
        activeCashFlows.add(_CashFlowWithInvestment(cf, inv));
      }
    }

    for (final inv in archivedInvestments) {
      final cashFlows = await _investmentRepository
          .getArchivedCashFlowsByInvestment(inv.id);
      if (cashFlows.isEmpty &&
          _valuationRowsOf(inv, snapshotsByInvestment).isEmpty) {
        investmentsWithoutCashFlows++;
      }
      for (final cf in cashFlows) {
        archivedCashFlows.add(_CashFlowWithInvestment(cf, inv));
      }
    }

    final goals = await _goalRepository.getAllGoals();
    final archivedGoals = await _goalRepository.watchArchivedGoals().first;

    // Get all documents from all investments
    final allInvestments = [...investments, ...archivedInvestments];
    final allDocuments = <DocumentEntity>[];
    for (final inv in allInvestments) {
      final docs = await _documentRepository.getDocumentsByInvestment(inv.id);
      allDocuments.addAll(docs);
    }

    LoggerService.info(
      'Data export: fetched all data',
      metadata: {
        'activeCashFlows': activeCashFlows.length,
        'archivedCashFlows': archivedCashFlows.length,
        'goals': goals.length,
        'archivedGoals': archivedGoals.length,
        'documents': allDocuments.length,
      },
    );

    // 2. Generate CSV files
    final cashflowsCsv = _generateCashFlowsCsv(activeCashFlows);
    final cashflowsArchivedCsv = _generateCashFlowsCsv(archivedCashFlows);
    final goalsCsv = _generateGoalsCsv(goals, allInvestments);
    final goalsArchivedCsv = _generateGoalsCsv(archivedGoals, allInvestments);
    final valuationsCsv = _generateValuationsCsv(
      active: investments,
      archived: archivedInvestments,
      snapshots: snapshotsByInvestment,
    );

    // 3. Create metadata JSON
    final metadata = _createMetadata(
      documents: allDocuments,
      investments: allInvestments,
    );

    // 4. Create ZIP archive
    final archive = Archive();

    // Add CSV files
    final cashflowsBytes = utf8.encode(cashflowsCsv);
    archive.addFile(
      ArchiveFile('cashflows.csv', cashflowsBytes.length, cashflowsBytes),
    );

    final cashflowsArchivedBytes = utf8.encode(cashflowsArchivedCsv);
    archive.addFile(
      ArchiveFile(
        'cashflows_archived.csv',
        cashflowsArchivedBytes.length,
        cashflowsArchivedBytes,
      ),
    );

    final goalsBytes = utf8.encode(goalsCsv);
    archive.addFile(ArchiveFile('goals.csv', goalsBytes.length, goalsBytes));

    final goalsArchivedBytes = utf8.encode(goalsArchivedCsv);
    archive.addFile(
      ArchiveFile(
        'goals_archived.csv',
        goalsArchivedBytes.length,
        goalsArchivedBytes,
      ),
    );

    final valuationsBytes = utf8.encode(valuationsCsv);
    archive.addFile(
      ArchiveFile('valuations.csv', valuationsBytes.length, valuationsBytes),
    );

    // Add metadata JSON
    final metadataBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(
      ArchiveFile('metadata.json', metadataBytes.length, metadataBytes),
    );

    // Add documents to the archive
    int documentsAdded = 0;
    int documentsFailed = 0;
    for (final doc in allDocuments) {
      final bytes = await _documentStorageService.readDocument(doc.localPath);
      if (bytes != null) {
        // Sanitize filename to prevent path traversal in ZIP
        final safeFileName = path.basename(doc.fileName);
        final docPath = 'documents/${doc.investmentId}/$safeFileName';
        archive.addFile(ArchiveFile(docPath, bytes.length, bytes));
        documentsAdded++;
      } else {
        LoggerService.debug(
          'Document not found or inaccessible during export',
          metadata: {'documentId': doc.id, 'investmentId': doc.investmentId},
        );
        documentsFailed++;
      }
    }
    // One report per export, as a count: no names or paths (CLAUDE.md rule 7).
    if (documentsFailed > 0) {
      LoggerService.warn(
        'Documents missing from export',
        metadata: {'documentsMissing': documentsFailed},
      );
    }

    LoggerService.info(
      'Documents export summary',
      metadata: {
        'total': allDocuments.length,
        'added': documentsAdded,
        'failed': documentsFailed,
      },
    );

    // Add FIRE settings if available (Rule 18: Data Lifecycle)
    var hasFireSettings = false;
    if (_fireSettingsRepository != null) {
      final fireSettings = await _fireSettingsRepository.getSettings();
      if (fireSettings != null) {
        hasFireSettings = true;
        final fireSettingsBytes = utf8.encode(
          jsonEncode(fireSettings.toJson()),
        );
        archive.addFile(
          ArchiveFile(
            'fire_settings.json',
            fireSettingsBytes.length,
            fireSettingsBytes,
          ),
        );
        LoggerService.debug('Added FIRE settings to export');
      }
    }

    // Not in the ZIP; counted so a caller can tell the user what an import
    // of it leaves behind. A failed count must not fail the export itself;
    // it is reported as unknown (null).
    int? expectedCashFlows;
    try {
      expectedCashFlows =
          (await _expectedCashFlowRepository?.getAllExpectedCashFlows())
              ?.length ??
          0;
    } catch (e, st) {
      LoggerService.error(
        'Could not count expected cash flows for export',
        error: e,
        stackTrace: st,
      );
    }

    // 5. Encode to ZIP
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('Failed to create ZIP archive');
    }
    return ZipExport(
      bytes: Uint8List.fromList(zipData),
      investments: allInvestments.length,
      cashFlows: activeCashFlows.length + archivedCashFlows.length,
      goals: goals.length + archivedGoals.length,
      documents: allDocuments.length,
      hasFireSettings: hasFireSettings,
      investmentsWithDetailsNotInExport: allInvestments
          .where(investmentHasDetailsNotInExport)
          .length,
      investmentsNotInExport: investmentsWithoutCashFlows,
      expectedCashFlows: expectedCashFlows,
    );
  }

  /// Saves export ZIP bytes to the temp directory and returns the file path.
  Future<String> _saveToTempFile(Uint8List zipData) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'InvTrack_Export_$timestamp.zip';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(zipData);

    LoggerService.info(
      'Export saved',
      metadata: {
        'filePath': filePath,
        'fileSizeKB': (zipData.length / 1024).toStringAsFixed(1),
      },
    );

    return filePath;
  }

  /// Export and share the ZIP file
  Future<void> exportAndShare() async {
    await shareZipFiles([await exportAsZip()]);
  }

  /// Shares export ZIP files already on disk, such as kept guest backups.
  Future<void> shareZipFiles(List<String> filePaths) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final filePath in filePaths) XFile(filePath)],
        text: 'InvTrack data export. Keep this file safe for backup or import.',
        subject: 'InvTrack Data Export',
      ),
    );
  }

  // ============ CSV Generation ============

  /// Generate CSV for cashflows with full investment metadata
  /// Format: Date, Investment Name, Type, Amount, Currency, Notes, Investment Type, Investment Status
  String _generateCashFlowsCsv(List<_CashFlowWithInvestment> items) {
    final rows = <List<dynamic>>[];

    // Header row - extended format with investment metadata and currency
    rows.add([
      'Date',
      'Investment Name',
      'Type',
      'Amount',
      'Currency',
      'Notes',
      'Investment Type',
      'Investment Status',
    ]);

    // Sort by date
    items.sort((a, b) => a.cashFlow.date.compareTo(b.cashFlow.date));

    // Data rows
    for (final item in items) {
      rows.add([
        item.cashFlow.date.toIso8601String().split('T').first,
        CsvUtils.sanitizeField(item.investment.name),
        _typeToExportString(item.cashFlow.type),
        item.cashFlow.amount,
        item.cashFlow.currency, // Preserve original currency (Rule 21.2)
        CsvUtils.sanitizeField(item.cashFlow.notes ?? ''),
        item.investment.type.name,
        item.investment.status.name,
      ]);
    }

    return csv.encode(rows);
  }

  /// Generate CSV for goals
  /// Format: Name, Type, Target Amount, Target Monthly Income, Target Date,
  ///         Tracking Mode, Linked Investment Names, Linked Types, Icon, Color, Currency
  String _generateGoalsCsv(
    List<GoalEntity> goals,
    List<InvestmentEntity> allInvestments,
  ) {
    // Create a map of investment ID to name for quick lookup
    final idToName = {for (final inv in allInvestments) inv.id: inv.name};

    final rows = <List<dynamic>>[];

    // Header row - includes Currency column (Rule 21.4)
    rows.add([
      'Name',
      'Type',
      'Target Amount',
      'Target Monthly Income',
      'Target Date',
      'Tracking Mode',
      'Linked Investment Names',
      'Linked Types',
      'Icon',
      'Color',
      'Currency',
    ]);

    // Data rows
    for (final goal in goals) {
      // Convert investment IDs to names for export
      final linkedNames = goal.linkedInvestmentIds
          .map((id) => idToName[id] ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      rows.add([
        CsvUtils.sanitizeField(goal.name),
        goal.type.name,
        goal.targetAmount,
        goal.targetMonthlyIncome ?? '',
        goal.targetDate?.toIso8601String().split('T').first ?? '',
        goal.trackingMode.name,
        CsvUtils.sanitizeField(linkedNames.join(';')),
        goal.linkedTypes.map((t) => t.name).join(';'),
        CsvUtils.sanitizeField(goal.icon),
        goal.colorValue,
        goal.currency, // Preserve original currency (Rule 21.2)
      ]);
    }

    return csv.encode(rows);
  }

  /// Generate CSV for the dated valuations users entered (money rule 6).
  /// Format: Investment Name, Archived, Date, Value, Currency, Snapshot ID,
  /// Kind, Source, Updated At, Investment Type, Investment Status.
  ///
  /// The first five columns are the ones older versions read, which keep the
  /// last row per investment: so each investment's rows go oldest first and
  /// the newest comes last. The Type and Status columns let an import create
  /// an investment that has no cash flows. Estimated values are not stored,
  /// so they are not exported.
  String _generateValuationsCsv({
    required List<InvestmentEntity> active,
    required List<InvestmentEntity> archived,
    required Map<String, List<InvestmentValuationSnapshot>> snapshots,
  }) {
    final rows = <List<dynamic>>[
      [
        'Investment Name',
        'Archived',
        'Date',
        'Value',
        'Currency',
        'Snapshot ID',
        'Kind',
        'Source',
        'Updated At',
        'Investment Type',
        'Investment Status',
      ],
    ];
    for (final (inv, isArchived) in [
      for (final inv in active) (inv, false),
      for (final inv in archived) (inv, true),
    ]) {
      for (final row in _valuationRowsOf(inv, snapshots)) {
        rows.add([
          CsvUtils.sanitizeField(inv.name),
          isArchived,
          row.date.toIso8601String().split('T').first,
          row.value,
          row.currency,
          row.snapshotId ?? '',
          row.kind.name,
          row.provenance.storageName,
          row.updatedAt?.toUtc().toIso8601String() ?? '',
          inv.type.name,
          inv.status.name,
        ]);
      }
    }
    return csv.encode(rows);
  }

  /// The valuation rows of [inv], oldest first: its live snapshots, then the
  /// value its `currentValue` pair holds when that is what the app shows (an
  /// older app version wrote it after the snapshots), or when there are no
  /// snapshots at all (a value from before dated valuations, exported as the
  /// single row it always was).
  List<_ValuationRow> _valuationRowsOf(
    InvestmentEntity inv,
    Map<String, List<InvestmentValuationSnapshot>> snapshots,
  ) {
    final own = [...?snapshots[inv.id]]
      ..sort(ValuationSnapshotSelector.compare);
    final rows = [
      for (final s in own)
        _ValuationRow(
          date: s.effectiveDate,
          value: s.amount,
          currency: s.currency,
          snapshotId: s.id,
          kind: s.kind,
          provenance: s.provenance,
          updatedAt: s.updatedAt ?? DateTime.now(),
        ),
    ];
    final value = inv.currentValue;
    final date = inv.currentValueDate;
    if (value == null || date == null) return rows;
    final shown = ValuationSnapshotSelector.select(
      investment: inv,
      snapshots: own,
      asOf: DateTime.now(),
    );
    if (own.isEmpty || (shown?.isCompat ?? false)) {
      rows.add(
        _ValuationRow(
          date: date,
          value: value,
          currency: inv.currency,
          kind: ValuationKind.carryingValue,
          provenance: ValuationProvenance.manual,
        ),
      );
    }
    return rows;
  }

  /// Converts CashFlowType to export string (reused from ExportService)
  String _typeToExportString(CashFlowType type) {
    switch (type) {
      case CashFlowType.invest:
        return 'INVEST';
      case CashFlowType.income:
        return 'INCOME';
      case CashFlowType.returnFlow:
        return 'RETURN';
      case CashFlowType.fee:
        return 'FEE';
    }
  }

  // ============ Metadata ============

  /// Create simple metadata JSON structure
  Map<String, dynamic> _createMetadata({
    required List<DocumentEntity> documents,
    required List<InvestmentEntity> investments,
  }) {
    // Create a lookup map for investment names
    final investmentIdToName = <String, String>{
      for (final inv in investments) inv.id: inv.name,
    };

    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'files': [
        {'fileName': 'cashflows.csv', 'type': ExportFileType.cashflows.name},
        {
          'fileName': 'cashflows_archived.csv',
          'type': ExportFileType.cashflowsArchived.name,
        },
        {'fileName': 'goals.csv', 'type': ExportFileType.goals.name},
        {
          'fileName': 'goals_archived.csv',
          'type': ExportFileType.goalsArchived.name,
        },
        {'fileName': 'valuations.csv', 'type': ExportFileType.valuations.name},
      ],
      'documents': documents.map((d) {
        return _documentToJson(d, investmentIdToName[d.investmentId] ?? '');
      }).toList(),
    };
  }

  Map<String, dynamic> _documentToJson(
    DocumentEntity doc,
    String investmentName,
  ) {
    // Sanitize filename for metadata as well
    final safeFileName = path.basename(doc.fileName);
    return {
      'id': doc.id,
      'investmentId': doc.investmentId,
      'investmentName': investmentName,
      'name': doc.name,
      'fileName': safeFileName,
      'type': doc.type.name,
      'mimeType': doc.mimeType,
      'fileSize': doc.fileSize,
      'createdAt': doc.createdAt.toIso8601String(),
      'updatedAt': doc.updatedAt.toIso8601String(),
      'zipPath': 'documents/${doc.investmentId}/$safeFileName',
    };
  }
}

/// One row of valuations.csv, before it is written.
class _ValuationRow {
  final DateTime date;
  final double value;
  final String currency;

  /// Null for a legacy value, which has no snapshot.
  final String? snapshotId;
  final ValuationKind kind;
  final ValuationProvenance provenance;
  final DateTime? updatedAt;

  const _ValuationRow({
    required this.date,
    required this.value,
    required this.currency,
    this.snapshotId,
    required this.kind,
    required this.provenance,
    this.updatedAt,
  });
}

/// Helper class to hold cashflow with its investment
class _CashFlowWithInvestment {
  final CashFlowEntity cashFlow;
  final InvestmentEntity investment;

  _CashFlowWithInvestment(this.cashFlow, this.investment);
}
