// A40 (#783) PR-2: TypeSelector can lay its chips out as one sideways-scrolling
// row, for the add investment form. Every chip is a 48dp touch target, the row
// is announced as a group, the next chip peeks at the edge, and the selected
// chip is scrolled into view. The wrap and grid layouts are unchanged (see
// type_selector_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/type_selector.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/add_investment_keys.dart';

const _rowLabel = 'Investment type, 14 choices. Scroll sideways to see all.';

Widget _row({
  required InvestmentType selected,
  required ValueChanged<InvestmentType> onSelected,
  bool scrolling = true,
  bool grid = false,
  bool keyed = true,
  double width = 411,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: TypeSelector<InvestmentType>(
          values: InvestmentType.values,
          selectedValue: selected,
          onSelected: onSelected,
          colorBuilder: (type) => type.color,
          iconBuilder: (type) => type.icon,
          labelBuilder: (type) => type.displayName,
          compactMode: true,
          gridLayout: grid,
          scrollingRow: scrolling,
          rowPadding: const EdgeInsets.symmetric(horizontal: 24),
          rowSemanticsLabel: _rowLabel,
          itemKeyBuilder: keyed ? AddInvestmentKeys.typeChip : null,
        ),
      ),
    ),
  ),
);

Finder _chip(InvestmentType type) =>
    find.byKey(AddInvestmentKeys.typeChip(type));

void main() {
  testWidgets('all 14 chips are at least 48 x 48', (tester) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _row(selected: InvestmentType.p2pLending, onSelected: (_) {}),
    );

    expect(InvestmentType.values, hasLength(14));
    for (final type in InvestmentType.values) {
      expect(_chip(type), findsOneWidget, reason: type.name);
      final size = tester.getSize(_chip(type));
      expect(size.height, greaterThanOrEqualTo(48.0), reason: type.name);
      expect(size.width, greaterThanOrEqualTo(48.0), reason: type.name);
    }
  });

  testWidgets('the row is one group with a count and a scroll hint', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _row(selected: InvestmentType.p2pLending, onSelected: (_) {}),
    );

    expect(find.bySemanticsLabel(_rowLabel), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('P2P Lending')),
      matchesSemantics(
        label: 'P2P Lending',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
        hasSelectedState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the row scrolls sideways and the next chip peeks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _row(selected: InvestmentType.p2pLending, onSelected: (_) {}),
    );

    // The first chip starts at the 24dp inset; the last is far off screen.
    expect(tester.getRect(_chip(InvestmentType.p2pLending)).left, 24.0);
    expect(tester.getRect(_chip(InvestmentType.other)).left, greaterThan(411));
    // Some chip crosses the right edge: the row invites a scroll.
    final crossing = InvestmentType.values.where((type) {
      final rect = tester.getRect(_chip(type));
      return rect.left < 411 && rect.right > 411;
    });
    expect(crossing, hasLength(1));

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(-4000, 0),
    );
    await tester.pumpAndSettle();

    final last = tester.getRect(_chip(InvestmentType.other));
    expect(last.right, lessThanOrEqualTo(411 - 24 + 0.01));
    expect(tester.getRect(_chip(InvestmentType.p2pLending)).right, lessThan(0));
  });

  testWidgets('tapping a chip selects it', (tester) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final selected = <InvestmentType>[];

    await tester.pumpWidget(
      _row(selected: InvestmentType.p2pLending, onSelected: selected.add),
    );
    await tester.tap(_chip(InvestmentType.fixedDeposit));

    expect(selected, [InvestmentType.fixedDeposit]);
  });

  testWidgets('a chip is selected by tapping its edge, inside 48dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final selected = <InvestmentType>[];

    await tester.pumpWidget(
      _row(selected: InvestmentType.p2pLending, onSelected: selected.add),
    );
    final rect = tester.getRect(_chip(InvestmentType.fixedDeposit));
    // The strip above the visible chip, inside the 48dp box.
    await tester.tapAt(Offset(rect.center.dx, rect.top + 1));

    expect(selected, [InvestmentType.fixedDeposit]);
  });

  testWidgets('a selected chip off screen is scrolled into view at once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A form opened with the Gold template selects a chip far to the right.
    await tester.pumpWidget(
      _row(selected: InvestmentType.gold, onSelected: (_) {}),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(_chip(InvestmentType.gold));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(411));
  });

  testWidgets('changing the selection scrolls the new chip into view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var selected = InvestmentType.p2pLending;
    late StateSetter setOuter;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return _row(selected: selected, onSelected: (_) {});
        },
      ),
    );
    expect(tester.getRect(_chip(InvestmentType.other)).left, greaterThan(411));

    setOuter(() => selected = InvestmentType.other);
    await tester.pumpAndSettle();

    final rect = tester.getRect(_chip(InvestmentType.other));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(411));
  });

  testWidgets('a visible selected chip does not move the row', (tester) async {
    tester.view.physicalSize = const Size(411, 842);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    var selected = InvestmentType.p2pLending;
    late StateSetter setOuter;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return _row(selected: selected, onSelected: (_) {});
        },
      ),
    );
    final before = tester.getRect(_chip(InvestmentType.p2pLending)).left;

    setOuter(() => selected = InvestmentType.fixedDeposit);
    await tester.pumpAndSettle();

    expect(tester.getRect(_chip(InvestmentType.p2pLending)).left, before);
  });

  testWidgets('itemKeyBuilder keys the chips of the wrap layout too', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _row(
        selected: InvestmentType.p2pLending,
        onSelected: (_) {},
        scrolling: false,
        width: 1000,
      ),
    );
    for (final type in InvestmentType.values) {
      expect(_chip(type), findsOneWidget, reason: type.name);
    }
  });

  testWidgets('itemKeyBuilder keys the chips of the grid layout too', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _row(
        selected: InvestmentType.p2pLending,
        onSelected: (_) {},
        scrolling: false,
        grid: true,
        width: 1000,
      ),
    );
    for (final type in InvestmentType.values) {
      expect(_chip(type), findsOneWidget, reason: type.name);
    }
  });

  test('a grid cannot also be a scrolling row', () {
    expect(
      () => TypeSelector<InvestmentType>(
        values: InvestmentType.values,
        selectedValue: InvestmentType.p2pLending,
        onSelected: (_) {},
        colorBuilder: (type) => type.color,
        iconBuilder: (type) => type.icon,
        labelBuilder: (type) => type.displayName,
        gridLayout: true,
        scrollingRow: true,
      ),
      throwsAssertionError,
    );
  });
}
