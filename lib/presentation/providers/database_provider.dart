import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/data/datasources/database/app_database.dart';
import 'package:inv_tracker/data/datasources/database/database_connection.dart';

/// Provider for the database instance.
///
/// This is an async provider since database initialization is async.
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await DatabaseConnection.getInstance();

  // Ensure database is closed when provider is disposed
  ref.onDispose(() {
    DatabaseConnection.close();
  });

  return db;
});

