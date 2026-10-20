// ignore_for_file: subtype_of_sealed_class
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/services/locale_detection_service.dart';
import 'package:inv_tracker/features/user_profile/data/repositories/firestore_user_profile_repository.dart';
import 'package:inv_tracker/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  const userId = 'user-1';
  late _MockDoc ref;
  late FirestoreUserProfileRepository repository;

  _MockSnapshot snapshot({bool exists = true, Map<String, dynamic>? data}) {
    final s = _MockSnapshot();
    when(() => s.exists).thenReturn(exists);
    when(s.data).thenReturn(data);
    return s;
  }

  setUp(() {
    ref = _MockDoc();
    final firestore = _MockFirestore();
    final users = _MockCollection();
    final userDoc = _MockDoc();
    final profile = _MockCollection();
    when(() => firestore.collection('users')).thenReturn(users);
    when(() => users.doc(userId)).thenReturn(userDoc);
    when(() => userDoc.collection('profile')).thenReturn(profile);
    when(() => profile.doc('settings')).thenReturn(ref);
    repository = FirestoreUserProfileRepository(
      firestore: firestore,
      userId: userId,
      baseCurrency: () => 'INR',
    );
  });

  setUpAll(() => registerFallbackValue(SetOptions(merge: true)));

  group('getProfile', () {
    test('returns null when the document does not exist', () async {
      when(ref.get).thenAnswer((_) async => snapshot(exists: false));
      expect(await repository.getProfile(), isNull);
    });

    test('returns null when the document exists but holds no data', () async {
      when(ref.get).thenAnswer((_) async => snapshot());
      expect(await repository.getProfile(), isNull);
    });

    test(
      'a document with no fields takes the base currency, not USD',
      () async {
        when(ref.get).thenAnswer((_) async => snapshot(data: {}));
        final profile = await repository.getProfile();
        expect(profile!.userId, userId);
        expect(profile.preferredCurrency, 'INR');
        expect(profile.dateFormatPattern, DateFormatPattern.mdy);
      },
    );

    test('reads the stored fields', () async {
      when(ref.get).thenAnswer(
        (_) async => snapshot(
          data: {
            'preferredCurrency': 'EUR',
            'dateFormatPattern': 'dmy',
            'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
          },
        ),
      );
      final profile = await repository.getProfile();
      expect(profile!.preferredCurrency, 'EUR');
      expect(profile.dateFormatPattern, DateFormatPattern.dmy);
      expect(profile.createdAt, DateTime(2026, 1, 1));
    });
  });

  group('watchProfile', () {
    test(
      'maps a missing document to null and a present one to a profile',
      () async {
        when(() => ref.snapshots()).thenAnswer(
          (_) => Stream.fromIterable([
            snapshot(exists: false),
            snapshot(data: {'preferredCurrency': 'GBP'}),
          ]),
        );
        final emitted = await repository.watchProfile().toList();
        expect(emitted[0], isNull);
        expect(emitted[1]!.preferredCurrency, 'GBP');
      },
    );
  });

  group('writes', () {
    final entity = UserProfileEntity(
      userId: userId,
      preferredCurrency: 'INR',
      preferredLocale: 'en_IN',
      countryCode: 'IN',
      languageCode: 'en',
      dateFormatPattern: DateFormatPattern.dmy,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('saveProfile merges the model fields into the document', () async {
      when(() => ref.set(any(), any())).thenAnswer((_) async {});
      await repository.saveProfile(entity);
      final captured = verify(
        () => ref.set(captureAny(), captureAny()),
      ).captured;
      expect((captured[0] as Map)['preferredCurrency'], 'INR');
      expect((captured[1] as SetOptions).merge, isTrue);
    });

    testWidgets('saveProfile gives up after 5s when the write is only cached', (
      tester,
    ) async {
      when(
        () => ref.set(any(), any()),
      ).thenAnswer((_) => Completer<void>().future);
      var done = false;
      repository.saveProfile(entity).then((_) => done = true);
      await tester.pump(const Duration(seconds: 4));
      expect(done, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(done, isTrue);
    });

    test('deleteProfile deletes the document', () async {
      when(ref.delete).thenAnswer((_) async {});
      await repository.deleteProfile();
      verify(ref.delete).called(1);
    });
  });

  group('profileExists', () {
    test('reflects whether the document exists', () async {
      when(ref.get).thenAnswer((_) async => snapshot(exists: false));
      expect(await repository.profileExists(), isFalse);
      when(ref.get).thenAnswer((_) async => snapshot());
      expect(await repository.profileExists(), isTrue);
    });
  });
}
