import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_export_provider.dart';
import 'package:inv_tracker/features/reports/presentation/providers/fy_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/fy_export_csv_button.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

final _report = FYReport(
  fyStart: DateTime(2025, 4, 1),
  fyEnd: DateTime(2026, 3, 31),
  fyLabel: '2025-26',
  totalInvested: 100000,
  totalReturns: 54000,
  totalIncome: 4000,
  totalFees: 150,
  netCashFlow: -42150,
  xirr: 0.12,
  monthlyBreakdown: const [],
  topPerformersByReturns: const [],
  topPerformersByXIRR: const [],
  portfolioValueAtStart: 0,
  portfolioValueAtEnd: 0,
  shortTermCapitalGains: 0,
  longTermCapitalGains: 0,
  dividendIncome: 1000,
  interestIncome: 3000,
);

class _Privacy extends PrivacyModeNotifier {
  _Privacy(this.value);
  final bool value;
  @override
  bool build() => value;
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
}

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  ShareParams? params;
  @override
  Future<ShareResult> share(ShareParams params) async {
    this.params = params;
    return const ShareResult('', ShareResultStatus.success);
  }
}

Widget _app({
  required FYCsvSharer share,
  required Future<FYReport> Function() report,
  bool privacy = false,
  ValueNotifier<String>? currency,
  VoidCallback? onReportDisposed,
}) => ProviderScope(
  overrides: [
    fyReportProvider(2025).overrideWith((ref) {
      if (onReportDisposed != null) ref.onDispose(onReportDisposed);
      return report();
    }),
    if (currency == null)
      currencyCodeProvider.overrideWithValue('INR')
    else
      currencyCodeProvider.overrideWith((ref) {
        void l() => ref.invalidateSelf();
        currency.addListener(l);
        ref.onDispose(() => currency.removeListener(l));
        return currency.value;
      }),
    privacyModeProvider.overrideWith(() => _Privacy(privacy)),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: FYExportCsvButton(fyYear: 2025, share: share)),
  ),
);

void main() {
  group('FYExportCsvButton share flow', () {
    testWidgets('shares with localized subject and privacy flag', (t) async {
      String? subjectOut;
      bool? masked;
      String? currency;
      await t.pumpWidget(
        _app(
          privacy: true,
          report: () async => _report,
          share: (r, c, {required subject, required maskSensitiveData}) async {
            currency = c;
            masked = maskSensitiveData;
            subjectOut = subject;
          },
        ),
      );
      await t.tap(find.bySubtype<TextButton>());
      await t.pumpAndSettle();
      expect(subjectOut, 'InvTrack FY 2025-26 report');
      expect(masked, isTrue);
      expect(currency, 'INR');
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('keeps the FY report provider alive until the share ends', (
      t,
    ) async {
      var disposed = false;
      final shareGate = Completer<void>();
      await t.pumpWidget(
        _app(
          report: () async => _report,
          onReportDisposed: () => disposed = true,
          share: (r, c, {required subject, required maskSensitiveData}) =>
              shareGate.future,
        ),
      );
      await t.tap(find.bySubtype<TextButton>());
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(disposed, isFalse, reason: 'disposed while share in flight');
      shareGate.complete();
      await t.pumpAndSettle();
    });

    testWidgets('share failure shows the failure snackbar and re-enables', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          report: () async => _report,
          share: (r, c, {required subject, required maskSensitiveData}) async =>
              throw Exception('boom'),
        ),
      );
      await t.tap(find.bySubtype<TextButton>());
      await t.pumpAndSettle();
      expect(
        find.text('Could not export the report. Please try again.'),
        findsOneWidget,
      );
      expect(
        t.widget<TextButton>(find.bySubtype<TextButton>()).onPressed,
        isNotNull,
      );
    });

    testWidgets('uses the currency from when the export started', (t) async {
      final completer = Completer<FYReport>();
      final cur = ValueNotifier('INR');
      String? currency;
      await t.pumpWidget(
        _app(
          currency: cur,
          report: () => completer.future,
          share: (r, c, {required subject, required maskSensitiveData}) async {
            currency = c;
          },
        ),
      );
      await t.tap(find.bySubtype<TextButton>());
      await t.pump();
      cur.value = 'USD';
      await t.pump();
      completer.complete(_report);
      await t.pumpAndSettle();
      expect(currency, 'INR');
    });

    testWidgets('disposal while the report loads does not share or throw', (
      t,
    ) async {
      final completer = Completer<FYReport>();
      var shared = false;
      await t.pumpWidget(
        _app(
          report: () => completer.future,
          share: (r, c, {required subject, required maskSensitiveData}) async {
            shared = true;
          },
        ),
      );
      await t.tap(find.bySubtype<TextButton>());
      await t.pump();
      await t.pumpWidget(const SizedBox());
      completer.complete(_report);
      await t.pumpAndSettle();
      expect(shared, isFalse);
      expect(t.takeException(), isNull);
    });

    testWidgets('disposal before a failing report is silent', (t) async {
      final completer = Completer<FYReport>();
      await t.pumpWidget(
        _app(
          report: () => completer.future,
          share:
              (r, c, {required subject, required maskSensitiveData}) async {},
        ),
      );
      await t.tap(find.bySubtype<TextButton>());
      await t.pump();
      await t.pumpWidget(const SizedBox());
      completer.completeError(Exception('late'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('shareFYReportCsv', () {
    late Directory tmp;
    late PathProviderPlatform origPath;
    late SharePlatform origShare;
    late _FakeShare fakeShare;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fycsv');
      origPath = PathProviderPlatform.instance;
      origShare = SharePlatform.instance;
      PathProviderPlatform.instance = _FakePathProvider(tmp.path);
      fakeShare = _FakeShare();
      SharePlatform.instance = fakeShare;
    });

    tearDown(() {
      PathProviderPlatform.instance = origPath;
      SharePlatform.instance = origShare;
      tmp.deleteSync(recursive: true);
    });

    test('writes the CSV file and shares it with the subject', () async {
      await shareFYReportCsv(
        _report,
        'INR',
        subject: 'Subj',
        maskSensitiveData: false,
      );
      final file = File('${tmp.path}/invtrack_fy_2025-26_report.csv');
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains('Amount (INR)'));
      expect(fakeShare.params?.subject, 'Subj');
      expect(fakeShare.params?.files?.single.path, file.path);
    });
  });
}
