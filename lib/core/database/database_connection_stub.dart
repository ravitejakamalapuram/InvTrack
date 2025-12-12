import 'package:drift/drift.dart';

/// Stub implementation - should never be called
/// Platform-specific implementations are in:
/// - database_connection_native.dart (mobile/desktop)
/// - database_connection_web.dart (web)
LazyDatabase openConnection([String? userId]) {
  throw UnsupportedError(
    'Cannot create database connection without dart:io or dart:html',
  );
}

/// Opens a database connection for a specific user ID.
/// Stub implementation - should never be called.
LazyDatabase openConnectionForUser(String userId) {
  return openConnection(userId);
}

