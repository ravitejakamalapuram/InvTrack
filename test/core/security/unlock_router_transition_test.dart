// A113: start-up questions open only once the app is unlocked. In the app
// the router swaps the lock page for the portfolio on the frame after the
// unlock, and the lock page takes any dialog opened on it along. A dialog
// closed that way returns null, which used to count as an answer: the
// deletion notice signed the user out, and the currency question recorded a
// dismissal. These tests use a router that redirects like routerProvider, so
// they see that swap.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/core/security/wait_until_unlocked.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/services/deletion_request_service.dart';
import 'package:inv_tracker/features/settings/data/services/legacy_currency_backfill_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/deletion_request_notice.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/legacy_currency_backfill_initializer.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks/fake_auth_repository.dart';
import '../../mocks/fake_legacy_currency_firestore.dart';

/// Rebuilt on every security change, like routerProvider: locked users go to
/// /lock, and /lock goes back to / once unlocked.
final _routerProvider = Provider<GoRouter>((ref) {
  final security = ref.watch(securityProvider);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final onLockPage = state.uri.path == '/lock';
      if (security.isLocked) return onLockPage ? null : '/lock';
      return onLockPage ? '/' : null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Portfolio')),
      ),
      GoRoute(
        path: '/lock',
        builder: (_, _) => const Scaffold(body: Text('Lock screen')),
      ),
    ],
  );
});

/// Mounted like InvTrackerApp: [above] wraps MaterialApp.router and [below]
/// sits in its builder, around the navigator.
class _App extends ConsumerWidget {
  const _App({this.above = _same, this.below = _same});

  final Widget Function(Widget child) above;
  final Widget Function(Widget child) below;

  static Widget _same(Widget child) => child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => above(
    MaterialApp.router(
      routerConfig: ref.watch(_routerProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => below(child ?? const SizedBox()),
    ),
  );
}

void main() {
  _TestSecurity security(WidgetTester tester) =>
      ProviderScope.containerOf(
            tester.element(find.byType(_App)),
          ).read(securityProvider.notifier)
          as _TestSecurity;

  group('WaitsForUnlock', () {
    testWidgets('after an unlock, a dialog opens over the portfolio and is '
        'not closed by the swap', (tester) async {
      final answers = <String?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [securityProvider.overrideWith(_TestSecurity.new)],
          child: _App(
            below: (child) => _Question(answers: answers, child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lock screen'), findsOneWidget);
      expect(find.text('Question'), findsNothing);

      security(tester).unlock();
      await tester.pumpAndSettle();

      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.text('Question'), findsOneWidget);
      expect(answers, isEmpty);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(answers, ['yes']);
    });
  });

  group('DeletionRequestNotice', () {
    const title = 'Account scheduled for deletion';
    late FakeAuthRepository auth;
    late _FakeDeletionRequests requests;

    setUp(() {
      auth = FakeAuthRepository(
        const UserEntity(id: 'uid-1', email: 'user@example.com'),
      );
      requests = _FakeDeletionRequests();
    });

    Widget app() => ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        deletionRequestServiceProvider.overrideWithValue(requests),
        securityProvider.overrideWith(_TestSecurity.new),
      ],
      child: _App(below: (child) => DeletionRequestNotice(child: child)),
    );

    testWidgets('unlocking shows the question once and signs nobody out', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);

      security(tester).unlock();
      await tester.pumpAndSettle();

      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(auth.signOutCalls, 0);
      expect(requests.withdrawCalls, 0);

      await tester.tap(find.text('Withdraw request'));
      await tester.pumpAndSettle();
      expect(requests.withdrawCalls, 1);
      expect(auth.signOutCalls, 0);
    });

    testWidgets('locked while the question is open: asked again after '
        'unlocking, not signed out', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      security(tester).unlock();
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      security(tester).lockApp();
      await tester.pumpAndSettle();

      expect(find.text('Lock screen'), findsOneWidget);
      expect(find.text(title), findsNothing);
      expect(auth.signOutCalls, 0);

      security(tester).unlock();
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(auth.signOutCalls, 0);
      expect(requests.hasRequestCalls, 1);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(auth.signOutCalls, 1);
      expect(requests.withdrawCalls, 0);
    });
  });

  group('LegacyCurrencyBackfillInitializer', () {
    const title = 'Older records have no currency';
    late SharedPreferences prefs;
    late FakeLegacyCurrencyFirestore firestore;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      firestore = FakeLegacyCurrencyFirestore()
        ..put('cashflows', 'cf-1', {'amount': 10.0});
    });

    LegacyCurrencyBackfillService service() => LegacyCurrencyBackfillService(
      firestore: firestore,
      userId: firestore.uid,
      prefs: prefs,
    );

    Widget app() => ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        securityProvider.overrideWith(_TestSecurity.new),
        legacyCurrencyBackfillServiceProvider.overrideWithValue(service()),
      ],
      child: _App(
        above: (child) => LegacyCurrencyBackfillInitializer(child: child),
      ),
    );

    testWidgets('unlocking shows the question once and records no '
        'dismissal', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);

      security(tester).unlock();
      await tester.pumpAndSettle();

      expect(find.text('Portfolio'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(service().promptDismissals, 0);

      await tester.tap(find.text('Mark as INR'));
      await tester.pumpAndSettle();
      expect(firestore.stored('cashflows', 'cf-1')!['currency'], 'INR');
    });

    testWidgets('locked while the question is open: asked again after '
        'unlocking, no dismissal recorded', (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      security(tester).unlock();
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      security(tester).lockApp();
      await tester.pumpAndSettle();

      expect(find.text('Lock screen'), findsOneWidget);
      expect(find.text(title), findsNothing);
      expect(service().promptDismissals, 0);

      security(tester).unlock();
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(service().promptDismissals, 0);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
      expect(service().promptDismissals, 1);
    });

    testWidgets('tapping outside the question still counts as Not Now', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      security(tester).unlock();
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text(title), findsNothing);
      expect(service().promptDismissals, 1);
    });
  });
}

/// Waits for the unlock, then asks a question that only a tap answers.
class _Question extends ConsumerStatefulWidget {
  const _Question({required this.answers, required this.child});

  final List<String?> answers;
  final Widget child;

  @override
  ConsumerState<_Question> createState() => _QuestionState();
}

class _QuestionState extends ConsumerState<_Question> with WaitsForUnlock {
  @override
  void initState() {
    super.initState();
    _ask();
  }

  Future<void> _ask() async {
    if (!await waitUntilUnlocked()) return;
    final context = rootNavigatorKey.currentContext!;
    final answer = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Question'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('yes'),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    widget.answers.add(answer);
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

/// Starts locked with a PIN set.
class _TestSecurity extends SecurityNotifier {
  @override
  SecurityState build() => const SecurityState(hasPin: true, isLocked: true);

  void unlock() => state = state.copyWith(isLocked: false);
}
