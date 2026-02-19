import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DocumentStorageService service;
  late Directory tempDir;
  late File outsideFile;

  setUp(() async {
    // Create a temporary directory for tests
    tempDir = await Directory.systemTemp.createTemp('inv_tracker_test_');

    // Create a file OUTSIDE the allowed documents directory
    // Allowed dir will be tempDir/documents/test_user
    // So create a file in tempDir/secret.txt
    outsideFile = File(path.join(tempDir.path, 'secret.txt'));
    await outsideFile.writeAsString('SECRET DATA');

    // Mock path_provider channel
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    service = DocumentStorageService(userId: 'test_user');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      // ignore
    }
  });

  test('readDocument prevents reading outside file', () async {
    // Expect FileSystemException because access should be denied
    expect(
      () => service.readDocument(outsideFile.path),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('readDocument allows reading valid file', () async {
    // Create a valid file
    final bytes = Uint8List.fromList([1, 2, 3]);
    final path = await service.saveDocument(
      investmentId: 'inv-123',
      documentId: 'doc-123',
      fileName: 'test.pdf',
      bytes: bytes,
    );

    final content = await service.readDocument(path);
    expect(content, equals(bytes));
  });
}
