// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/fire_number/data/repositories/firestore_fire_settings_repository.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_settings_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  const userId = 'user-1';
  late _MockDoc ref;
  late FirestoreFireSettingsRepository repository;

  _MockSnapshot snapshot({bool exists = true, Map<String, dynamic>? data}) {
    final s = _MockSnapshot();
    when(() => s.exists).thenReturn(exists);
    when(() => s.id).thenReturn('settings');
    when(s.data).thenReturn(data);
    return s;
  }

  Map<String, dynamic> stored({bool setupComplete = true}) => {
    'monthlyExpenses': 75000,
    'birthYear': 1990,
    'targetFireAge': 50,
    'currency': 'INR',
    'isSetupComplete': setupComplete,
    'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 2, 1)),
  };

  setUpAll(() => registerFallbackValue(SetOptions(merge: true)));

  setUp(() {
    ref = _MockDoc();
    final firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    final fire = _MockCollection();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(userId)).thenReturn(userDoc);
    when(() => userDoc.collection('fireSettings')).thenReturn(fire);
    when(() => fire.doc('settings')).thenReturn(ref);
    repository = FirestoreFireSettingsRepository(
      firestore: firestore,
      userId: userId,
    );
  });

  group('getSettings', () {
    test('returns null when the document does not exist', () async {
      when(ref.get).thenAnswer((_) async => snapshot(exists: false));
      expect(await repository.getSettings(), isNull);
    });

    test('returns null when the document exists but holds no data', () async {
      when(ref.get).thenAnswer((_) async => snapshot());
      expect(await repository.getSettings(), isNull);
    });

    test('reads the stored settings with the document id', () async {
      when(ref.get).thenAnswer((_) async => snapshot(data: stored()));
      final settings = await repository.getSettings();
      expect(settings!.id, 'settings');
      expect(settings.monthlyExpenses, 75000);
      expect(settings.birthYear, 1990);
      expect(settings.currency, 'INR');
    });
  });

  group('watchSettings', () {
    test('maps a missing document to null and a present one to settings',
        () async {
      when(() => ref.snapshots()).thenAnswer(
        (_) => Stream.fromIterable([
          snapshot(exists: false),
          snapshot(data: stored()),
        ]),
      );
      final emitted = await repository.watchSettings().toList();
      expect(emitted[0], isNull);
      expect(emitted[1]!.monthlyExpenses, 75000);
    });
  });

  group('writes', () {
    test('saveSettings merges the model fields into the document', () async {
      when(() => ref.set(any(), any())).thenAnswer((_) async {});
      await repository.saveSettings(
        FireSettingsEntity(
          id: 'settings',
          monthlyExpenses: 75000,
          birthYear: 1990,
          targetFireAge: 50,
          currency: 'INR',
          isSetupComplete: true,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      final captured =
          verify(() => ref.set(captureAny(), captureAny())).captured;
      expect((captured[0] as Map)['monthlyExpenses'], 75000);
      expect((captured[0] as Map)['currency'], 'INR');
      expect((captured[1] as SetOptions).merge, isTrue);
    });

    test('deleteSettings deletes the document', () async {
      when(ref.delete).thenAnswer((_) async {});
      await repository.deleteSettings();
      verify(ref.delete).called(1);
    });
  });

  group('hasCompletedSetup', () {
    test('is false with no settings and with unfinished setup', () async {
      when(ref.get).thenAnswer((_) async => snapshot(exists: false));
      expect(await repository.hasCompletedSetup(), isFalse);
      when(ref.get)
          .thenAnswer((_) async => snapshot(data: stored(setupComplete: false)));
      expect(await repository.hasCompletedSetup(), isFalse);
    });

    test('is true once setup is complete', () async {
      when(ref.get).thenAnswer((_) async => snapshot(data: stored()));
      expect(await repository.hasCompletedSetup(), isTrue);
    });
  });
}
