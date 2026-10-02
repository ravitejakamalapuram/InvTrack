import 'dart:async';

import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

/// Test users shared by the guest sign-out and backup-merge tests.
const guestUser = UserEntity(id: 'anon-uid', email: '', isAnonymous: true);

const googleUser = UserEntity(
  id: 'google-uid',
  email: 'existing@example.com',
  displayName: 'Existing User',
);

/// In-memory [AuthRepository] whose auth stream behaves like Firebase:
/// new listeners get the current user first, then every change.
class FakeAuthRepository extends Fake implements AuthRepository {
  FakeAuthRepository(this._user);

  UserEntity? _user;
  final _changes = StreamController<UserEntity?>.broadcast();

  /// What [signInWithGoogle] does. Defaults to the user cancelling.
  Future<UserEntity?> Function() onSignInWithGoogle = () async => null;

  /// What [linkAnonymousToGoogle] does. Defaults to "Google account exists".
  Future<UserEntity?> Function() onLinkAnonymousToGoogle = () async =>
      throw AuthException(
        technicalMessage: 'credential-already-in-use during account linking',
        shouldReport: false,
        code: AuthExceptionCode.credentialAlreadyInUse,
      );

  int signInWithGoogleCalls = 0;
  int signOutCalls = 0;

  /// Simulates Firebase reporting a new user on the auth stream.
  void emit(UserEntity? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Stream<UserEntity?> get authStateChanges {
    StreamSubscription<UserEntity?>? changes;
    late final StreamController<UserEntity?> controller;
    controller = StreamController<UserEntity?>(
      onListen: () {
        controller.add(_user);
        changes = _changes.stream.listen(controller.add);
      },
      onCancel: () async {
        await changes?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  UserEntity? get currentUser => _user;

  @override
  Future<UserEntity?> signInWithGoogle() {
    signInWithGoogleCalls++;
    return onSignInWithGoogle();
  }

  @override
  Future<UserEntity?> linkAnonymousToGoogle() => onLinkAnonymousToGoogle();

  @override
  Future<void> signOut() async {
    signOutCalls++;
    emit(null);
  }
}
