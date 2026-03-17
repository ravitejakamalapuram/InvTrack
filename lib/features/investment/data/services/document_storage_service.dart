import 'dart:io';
import 'dart:typed_data';

import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_lib;

/// Service for managing local document file storage
/// Handles saving, reading, and deleting document files from local storage
class DocumentStorageService {
  final String _userId;

  DocumentStorageService({required String userId}) : _userId = userId;

  /// Get the base directory for storing documents
  Future<Directory> get _documentsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(path_lib.join(appDir.path, 'documents', _userId));
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir;
  }

  /// Validate ID format to prevent path traversal
  bool _isValidId(String id) {
    // Only allow alphanumeric characters, dashes, and underscores
    return RegExp(r'^[a-zA-Z0-9\-_]+$').hasMatch(id);
  }

  /// Validates that the path is within the allowed documents directory
  Future<bool> _isSafePath(String path) async {
    try {
      final docsDir = await _documentsDirectory;
      final canonicalDocsDir = path_lib.canonicalize(docsDir.path);
      final canonicalPath = path_lib.canonicalize(path);

      // Allow access only within the specific user's documents folder
      return path_lib.isWithin(canonicalDocsDir, canonicalPath) ||
          canonicalPath == canonicalDocsDir;
    } catch (e) {
      LoggerService.warn('Security: Failed to validate path safety', error: e);
      return false;
    }
  }

  /// Get the directory for a specific investment's documents
  Future<Directory> _getInvestmentDirectory(String investmentId) async {
    if (!_isValidId(investmentId)) {
      throw const FormatException('Invalid investment ID format');
    }
    final baseDir = await _documentsDirectory;
    final invDir = Directory(path_lib.join(baseDir.path, investmentId));
    if (!await invDir.exists()) {
      await invDir.create(recursive: true);
    }
    return invDir;
  }

  /// Save a document file and return the local path
  /// [investmentId] - The investment this document belongs to
  /// [documentId] - Unique ID for the document
  /// [fileName] - Original file name (used to get extension)
  /// [bytes] - The file content
  Future<String> saveDocument({
    required String investmentId,
    required String documentId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (!_isValidId(documentId)) {
      throw const FormatException('Invalid document ID format');
    }
    final invDir = await _getInvestmentDirectory(investmentId);
    final extension = path_lib.extension(fileName);
    final localFileName = '$documentId$extension';
    final filePath = path_lib.join(invDir.path, localFileName);

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  /// Read a document file as bytes
  Future<Uint8List?> readDocument(String localPath) async {
    if (!await _isSafePath(localPath)) {
      LoggerService.warn(
        'Security: Blocked access to unsafe path',
        metadata: {'path': localPath},
      );
      return null;
    }

    final file = File(localPath);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// Check if a document file exists
  Future<bool> documentExists(String localPath) async {
    if (!await _isSafePath(localPath)) {
      return false;
    }
    final file = File(localPath);
    return file.exists();
  }

  /// Delete a document file
  Future<void> deleteDocument(String localPath) async {
    if (!await _isSafePath(localPath)) {
      LoggerService.warn(
        'Security: Blocked deletion of unsafe path',
        metadata: {'path': localPath},
      );
      return;
    }

    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Delete all documents for an investment
  Future<void> deleteInvestmentDocuments(String investmentId) async {
    final invDir = await _getInvestmentDirectory(investmentId);
    if (await invDir.exists()) {
      await invDir.delete(recursive: true);
    }
  }

  /// Get the file size in bytes
  Future<int> getFileSize(String localPath) async {
    if (!await _isSafePath(localPath)) {
      return 0;
    }
    final file = File(localPath);
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// Get total storage used by all documents for a user
  Future<int> getTotalStorageUsed() async {
    final baseDir = await _documentsDirectory;
    if (!await baseDir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in baseDir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Format storage size to human-readable string
  static String formatStorageSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
