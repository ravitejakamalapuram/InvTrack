// A113: the "scheduled for deletion" question offers to withdraw a pending
// account deletion. It must not open over the lock screen, where whoever
// holds the phone could answer it without the PIN.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/deletion_request_notice.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  const title = 'Account scheduled for deletion';
  const message =
      'A request to delete this account and all its data is pending. It will '
      'be completed soon and cannot be undone afterwards. If you did not '
      'request this, or changed your mind, withdraw the request now.';
  const user = UserEntity(id: 'uid-1', email: 'user@example.com');

  late _FakeDeletionRequests requests;
  late StreamController<UserEntity?> users;

  setUp(() {
    requests = _FakeDeletionRequests();
    users = StreamController<UserEntity?>()..add(user);
  });

  tearDown(() => users.close());

  Widget app({required bool locked}) => ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => users.stream),
      deletionRequestServiceProvider.overrideWithValue(requests),
      securityProvider.overrideWith(() => _TestSecurity(locked: locked)),
    ],
    child: MaterialApp(
      navigatorKey: rootNavigatorKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DeletionRequestNotice(child: SizedBox())),
    ),
  );

  _TestSecurity security(WidgetTester tester) =>
      ProviderScope.containerOf(
            tester.element(find.byType(DeletionRequestNotice)),
          ).read(securityProvider.notifier)
          as _TestSecurity;

  testWidgets('locked: no question over the lock screen; asked once after '
      'unlocking', (tester) async {
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();

    expect(requests.hasRequestCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(title), findsNothing);

    security(tester).unlock();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(title), findsOneWidget);
    expect(find.bySemanticsLabel(message), findsOneWidget);

    // Locking and unlocking again does not stack a second question.
    security(tester).lockApp();
    await tester.pumpAndSettle();
    security(tester).unlock();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(requests.hasRequestCalls, 1);
    expect(requests.withdrawCalls, 0);
  });

  testWidgets('no PIN: asked at once, as before', (tester) async {
    await tester.pumpWidget(app(locked: false));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(title), findsOneWidget);

    await tester.tap(find.text('Withdraw request'));
    await tester.pumpAndSettle();

    expect(requests.withdrawCalls, 1);
  });

  testWidgets('removed while waiting for unlock: no question and no error', (
    tester,
  ) async {
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(requests.withdrawCalls, 0);
  });

  testWidgets('signed out on the lock screen: the question is not shown '
      'after unlocking', (tester) async {
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();

    users.add(null);
    await tester.pumpAndSettle();
    security(tester).unlock();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(requests.withdrawCalls, 0);
  });

  testWidgets('signed out and in again on the lock screen: asked once after '
      'unlocking', (tester) async {
    await tester.pumpWidget(app(locked: true));
    await tester.pumpAndSettle();

    users.add(null);
    await tester.pumpAndSettle();
    users.add(user);
    await tester.pumpAndSettle();
    security(tester).unlock();
    await tester.pumpAndSettle();

    expect(requests.hasRequestCalls, 2);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

class _FakeDeletionRequests implements DeletionRequestService {
  int hasRequestCalls = 0;
  int withdrawCalls = 0;

  @override
  Future<bool> hasRequest() async {
    hasRequestCalls++;
    return true;
  }

  @override
  Future<bool> withdraw() async {
    withdrawCalls++;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSecurity extends SecurityNotifier {
  _TestSecurity({required this.locked});

  final bool locked;

  @override
  SecurityState build() => SecurityState(hasPin: locked, isLocked: locked);

  void unlock() => state = state.copyWith(isLocked: false);
}
