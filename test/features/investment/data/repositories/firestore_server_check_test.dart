// A121 (#895): before sample data is written, the server, never the cache,
// must say whether the account already holds an investment. One-shot reads
// of the archived list must not wait for a server answer either, which the
// live stream now does.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'investment_snapshot_mocks.dart';

void main() {
  setUpAll(registerInvestmentSnapshotFallbacks);

  late InvestmentFirestoreMock firestore;

  setUp(() => firestore = InvestmentFirestoreMock());
  tearDown(() => firestore.close());

  final oneDoc = {'inv-1': investmentDoc('HDFC FD')};

  group('hasAnyInvestmentOnServer', () {
    test('is true when the server has an active investment', () async {
      firestore.activeOnServer = () =>
          querySnapshot(docs: oneDoc, fromCache: false);

      expect(await firestore.repository().hasAnyInvestmentOnServer(), isTrue);
    });

    test('is true when the server has only an archived investment', () async {
      firestore.archivedOnServer = () =>
          querySnapshot(docs: oneDoc, fromCache: false);

      expect(await firestore.repository().hasAnyInvestmentOnServer(), isTrue);
    });

    test('is false when both collections are empty on the server', () async {
      expect(await firestore.repository().hasAnyInvestmentOnServer(), isFalse);
    });

    test('reads one document of each collection from the server only, '
        'never the cache', () async {
      await firestore.repository().hasAnyInvestmentOnServer();

      for (final collection in [firestore.active, firestore.archived]) {
        verify(() => collection.limit(1)).called(1);
        final options =
            verify(
                  () =>
                      firestore.firstDocQueries[collection]!.get(captureAny()),
                ).captured.single
                as GetOptions;
        expect(options.source, Source.server);
      }
    });

    test('throws when the server cannot be reached', () async {
      firestore.activeOnServer = () => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );

      await expectLater(
        firestore.repository().hasAnyInvestmentOnServer(),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
    });
  });

  group('getAllArchivedInvestments', () {
    test('returns what a one-shot read finds, even an empty list from the '
        'cache', () async {
      firestore.archivedOnServer = () =>
          querySnapshot(docs: oneDoc, fromCache: true);
      final archived = await firestore.repository().getAllArchivedInvestments();
      expect(archived.map((i) => i.name), ['HDFC FD']);

      firestore.archivedOnServer = () => querySnapshot(fromCache: true);
      expect(await firestore.repository().getAllArchivedInvestments(), isEmpty);
    });
  });
}
