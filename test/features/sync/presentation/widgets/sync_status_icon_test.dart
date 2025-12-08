import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/sync/domain/services/sync_service.dart';

import 'package:inv_tracker/features/sync/presentation/widgets/sync_status_icon.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockSyncService mockSyncService;

  setUp(() {
    mockSyncService = MockSyncService();
  });

  testWidgets('SyncStatusIcon shows sync button initially', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncServiceProvider.overrideWithValue(mockSyncService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIcon(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Debug: Print widget tree if needed
    // debugDumpApp();
    
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('SyncStatusIcon shows loading when syncing', (tester) async {
    // We need to mock the provider to return loading state
    // Or mock the service and trigger sync.
    
    when(() => mockSyncService.sync()).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 1));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncServiceProvider.overrideWithValue(mockSyncService),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SyncStatusIcon(),
          ),
        ),
      ),
    );

    // Tap the button
    await tester.tap(find.byType(IconButton));
    await tester.pump(); // Start animation

    // Should show loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    await tester.pump(const Duration(seconds: 1)); // Finish
    await tester.pumpAndSettle();
    
    // Should show done
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });
}
