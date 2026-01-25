import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/utils/csv_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:inv_tracker/features/fire_number/domain/repositories/fire_settings_repository.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';

/// File types for metadata.json
enum ExportFileType {
  cashflows,
  cashflowsArchived,
  goals,
  goalsArchived,
}

/// Service for exporting all user data as a ZIP file with CSV data files
class DataExportService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  final DocumentRepository _documentRepository;
  final DocumentStorageService _documentStorageService;
  final FireSettingsRepository? _fireSettingsRepository;

  DataExportService({
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

  /// Export all user data as a ZIP file
  /// Returns the path to the exported ZIP file
  Future<String> exportAsZip() async {
    if (kDebugMode) {
      debugPrint('📦 Starting data export...');
    }

    // 1. Fetch all data
    final investments = await _investmentRepository.getAllInvestments();
    final archivedInvestments =
        await _investmentRepository.watchArchivedInvestments().first;

    // Separate active and archived cashflows
    final activeCashFlows = <_CashFlowWithInvestment>[];
    final archivedCashFlows = <_CashFlowWithInvestment>[];

    for (final inv in investments) {
      final cashFlows =
          await _investmentRepository.getCashFlowsByInvestment(inv.id);
      for (final cf in cashFlows) {
        activeCashFlows.add(_CashFlowWithInvestment(cf, inv));
      }
    }

    for (final inv in archivedInvestments) {
      final cashFlows =
          await _investmentRepository.getArchivedCashFlowsByInvestment(inv.id);
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
      final docs =
          await _documentRepository.getDocumentsByInvestment(inv.id);
      allDocuments.addAll(docs);
    }

    if (kDebugMode) {
      debugPrint('📦 Found ${activeCashFlows.length} active cashflows, '
          '${archivedCashFlows.length} archived cashflows, '
          '${goals.length} goals, ${archivedGoals.length} archived goals, '
          '${allDocuments.length} documents');
    }

    // 2. Generate CSV files
    final cashflowsCsv = _generateCashFlowsCsv(activeCashFlows);
    final cashflowsArchivedCsv = _generateCashFlowsCsv(archivedCashFlows);
    final goalsCsv = _generateGoalsCsv(goals, allInvestments);
    final goalsArchivedCsv = _generateGoalsCsv(archivedGoals, allInvestments);

    // 3. Create metadata JSON
    final metadata = _createMetadata(
      documents: allDocuments,
      investments: allInvestments,
    );

    // 4. Create ZIP archive
    final archive = Archive();

    // Add CSV files
    final cashflowsBytes = utf8.encode(cashflowsCsv);
    archive.addFile(ArchiveFile(
      'cashflows.csv',
      cashflowsBytes.length,
      cashflowsBytes,
    ));

    final cashflowsArchivedBytes = utf8.encode(cashflowsArchivedCsv);
    archive.addFile(ArchiveFile(
      'cashflows_archived.csv',
      cashflowsArchivedBytes.length,
      cashflowsArchivedBytes,
    ));

    final goalsBytes = utf8.encode(goalsCsv);
    archive.addFile(ArchiveFile(
      'goals.csv',
      goalsBytes.length,
      goalsBytes,
    ));

    final goalsArchivedBytes = utf8.encode(goalsArchivedCsv);
    archive.addFile(ArchiveFile(
      'goals_archived.csv',
      goalsArchivedBytes.length,
      goalsArchivedBytes,
    ));

    // Add metadata JSON
    final metadataBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(ArchiveFile(
      'metadata.json',
      metadataBytes.length,
      metadataBytes,
    ));

    // Add documents to the archive
    for (final doc in allDocuments) {
      final bytes = await _documentStorageService.readDocument(doc.localPath);
      if (bytes != null) {
        final docPath = 'documents/${doc.investmentId}/${doc.fileName}';
        archive.addFile(ArchiveFile(docPath, bytes.length, bytes));
      }
    }

    // Add FIRE settings if available (Rule 18: Data Lifecycle)
    if (_fireSettingsRepository != null) {
      final fireSettings = await _fireSettingsRepository.getSettings();
      if (fireSettings != null) {
        final fireSettingsBytes = utf8.encode(jsonEncode(fireSettings.toJson()));
        archive.addFile(ArchiveFile(
          'fire_settings.json',
          fireSettingsBytes.length,
          fireSettingsBytes,
        ));
        if (kDebugMode) {
          debugPrint('📦 Added FIRE settings to export');
        }
      }
    }

    // 5. Encode to ZIP
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('Failed to create ZIP archive');
    }

    // 6. Save to temp directory
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'InvTrack_Export_$timestamp.zip';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(zipData);

    if (kDebugMode) {
      debugPrint('📦 Export saved to: $filePath');
      debugPrint(
          '📦 File size: ${(zipData.length / 1024).toStringAsFixed(1)} KB');
    }

    return filePath;
  }

  /// Export and share the ZIP file
  Future<void> exportAndShare() async {
    final filePath = await exportAsZip();

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        text: 'InvTrack data export. Keep this file safe for backup or import.',
        subject: 'InvTrack Data Export',
      ),
    );
  }

  // ============ CSV Generation ============

  /// Generate CSV for cashflows with full investment metadata
  /// Format: Date, Investment Name, Type, Amount, Notes, Investment Type, Investment Status
  String _generateCashFlowsCsv(List<_CashFlowWithInvestment> items) {
    final rows = <List<dynamic>>[];

    // Header row - extended format with investment metadata
    rows.add([
      'Date',
      'Investment Name',
      'Type',
      'Amount',
      'Notes',
      'Investment Type',
      'Investment Status',
    ]);

    // Sort by date
    items.sort((a, b) => a.cashFlow.date.compareTo(b.cashFlow.date));

    // Data rows
    for (final item in items) {
      rows.add([
        CsvUtils.sanitizeField(
          item.cashFlow.date.toIso8601String().split('T').first,
        ),
        CsvUtils.sanitizeField(item.investment.name),
        CsvUtils.sanitizeField(_typeToExportString(item.cashFlow.type)),
        CsvUtils.sanitizeField(item.cashFlow.amount),
        CsvUtils.sanitizeField(item.cashFlow.notes ?? ''),
        CsvUtils.sanitizeField(item.investment.type.name),
        CsvUtils.sanitizeField(item.investment.status.name),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate CSV for goals
  /// Format: Name, Type, Target Amount, Target Monthly Income, Target Date,
  ///         Tracking Mode, Linked Investment Names, Linked Types, Icon, Color
  String _generateGoalsCsv(
    List<GoalEntity> goals,
    List<InvestmentEntity> allInvestments,
  ) {
    // Create a map of investment ID to name for quick lookup
    final idToName = {for (final inv in allInvestments) inv.id: inv.name};

    final rows = <List<dynamic>>[];

    // Header row - changed "Linked Investment IDs" to "Linked Investment Names"
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
        CsvUtils.sanitizeField(goal.type.name),
        CsvUtils.sanitizeField(goal.targetAmount),
        CsvUtils.sanitizeField(goal.targetMonthlyIncome ?? ''),
        CsvUtils.sanitizeField(
          goal.targetDate?.toIso8601String().split('T').first ?? '',
        ),
        CsvUtils.sanitizeField(goal.trackingMode.name),
        CsvUtils.sanitizeField(linkedNames.join(';')),
        CsvUtils.sanitizeField(goal.linkedTypes.map((t) => t.name).join(';')),
        CsvUtils.sanitizeField(goal.icon),
        CsvUtils.sanitizeField(goal.colorValue),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
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
          'type': ExportFileType.cashflowsArchived.name
        },
        {'fileName': 'goals.csv', 'type': ExportFileType.goals.name},
        {
          'fileName': 'goals_archived.csv',
          'type': ExportFileType.goalsArchived.name
        },
      ],
      'documents': documents.map((d) {
        return _documentToJson(d, investmentIdToName[d.investmentId] ?? '');
      }).toList(),
    };
  }

  Map<String, dynamic> _documentToJson(
    DocumentEntity doc,
    String investmentName,
  ) =>
      {
        'id': doc.id,
        'investmentId': doc.investmentId,
        'investmentName': investmentName,
        'name': doc.name,
        'fileName': doc.fileName,
        'type': doc.type.name,
        'mimeType': doc.mimeType,
        'fileSize': doc.fileSize,
        'createdAt': doc.createdAt.toIso8601String(),
        'updatedAt': doc.updatedAt.toIso8601String(),
        'zipPath': 'documents/${doc.investmentId}/${doc.fileName}',
      };
}

/// Helper class to hold cashflow with its investment
class _CashFlowWithInvestment {
  final CashFlowEntity cashFlow;
  final InvestmentEntity investment;

  _CashFlowWithInvestment(this.cashFlow, this.investment);
}

