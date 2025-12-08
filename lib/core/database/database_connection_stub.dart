import 'package:drift/drift.dart';

/// Stub implementation - should never be called
/// Platform-specific implementations are in:
/// - database_connection_native.dart (mobile/desktop)
/// - database_connection_web.dart (web)
LazyDatabase openConnection() {
  throw UnsupportedError(
    'Cannot create database connection without dart:io or dart:html',
  );
}

