import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/features/investment/data/services/document_storage_service.dart';
import 'package:inv_tracker/features/investment/domain/repositories/document_repository.dart';
import 'package:inv_tracker/features/settings/data/services/backup_crypto.dart';
import 'package:inv_tracker/features/settings/data/services/data_export_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../goals/data/repositories/mock_goal_repository.dart';
import '../../../investment/data/repositories/mock_investment_repository.dart';

class _MockDocumentRepository extends Mock implements DocumentRepository {}

class _MockDocumentStorageService extends Mock
    implements DocumentStorageService {}

class _MockPerformanceService extends Mock implements PerformanceService {}

void main() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const fastIterations = 1000;

  late Directory tempDir;
  late DataExportService service;
  late List<String> sharedPaths;
  late List<bool> existedWhenShared;
  var shareShouldFail = false;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('enc_export_');
    sharedPaths = [];
    existedWhenShared = [];
    shareShouldFail = false;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      final paths = ((call.arguments as Map)['paths'] as List).cast<String>();
      sharedPaths.addAll(paths);
      existedWhenShared.addAll(paths.map((p) => File(p).existsSync()));
      if (shareShouldFail) throw PlatformException(code: 'boom');
      return 'dev.fluttercommunity.plus/share/success';
    });

    final performance = _MockPerformanceService();
    when(
      () => performance.trackOperation<String>(
        any(),
        any(),
        metrics: any(named: 'metrics'),
        attributes: any(named: 'attributes'),
      ),
    ).thenAnswer(
      (i) => (i.positionalArguments[1] as Future<String> Function())(),
    );
    final storage = _MockDocumentStorageService();
    when(
      () => storage.readDocument(any()),
    ).thenAnswer((_) async => Uint8List.fromList([1]));

    service = DataExportService(
      investmentRepository: FakeInvestmentRepository(),
      goalRepository: FakeGoalRepository(),
      documentRepository: _MockDocumentRepository(),
      documentStorageService: storage,
      performanceService: performance,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(shareChannel, null);
    tempDir.deleteSync(recursive: true);
  });

  test('without a password the export is a plain ZIP', () async {
    final path = await service.exportAsZip();
    final bytes = File(path).readAsBytesSync();
    expect(path, endsWith('.zip'));
    expect(BackupCrypto.isEncrypted(bytes), isFalse);
    expect(
      ZipDecoder().decodeBytes(bytes).findFile('metadata.json'),
      isNotNull,
    );
  });

  test(
    'with a password the file is encrypted and opens only with it',
    () async {
      final path = await service.exportAsZip(
        password: 'correct horse',
        kdfIterations: fastIterations,
      );
      final bytes = File(path).readAsBytesSync();
      expect(path, endsWith('.invbackup'));
      expect(BackupCrypto.isEncrypted(bytes), isTrue);

      final zip = await BackupCrypto.decrypt(bytes, 'correct horse');
      expect(
        ZipDecoder().decodeBytes(zip).findFile('metadata.json'),
        isNotNull,
      );
      expect(
        BackupCrypto.decrypt(bytes, 'wrong'),
        throwsA(isA<BackupDecryptionException>()),
      );
    },
  );

  test('exportAndShare deletes the temp file once sharing returns', () async {
    await service.exportAndShare(password: 'pw', kdfIterations: fastIterations);
    expect(sharedPaths, hasLength(1));
    expect(existedWhenShared, [true]);
    expect(File(sharedPaths.single).existsSync(), isFalse);
  });

  test('exportAndShare deletes the temp file when sharing fails', () async {
    shareShouldFail = true;
    await expectLater(service.exportAndShare(), throwsA(isA<Exception>()));
    expect(sharedPaths, hasLength(1));
    expect(File(sharedPaths.single).existsSync(), isFalse);
  });

  test('a new export purges stale exports left by earlier runs', () async {
    final stale = File('${tempDir.path}/InvTrack_Export_1.zip')
      ..writeAsBytesSync([1]);
    final staleEnc = File('${tempDir.path}/InvTrack_Export_2.invbackup')
      ..writeAsBytesSync([1]);
    final unrelated = File('${tempDir.path}/other.zip')..writeAsBytesSync([1]);

    await service.exportAsZip();

    expect(stale.existsSync(), isFalse);
    expect(staleEnc.existsSync(), isFalse);
    expect(unrelated.existsSync(), isTrue);
  });
}
