import 'package:flutter/material.dart';

/// Document type categories for investment-related documents
enum DocumentType {
  receipt,
  contract,
  statement,
  certificate,
  image,
  other;

  String get displayName {
    switch (this) {
      case DocumentType.receipt:
        return 'Receipt';
      case DocumentType.contract:
        return 'Contract';
      case DocumentType.statement:
        return 'Statement';
      case DocumentType.certificate:
        return 'Certificate';
      case DocumentType.image:
        return 'Image';
      case DocumentType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.receipt:
        return Icons.receipt_long_rounded;
      case DocumentType.contract:
        return Icons.description_rounded;
      case DocumentType.statement:
        return Icons.summarize_rounded;
      case DocumentType.certificate:
        return Icons.workspace_premium_rounded;
      case DocumentType.image:
        return Icons.image_rounded;
      case DocumentType.other:
        return Icons.attach_file_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DocumentType.receipt:
        return const Color(0xFF10B981); // Emerald
      case DocumentType.contract:
        return const Color(0xFF3B82F6); // Blue
      case DocumentType.statement:
        return const Color(0xFFF59E0B); // Amber
      case DocumentType.certificate:
        return const Color(0xFF8B5CF6); // Purple
      case DocumentType.image:
        return const Color(0xFFEC4899); // Pink
      case DocumentType.other:
        return const Color(0xFF6B7280); // Gray
    }
  }

  static DocumentType fromString(String value) {
    return DocumentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => DocumentType.other,
    );
  }
}

/// Supported file extensions and their MIME types
class DocumentMimeTypes {
  static const Map<String, String> extensionToMime = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  static const List<String> supportedExtensions = [
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic',
  ];

  static const List<String> imageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic',
  ];

  static String getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return extensionToMime[ext] ?? 'application/octet-stream';
  }

  static bool isImage(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return imageExtensions.contains(ext);
  }

  static bool isPdf(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf');
  }

  static bool isSupported(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return supportedExtensions.contains(ext);
  }
}

/// Document Entity - represents a document attached to an investment
class DocumentEntity {
  final String id;
  final String investmentId;
  final String name;
  final String fileName;
  final DocumentType type;
  final String mimeType;
  final String localPath;
  final int fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentEntity({
    required this.id,
    required this.investmentId,
    required this.name,
    required this.fileName,
    required this.type,
    required this.mimeType,
    required this.localPath,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if this document is an image
  bool get isImage => DocumentMimeTypes.isImage(fileName);

  /// Check if this document is a PDF
  bool get isPdf => DocumentMimeTypes.isPdf(fileName);

  /// Get file size in human-readable format
  String get fileSizeFormatted {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  DocumentEntity copyWith({
    String? id,
    String? investmentId,
    String? name,
    String? fileName,
    DocumentType? type,
    String? mimeType,
    String? localPath,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DocumentEntity(
      id: id ?? this.id,
      investmentId: investmentId ?? this.investmentId,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentEntity &&
        other.id == id &&
        other.investmentId == investmentId &&
        other.name == name &&
        other.fileName == fileName &&
        other.type == type &&
        other.mimeType == mimeType &&
        other.localPath == localPath &&
        other.fileSize == fileSize &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        investmentId.hashCode ^
        name.hashCode ^
        fileName.hashCode ^
        type.hashCode ^
        mimeType.hashCode ^
        localPath.hashCode ^
        fileSize.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}

