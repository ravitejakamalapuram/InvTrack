import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/auth/domain/usecases/link_account_usecase.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late LinkAccountUseCase useCase;

  const anonymousUser = UserEntity(
    id: 'anon-uid-123',
    email: '',
    isAnonymous: true,
  );

  const linkedUser = UserEntity(
    id: 'anon-uid-123', // same UID preserved
    email: 'user@example.com',
    displayName: 'Test User',
    isAnonymous: false,
  );

  const nonAnonymousUser = UserEntity(
    id: 'google-uid-456',
    email: 'existing@example.com',
    isAnonymous: false,
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    useCase = LinkAccountUseCase(mockAuthRepository);
  });

  group('LinkAccountUseCase - notAnonymous cases', () {
    test('returns notAnonymous when currentUser is null', () async {
      when(() => mockAuthRepository.currentUser).thenReturn(null);

      final result = await useCase.execute();

      expect(result, isA<LinkAccountNotAnonymous>());
      verifyNever(() => mockAuthRepository.linkAnonymousToGoogle());
    });

    test('returns notAnonymous when currentUser is not anonymous', () async {
      when(() => mockAuthRepository.currentUser).thenReturn(nonAnonymousUser);

      final result = await useCase.execute();

      expect(result, isA<LinkAccountNotAnonymous>());
      verifyNever(() => mockAuthRepository.linkAnonymousToGoogle());
    });
  });

  group('LinkAccountUseCase - success cases', () {
    test('returns success with linked user when linking succeeds', () async {
      when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
      when(
        () => mockAuthRepository.linkAnonymousToGoogle(),
      ).thenAnswer((_) async => linkedUser);

      final result = await useCase.execute();

      expect(result, isA<LinkAccountSuccess>());
      final success = result as LinkAccountSuccess;
      expect(success.user.id, 'anon-uid-123');
      expect(success.user.isAnonymous, isFalse);
      expect(success.user.email, 'user@example.com');
      verify(() => mockAuthRepository.linkAnonymousToGoogle()).called(1);
    });

    test('returns failure when linked user is still anonymous', () async {
      const stillAnonymousUser = UserEntity(
        id: 'anon-uid-123',
        email: '',
        isAnonymous: true,
      );

      when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
      when(
        () => mockAuthRepository.linkAnonymousToGoogle(),
      ).thenAnswer((_) async => stillAnonymousUser);

      final result = await useCase.execute();

      expect(result, isA<LinkAccountFailure>());
      final failure = result as LinkAccountFailure;
      expect(failure.message, contains('still anonymous'));
    });

    test('returns failure when linkAnonymousToGoogle returns null', () async {
      when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
      when(
        () => mockAuthRepository.linkAnonymousToGoogle(),
      ).thenAnswer((_) async => null);

      final result = await useCase.execute();

      expect(result, isA<LinkAccountFailure>());
    });
  });

  group('LinkAccountUseCase - accountExists cases', () {
    test(
      'returns accountExists when AuthException message contains "already registered"',
      () async {
        when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
        when(
          () => mockAuthRepository.linkAnonymousToGoogle(),
        ).thenThrow(
          AuthException(
            userMessage:
                'This Google account is already registered. Please use the backup & merge option.',
            technicalMessage: 'credential-already-in-use during account linking',
            shouldReport: false,
          ),
        );

        final result = await useCase.execute();

        expect(result, isA<LinkAccountAccountExists>());
      },
    );

    test(
      'returns accountExists when AuthException message contains "already exists"',
      () async {
        when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
        when(
          () => mockAuthRepository.linkAnonymousToGoogle(),
        ).thenThrow(
          AuthException(
            userMessage: 'Account already exists with a different credential.',
            technicalMessage: 'account-exists-with-different-credential',
            shouldReport: false,
          ),
        );

        final result = await useCase.execute();

        expect(result, isA<LinkAccountAccountExists>());
      },
    );
  });

  group('LinkAccountUseCase - cancelled cases', () {
    test(
      'returns cancelled when AuthException message contains "cancelled"',
      () async {
        when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
        when(
          () => mockAuthRepository.linkAnonymousToGoogle(),
        ).thenThrow(AuthException.signInCancelled());

        final result = await useCase.execute();

        expect(result, isA<LinkAccountCancelled>());
      },
    );
  });

  group('LinkAccountUseCase - failure cases', () {
    test(
      'returns failure with message for other AuthExceptions',
      () async {
        when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
        when(
          () => mockAuthRepository.linkAnonymousToGoogle(),
        ).thenThrow(
          AuthException(
            userMessage: 'Invalid Google credentials. Please try again.',
            technicalMessage: 'Invalid credential for linking',
            shouldReport: true,
          ),
        );

        final result = await useCase.execute();

        expect(result, isA<LinkAccountFailure>());
        final failure = result as LinkAccountFailure;
        expect(failure.message, 'Invalid Google credentials. Please try again.');
      },
    );

    test(
      'returns failure with toString for generic exceptions',
      () async {
        when(() => mockAuthRepository.currentUser).thenReturn(anonymousUser);
        when(
          () => mockAuthRepository.linkAnonymousToGoogle(),
        ).thenThrow(Exception('Network error'));

        final result = await useCase.execute();

        expect(result, isA<LinkAccountFailure>());
        final failure = result as LinkAccountFailure;
        expect(failure.message, contains('Network error'));
      },
    );
  });

  group('LinkAccountResult sealed class', () {
    test('LinkAccountSuccess holds linked user', () {
      final result = LinkAccountResult.success(linkedUser);
      expect(result, isA<LinkAccountSuccess>());
      expect((result as LinkAccountSuccess).user, linkedUser);
    });

    test('LinkAccountAccountExists is constructed correctly', () {
      final result = LinkAccountResult.accountExists();
      expect(result, isA<LinkAccountAccountExists>());
    });

    test('LinkAccountNotAnonymous is constructed correctly', () {
      final result = LinkAccountResult.notAnonymous();
      expect(result, isA<LinkAccountNotAnonymous>());
    });

    test('LinkAccountCancelled is constructed correctly', () {
      final result = LinkAccountResult.cancelled();
      expect(result, isA<LinkAccountCancelled>());
    });

    test('LinkAccountFailure holds message', () {
      const message = 'Something went wrong';
      final result = LinkAccountResult.failure(message);
      expect(result, isA<LinkAccountFailure>());
      expect((result as LinkAccountFailure).message, message);
    });
  });
}