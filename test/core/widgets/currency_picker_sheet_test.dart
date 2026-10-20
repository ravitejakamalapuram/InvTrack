import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/currency_picker_sheet.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  Future<ValueNotifier<String?>> open(WidgetTester tester) async {
    final picked = ValueNotifier<String?>(null);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked.value = await showCurrencyPickerSheet(
              context,
              selected: 'INR',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('scrolls to currencies beyond the first screen', (tester) async {
    await open(tester);
    expect(find.text('KRW'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('KRW'),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('KRW'), findsOneWidget);
  });

  testWidgets('search finds a currency by name and returns its code', (
    tester,
  ) async {
    final picked = await open(tester);
    await tester.enterText(find.byType(TextField), 'dirham');
    await tester.pumpAndSettle();
    expect(find.text('AED'), findsOneWidget);
    expect(find.text('USD'), findsNothing);
    await tester.tap(find.text('AED'));
    await tester.pumpAndSettle();
    expect(picked.value, 'AED');
  });
}
