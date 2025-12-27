import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';

/// Provider for DocumentNotifier - handles document CRUD operations
final documentNotifierProvider = Provider<DocumentNotifier>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  if (!isAuthenticated) {
    throw AuthException.notAuthenticated();
  }

  return DocumentNotifier(
    repository: ref.watch(documentRepositoryProvider),
    storageService: ref.watch(documentStorageServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
});

/// Notifier for document operations
class DocumentNotifier {
  final DocumentRepository _repository;
  final DocumentStorageService _storageService;
  final AnalyticsService _analytics;
  final _uuid = const Uuid();

  DocumentNotifier({
    required DocumentRepository repository,
    required DocumentStorageService storageService,
    required AnalyticsService analytics,
  })  : _repository = repository,
        _storageService = storageService,
        _analytics = analytics;

  /// Add a new document to an investment
  /// [investmentId] - The investment to attach the document to
  /// [name] - User-friendly name for the document
  /// [fileName] - Original file name
  /// [type] - Document type category
  /// [bytes] - The file content
  Future<DocumentEntity> addDocument({
    required String investmentId,
    required String name,
    required String fileName,
    required DocumentType type,
    required Uint8List bytes,
  }) async {
    // Validate file name
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ValidationException(
        userMessage: 'Document name cannot be empty',
        technicalMessage: 'Empty document name provided',
      );
    }
    if (trimmedName.length > 100) {
      throw ValidationException(
        userMessage: 'Document name cannot exceed 100 characters',
        technicalMessage: 'Document name length ${trimmedName.length} exceeds 100',
      );
    }

    // Validate file is supported
    if (!DocumentMimeTypes.isSupported(fileName)) {
      throw ValidationException(
        userMessage: 'Unsupported file type. Supported: PDF, JPG, PNG, GIF, WEBP',
        technicalMessage: 'Unsupported file type: $fileName',
      );
    }

    // Validate file size (max 10MB)
    const maxSize = 10 * 1024 * 1024; // 10MB
    if (bytes.length > maxSize) {
      throw ValidationException(
        userMessage: 'File size cannot exceed 10MB',
        technicalMessage: 'File size ${bytes.length} exceeds max $maxSize',
      );
    }

    final documentId = _uuid.v4();
    final now = DateTime.now();

    // Save file locally
    final localPath = await _storageService.saveDocument(
      investmentId: investmentId,
      documentId: documentId,
      fileName: fileName,
      bytes: bytes,
    );

    // Create document entity
    final document = DocumentEntity(
      id: documentId,
      investmentId: investmentId,
      name: trimmedName,
      fileName: fileName,
      type: type,
      mimeType: DocumentMimeTypes.getMimeType(fileName),
      localPath: localPath,
      fileSize: bytes.length,
      createdAt: now,
      updatedAt: now,
    );

    // Save to Firestore
    await _repository.createDocument(document);

    // Track analytics
    _analytics.trackDocumentAdded(
      documentType: type.name,
      fileType: DocumentMimeTypes.isImage(fileName) ? 'image' : 'pdf',
    );

    if (kDebugMode) {
      debugPrint('📄 Document added: ${document.name} to investment $investmentId');
    }

    return document;
  }

  /// Update document metadata (name or type)
  Future<void> updateDocument({
    required String documentId,
    String? name,
    DocumentType? type,
  }) async {
    final existing = await _repository.getDocumentById(documentId);
    if (existing == null) {
      throw DataException.notFound('Document', documentId);
    }

    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isEmpty) {
      throw ValidationException(
        userMessage: 'Document name cannot be empty',
        technicalMessage: 'Empty document name provided for update',
      );
    }
    if (trimmedName != null && trimmedName.length > 100) {
      throw ValidationException(
        userMessage: 'Document name cannot exceed 100 characters',
        technicalMessage: 'Document name length ${trimmedName.length} exceeds 100',
      );
    }

    final updated = existing.copyWith(
      name: trimmedName ?? existing.name,
      type: type ?? existing.type,
      updatedAt: DateTime.now(),
    );

    await _repository.updateDocument(updated);

    if (kDebugMode) {
      debugPrint('📄 Document updated: ${updated.name}');
    }
  }

  /// Delete a document and its file
  Future<void> deleteDocument(String documentId) async {
    final document = await _repository.getDocumentById(documentId);
    if (document == null) {
      throw DataException.notFound('Document', documentId);
    }

    // Delete file first
    await _storageService.deleteDocument(document.localPath);

    // Delete from Firestore
    await _repository.deleteDocument(documentId);

    if (kDebugMode) {
      debugPrint('📄 Document deleted: ${document.name}');
    }
  }

  /// Delete all documents for an investment
  Future<void> deleteAllDocumentsForInvestment(String investmentId) async {
    // Delete all files
    await _storageService.deleteInvestmentDocuments(investmentId);

    // Delete from Firestore
    await _repository.deleteDocumentsByInvestment(investmentId);

    if (kDebugMode) {
      debugPrint('📄 All documents deleted for investment $investmentId');
    }
  }

  /// Check if a document file exists locally
  Future<bool> documentFileExists(String localPath) async {
    return _storageService.documentExists(localPath);
  }

  /// Get document file bytes
  Future<Uint8List?> getDocumentBytes(String localPath) async {
    return _storageService.readDocument(localPath);
  }
}

