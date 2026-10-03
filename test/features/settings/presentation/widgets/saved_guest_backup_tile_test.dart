import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/saved_guest_backup_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class _FakeBackupStore implements GuestBackupStore {
  _FakeBackupStore(this.files);

  final List<String> files;

  @override
  Future<String> save(Uint8List bytes) => throw UnimplementedError();

  @override
  Future<List<String>> list() async => List.of(files);

  @override
  Future<void> delete(String filePath) async => files.remove(filePath);

  @override
  Future<void> deleteAll() async => files.clear();
}

class _FakeExportService extends Fake implements DataExportService {
  final shared = <List<String>>[];

  @override
  Future<void> shareZipFiles(List<String> filePaths) async =>
      shared.add(filePaths);
}

/// A05-F1 / auth-account-02: a guest backup left after a partial merge must
/// stay reachable after the merge prompt is gone, even after a restart.
void main() {
  const backups = [
    '/data/app/files/guest_backups/InvTrack_Guest_Backup_1.zip',
    '/data/app/files/guest_backups/InvTrack_Guest_Backup_2.zip',
  ];
  late _FakeBackupStore store;
  late _FakeExportService exportService;

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          guestBackupStoreProvider.overrideWithValue(store),
          dataExportServiceProvider.overrideWithValue(exportService),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SavedGuestBackupTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => exportService = _FakeExportService());

  testWidgets('shows nothing when no guest backup is kept', (tester) async {
    store = _FakeBackupStore([]);

    await pumpTile(tester);

    expect(find.text('Saved guest backup'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('offers every kept backup for sharing', (tester) async {
    store = _FakeBackupStore(List.of(backups));

    await pumpTile(tester);

    expect(find.text('Saved guest backup'), findsOneWidget);
    expect(
      find.text(
        'A copy of your guest data from before you signed in, kept on this '
        'device. Share it to keep it safe.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Share backup'), findsOneWidget);

    await tester.tap(find.byTooltip('Share backup'));
    await tester.pumpAndSettle();

    expect(exportService.shared, [backups]);
    expect(store.files, backups, reason: 'sharing alone keeps the backups');
  });

  testWidgets('deleting asks first and keeps the backup on cancel', (
    tester,
  ) async {
    store = _FakeBackupStore(List.of(backups));

    await pumpTile(tester);
    await tester.tap(find.byTooltip('Delete backup'));
    await tester.pumpAndSettle();

    expect(find.text('Delete the guest backup?'), findsOneWidget);
    expect(
      find.text(
        'This removes the backup of your guest data from this device. '
        'Anything in it that is not already in your Google account is lost '
        'for good.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(store.files, backups);
    expect(find.text('Saved guest backup'), findsOneWidget);
  });

  testWidgets('deleting after confirmation removes every backup', (
    tester,
  ) async {
    store = _FakeBackupStore(List.of(backups));

    await pumpTile(tester);
    await tester.tap(find.byTooltip('Delete backup'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.files, isEmpty);
    expect(find.text('Saved guest backup'), findsNothing);
  });
}
