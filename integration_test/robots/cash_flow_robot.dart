import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/app_text_field.dart';
import 'package:inv_tracker/core/widgets/gradient_button.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

import 'base_robot.dart';

/// Robot for interacting with cash flow/transaction screens.
class CashFlowRobot extends BaseRobot {
  CashFlowRobot(super.tester);

  // ============ ADD CASH FLOW SCREEN ============

  /// Verify on add cash flow screen
  void verifyOnAddCashFlowScreen() {
    verifyTextDisplayed('Add Cash Flow');
    verifyTextDisplayed('Cash Flow Type');
    verifyTextDisplayed('Amount');
  }

  /// Verify on edit cash flow screen
  void verifyOnEditCashFlowScreen() {
    verifyTextDisplayed('Edit Cash Flow');
    verifyTextDisplayed('Cash Flow Type');
  }

  /// Select cash flow type
  Future<void> selectType(CashFlowType type) async {
    await tapText(type.displayName);
  }

  /// Enter amount
  Future<void> enterAmount(String amount) async {
    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, amount);
    await pumpAndSettle();
  }

  /// Scroll the form (a lazy ListView, the outermost Scrollable) until
  /// [target] is built, then bring its first match fully on screen. Unlike
  /// WidgetTester.scrollUntilVisible this accepts more than one match, because
  /// a field label can be drawn twice.
  Future<void> _scrollFormTo(Finder target, {double delta = 300}) async {
    final form = find.byType(Scrollable).first;
    for (var i = 0; i < 20 && !tester.any(target); i++) {
      await tester.drag(form, Offset(0, -delta));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(target.first);
    await pumpAndSettle();
  }

  /// Enter notes. The form is a lazy ListView, so scroll to the field first.
  Future<void> enterNotes(String notes) async {
    final field = find.widgetWithText(AppTextField, 'Notes (Optional)');
    await _scrollFormTo(field);
    // By label, not position: scrolling can unbuild the Amount field.
    final input = find.descendant(
      of: field.first,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(input, notes);
    await pumpAndSettle();
  }

  /// Tap the Save Cash Flow button (the label no longer depends on the type).
  Future<void> tapSave() async {
    final save = find.widgetWithText(GradientButton, 'Save Cash Flow');
    await _scrollFormTo(save);
    await tap(save);
  }

  /// Add a cash flow with type and amount
  Future<void> addCashFlow({
    required CashFlowType type,
    required String amount,
    String? notes,
  }) async {
    await selectType(type);
    await enterAmount(amount);
    if (notes != null) {
      await enterNotes(notes);
    }
    await tapSave();
  }

  /// Tap on date picker to change date
  Future<void> tapDatePicker() async {
    await tapIcon(Icons.calendar_today_rounded);
  }

  /// Verify cash flow preview shows correct direction
  Future<void> verifyCashOutPreview() async {
    await _scrollFormTo(find.text('Cash Out'));
    verifyTextDisplayed('Cash Out');
  }

  Future<void> verifyCashInPreview() async {
    await _scrollFormTo(find.text('Cash In'));
    verifyTextDisplayed('Cash In');
  }

  // ============ VALIDATION ============

  /// Verify validation error for amount
  Future<void> verifyAmountRequired() async {
    // Saving scrolled the form down; the error sits under the Amount field.
    await _scrollFormTo(find.text('Required'), delta: -300);
    verifyTextDisplayed('Required');
  }

  void verifyInvalidAmount() {
    verifyTextDisplayed('Invalid amount');
  }

  void verifyAmountMustBePositive() {
    verifyTextDisplayed('Must be positive');
  }

  // ============ TRANSACTION LIST ============

  /// Verify a transaction is displayed
  void verifyTransactionDisplayed(String amount) {
    verifyTextDisplayed(
      amount,
      reason: 'Transaction with amount "$amount" should be visible',
    );
  }

  /// Tap on a transaction to edit
  Future<void> tapTransaction(String amount) async {
    await tapText(amount);
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String amount) async {
    await tapTransaction(amount);
    await tapIcon(Icons.delete_outline_rounded);
    await tapText('Delete');
  }

  /// Verify empty transactions state
  void verifyNoTransactions() {
    verifyTextDisplayed('No transactions yet');
  }

  /// Verify transaction count
  void verifyTransactionCount(int count) {
    if (count == 0) {
      verifyNoTransactions();
    }
  }

  // ============ EDIT CASH FLOW ============

  /// Update the amount
  Future<void> updateAmount(String newAmount) async {
    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '');
    await tester.enterText(amountField, newAmount);
    await pumpAndSettle();
  }

  /// Tap update button
  Future<void> tapUpdate() async {
    await tapText('Update');
  }
}
