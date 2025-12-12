import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Opens a web database connection using IndexedDB
/// Used for web platform
/// [userId] is optional - if provided, creates a user-specific database
LazyDatabase openConnection([String? userId]) {
  final effectiveUserId = userId ?? 'default';
  return LazyDatabase(() async {
    return WebDatabase('inv_tracker_$effectiveUserId');
  });
}

/// Opens a database connection for a specific user ID.
LazyDatabase openConnectionForUser(String userId) {
  return openConnection(userId);
}

