import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DocumentStorageService service;
  late String mockAppDocPath;

  setUp(() async {
    // Create a temporary directory for tests
    final tempDir = Directory.systemTemp.createTempSync('inv_tracker_test_');
    mockAppDocPath = tempDir.path;

    // Mock path_provider channel
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return mockAppDocPath;
        }
        return null;
      },
    );

    service = DocumentStorageService(userId: 'test_user');
  });

  tearDown(() {
    try {
      if (Directory(mockAppDocPath).existsSync()) {
        Directory(mockAppDocPath).deleteSync(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  test('saveDocument handles normal IDs correctly', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final path = await service.saveDocument(
      investmentId: 'inv-123',
      documentId: 'doc-123',
      fileName: 'test.pdf',
      bytes: bytes,
    );

    expect(path, contains('inv-123'));
    expect(path, contains('doc-123.pdf'));
    expect(File(path).existsSync(), isTrue);
  });

  test('saveDocument prevents directory traversal in investmentId', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final maliciousId = '../malicious';

    // This expects the service to throw FormatException for invalid ID
    // If vulnerable, it will NOT throw, and the test will fail
    expect(
      () => service.saveDocument(
        investmentId: maliciousId,
        documentId: 'doc-123',
        fileName: 'test.pdf',
        bytes: bytes,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('saveDocument prevents directory traversal in documentId', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final maliciousId = '../malicious';

    expect(
      () => service.saveDocument(
        investmentId: 'inv-123',
        documentId: maliciousId,
        fileName: 'test.pdf',
        bytes: bytes,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
