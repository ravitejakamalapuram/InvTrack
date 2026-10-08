// A121 (#895): sample data includes a goal, so before it is written the
// server, never the cache, must also say whether the account holds a goal.

// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/data/repositories/firestore_goal_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class _MockQueryDoc extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

QuerySnapshot<Map<String, dynamic>> _snapshot({required int docs}) {
  final snapshot = _MockQuerySnapshot();
  when(
    () => snapshot.docs,
  ).thenReturn([for (var i = 0; i < docs; i++) _MockQueryDoc()]);
  return snapshot;
}

void main() {
  setUpAll(() => registerFallbackValue(const GetOptions()));

  late _MockFirestore firestore;
  late Map<String, _MockQuery> firstDoc;
  late Map<String, QuerySnapshot<Map<String, dynamic>> Function()> onServer;

  setUp(() {
    firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc('uid-1')).thenReturn(userDoc);
    firstDoc = {};
    onServer = {};
    for (final name in ['goals', 'archivedGoals']) {
      final collection = _MockCollection();
      final query = _MockQuery();
      firstDoc[name] = query;
      onServer[name] = () => _snapshot(docs: 0);
      when(() => userDoc.collection(name)).thenReturn(collection);
      when(() => collection.limit(1)).thenReturn(query);
      when(() => query.get(any())).thenAnswer((_) async => onServer[name]!());
    }
  });

  FirestoreGoalRepository repository() => FirestoreGoalRepository(
    firestore: firestore,
    userId: 'uid-1',
    baseCurrency: () => 'INR',
  );

  test('is true when the server has an active goal', () async {
    onServer['goals'] = () => _snapshot(docs: 1);

    expect(await repository().hasAnyGoalOnServer(), isTrue);
  });

  test('is true when the server has only an archived goal', () async {
    onServer['archivedGoals'] = () => _snapshot(docs: 1);

    expect(await repository().hasAnyGoalOnServer(), isTrue);
  });

  test('is false when both goal collections are empty on the server', () async {
    expect(await repository().hasAnyGoalOnServer(), isFalse);
  });

  test('reads one document of each collection from the server only, never '
      'the cache', () async {
    await repository().hasAnyGoalOnServer();

    for (final query in firstDoc.values) {
      final options =
          verify(() => query.get(captureAny())).captured.single as GetOptions;
      expect(options.source, Source.server);
    }
  });

  test('throws when the server cannot be reached', () async {
    onServer['goals'] = () =>
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');

    await expectLater(
      repository().hasAnyGoalOnServer(),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
      ),
    );
  });
}
