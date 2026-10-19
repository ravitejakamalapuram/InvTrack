import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// Total content size above which deflating takes longer than a frame.
const int kZipIsolateMinBytes = 256 * 1024;

List<int>? _encode(Archive archive) => ZipEncoder().encode(archive);

Future<List<int>?> _runInIsolate(Archive archive) => compute(_encode, archive);

/// Same bytes as `ZipEncoder().encode(archive)`, but an archive with scanned
/// documents or photos is compressed in a background isolate, so exporting
/// does not freeze the screen.
///
/// [runner] is only replaced in tests.
Future<List<int>> encodeZipOffUiThread(
  Archive archive, {
  int minBytesForIsolate = kZipIsolateMinBytes,
  Future<List<int>?> Function(Archive archive) runner = _runInIsolate,
}) async {
  var bytes = 0;
  for (final file in archive.files) {
    bytes += file.size;
  }
  final zip = bytes < minBytesForIsolate ? _encode(archive) : await runner(archive);
  if (zip == null) throw Exception('Failed to create ZIP archive');
  return zip;
}
