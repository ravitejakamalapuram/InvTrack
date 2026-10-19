import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/settings/data/services/zip_off_ui_thread.dart';

Archive _archive({int documentBytes = 300000}) {
  final csv = utf8.encode('id,amount\n1,100\n2,200\n');
  final doc = Uint8List.fromList(
    List.generate(documentBytes, (i) => (i * 31) % 251),
  );
  return Archive()
    ..addFile(ArchiveFile('cashflows.csv', csv.length, csv))
    ..addFile(ArchiveFile('documents/inv-1/scan.pdf', doc.length, doc));
}

void _expectSameFiles(List<int> zipBytes, Archive original) {
  final decoded = ZipDecoder().decodeBytes(zipBytes);
  expect(decoded.files.map((f) => f.name), original.files.map((f) => f.name));
  for (var i = 0; i < original.files.length; i++) {
    expect(decoded.files[i].content, original.files[i].content);
  }
}

void main() {
  group('encodeZipOffUiThread', () {
    test('a real isolate produces the same zip the UI isolate would', () async {
      final archive = _archive();
      final inline = ZipEncoder().encode(archive)!;

      final actual = await encodeZipOffUiThread(archive, minBytesForIsolate: 0);

      expect(actual, inline);
      _expectSameFiles(actual, archive);
    });

    test('big archives go to the runner, small ones stay inline', () async {
      var runs = 0;
      Future<List<int>?> spy(Archive a) async {
        runs++;
        return ZipEncoder().encode(a);
      }

      final big = _archive(documentBytes: 300000);
      await encodeZipOffUiThread(big, runner: spy);
      expect(runs, 1);

      final small = _archive(documentBytes: 10);
      await encodeZipOffUiThread(small, runner: spy);
      expect(runs, 1, reason: 'under the limit nothing is sent to a runner');
    });

    test('archives over the memory cap stay inline', () async {
      var runs = 0;
      Future<List<int>?> spy(Archive a) async {
        runs++;
        return ZipEncoder().encode(a);
      }

      final big = _archive(documentBytes: 300000);
      final zip = await encodeZipOffUiThread(
        big,
        runner: spy,
        maxBytesForIsolate: 100000,
      );
      expect(runs, 0);
      _expectSameFiles(zip, big);
    });

    test('throws when the archive cannot be encoded', () async {
      Future<List<int>?> failing(Archive a) async => null;
      expect(
        encodeZipOffUiThread(_archive(), runner: failing),
        throwsException,
      );
    });
  });
}
