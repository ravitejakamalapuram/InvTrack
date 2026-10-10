// #936: the optional "Custom type" field of the investment form. It shows for
// type Other only, behind the feature flag; saved types are suggested; saving
// one is an explicit action; what the form sends the notifier is the text
// typed, and blank text means today's behaviour.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/screens/add_investment_screen.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/custom_type_field.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../data/repositories/fake_custom_investment_type_repository.dart';

typedef _Call = Map<String, Object?>;

class _RecordingNotifier extends InvestmentNotifier {
  _RecordingNotifier(this.adds, this.updates);
  final List<_Call> adds;
  final List<_Call> updates;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  @override
  Future<InvestmentEntity> addInvestment({
    required String name,
    required InvestmentType type,
    String? notes,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    String? currency,
    String? customTypeLabel,
  }) async {
    adds.add({'name': name, 'type': type, 'customTypeLabel': customTypeLabel});
    return InvestmentEntity(
      id: 'new',
      name: name,
      type: type,
      status: InvestmentStatus.open,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<void> updateInvestment({
    required String id,
    required String name,
    required InvestmentType type,
    String? notes,
    DateTime? maturityDate,
    IncomeFrequency? incomeFrequency,
    DateTime? startDate,
    double? expectedRate,
    int? tenureMonths,
    String? platform,
    InterestPayoutMode? interestPayoutMode,
    bool? autoRenewal,
    RiskLevel? riskLevel,
    CompoundingFrequency? compoundingFrequency,
    String? currency,
    String? customTypeLabel,
  }) async {
    updates.add({'id': id, 'type': type, 'customTypeLabel': customTypeLabel});
  }
}

CustomInvestmentType _def(String id, String label) => CustomInvestmentType(
  id: id,
  label: label,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

InvestmentEntity _stamps({InvestmentType type = InvestmentType.other}) =>
    InvestmentEntity(
      id: 'inv-stamps',
      name: 'Stamp album',
      type: type,
      status: InvestmentStatus.open,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      currency: 'INR',
      customTypeId: 'c1',
      customTypeLabel: 'Stamps',
    );

const _label = 'Custom type (optional)';
const _saveAction = 'Save as reusable type';

void main() {
  late List<_Call> adds;
  late List<_Call> updates;
  late FakeCustomInvestmentTypeRepository types;

  Future<void> pump(
    WidgetTester tester, {
    bool flag = true,
    List<CustomInvestmentType> saved = const [],
    InvestmentEntity? edit,
  }) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    adds = [];
    updates = [];
    types = FakeCustomInvestmentTypeRepository(saved);
    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
          routes: [
            GoRoute(
              path: 'form',
              builder: (_, _) => AddInvestmentScreen(investmentToEdit: edit),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currencyCodeProvider.overrideWithValue('INR'),
          currencySymbolProvider.overrideWithValue('₹'),
          currencyLocaleProvider.overrideWithValue('en_IN'),
          analyticsServiceProvider.overrideWithValue(FakeAnalyticsService()),
          isAuthenticatedProvider.overrideWithValue(true),
          isCustomInvestmentTypesEnabledProvider.overrideWithValue(flag),
          customInvestmentTypeRepositoryProvider.overrideWithValue(types),
          investmentNotifierProvider.overrideWith(
            () => _RecordingNotifier(adds, updates),
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectType(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(TypeSelector<InvestmentType>),
        matching: find.text(name),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder customTypeInput() => find.descendant(
    of: find.byType(CustomTypeField),
    matching: find.byType(EditableText),
  );

  Finder nameInput() => find.descendant(
    of: find.widgetWithText(AppTextField, 'Investment Name'),
    matching: find.byType(EditableText),
  );

  Future<void> submit(WidgetTester tester, String label) async {
    final button = find.widgetWithText(GradientButton, label);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('visibility', () {
    testWidgets('the field shows for Other only', (tester) async {
      await pump(tester);
      expect(find.byType(CustomTypeField), findsNothing, reason: 'P2P');

      await selectType(tester, 'Other');
      expect(find.byType(CustomTypeField), findsOneWidget);
      expect(find.text(_label), findsWidgets);
      expect(find.text('e.g. Art prints, Vintage cars'), findsOneWidget);
      expect(
        find.text(
          'Names this investment more specifically. It does not change how '
          'it is calculated.',
        ),
        findsOneWidget,
      );

      await selectType(tester, 'Bonds/Debentures');
      expect(find.byType(CustomTypeField), findsNothing);
      expect(find.text(_label), findsNothing);
    });

    testWidgets('behind the feature flag: off means no field', (tester) async {
      await pump(tester, flag: false);
      await selectType(tester, 'Other');
      expect(find.text(_label), findsNothing);
      expect(find.byType(CustomTypeField), findsNothing);
    });
  });

  group('saved types', () {
    testWidgets('are suggested and a tap fills the field', (tester) async {
      await pump(tester, saved: [_def('a', 'Art Prints'), _def('b', 'Wine')]);
      await selectType(tester, 'Other');

      expect(find.text('Saved types'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Use saved type Art Prints'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Use saved type Wine'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Use saved type Wine'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<EditableText>(customTypeInput()).controller.text,
        'Wine',
      );
    });

    testWidgets('none saved: no suggestions heading', (tester) async {
      await pump(tester);
      await selectType(tester, 'Other');
      expect(find.text('Saved types'), findsNothing);
      expect(find.text('Manage saved types'), findsNothing);
    });
  });

  group('saving a type is an explicit action', () {
    testWidgets('typing alone saves nothing', (tester) async {
      await pump(tester);
      await selectType(tester, 'Other');

      await tester.enterText(customTypeInput(), 'Art Prints');
      await tester.pumpAndSettle();

      expect(types.writes, 0);
      expect(find.text('Saved types'), findsNothing);
    });

    testWidgets('the button is disabled while the field is blank', (
      tester,
    ) async {
      await pump(tester);
      await selectType(tester, 'Other');

      final button = find.widgetWithText(TextButton, _saveAction);
      expect(tester.widget<TextButton>(button).onPressed, isNull);

      await tester.enterText(customTypeInput(), '   ');
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(button).onPressed, isNull);

      await tester.enterText(customTypeInput(), 'Art Prints');
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(button).onPressed, isNotNull);
    });

    testWidgets('tapping it saves the label and suggests it', (tester) async {
      await pump(tester);
      await selectType(tester, 'Other');
      await tester.enterText(customTypeInput(), '  art   prints ');
      await tester.pumpAndSettle();

      await tester.tap(find.text(_saveAction));
      await tester.pumpAndSettle();

      expect(types.definitions.single.label, 'art prints');
      expect(
        find.text('Saved "art prints" as a reusable type'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Use saved type art prints'),
        findsOneWidget,
      );
    });

    testWidgets('a label already saved, in any case, cannot be saved again', (
      tester,
    ) async {
      await pump(tester, saved: [_def('a', 'Art Prints')]);
      await selectType(tester, 'Other');

      await tester.enterText(customTypeInput(), ' ART   prints');
      await tester.pumpAndSettle();

      final button = find.widgetWithText(TextButton, _saveAction);
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(find.text('This type is already saved'), findsOneWidget);
      expect(types.writes, 0);
    });

    testWidgets('at 50 saved types the button is disabled with a message, '
        'and the label still applies to the investment', (tester) async {
      await pump(
        tester,
        saved: [for (var i = 0; i < 50; i++) _def('d$i', 'Type $i')],
      );
      await selectType(tester, 'Other');

      await tester.enterText(customTypeInput(), 'One more');
      await tester.pumpAndSettle();

      final button = find.widgetWithText(TextButton, _saveAction);
      expect(tester.widget<TextButton>(button).onPressed, isNull);
      expect(
        find.text(
          'You can save up to 50 reusable types. The label still applies to '
          'this investment.',
        ),
        findsOneWidget,
      );

      await tester.enterText(nameInput(), 'Stamp album');
      await submit(tester, 'Add Investment');
      expect(adds.single['customTypeLabel'], 'One more');
    });
  });

  group('what the form sends', () {
    testWidgets('typed text goes to the notifier as typed', (tester) async {
      await pump(tester);
      await selectType(tester, 'Other');
      await tester.enterText(nameInput(), 'Stamp album');
      await tester.enterText(customTypeInput(), 'Rare Stamps');

      await submit(tester, 'Add Investment');

      expect(adds, hasLength(1));
      expect(adds.single['type'], InvestmentType.other);
      expect(adds.single['customTypeLabel'], 'Rare Stamps');
    });

    testWidgets('a blank field sends nothing: today\'s behaviour', (
      tester,
    ) async {
      await pump(tester);
      await selectType(tester, 'Other');
      await tester.enterText(nameInput(), 'Stamp album');

      await submit(tester, 'Add Investment');

      expect(adds.single['type'], InvestmentType.other);
      expect(adds.single['customTypeLabel'], isNull);
    });

    testWidgets('text typed and then a built-in type chosen is not sent', (
      tester,
    ) async {
      await pump(tester);
      await selectType(tester, 'Other');
      await tester.enterText(customTypeInput(), 'Rare Stamps');
      await selectType(tester, 'Bonds/Debentures');
      await tester.enterText(nameInput(), 'A bond');

      await submit(tester, 'Add Investment');

      expect(adds.single['type'], InvestmentType.bonds);
      expect(adds.single['customTypeLabel'], isNull);
    });

    testWidgets('the edit form shows the stored label and sends it back', (
      tester,
    ) async {
      await pump(tester, edit: _stamps());

      expect(
        tester.widget<EditableText>(customTypeInput()).controller.text,
        'Stamps',
      );
      await submit(tester, 'Save Changes');

      expect(updates.single['customTypeLabel'], 'Stamps');
    });

    testWidgets('clearing the field in the edit form sends null', (
      tester,
    ) async {
      await pump(tester, edit: _stamps());

      await tester.enterText(customTypeInput(), '');
      await submit(tester, 'Save Changes');

      expect(updates.single['customTypeLabel'], isNull);
    });

    testWidgets('flag off: an edit still sends the stored label, so it is '
        'not lost', (tester) async {
      await pump(tester, flag: false, edit: _stamps());
      expect(find.text(_label), findsNothing);

      await submit(tester, 'Save Changes');

      expect(updates.single['customTypeLabel'], 'Stamps');
    });
  });

  group('managing saved types', () {
    testWidgets('lists them, with the promise that investments are kept', (
      tester,
    ) async {
      await pump(tester, saved: [_def('a', 'Art Prints'), _def('b', 'Wine')]);
      await selectType(tester, 'Other');

      await tester.tap(find.text('Manage saved types'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Renaming or removing a saved type does not change investments '
          'that already use it.',
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Rename Art Prints'), findsOneWidget);
      expect(find.byTooltip('Remove Wine'), findsOneWidget);
    });

    testWidgets('renaming changes the suggestion only', (tester) async {
      await pump(tester, saved: [_def('a', 'Art Prints')]);
      await selectType(tester, 'Other');
      await tester.tap(find.text('Manage saved types'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Rename Art Prints'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Paintings');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(types.definitions.single.label, 'Paintings');
      expect(types.definitions.single.id, 'a');
    });

    testWidgets('renaming onto another saved type is refused in the dialog', (
      tester,
    ) async {
      await pump(tester, saved: [_def('a', 'Art Prints'), _def('b', 'Wine')]);
      await selectType(tester, 'Other');
      await tester.tap(find.text('Manage saved types'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Rename Art Prints'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, ' wine ');
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(
        find.text('You already have a saved type with that name'),
        findsOneWidget,
      );
      expect(types.writes, 0);
    });

    testWidgets('removing asks first and keeps the investments', (
      tester,
    ) async {
      await pump(tester, saved: [_def('a', 'Art Prints')]);
      await selectType(tester, 'Other');
      await tester.tap(find.text('Manage saved types'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove Art Prints'));
      await tester.pumpAndSettle();
      expect(find.text('Remove saved type?'), findsOneWidget);
      expect(
        find.text(
          '"Art Prints" will no longer be suggested. Investments that use '
          'it keep their label.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(types.definitions.single.isRemoved, isTrue);
      expect(find.byTooltip('Rename Art Prints'), findsNothing);
      expect(find.text('No saved types yet'), findsOneWidget);
    });
  });

  testWidgets('the field and its actions are named for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester, saved: [_def('a', 'Art Prints')]);
    await selectType(tester, 'Other');

    expect(find.bySemanticsLabel(RegExp('Custom type')), findsWidgets);
    expect(find.bySemanticsLabel(_saveAction), findsOneWidget);
    expect(find.bySemanticsLabel('Manage saved types'), findsOneWidget);
    expect(find.bySemanticsLabel('Use saved type Art Prints'), findsOneWidget);
    handle.dispose();
  });
}
