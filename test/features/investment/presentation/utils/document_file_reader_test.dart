import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/utils/document_file_reader.dart';

/// A file whose bytes must never be read: only `length()` is implemented, so
/// `readAsBytes()` throws if the reader loads an oversized file.
class _LengthOnlyFile extends Fake implements File {
  _LengthOnlyFile(this._length);
  final int _length;

  @override
  Future<int> length() async => _length;
}

void main() {
  group('readDocumentBytesWithinLimit', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('doc_reader_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('does not read the bytes of a file over the limit', () async {
      final result = await readDocumentBytesWithinLimit(
        _LengthOnlyFile(kMaxDocumentBytes + 1),
      );
      expect(result, isNull);
    });

    test('returns the bytes of a file exactly at the limit', () async {
      final file = File('${dir.path}/at_limit.bin')
        ..writeAsBytesSync(List.filled(10, 7));
      final result = await readDocumentBytesWithinLimit(file, maxBytes: 10);
      expect(result, Uint8List.fromList(List.filled(10, 7)));
    });

    test('returns null one byte over the limit', () async {
      final file = File('${dir.path}/over.bin')
        ..writeAsBytesSync(List.filled(11, 7));
      expect(await readDocumentBytesWithinLimit(file, maxBytes: 10), isNull);
    });

    test('limit is the 10 MB the document notifier enforces', () {
      expect(kMaxDocumentBytes, 10 * 1024 * 1024);
    });
  });
}
