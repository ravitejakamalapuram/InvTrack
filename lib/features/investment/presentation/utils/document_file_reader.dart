import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Largest document the app stores (also enforced when saving).
const int kMaxDocumentBytes = 10 * 1024 * 1024;

/// Reads [file] only if it is at most [maxBytes], so a huge file picked by the
/// user is never loaded into memory. Returns null when it is over the limit.
Future<Uint8List?> readDocumentBytesWithinLimit(
  File file, {
  int maxBytes = kMaxDocumentBytes,
}) async {
  if (await file.length() > maxBytes) return null;
  return file.readAsBytes();
}

/// Reads a file chosen in the picker if it is at most [maxBytes]. Files on a
/// real path are read from disk; the others (for example an Android content
/// URI, which has no path) are read through the picker, stopping as soon as
/// the limit is passed. Returns null when the file is over the limit.
Future<Uint8List?> readPickedDocumentBytesWithinLimit(
  PlatformFile picked, {
  int maxBytes = kMaxDocumentBytes,
}) async {
  final path = picked.path;
  if (path != null) {
    return readDocumentBytesWithinLimit(File(path), maxBytes: maxBytes);
  }
  final length = await picked.length();
  if (length != null && length > maxBytes) return null;
  final builder = BytesBuilder(copy: false);
  await for (final chunk in picked.readAsByteStream()) {
    builder.add(chunk);
    if (builder.length > maxBytes) return null;
  }
  return builder.takeBytes();
}
