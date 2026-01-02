import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

/// Robot for interacting with settings screen.
class SettingsRobot extends BaseRobot {
  SettingsRobot(super.tester);

  // ============ SETTINGS SECTIONS ============

  /// Verify settings screen is displayed
  void verifyOnSettingsScreen() {
    verifyTextDisplayed('Settings');
    verifyTextDisplayed('Appearance');
  }

  /// Verify appearance section
  void verifyAppearanceSection() {
    verifyTextDisplayed('Appearance');
  }

  /// Verify data section
  void verifyDataSection() {
    verifyExists(find.text('Export Data'), reason: 'Export Data option should exist');
  }

  /// Verify security section
  void verifySecuritySection() {
    verifyExists(find.textContaining('Security'), reason: 'Security section should exist');
  }

  // ============ THEME SWITCHING ============

  /// Tap on appearance/theme option
  Future<void> tapAppearance() async {
    await tapText('Appearance');
  }

  /// Select light theme
  Future<void> selectLightTheme() async {
    await tapText('Light');
  }

  /// Select dark theme
  Future<void> selectDarkTheme() async {
    await tapText('Dark');
  }

  /// Select system theme
  Future<void> selectSystemTheme() async {
    await tapText('System');
  }

  // ============ CURRENCY SETTINGS ============

  /// Tap currency option
  Future<void> tapCurrency() async {
    await scrollUntilVisible(find.text('Currency'));
    await tapText('Currency');
  }

  /// Select a currency
  Future<void> selectCurrency(String currencyCode) async {
    await tapText(currencyCode);
  }

  // ============ EXPORT/IMPORT ============

  /// Tap export data
  Future<void> tapExportData() async {
    await scrollUntilVisible(find.text('Export Data'));
    await tapText('Export Data');
  }

  /// Tap import data
  Future<void> tapImportData() async {
    await scrollUntilVisible(find.text('Import Data'));
    await tapText('Import Data');
  }

  // ============ SECURITY ============

  /// Tap security option
  Future<void> tapSecurity() async {
    await scrollUntilVisible(find.textContaining('Passcode'));
    await tapText('Passcode');
  }

  /// Toggle biometric setting
  Future<void> toggleBiometric() async {
    final biometricSwitch = find.byType(Switch).first;
    if (tester.any(biometricSwitch)) {
      await tap(biometricSwitch);
    }
  }

  // ============ ACCOUNT ============

  /// Tap sign out
  Future<void> tapSignOut() async {
    await scrollUntilVisible(find.text('Sign Out'));
    await tapText('Sign Out');
  }

  /// Confirm sign out
  Future<void> confirmSignOut() async {
    await tapText('Sign Out');
  }

  /// Cancel sign out
  Future<void> cancelSignOut() async {
    await tapText('Cancel');
  }

  /// Verify sign out option visible
  void verifySignOutVisible() {
    verifyTextDisplayed('Sign Out');
  }

  // ============ NOTIFICATIONS ============

  /// Tap notifications settings
  Future<void> tapNotifications() async {
    await scrollUntilVisible(find.text('Notifications'));
    await tapText('Notifications');
  }

  /// Toggle notification setting
  Future<void> toggleNotifications() async {
    final toggle = find.byType(Switch).first;
    if (tester.any(toggle)) {
      await tap(toggle);
    }
  }

  // ============ ABOUT ============

  /// Tap about/version
  Future<void> tapAbout() async {
    await scrollUntilVisible(find.text('About'));
    await tapText('About');
  }

  /// Verify app version is displayed
  void verifyVersionDisplayed() {
    // Look for version pattern like "1.0.0"
    verifyExists(
      find.textContaining(RegExp(r'\d+\.\d+\.\d+')),
      reason: 'Version number should be visible',
    );
  }

  // ============ PRIVACY ============

  /// Toggle privacy mode
  Future<void> togglePrivacyMode() async {
    await scrollUntilVisible(find.text('Privacy Mode'));
    await tapText('Privacy Mode');
  }
}

