import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/investment/domain/entities/document_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';

/// Firestore-based implementation of DocumentRepository
/// Stores document metadata in Firestore for sync across devices
/// Actual files are stored locally on device
class FirestoreDocumentRepository implements DocumentRepository {
  final FirebaseFirestore _firestore;
  final String _userId;

  /// Timeout for write operations - allows offline writes to complete quickly
  static const Duration _writeTimeout = Duration(seconds: 3);

  FirestoreDocumentRepository({
    required FirebaseFirestore firestore,
    required String userId,
  }) : _firestore = firestore,
       _userId = userId;

  /// Execute a write operation with timeout
  Future<void> _executeWrite(Future<void> Function() writeOperation) async {
    try {
      await writeOperation().timeout(_writeTimeout);
    } on TimeoutException {
      // Write is cached locally, will sync when online
    }
  }

  /// Collection reference for documents
  CollectionReference<Map<String, dynamic>> get _documentsRef =>
      _firestore.collection('users').doc(_userId).collection('documents');

  @override
  Stream<List<DocumentEntity>> watchDocumentsByInvestment(String investmentId) {
    // Use simple query without orderBy to avoid needing composite index
    // Sort in memory instead
    return _documentsRef
        .where('investmentId', isEqualTo: investmentId)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs
              .map((doc) => _documentFromFirestore(doc.data(), doc.id))
              .toList();
          // Sort by createdAt descending in memory
          docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return docs;
        });
  }

  @override
  Future<List<DocumentEntity>> getDocumentsByInvestment(
    String investmentId,
  ) async {
    final snapshot = await _documentsRef
        .where('investmentId', isEqualTo: investmentId)
        .get();
    final docs = snapshot.docs
        .map((doc) => _documentFromFirestore(doc.data(), doc.id))
        .toList();
    // Sort by createdAt descending in memory
    docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return docs;
  }

  @override
  Future<DocumentEntity?> getDocumentById(String documentId) async {
    final doc = await _documentsRef.doc(documentId).get();
    if (!doc.exists) return null;
    return _documentFromFirestore(doc.data()!, doc.id);
  }

  @override
  Future<void> createDocument(DocumentEntity document) async {
    await _executeWrite(
      () => _documentsRef.doc(document.id).set(_documentToFirestore(document)),
    );
  }

  @override
  Future<void> updateDocument(DocumentEntity document) async {
    await _executeWrite(
      () =>
          _documentsRef.doc(document.id).update(_documentToFirestore(document)),
    );
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await _executeWrite(() => _documentsRef.doc(documentId).delete());
  }

  @override
  Future<void> deleteDocumentsByInvestment(String investmentId) async {
    final snapshot = await _documentsRef
        .where('investmentId', isEqualTo: investmentId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await _executeWrite(() => batch.commit());
  }

  @override
  Future<int> getDocumentCount(String investmentId) async {
    final snapshot = await _documentsRef
        .where('investmentId', isEqualTo: investmentId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  // ============ FIRESTORE MAPPERS ============

  Map<String, dynamic> _documentToFirestore(DocumentEntity document) {
    return {
      'investmentId': document.investmentId,
      'name': document.name,
      'fileName': document.fileName,
      'type': document.type.name,
      'mimeType': document.mimeType,
      'localPath': document.localPath,
      'fileSize': document.fileSize,
      'createdAt': Timestamp.fromDate(document.createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DocumentEntity _documentFromFirestore(Map<String, dynamic> data, String id) {
    return DocumentEntity(
      id: id,
      investmentId: data['investmentId'] as String,
      name: data['name'] as String,
      fileName: data['fileName'] as String,
      type: DocumentType.fromString(data['type'] as String),
      mimeType: data['mimeType'] as String,
      localPath: data['localPath'] as String,
      fileSize: data['fileSize'] as int,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
