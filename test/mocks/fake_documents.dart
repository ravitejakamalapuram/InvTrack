import 'dart:typed_data';

import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';

/// In-memory document records, keyed by id.
class FakeDocumentRepository implements DocumentRepository {
  final Map<String, DocumentEntity> records = {};

  /// Set to make [createDocument] throw, to test failure handling.
  bool failOnCreate = false;

  @override
  Stream<List<DocumentEntity>> watchDocumentsByInvestment(
    String investmentId,
  ) => Stream.value(
    records.values.where((d) => d.investmentId == investmentId).toList(),
  );

  @override
  Future<List<DocumentEntity>> getDocumentsByInvestment(
    String investmentId,
  ) async =>
      records.values.where((d) => d.investmentId == investmentId).toList();

  @override
  Future<DocumentEntity?> getDocumentById(String documentId) async =>
      records[documentId];

  @override
  Future<void> createDocument(DocumentEntity document) async {
    if (failOnCreate) throw Exception('create failed');
    records[document.id] = document;
  }

  @override
  Future<void> updateDocument(DocumentEntity document) async =>
      records[document.id] = document;

  @override
  Future<void> deleteDocument(String documentId) async =>
      records.remove(documentId);

  @override
  Future<void> deleteDocumentsByInvestment(String investmentId) async =>
      records.removeWhere((_, d) => d.investmentId == investmentId);

  @override
  Future<void> deleteAllDocuments() async => records.clear();

  @override
  Future<int> getDocumentCount(String investmentId) async =>
      records.values.where((d) => d.investmentId == investmentId).length;
}

/// In-memory document files: path -> bytes. No disk, no path_provider.
class FakeDocumentStorageService extends DocumentStorageService {
  FakeDocumentStorageService() : super(userId: 'test-user');

  final Map<String, Uint8List> files = {};

  @override
  Future<String> saveDocument({
    required String investmentId,
    required String documentId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final path = '$investmentId/$documentId.${fileName.split('.').last}';
    files[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List?> readDocument(String localPath) async => files[localPath];

  @override
  Future<void> deleteDocument(String localPath) async =>
      files.remove(localPath);

  @override
  Future<void> deleteInvestmentDocuments(String investmentId) async =>
      files.removeWhere((path, _) => path.startsWith('$investmentId/'));
}
