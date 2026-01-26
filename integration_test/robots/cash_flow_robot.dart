import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  /// Enter notes
  Future<void> enterNotes(String notes) async {
    final notesField = find.byType(TextFormField).at(1);
    await tester.enterText(notesField, notes);
    await pumpAndSettle();
  }

  /// Tap add/update button
  Future<void> tapSave() async {
    // The button text depends on the selected type
    final addInvest = find.text('Add Invest');
    final addReturn = find.text('Add Return');
    final addIncome = find.text('Add Income');
    final addFee = find.text('Add Fee');

    if (tester.any(addInvest)) {
      await tapText('Add Invest');
    } else if (tester.any(addReturn)) {
      await tapText('Add Return');
    } else if (tester.any(addIncome)) {
      await tapText('Add Income');
    } else if (tester.any(addFee)) {
      await tapText('Add Fee');
    }
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
  void verifyCashOutPreview() {
    verifyTextDisplayed('Cash Out');
  }

  void verifyCashInPreview() {
    verifyTextDisplayed('Cash In');
  }

  // ============ VALIDATION ============

  /// Verify validation error for amount
  void verifyAmountRequired() {
    verifyTextDisplayed('Required');
  }

  void verifyInvalidAmount() {
    verifyTextDisplayed('Invalid amount');
  }

  void verifyAmountMustBePositive() {
    verifyTextDisplayed('Must be greater than 0');
  }

  // ============ TRANSACTION LIST ============

  /// Verify a transaction is displayed
  void verifyTransactionDisplayed(String amount) {
    verifyTextDisplayed(amount, reason: 'Transaction with amount "$amount" should be visible');
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
