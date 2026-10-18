// A45 (#788): notification permission is asked after the first investment that
// has a maturity date, never at sign-in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/maturity_reminder_prompt.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNotificationService extends Mock implements NotificationService {}

void main() {
  final maturity = DateTime(2027, 4, 1);

  group('shouldAskMaturityReminder', () {
    test('asks for a dated investment when never asked', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(shouldAskMaturityReminder(prefs, maturity), isTrue);
    });

    test('does not ask without a maturity date', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(shouldAskMaturityReminder(prefs, null), isFalse);
    });

    test('does not ask twice', () async {
      SharedPreferences.setMockInitialValues({
        'notification_permissions_requested': true,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(shouldAskMaturityReminder(prefs, maturity), isFalse);
    });
  });

  group('askMaturityReminderIfNeeded', () {
    late _MockNotificationService service;
    late SharedPreferences prefs;

    setUp(() async {
      service = _MockNotificationService();
      when(() => service.requestPermissions()).thenAnswer((_) async => true);
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> pump(
      WidgetTester tester,
      DateTime? maturityDate, {
      bool flagOn = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            notificationServiceProvider.overrideWithValue(service),
            isMaturityReminderPromptEnabledProvider.overrideWithValue(flagOn),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => askMaturityReminderIfNeeded(
                    context,
                    ref,
                    maturityDate: maturityDate,
                  ),
                  child: const Text('save'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();
    }

    testWidgets('Remind me asks the system once and remembers', (tester) async {
      await pump(tester, maturity);
      expect(find.text('Get a reminder when this pays out?'), findsOneWidget);
      verifyNever(() => service.requestPermissions());

      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();

      verify(() => service.requestPermissions()).called(1);
      expect(prefs.getBool('notification_permissions_requested'), isTrue);
    });

    testWidgets('Not now never calls the system and is not asked again', (
      tester,
    ) async {
      await pump(tester, maturity);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      verifyNever(() => service.requestPermissions());
      expect(prefs.getBool('notification_permissions_requested'), isTrue);
    });

    testWidgets('no maturity date: no dialog, no system request', (
      tester,
    ) async {
      await pump(tester, null);
      expect(find.text('Get a reminder when this pays out?'), findsNothing);
      verifyNever(() => service.requestPermissions());
    });

    testWidgets('flag off: no dialog, no system request', (tester) async {
      await pump(tester, maturity, flagOn: false);
      expect(find.text('Get a reminder when this pays out?'), findsNothing);
      verifyNever(() => service.requestPermissions());
    });

    testWidgets('dismissed without a choice is asked again later', (
      tester,
    ) async {
      await pump(tester, maturity);
      await tester.tapAt(const Offset(2, 2)); // the barrier
      await tester.pumpAndSettle();

      verifyNever(() => service.requestPermissions());
      expect(prefs.getBool('notification_permissions_requested'), isNull);
    });

    testWidgets('a failing system request does not throw', (tester) async {
      when(() => service.requestPermissions()).thenThrow(StateError('boom'));
      await pump(tester, maturity);
      await tester.tap(find.text('Remind me'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(prefs.getBool('notification_permissions_requested'), isTrue);
    });
  });
}
