/// A88: while a `deletionRequests/{uid}` document exists, Overview and
/// Data & Account say so and offer to withdraw it.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/auth/data/services/guest_backup_store.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/overview/presentation/screens/overview_screen.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/deletion_request_status_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/data_management_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/deletion_request_banner.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';

class MockDeletionRequestService extends Mock
    implements DeletionRequestService {}

class _NoGuestBackups extends Fake implements GuestBackupStore {
  @override
  Future<List<String>> list({required String ownerId}) async => const [];

  @override
  Future<String> save(Uint8List bytes, {required String ownerId}) =>
      throw UnimplementedError();
}

const _scheduled = 'Your account is scheduled for deletion.';
const _pending = "Your deletion request will be sent when you're online.";
const _withdraw = 'Withdraw request';
const _withdrawn = 'Deletion request withdrawn. Your account is kept.';
const _withdrawFailed =
    'Could not withdraw the request. Check your connection and try again.';

void main() {
  late MockDeletionRequestService requests;
  late StreamController<DeletionRequestStatus> statuses;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'privacy_mode_enabled': false});
    prefs = await SharedPreferences.getInstance();
    requests = MockDeletionRequestService();
    statuses = StreamController<DeletionRequestStatus>.broadcast();
    addTearDown(statuses.close);
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          deletionRequestStatusProvider.overrideWith((ref) => statuses.stream),
          deletionRequestServiceProvider.overrideWithValue(requests),
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          authStateProvider.overrideWith(
            (ref) =>
                Stream.value(const UserEntity(id: 'uid-1', email: 'a@b.c')),
          ),
          guestBackupStoreProvider.overrideWithValue(_NoGuestBackups()),
          currencyCodeProvider.overrideWith((ref) => 'INR'),
          currencySymbolProvider.overrideWith((ref) => '₹'),
          currencyLocaleProvider.overrideWith((ref) => 'en_IN'),
          allInvestmentsProvider.overrideWith((ref) => Stream.value(const [])),
          allCashFlowsStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          archivedInvestmentsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, DeletionRequestStatus status) async {
    statuses.add(status);
    await tester.pump();
    await tester.pump();
  }

  /// The message is read on its own, then Withdraw as a button (A88).
  void expectMessageAndWithdrawButton(WidgetTester tester, String message) {
    expect(find.bySemanticsLabel(message), findsOneWidget);
    expect(
      tester.getSemantics(find.widgetWithText(TextButton, _withdraw)),
      containsSemantics(label: _withdraw, isButton: true, hasTapAction: true),
    );
  }

  final screens = <String, Widget>{
    'Overview': const OverviewScreen(),
    'Data & Account': const DataManagementScreen(),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    testWidgets('$name shows the scheduled banner with a Withdraw button '
        'while the server holds the request', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester, screen);

      await emit(tester, DeletionRequestStatus.confirmed);

      expect(find.byType(DeletionRequestBanner), findsOneWidget);
      expect(find.text(_scheduled), findsOneWidget);
      expectMessageAndWithdrawButton(tester, _scheduled);
      semantics.dispose();
    });

    testWidgets('$name shows no banner when there is no request', (
      tester,
    ) async {
      await pumpApp(tester, screen);

      await emit(tester, DeletionRequestStatus.none);

      expect(find.text(_scheduled), findsNothing);
      expect(find.text(_pending), findsNothing);
      expect(find.text(_withdraw), findsNothing);
    });
  }

  Future<void> pumpBanner(WidgetTester tester) =>
      pumpApp(tester, const Scaffold(body: DeletionRequestBanner()));

  testWidgets('a request only on this device says it will be sent when '
      'online', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpBanner(tester);

    await emit(tester, DeletionRequestStatus.pending);

    expect(find.text(_pending), findsOneWidget);
    expectMessageAndWithdrawButton(tester, _pending);
    expect(find.text(_scheduled), findsNothing);
    semantics.dispose();
  });

  testWidgets('withdrawing removes the banner and says the account is kept', (
    tester,
  ) async {
    // Firestore drops the document from the local snapshot as soon as the
    // delete is issued.
    when(() => requests.withdraw()).thenAnswer((_) async {
      statuses.add(DeletionRequestStatus.none);
      return true;
    });
    await pumpBanner(tester);
    await emit(tester, DeletionRequestStatus.confirmed);

    await tester.tap(find.text(_withdraw));
    await tester.pump();
    await tester.pump();

    verify(() => requests.withdraw()).called(1);
    expect(find.text(_scheduled), findsNothing);
    expect(find.text(_withdraw), findsNothing);
    expect(find.text(_withdrawn), findsOneWidget);
  });

  // Firestore removes the document from this device's view as soon as the
  // delete is issued, and does not flag a deleted document as a pending
  // write, so the live status reads "no request" while the server may still
  // hold it.
  void withdrawFailsAfterLocalDelete() =>
      when(() => requests.withdraw()).thenAnswer((_) async {
        statuses.add(DeletionRequestStatus.none);
        return false;
      });

  Future<void> tapWithdraw(WidgetTester tester) async {
    await tester.tap(find.text(_withdraw));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a withdrawal the server has not confirmed keeps the banner and '
      'its Withdraw button, and says to try again', (tester) async {
    withdrawFailsAfterLocalDelete();
    when(
      () => requests.pendingWritesSent(),
    ).thenAnswer((_) => Completer<bool>().future);
    await pumpBanner(tester);
    await emit(tester, DeletionRequestStatus.confirmed);

    await tapWithdraw(tester);

    verify(() => requests.withdraw()).called(1);
    expect(find.text(_scheduled), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, _withdraw))
          .onPressed,
      isNotNull,
    );
    expect(find.text(_withdrawFailed), findsOneWidget);

    // Back online, trying again works and removes the banner.
    when(() => requests.withdraw()).thenAnswer((_) async => true);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tapWithdraw(tester);

    expect(find.text(_scheduled), findsNothing);
    expect(find.text(_withdraw), findsNothing);
    expect(find.text(_withdrawn), findsOneWidget);
  });

  testWidgets('the banner goes once the queued withdrawal reaches the '
      'server', (tester) async {
    final sent = Completer<bool>();
    withdrawFailsAfterLocalDelete();
    when(() => requests.pendingWritesSent()).thenAnswer((_) => sent.future);
    await pumpBanner(tester);
    await emit(tester, DeletionRequestStatus.confirmed);
    await tapWithdraw(tester);
    expect(find.text(_scheduled), findsOneWidget);

    sent.complete(true);
    await tester.pump();
    await tester.pump();

    expect(find.text(_scheduled), findsNothing);
    expect(find.text(_withdraw), findsNothing);
  });

  testWidgets('a withdrawal the server has not confirmed is still shown after '
      'leaving and reopening the screen', (tester) async {
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    withdrawFailsAfterLocalDelete();
    when(
      () => requests.pendingWritesSent(),
    ).thenAnswer((_) => Completer<bool>().future);
    await pumpApp(
      tester,
      Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, visible, _) =>
              visible ? const DeletionRequestBanner() : const SizedBox.shrink(),
        ),
      ),
    );
    await emit(tester, DeletionRequestStatus.confirmed);
    await tapWithdraw(tester);

    show.value = false;
    await tester.pump();
    expect(find.text(_scheduled), findsNothing);
    show.value = true;
    await tester.pump();
    await tester.pump();

    expect(find.text(_scheduled), findsOneWidget);
    expect(find.text(_withdraw), findsOneWidget);
  });

  // Withdrawing while Delete Account runs would let the wipe go on with no
  // request left for the server job, and then report it as scheduled.
  testWidgets('nothing is offered while a deletion is running on this '
      'device', (tester) async {
    await pumpBanner(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DeletionRequestBanner)),
    );
    container.read(deletionInProgressProvider.notifier).start();
    await emit(tester, DeletionRequestStatus.confirmed);

    expect(find.text(_scheduled), findsNothing);
    expect(find.text(_withdraw), findsNothing);

    container.read(deletionInProgressProvider.notifier).finish();
    await tester.pump();

    expect(find.text(_scheduled), findsOneWidget);
    expect(find.text(_withdraw), findsOneWidget);
  });
}
