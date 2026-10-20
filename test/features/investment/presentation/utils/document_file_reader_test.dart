import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/utils/document_file_reader.dart';

import '../../../../helpers/fake_file_picker.dart';

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

  group('readPickedDocumentBytesWithinLimit', () {
    // A picked file with no path, like an Android content URI.
    FakePickedFile pathless(int size) =>
        FakePickedFile(name: 'scan.pdf', bytes: Uint8List(size));

    test('reads a path-less file at the limit', () async {
      final result = await readPickedDocumentBytesWithinLimit(
        pathless(10),
        maxBytes: 10,
      );
      expect(result, hasLength(10));
    });

    test('returns null for a path-less file one byte over the limit', () async {
      final result = await readPickedDocumentBytesWithinLimit(
        pathless(11),
        maxBytes: 10,
      );
      expect(result, isNull);
    });

    test('reads a file that has a path from disk', () async {
      final dir = Directory.systemTemp.createTempSync('picked_doc_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.pdf')..writeAsBytesSync([1, 2, 3]);
      final result = await readPickedDocumentBytesWithinLimit(
        FakePickedFile(name: 'a.pdf', filePath: file.path),
      );
      expect(result, Uint8List.fromList([1, 2, 3]));
    });
  });
}
