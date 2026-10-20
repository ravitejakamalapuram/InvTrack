import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:path/path.dart' as path_lib;

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return mockAppDocPath;
          }
          return null;
        });

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

  group('deleteAllUserDocuments', () {
    test('removes every attachment across all investments for the user', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      await service.saveDocument(
        investmentId: 'inv-1',
        documentId: 'doc-1',
        fileName: 'a.pdf',
        bytes: bytes,
      );
      await service.saveDocument(
        investmentId: 'inv-2',
        documentId: 'doc-2',
        fileName: 'b.pdf',
        bytes: bytes,
      );

      final userDir = Directory(
        path_lib.join(mockAppDocPath, 'documents', 'test_user'),
      );
      expect(userDir.existsSync(), isTrue);

      await service.deleteAllUserDocuments();

      expect(userDir.existsSync(), isFalse);
    });

    test('does not throw when the user has no documents on disk', () async {
      await expectLater(service.deleteAllUserDocuments(), completes);
    });

    test('does not affect another user\'s documents directory', () async {
      final otherService = DocumentStorageService(userId: 'other_user');
      final bytes = Uint8List.fromList([1, 2, 3]);
      await service.saveDocument(
        investmentId: 'inv-1',
        documentId: 'doc-1',
        fileName: 'a.pdf',
        bytes: bytes,
      );
      await otherService.saveDocument(
        investmentId: 'inv-1',
        documentId: 'doc-1',
        fileName: 'a.pdf',
        bytes: bytes,
      );

      await service.deleteAllUserDocuments();

      final otherUserDir = Directory(
        path_lib.join(mockAppDocPath, 'documents', 'other_user'),
      );
      expect(otherUserDir.existsSync(), isTrue);
    });
  });
}
