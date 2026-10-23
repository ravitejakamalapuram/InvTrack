// #1103: the import errors are typed values in the data layer and become text
// in one place in the presentation layer.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/features/settings/presentation/utils/import_error_text.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String text(ImportError e) => importErrorText(l10n, e);

  test('fixed errors read as before', () {
    expect(text(const ImportError.invalidZip()), 'Invalid ZIP file');
    expect(
      text(const ImportError.metadataMissing()),
      'Invalid ZIP file: metadata.json not found',
    );
    expect(
      text(const ImportError.metadataUnparseable()),
      'Failed to parse metadata.json',
    );
  });

  test('a stopped Replace names the file and says nothing was changed', () {
    expect(
      text(const ImportError.cashflowsUnreadable()),
      'Backup not imported: cashflows.csv could not be read. Your existing '
      'data was not changed.',
    );
    expect(
      text(const ImportError.cashflowsMissing()),
      'Backup not imported: cashflows.csv is missing. Your existing data was '
      'not changed.',
    );
    expect(
      text(const ImportError.cashflowsNoRows()),
      'Backup not imported: cashflows.csv has no readable rows. Your existing '
      'data was not changed.',
    );
    expect(
      text(const ImportError.fileDamaged('goals.csv')),
      'Backup not imported: goals.csv is damaged. Your existing data was not '
      'changed.',
    );
  });

  test('archive failures use the singular and the plural', () {
    expect(
      text(const ImportError.archiveFailures(1)),
      '1 restored item could not be moved to the archive',
    );
    expect(
      text(const ImportError.archiveFailures(2)),
      '2 restored items could not be moved to the archive',
    );
  });

  test('a row message from the CSV parser is shown as it is', () {
    expect(
      text(const ImportError.rowDetail('Row 3: bad date')),
      'Row 3: bad date',
    );
  });

  test('every error has a stable code that carries no user text', () {
    expect(const ImportError.invalidZip().code, 'invalidZip');
    expect(const ImportError.archiveFailures(2).code, 'archiveFailures');
    expect(const ImportError.fileDamaged('goals.csv').code, 'fileDamaged');
    const rowDetail = ImportError.rowDetail('Row 3: Name X, Amount 100000');
    expect(rowDetail.code, 'rowDetail');
    expect(rowDetail.toString(), 'rowDetail');
  });

  test('errors with the same kind and parameter are equal', () {
    expect(
      const ImportError.archiveFailures(2),
      const ImportError.archiveFailures(2),
    );
    expect(
      const ImportError.archiveFailures(1),
      isNot(const ImportError.archiveFailures(2)),
    );
  });
}
