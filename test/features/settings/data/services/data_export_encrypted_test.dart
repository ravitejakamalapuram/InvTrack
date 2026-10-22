import 'dart:io';

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

  File aged(String name) => File('${tempDir.path}/$name')
    ..writeAsBytesSync([1])
    ..setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

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
    await expectLater(
      service.exportAndShare(cleanupDelay: Duration.zero),
      throwsA(isA<Exception>()),
    );
    expect(sharedPaths, hasLength(1));
    expect(File(sharedPaths.single).existsSync(), isFalse);
  });

  test(
    'shareZipFiles with a password shares an encrypted copy, deletes it after '
    'and leaves the source file alone',
    () async {
      final source = File('${tempDir.path}/guest.zip')
        ..writeAsBytesSync([9, 8, 7]);
      Uint8List? sharedBytes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
            final paths = ((call.arguments as Map)['paths'] as List)
                .cast<String>();
            sharedPaths.addAll(paths);
            sharedBytes = File(paths.single).readAsBytesSync();
            return 'dev.fluttercommunity.plus/share/success';
          });

      await service.shareZipFiles(
        [source.path],
        password: 'pw',
        kdfIterations: fastIterations,
      );

      expect(sharedPaths.single, endsWith('.invbackup'));
      expect(BackupCrypto.isEncrypted(sharedBytes!), isTrue);
      expect(await BackupCrypto.decrypt(sharedBytes!, 'pw'), [9, 8, 7]);
      expect(File(sharedPaths.single).existsSync(), isFalse);
      expect(source.readAsBytesSync(), [9, 8, 7]);
    },
  );

  test('overlapping password shares never reuse a temp file name', () async {
    final source = File('${tempDir.path}/guest.zip')..writeAsBytesSync([1]);
    await Future.wait([
      for (var i = 0; i < 4; i++)
        service.shareZipFiles(
          [source.path],
          password: 'pw',
          kdfIterations: fastIterations,
        ),
    ]);
    expect(sharedPaths.toSet(), hasLength(4));
  });

  test('shareZipFiles deletes the encrypted copy when sharing fails', () async {
    final source = File('${tempDir.path}/guest.zip')..writeAsBytesSync([1]);
    shareShouldFail = true;
    await expectLater(
      service.shareZipFiles(
        [source.path],
        password: 'pw',
        kdfIterations: fastIterations,
      ),
      throwsA(isA<Exception>()),
    );
    expect(File(sharedPaths.single).existsSync(), isFalse);
  });

  test('a new export purges stale exports left by earlier runs', () async {
    final stale = aged('InvTrack_Export_1.zip');
    final staleEnc = aged('InvTrack_Export_2.invbackup');
    final active = File('${tempDir.path}/InvTrack_Export_3.zip')
      ..writeAsBytesSync([1]);
    final unrelated = File('${tempDir.path}/other.zip')..writeAsBytesSync([1]);

    await service.exportAsZip();

    expect(stale.existsSync(), isFalse);
    expect(staleEnc.existsSync(), isFalse);
    expect(unrelated.existsSync(), isTrue);
    expect(active.existsSync(), isTrue); // young: maybe a running export
  });

  test(
    'a delayed cleanup leaves the file for the receiving app first',
    () async {
      await service.exportAndShare(
        cleanupDelay: const Duration(milliseconds: 300),
      );
      final file = File(sharedPaths.single);
      expect(file.existsSync(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(file.existsSync(), isFalse);
    },
  );

  test('purgeStaleBackupExports clears leftovers without an export', () async {
    final stale = aged('InvTrack_Export_9.zip');
    await purgeStaleBackupExports();
    expect(stale.existsSync(), isFalse);
  });
}
