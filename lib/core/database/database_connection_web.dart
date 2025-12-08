import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Opens a web database connection using IndexedDB
/// Used for web platform
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    return WebDatabase('inv_tracker');
  });
}

