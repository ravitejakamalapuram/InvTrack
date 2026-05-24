import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';
import 'package:inv_tracker/core/widgets/in_app_update_initializer.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockInAppUpdateService extends Mock implements InAppUpdateService {}

class MockAppUpdateInfo extends Mock implements AppUpdateInfo {}

/// Helper to pump the InAppUpdateInitializer widget with localization support
Future<void> pumpInitializer(
  WidgetTester tester, {
  required List<Override> overrides,
  Widget child = const Text('Test Child'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InAppUpdateInitializer(child: child),
        ),
      ),
    ),
  );
}

void main() {
  late MockInAppUpdateService mockService;

  setUp(() {
    mockService = MockInAppUpdateService();
  });

  group('InAppUpdateInitializer', () {
    group('basic rendering', () {
      testWidgets('renders child widget', (tester) async {
        when(() => mockService.checkForUpdate()).thenAnswer((_) async => null);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );

        expect(find.text('Test Child'), findsOneWidget);
      });

      testWidgets('renders custom child widget', (tester) async {
        when(() => mockService.checkForUpdate()).thenAnswer((_) async => null);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
          child: const Column(
            children: [Text('Child A'), Text('Child B')],
          ),
        );

        expect(find.text('Child A'), findsOneWidget);
        expect(find.text('Child B'), findsOneWidget);
      });
    });

    group('update check on start', () {
      testWidgets('calls checkForUpdate after first frame', (tester) async {
        when(() => mockService.checkForUpdate()).thenAnswer((_) async => null);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );

        // Before first frame callback fires, service should not be called yet
        // (pumpWidget processes the first frame, but addPostFrameCallback fires after)
        // After pump + settle, the callback should have fired
        await tester.pumpAndSettle();

        verify(() => mockService.checkForUpdate()).called(1);
      });

      testWidgets('calls checkForUpdate only once even after rebuild', (tester) async {
        int checkCount = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inAppUpdateProvider.overrideWith(
                () => _CheckCountingNotifier(() => checkCount++),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: StatefulBuilder(
                builder: (context, setState) => Scaffold(
                  body: Column(
                    children: [
                      InAppUpdateInitializer(child: const Text('Test')),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Rebuild'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(checkCount, 1);

        // Trigger a rebuild
        await tester.tap(find.text('Rebuild'));
        await tester.pumpAndSettle();

        // _hasChecked flag prevents re-checking on rebuild
        expect(checkCount, 1);
      });
    });

    group('no update available', () {
      testWidgets('does not show dialog when no update available', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateNotAvailable);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('does not show dialog when service returns null', (tester) async {
        when(() => mockService.checkForUpdate()).thenAnswer((_) async => null);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      });
    });

    group('flexible update dialog', () {
      testWidgets('shows flexible update dialog for low-priority update', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(false);
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(true);
        when(() => mockInfo.updatePriority).thenReturn(2); // low priority
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        // Flexible update dialog should appear
        expect(find.byType(AlertDialog), findsOneWidget);
        // "Later" and "Update" buttons should be visible
        expect(find.text('Later'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);
      });

      testWidgets('does not show dialog when flexibleUpdateAllowed is false and not high priority', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(false);
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(false);
        when(() => mockInfo.updatePriority).thenReturn(2); // low priority
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('Later button dismisses flexible update dialog', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(false);
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(true);
        when(() => mockInfo.updatePriority).thenReturn(1);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('Update button calls startFlexibleUpdate', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(false);
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(true);
        when(() => mockInfo.updatePriority).thenReturn(1);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);

        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        verify(() => mockService.startFlexibleUpdate()).called(1);
      });

      testWidgets('shows snackbar on successful flexible update start', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(false);
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(true);
        when(() => mockInfo.updatePriority).thenReturn(1);
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        // Snackbar should appear with background download message
        expect(
          find.text('Downloading update in background...'),
          findsOneWidget,
        );
      });
    });

    group('high priority update (immediate)', () {
      testWidgets('calls startImmediateUpdate for high priority updates', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(true);
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(true);
        when(() => mockInfo.updatePriority).thenReturn(5); // high priority
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);
        when(() => mockService.startImmediateUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        verify(() => mockService.startImmediateUpdate()).called(1);
        // No dialog should be shown for immediate updates
        expect(find.byType(AlertDialog), findsNothing);
      });

      testWidgets('does not call startImmediateUpdate if immediateUpdateAllowed is false', (tester) async {
        final mockInfo = MockAppUpdateInfo();
        when(() => mockInfo.updateAvailability)
            .thenReturn(UpdateAvailability.updateAvailable);
        when(() => mockInfo.immediateUpdateAllowed).thenReturn(false);
        when(() => mockInfo.flexibleUpdateAllowed).thenReturn(true);
        when(() => mockInfo.updatePriority).thenReturn(5); // high priority but not allowed
        when(() => mockService.checkForUpdate())
            .thenAnswer((_) async => mockInfo);
        when(() => mockService.startFlexibleUpdate())
            .thenAnswer((_) async => AppUpdateResult.success);

        await pumpInitializer(
          tester,
          overrides: [
            inAppUpdateServiceProvider.overrideWithValue(mockService),
          ],
        );
        await tester.pumpAndSettle();

        verifyNever(() => mockService.startImmediateUpdate());
      });
    });

    group('install dialog after download', () {
      testWidgets('shows install dialog when download transitions from downloading to complete', (tester) async {
        // We need a fake notifier that lets us control the state
        late void Function(InAppUpdateState) setState;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inAppUpdateProvider.overrideWith(
                () {
                  final notifier = _ControllableFakeNotifier();
                  setState = (s) => notifier.updateState(s);
                  return notifier;
                },
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: InAppUpdateInitializer(child: Text('Test')),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Simulate download starting
        setState(const InAppUpdateState(isDownloading: true));
        await tester.pump();

        // Simulate download completing successfully
        setState(const InAppUpdateState(isDownloading: false));
        await tester.pumpAndSettle();

        // Install dialog should appear
        expect(find.text('Update Ready'), findsOneWidget);
        expect(find.text('Restart'), findsOneWidget);
      });

      testWidgets('Later button dismisses install dialog', (tester) async {
        late void Function(InAppUpdateState) setState;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inAppUpdateProvider.overrideWith(
                () {
                  final notifier = _ControllableFakeNotifier();
                  setState = (s) => notifier.updateState(s);
                  return notifier;
                },
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: InAppUpdateInitializer(child: Text('Test')),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Trigger install dialog
        setState(const InAppUpdateState(isDownloading: true));
        await tester.pump();
        setState(const InAppUpdateState(isDownloading: false));
        await tester.pumpAndSettle();

        expect(find.text('Update Ready'), findsOneWidget);

        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();

        expect(find.text('Update Ready'), findsNothing);
      });

      testWidgets('does not show install dialog when error occurs during download', (tester) async {
        late void Function(InAppUpdateState) setState;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inAppUpdateProvider.overrideWith(
                () {
                  final notifier = _ControllableFakeNotifier();
                  setState = (s) => notifier.updateState(s);
                  return notifier;
                },
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: InAppUpdateInitializer(child: Text('Test')),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Simulate download starting
        setState(const InAppUpdateState(isDownloading: true));
        await tester.pump();

        // Simulate download failing (isDownloading=false but error present)
        setState(
          const InAppUpdateState(
            isDownloading: false,
            error: 'Download failed',
          ),
        );
        await tester.pumpAndSettle();

        // Install dialog should NOT appear when error occurred
        expect(find.text('Update Ready'), findsNothing);
      });
    });
  });
}

/// A fake notifier that counts how many times checkForUpdate is called
class _CheckCountingNotifier extends InAppUpdateNotifier {
  final void Function() onCheck;
  _CheckCountingNotifier(this.onCheck);

  @override
  InAppUpdateState build() => const InAppUpdateState();

  @override
  Future<void> checkForUpdate() async => onCheck();

  @override
  Future<void> startFlexibleUpdate() async {}

  @override
  Future<void> startImmediateUpdate() async {}

  @override
  Future<void> completeFlexibleUpdate() async {}
}

/// A controllable fake notifier for widget tests
/// Allows tests to drive state changes manually
class _ControllableFakeNotifier extends InAppUpdateNotifier {
  @override
  InAppUpdateState build() => const InAppUpdateState();

  void updateState(InAppUpdateState newState) {
    state = newState;
  }

  @override
  Future<void> checkForUpdate() async {
    // no-op: don't trigger platform calls in widget tests
  }

  @override
  Future<void> startFlexibleUpdate() async {}

  @override
  Future<void> startImmediateUpdate() async {}

  @override
  Future<void> completeFlexibleUpdate() async {}
}
