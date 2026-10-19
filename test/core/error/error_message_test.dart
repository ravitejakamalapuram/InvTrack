import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/error/error_message.dart';
import 'package:inv_tracker/core/providers/connectivity_provider.dart';
import 'package:inv_tracker/core/widgets/connectivity_listener.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_states.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

Widget _app(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  test('kindOf maps firebase codes by type', () {
    expect(
      ErrorHandler.kindOf(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
      ErrorKind.network,
    );
    expect(
      ErrorHandler.kindOf(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      ),
      ErrorKind.permission,
    );
    expect(ErrorHandler.kindOf(StateError('x')), ErrorKind.unknown);
  });

  testWidgets('permission error on the list is not the connection message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: InvestmentErrorState(
            isDark: false,
            onRetry: () {},
            error: FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Connection Error'), findsNothing);
    expect(find.textContaining('check your connection'), findsNothing);
  });

  testWidgets('network error on the list keeps the connection message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: InvestmentErrorState(
            isDark: false,
            onRetry: () {},
            error: FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            ),
          ),
        ),
      ),
    );
    expect(find.text('Connection Error'), findsOneWidget);
  });

  testWidgets('export reason never carries the exception text', (tester) async {
    late String text;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            text = exportFailureMessage(
              AppLocalizations.of(context),
              Exception('boom /data/user/0/secret.csv'),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(text, isNot(contains('Exception')));
    expect(text, isNot(contains('secret')));
    expect(text, startsWith('Export failed'));
  });

  testWidgets('offline shows a live-region banner, online hides it', (
    tester,
  ) async {
    final controller = StreamController<bool>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      _app(
        const ConnectivityListener(child: Scaffold(body: Text('App'))),
        overrides: [
          connectivityStatusProvider.overrideWith((ref) => controller.stream),
        ],
      ),
    );
    controller.add(false);
    await tester.pump();
    final banner = find.textContaining("You're offline");
    expect(banner, findsOneWidget);
    expect(
      tester
          .getSemantics(banner)
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );

    controller.add(true);
    await tester.pump();
    await tester.pump();
    expect(banner, findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
