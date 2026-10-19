import 'dart:io';
import 'dart:typed_data';

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
