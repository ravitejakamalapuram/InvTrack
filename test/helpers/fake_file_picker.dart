import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// A picked file for widget tests: a name, and either bytes or a path.
base class FakePickedFile extends PlatformFile {
  FakePickedFile({required this.name, this.bytes, String? filePath})
    : uri = filePath == null ? Uri(path: name) : Uri.file(filePath);

  @override
  final String name;

  @override
  final Uri uri;

  final Uint8List? bytes;

  @override
  get xFile => throw UnimplementedError('xFile is not used by the app');

  @override
  int? lengthSync() => bytes?.length;

  @override
  Future<int?> length() async => bytes?.length;

  @override
  Future<Uint8List> readAsBytes() async =>
      bytes ?? (throw StateError('$name has no bytes'));

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes ?? Uint8List(0));
}

/// Replaces the system file picker with a fixed list of files.
class FakeFilePicker extends FilePickerPlatform {
  FakeFilePicker(this.files);

  final List<PlatformFile> files;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => files;
}
