import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:http/http.dart' as http;
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/sync/domain/services/sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockClient extends Mock implements http.Client {}
class MockRef extends Mock implements Ref {}

void main() {
  late MockGoogleSignIn mockGoogleSignIn;

  late MockRef mockRef;
  late SyncService syncService;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();

    mockRef = MockRef();
    syncService = SyncService(mockRef);

    when(() => mockRef.read(googleSignInProvider)).thenReturn(mockGoogleSignIn);
  });

  // Note: Testing SyncService fully requires mocking GoogleDriveDataSource and GoogleSheetsDataSource
  // which are instantiated inside the service.
  // For a proper unit test, we should inject these datasources or factories.
  // Given the current implementation, we can't easily mock them without refactoring.
  //
  // However, we can verify that the service handles the "not signed in" case.

  test('pushToSheet returns early if user is not signed in', () async {
    when(() => mockGoogleSignIn.currentUser).thenReturn(null);

    await syncService.pushToSheet();

    verify(() => mockGoogleSignIn.currentUser).called(1);
    // Cannot verify extension method calls easily with Mocktail
    // verifyNever(() => mockGoogleSignIn.authenticatedClient());
  });
}
