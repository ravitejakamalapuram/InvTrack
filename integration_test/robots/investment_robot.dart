import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

import 'base_robot.dart';

/// Robot for interacting with investment screens.
class InvestmentRobot extends BaseRobot {
  InvestmentRobot(super.tester);

  // ============ INVESTMENT LIST SCREEN ============

  /// Verify empty state is shown
  void verifyEmptyState() {
    verifyTextDisplayed('No Investments Yet');
  }

  /// Verify an investment is displayed in the list
  void verifyInvestmentDisplayed(String name) {
    verifyTextDisplayed(name, reason: 'Investment "$name" should be in the list');
  }

  /// Verify an investment is not displayed
  void verifyInvestmentNotDisplayed(String name) {
    verifyTextNotDisplayed(name, reason: 'Investment "$name" should not be in the list');
  }

  /// Tap on an investment in the list
  Future<void> tapInvestment(String name) async {
    await tapText(name);
  }

  // ============ ADD INVESTMENT ============

  /// Open add investment screen via FAB
  Future<void> openAddInvestment() async {
    await tap(find.byType(FloatingActionButton));
  }

  /// Enter investment name
  Future<void> enterName(String name) async {
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, name);
    await pumpAndSettle();
  }

  /// Select investment type
  Future<void> selectType(InvestmentType type) async {
    await tapText(type.displayName);
  }

  /// Enter notes
  Future<void> enterNotes(String notes) async {
    final notesField = find.byType(TextFormField).at(1);
    await tester.enterText(notesField, notes);
    await pumpAndSettle();
  }

  /// Tap save/add button
  Future<void> tapSave() async {
    // Look for the gradient button with "Add Investment" or "Save Changes"
    final addButton = find.text('Add Investment');
    final saveButton = find.text('Save Changes');

    if (tester.any(addButton)) {
      await tapText('Add Investment');
    } else if (tester.any(saveButton)) {
      await tapText('Save Changes');
    }
  }

  /// Complete add investment flow
  Future<void> addInvestment({
    required String name,
    required InvestmentType type,
    String? notes,
  }) async {
    await openAddInvestment();
    await selectType(type);
    await enterName(name);
    if (notes != null) {
      await enterNotes(notes);
    }
    await tapSave();
  }

  // ============ INVESTMENT DETAIL SCREEN ============

  /// Verify on investment detail screen
  void verifyOnDetailScreen(String investmentName) {
    verifyTextDisplayed(investmentName);
  }

  /// Open edit from detail screen
  Future<void> openEdit() async {
    await tapIcon(Icons.edit_outlined);
  }

  /// Tap delete from detail screen
  Future<void> tapDelete() async {
    await tapIcon(Icons.delete_outline_rounded);
  }

  /// Confirm delete in dialog
  Future<void> confirmDelete() async {
    await tapText('Delete');
  }

  /// Cancel delete in dialog
  Future<void> cancelDelete() async {
    await tapText('Cancel');
  }

  /// Open add cash flow screen from detail
  Future<void> openAddCashFlow() async {
    final fab = find.byType(FloatingActionButton);
    if (tester.any(fab)) {
      await tap(fab);
    } else {
      await tapText('Add Cash Flow');
    }
  }

  /// Tap archive button
  Future<void> tapArchive() async {
    await tapIcon(Icons.archive_outlined);
  }

  /// Confirm archive in dialog
  Future<void> confirmArchive() async {
    await tapText('Archive');
  }

  /// Cancel archive in dialog
  Future<void> cancelArchive() async {
    await tapText('Cancel');
  }

  /// Swipe right to archive an investment
  Future<void> swipeToArchive(String name) async {
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byType(GlassCard),
    );
    await swipeRight(card);
  }

  /// Swipe left to delete an investment
  Future<void> swipeToDelete(String name) async {
    final card = find.ancestor(
      of: find.text(name),
      matching: find.byType(GlassCard),
    );
    await swipeLeft(card);
  }

  /// Open archived investments view
  Future<void> openArchivedView() async {
    await tapText('Archived');
  }

  /// Open active investments view
  Future<void> openActiveView() async {
    await tapText('Active');
  }

  /// Tap unarchive button
  Future<void> tapUnarchive() async {
    await tapIcon(Icons.unarchive_outlined);
  }

  /// Confirm unarchive in dialog
  Future<void> confirmUnarchive() async {
    await tapText('Unarchive');
  }

  /// Verify transaction list
  void verifyTransactionCount(int count) {
    if (count == 0) {
      verifyTextDisplayed('No transactions yet');
    }
  }

  /// Scroll to bottom of detail screen
  Future<void> scrollToBottom() async {
    await scrollUntilVisible(
      find.byType(GlassCard).last,
      delta: 200,
    );
  }

  // ============ FORM VALIDATION ============

  /// Verify form validation error is shown
  void verifyValidationError(String errorText) {
    verifyTextDisplayed(errorText);
  }

  /// Clear the name field
  Future<void> clearName() async {
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, '');
    await pumpAndSettle();
  }

  /// Verify add investment screen is shown
  void verifyOnAddInvestmentScreen() {
    verifyTextDisplayed('Add Investment');
    verifyTextDisplayed('Investment Type');
    verifyTextDisplayed('Investment Name');
  }

  /// Verify edit investment screen is shown
  void verifyOnEditInvestmentScreen() {
    verifyTextDisplayed('Save Changes');
    verifyTextDisplayed('Investment Type');
    verifyTextDisplayed('Investment Name');
  }

  /// Tap cancel/back to close form
  Future<void> tapCancel() async {
    await tester.pageBack();
    await pumpAndSettle();
  }

  // ============ CASH FLOW NAVIGATION ============

  /// Open add transaction screen from detail screen
  Future<void> openAddTransaction() async {
    await tapText('Add Transaction');
  }

  /// Verify transactions tab is selected
  void verifyTransactionsTabSelected() {
    verifyTextDisplayed('Transactions');
  }

  /// Verify documents tab is selected
  Future<void> tapDocumentsTab() async {
    await tapText('Documents');
  }

  // ============ FILTER & SORT ============

  /// Open filter sheet
  Future<void> openFilterSheet() async {
    await tapIcon(Icons.filter_list_rounded);
  }

  /// Filter by investment type
  Future<void> filterByType(InvestmentType type) async {
    await openFilterSheet();
    await tapText(type.displayName);
    await tapText('Apply');
  }

  /// Clear all filters
  Future<void> clearFilters() async {
    await openFilterSheet();
    await tapText('Clear');
  }

  /// Open sort options
  Future<void> openSortOptions() async {
    await tapIcon(Icons.sort_rounded);
  }

  /// Sort by name
  Future<void> sortByName() async {
    await openSortOptions();
    await tapText('Name');
  }

  /// Sort by value
  Future<void> sortByValue() async {
    await openSortOptions();
    await tapText('Value');
  }

  /// Sort by date
  Future<void> sortByDate() async {
    await openSortOptions();
    await tapText('Date');
  }

  // ============ BULK SELECTION ============

  /// Long press to enter selection mode
  Future<void> longPressToSelect(String name) async {
    await longPress(find.text(name));
  }

  /// Verify selection mode is active
  void verifySelectionModeActive() {
    verifyExists(
      find.byIcon(Icons.close),
      reason: 'Close button should be visible in selection mode',
    );
  }

  /// Tap select all
  Future<void> selectAll() async {
    await tapText('Select All');
  }

  /// Tap delete selected
  Future<void> deleteSelected() async {
    await tapIcon(Icons.delete_outline_rounded);
  }

  /// Cancel selection mode
  Future<void> cancelSelection() async {
    await tapIcon(Icons.close);
  }
}

