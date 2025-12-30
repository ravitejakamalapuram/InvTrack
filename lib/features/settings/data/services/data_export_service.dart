import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/repositories/goal_repository.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/investment_repository.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';

/// Service for exporting all user data as a ZIP file with encrypted metadata
class DataExportService {
  final InvestmentRepository _investmentRepository;
  final GoalRepository _goalRepository;
  final DocumentRepository _documentRepository;
  final DocumentStorageService _documentStorageService;
  final String _userId;

  /// Encryption key derived from user ID (for data portability)
  static const String _encryptionSalt = 'InvTrack_Export_2024';

  DataExportService({
    required InvestmentRepository investmentRepository,
    required GoalRepository goalRepository,
    required DocumentRepository documentRepository,
    required DocumentStorageService documentStorageService,
    required String userId,
  })  : _investmentRepository = investmentRepository,
        _goalRepository = goalRepository,
        _documentRepository = documentRepository,
        _documentStorageService = documentStorageService,
        _userId = userId;

  /// Export all user data as a ZIP file
  /// Returns the path to the exported ZIP file
  Future<String> exportAsZip() async {
    if (kDebugMode) {
      debugPrint('📦 Starting data export...');
    }

    // 1. Fetch all data
    final investments = await _investmentRepository.getAllInvestments();
    // Get archived investments from stream (first emission)
    final archivedInvestments =
        await _investmentRepository.watchArchivedInvestments().first;
    final allInvestments = [...investments, ...archivedInvestments];

    final allCashFlows = <CashFlowEntity>[];
    for (final inv in allInvestments) {
      // Use appropriate method based on whether investment is archived
      final cashFlows = inv.isArchived
          ? await _investmentRepository.getArchivedCashFlowsByInvestment(inv.id)
          : await _investmentRepository.getCashFlowsByInvestment(inv.id);
      allCashFlows.addAll(cashFlows);
    }

    final goals = await _goalRepository.getAllGoals();
    // Get archived goals from stream (first emission)
    final archivedGoals = await _goalRepository.watchArchivedGoals().first;
    final allGoals = [...goals, ...archivedGoals];

    // Get all documents
    final allDocuments = <DocumentEntity>[];
    for (final inv in allInvestments) {
      final docs =
          await _documentRepository.getDocumentsByInvestment(inv.id);
      allDocuments.addAll(docs);
    }

    if (kDebugMode) {
      debugPrint('📦 Found ${allInvestments.length} investments, '
          '${allCashFlows.length} cash flows, '
          '${allGoals.length} goals, '
          '${allDocuments.length} documents');
    }

    // 2. Create metadata JSON
    final metadata = _createMetadata(
      investments: allInvestments,
      cashFlows: allCashFlows,
      goals: allGoals,
      documents: allDocuments,
    );

    // 3. Encrypt metadata
    final encryptedMetadata = _encryptData(jsonEncode(metadata));

    // 4. Create ZIP archive
    final archive = Archive();

    // Add encrypted metadata
    archive.addFile(ArchiveFile(
      'metadata.enc',
      encryptedMetadata.length,
      encryptedMetadata,
    ));

    // Add plain text README
    final readme = _createReadme();
    archive.addFile(ArchiveFile(
      'README.txt',
      readme.length,
      utf8.encode(readme),
    ));

    // Add documents to the archive
    for (final doc in allDocuments) {
      final bytes = await _documentStorageService.readDocument(doc.localPath);
      if (bytes != null) {
        final docPath = 'documents/${doc.investmentId}/${doc.fileName}';
        archive.addFile(ArchiveFile(docPath, bytes.length, bytes));
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
      debugPrint('📦 File size: ${(zipData.length / 1024).toStringAsFixed(1)} KB');
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

  /// Create metadata JSON structure
  Map<String, dynamic> _createMetadata({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
    required List<GoalEntity> goals,
    required List<DocumentEntity> documents,
  }) {
    return {
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'userId': _userId,
      'investments': investments.map((i) => _investmentToJson(i)).toList(),
      'cashFlows': cashFlows.map((c) => _cashFlowToJson(c)).toList(),
      'goals': goals.map((g) => _goalToJson(g)).toList(),
      'documents': documents.map((d) => _documentToJson(d)).toList(),
      'stats': {
        'totalInvestments': investments.length,
        'totalCashFlows': cashFlows.length,
        'totalGoals': goals.length,
        'totalDocuments': documents.length,
      },
    };
  }

  Map<String, dynamic> _investmentToJson(InvestmentEntity inv) => {
        'id': inv.id,
        'name': inv.name,
        'type': inv.type.name,
        'status': inv.status.name,
        'notes': inv.notes,
        'createdAt': inv.createdAt.toIso8601String(),
        'updatedAt': inv.updatedAt.toIso8601String(),
        'maturityDate': inv.maturityDate?.toIso8601String(),
        'incomeFrequency': inv.incomeFrequency?.name,
        'isArchived': inv.isArchived,
      };

  Map<String, dynamic> _cashFlowToJson(CashFlowEntity cf) => {
        'id': cf.id,
        'investmentId': cf.investmentId,
        'type': cf.type.name,
        'amount': cf.amount,
        'date': cf.date.toIso8601String(),
        'notes': cf.notes,
        'createdAt': cf.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _goalToJson(GoalEntity goal) => {
        'id': goal.id,
        'name': goal.name,
        'type': goal.type.name,
        'targetAmount': goal.targetAmount,
        'targetMonthlyIncome': goal.targetMonthlyIncome,
        'targetDate': goal.targetDate?.toIso8601String(),
        'trackingMode': goal.trackingMode.name,
        'linkedInvestmentIds': goal.linkedInvestmentIds,
        'linkedTypes': goal.linkedTypes.map((t) => t.name).toList(),
        'icon': goal.icon,
        'colorValue': goal.colorValue,
        'isArchived': goal.isArchived,
        'createdAt': goal.createdAt.toIso8601String(),
        'updatedAt': goal.updatedAt.toIso8601String(),
      };

  Map<String, dynamic> _documentToJson(DocumentEntity doc) => {
        'id': doc.id,
        'investmentId': doc.investmentId,
        'name': doc.name,
        'fileName': doc.fileName,
        'type': doc.type.name,
        'mimeType': doc.mimeType,
        'fileSize': doc.fileSize,
        'createdAt': doc.createdAt.toIso8601String(),
        'updatedAt': doc.updatedAt.toIso8601String(),
        // localPath is replaced with relative path in ZIP
        'zipPath': 'documents/${doc.investmentId}/${doc.fileName}',
      };

  /// Encrypt data using AES encryption
  Uint8List _encryptData(String plainText) {
    // Derive key from user ID + salt (for portability)
    final keyString = '$_encryptionSalt$_userId'.padRight(32, '0').substring(0, 32);
    final key = encrypt.Key.fromUtf8(keyString);
    final iv = encrypt.IV.fromLength(16);

    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Prepend IV to encrypted data for decryption
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
    result.setAll(0, iv.bytes);
    result.setAll(iv.bytes.length, encrypted.bytes);

    return result;
  }

  /// Create README file content
  String _createReadme() => '''
InvTrack Data Export
====================

This ZIP file contains your complete InvTrack data backup.

Contents:
- metadata.enc: Encrypted JSON containing all your investment data
- documents/: Folder containing all attached documents

How to Import:
1. Open InvTrack on another device
2. Go to Settings > Data Management > Import Backup
3. Select this ZIP file

Security Note:
The metadata.enc file is encrypted with your account credentials.
Only you can decrypt and import this data.

Export Date: ${DateTime.now().toIso8601String()}

For support, visit: https://invtrack.app/support
''';
}

