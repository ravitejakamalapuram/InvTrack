import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counts the saves the server rejected after the app had reported them as
/// done (A26). A save is done once it is on this device; the app shows one
/// message per rejection, from the connectivity listener.
class WriteRejectedNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void report() => state++;
}

final writeRejectedProvider = NotifierProvider<WriteRejectedNotifier, int>(
  WriteRejectedNotifier.new,
);
