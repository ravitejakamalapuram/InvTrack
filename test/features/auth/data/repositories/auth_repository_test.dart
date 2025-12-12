import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/data/repositories/auth_repository_impl.dart';

import 'package:mocktail/mocktail.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

void main() {
  late AuthRepositoryImpl authRepository;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockSecureStorage = MockFlutterSecureStorage();
    
    // Default behavior for secure storage
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async => {});
    when(() => mockSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async => {});

    // Default behavior for google sign in
    when(() => mockGoogleSignIn.onCurrentUserChanged)
        .thenAnswer((_) => Stream.value(null));
    when(() => mockGoogleSignIn.currentUser).thenReturn(null);

    authRepository = AuthRepositoryImpl(mockGoogleSignIn, mockSecureStorage);
  });

  group('AuthRepositoryImpl', () {
    test('signInAsGuest should sign out google and persist guest flag', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

      final user = await authRepository.signInAsGuest();

      verify(() => mockGoogleSignIn.signOut()).called(1);
      verify(() => mockSecureStorage.write(key: 'is_guest', value: 'true')).called(1);

      expect(user?.isGuest, true);
      expect(user?.id, startsWith('guest_'));
    });

    test('signOut should clear guest flag and sign out google', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

      await authRepository.signOut();

      verify(() => mockSecureStorage.delete(key: 'is_guest')).called(1);
      verify(() => mockGoogleSignIn.signOut()).called(1);
      expect(authRepository.currentUser, null);
    });
  });
}
