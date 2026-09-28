import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';

/// Repository for managing investment documents
abstract class DocumentRepository {
  /// Watch all documents for an investment (reactive stream)
  Stream<List<DocumentEntity>> watchDocumentsByInvestment(String investmentId);

  /// Get all documents for an investment
  Future<List<DocumentEntity>> getDocumentsByInvestment(String investmentId);

  /// Get a document by ID
  Future<DocumentEntity?> getDocumentById(String documentId);

  /// Create a new document record
  Future<void> createDocument(DocumentEntity document);

  /// Update an existing document record
  Future<void> updateDocument(DocumentEntity document);

  /// Delete a document record (does not delete the file)
  Future<void> deleteDocument(String documentId);

  /// Delete all documents for an investment
  Future<void> deleteDocumentsByInvestment(String investmentId);

  /// Delete every document record for the current user, regardless of which
  /// investment it is attached to. Used for full account/data deletion so no
  /// document metadata is left behind.
  Future<void> deleteAllDocuments();

  /// Get total document count for an investment
  Future<int> getDocumentCount(String investmentId);
}
